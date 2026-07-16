"""Seeded-DB recs generation with a stubbed LLM — the honesty + wiring contract.

Proves, end to end and offline:
  * recs go THROUGH the choke point and land in ``recommendation`` with resolvable
    ``[note_id]`` citations AND the ``raw_llm_prompt`` / ``raw_llm_response`` audit
    columns (the schema fix);
  * an individual rec whose ``research_note_ids`` cites an unknown note is DROPPED
    while the valid rec ships;
  * the signals read the DB ``profile`` table (not a JSON file);
  * ``/api/today`` then returns non-empty ``recommendations``;
  * a fabricated INLINE citation is blocked by the choke-point validator — nothing
    ships (the recs never carry an ungrounded claim).
"""

from __future__ import annotations

import sys
from datetime import date, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from tests.insights._ids import ESTABLISHED_ID
from tests.insights._stub import StubLLM

from healthee.api.app import create_app
from healthee.core.config import get_settings
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.jobs import recs
from healthee.jobs.recs_context import build_recs_signals

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analytics"))
import _seed_db as sd  # type: ignore[import-not-found]  # noqa: E402 — shared v2 seed helpers

pytestmark = pytest.mark.integration

_TOKEN = "recs-test-token"
_AUTH = {"Authorization": f"Bearer {_TOKEN}"}
_DAY = date(2026, 7, 15)

# A response the choke point validates (inline cites a real Established note) with
# TWO recs: the first is fully citable; the second cites an unknown note ONLY in
# its research_note_ids array (inline cite is valid, so the whole response still
# passes the choke point) — it must be dropped by the per-rec check.
# __EST__ is substituted with a real current Established id (robust to reconciliation).
_GOOD_PLUS_UNCITABLE = """{"recommendations": [
  {"action": "Aim for a 30-minute brisk walk today.",
   "rationale": "Consistent moderate activity may support recovery [__EST__].",
   "expected_effect": "chips away at your weekly MVPA gap",
   "category": "activity", "evidence_grade": 3,
   "research_note_ids": ["__EST__"], "signal_source": "mvpa_gap"},
  {"action": "Wind down 30 minutes earlier tonight.",
   "rationale": "An earlier wind-down may lengthen time in bed [__EST__].",
   "category": "sleep", "evidence_grade": 2,
   "research_note_ids": ["not_a_real_note"], "signal_source": "sleep_debt"}
]}""".replace("__EST__", ESTABLISHED_ID)

# Inline citation is fabricated → the blocking validator rejects it (both tries) →
# the choke point returns its honest fallback → recs parses nothing.
_FABRICATED = """{"recommendations": [
  {"action": "Do hard intervals today.",
   "rationale": "Intervals raise VO2max quickly [totally_made_up_note].",
   "category": "fitness", "evidence_grade": 3,
   "research_note_ids": ["totally_made_up_note"], "signal_source": "vo2max"}
]}"""


def _seed(dob: date = date(1990, 5, 1)) -> None:
    migrate.apply_migrations()
    days = [date.today() - timedelta(days=i) for i in range(30)]
    sd.clean("kv", "recommendation")
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_profile(cur, dob=dob, sex="male", height_cm=178.0)
        sd.seed_daily(cur, "rhr_daily", {d: 54.0 + (i % 3) for i, d in enumerate(days)})
        sd.seed_daily(cur, "hrv_sleep_avg", {d: 42.0 + (i % 4) for i, d in enumerate(days)})
        sd.seed_daily(cur, "mvpa_min", {d: 15.0 + (i % 5) for i, d in enumerate(days)})
        sd.seed_daily(cur, "recovery_score", {d: 62.0 for d in days})


def _rows() -> list[tuple]:
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "SELECT rank, action, research_note_ids, raw_llm_prompt, raw_llm_response "
            "FROM recommendation WHERE date = %s ORDER BY rank",
            (_DAY,),
        )
        return cur.fetchall()


def test_recs_persist_with_citations_and_audit_columns(db: None) -> None:  # noqa: ARG001
    _seed()
    stub = StubLLM([_GOOD_PLUS_UNCITABLE])
    result = recs.generate_recs(SENTINEL_USER_ID, SENTINEL_TZ, _DAY, client=stub)

    assert result["persisted"] == 1  # the good rec
    assert result["dropped"] == 1  # the uncitable rec
    rows = _rows()
    assert len(rows) == 1
    rank, action, note_ids, raw_prompt, raw_response = rows[0]
    assert rank == 1
    assert "walk" in action.lower()
    assert note_ids == [ESTABLISHED_ID]  # resolvable citation
    assert raw_prompt and "SIGNALS" in raw_prompt  # audit trail written
    assert raw_response and "recommendations" in raw_response


def test_signals_read_the_db_profile_not_a_json_file(db: None) -> None:  # noqa: ARG001
    _seed(dob=date.today().replace(year=date.today().year - 34))
    signals = build_recs_signals(SENTINEL_USER_ID, SENTINEL_TZ)
    assert "Profile:" in signals
    assert "age 34" in signals  # computed from the profile.dob row, v2-native


def test_today_endpoint_returns_the_persisted_recommendations(
    db: None, monkeypatch: pytest.MonkeyPatch
) -> None:  # noqa: ARG001
    _seed()
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", _TOKEN)
    get_settings.cache_clear()
    # Persist for today's real date so /api/today (which reads the latest day) sees them.
    recs.generate_recs(SENTINEL_USER_ID, SENTINEL_TZ, client=StubLLM([_GOOD_PLUS_UNCITABLE]))

    api = TestClient(create_app())
    resp = api.get("/api/today", headers=_AUTH)
    assert resp.status_code == 200
    recommendations = resp.json()["recommendations"]
    assert recommendations  # non-empty — the field /api/today used to return []
    assert recommendations[0]["research_note_ids"] == [ESTABLISHED_ID]
    get_settings.cache_clear()


def test_a_fabricated_inline_citation_is_blocked_nothing_ships(db: None) -> None:  # noqa: ARG001
    _seed()
    stub = StubLLM([_FABRICATED, _FABRICATED])  # both tries fail validation
    result = recs.generate_recs(SENTINEL_USER_ID, SENTINEL_TZ, _DAY, client=stub)

    assert result["validated"] is False  # the choke point fell back
    assert result["persisted"] == 0
    assert _rows() == []  # no ungrounded rec reaches the table
    assert stub.calls == 2  # original + one nudged retry, then the honest fallback
