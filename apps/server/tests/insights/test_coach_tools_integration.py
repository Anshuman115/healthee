"""Seeded-DB tests for the coach's tools + its history-rich context.

Proves each tool returns correct JSON on real v2 rows (not a guess), that
``compare_event`` on a seeded FASTING schedule yields on/off-day deltas (the
fasting-schedule analysis COACH_PROMPT.md requires), and that the coach context
carries ≥30 days of the intervention log (the history requirement).
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.insights import coach_tools, manifest
from healthee.insights.coach_context import build_coach_context

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analytics"))
import _seed_db as sd  # type: ignore[import-not-found]  # noqa: E402 — shared v2 seed helpers

pytestmark = pytest.mark.integration


def _seed_fasting_schedule() -> tuple[list, int]:
    """30 days of HRV with a fasting log on even-indexed days (HRV higher then)."""
    migrate.apply_migrations()
    days = sd.recent_days(30)
    fasting_days = [d for i, d in enumerate(days) if i % 2 == 0]
    sd.clean("kv")
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(
            cur,
            "hrv_sleep_avg",
            {d: (55.0 if d in fasting_days else 45.0) for d in days},
        )
        sd.seed_daily(cur, "rhr_daily", {d: 54.0 + (i % 3) for i, d in enumerate(days)})
        for d in fasting_days:
            sd.seed_event(cur, "fasting", d)
    return days, len(fasting_days)


def test_query_metric_reads_real_values(db: None) -> None:  # noqa: ARG001
    _seed_fasting_schedule()
    avg = coach_tools.query_metric(SENTINEL_USER_ID, SENTINEL_TZ, "rhr_daily", days=30, stat="avg")
    assert avg["metric"] == "rhr_daily"
    assert 54.0 <= avg["avg"] <= 56.0
    assert avg["n"] == 30
    latest = coach_tools.query_metric(
        SENTINEL_USER_ID, SENTINEL_TZ, "rhr_daily", days=30, stat="latest"
    )
    assert "latest" in latest and "as_of" in latest


def test_query_metric_no_data_is_honest(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    sd.clean()
    out = coach_tools.query_metric(SENTINEL_USER_ID, SENTINEL_TZ, "hrv_sleep_avg", days=7)
    assert out["note"] == "no data for this metric/range"


def test_compare_event_on_a_fasting_schedule_returns_deltas(db: None) -> None:  # noqa: ARG001
    _, n_fasting = _seed_fasting_schedule()
    out = coach_tools.compare_event(
        SENTINEL_USER_ID, SENTINEL_TZ, "fasting", "hrv_sleep_avg", days=60
    )
    assert out["event"] == "fasting"
    assert out["on_days_avg"] == 55.0  # HRV on fasting days
    assert out["off_days_avg"] == 45.0  # HRV off fasting days
    assert out["delta"] == 10.0
    assert out["n_on"] == n_fasting
    assert out["note"] == "observational, single-subject — a hint, not proof"


def test_compare_event_unlogged_is_honest(db: None) -> None:  # noqa: ARG001
    _seed_fasting_schedule()
    out = coach_tools.compare_event(
        SENTINEL_USER_ID, SENTINEL_TZ, "sauna", "hrv_sleep_avg", days=60
    )
    assert "no 'sauna' logged yet" in out["note"]


def test_sleep_consistency_tool(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    nights = sd.recent_days(10)
    sd.clean()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        for d in nights:
            sd.seed_night(cur, d, rem=90, light=240, deep=90, wake=20)
    out = coach_tools.execute_tool("sleep_consistency", {"days": 28}, SENTINEL_USER_ID, SENTINEL_TZ)
    assert out["nights"] == 10
    assert "median_bedtime" in out and "sri" in out


def test_log_entry_writes_a_manual_row(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    sd.clean()
    result = coach_tools.log_entry(SENTINEL_USER_ID, "caffeine", amount=80)
    assert result == {"ok": True}
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "SELECT amount FROM manual_entry WHERE kind='caffeine' ORDER BY ts DESC LIMIT 1"
        )
        row = cur.fetchone()
    assert row is not None and row[0] == 80


def test_get_knowledge_returns_a_note_body() -> None:
    note_id = next(iter(sorted(manifest.note_ids())))
    out = coach_tools.get_knowledge(None, note_id)
    assert out["note_id"] == note_id
    assert out["cite_as"] == f"[{note_id}]"
    assert out["body"]  # a non-empty body the coach can ground a claim on


def test_get_knowledge_by_topic() -> None:
    out = coach_tools.get_knowledge("sleep regularity", None)
    assert out.get("note_id")
    assert out.get("body")


def test_coach_context_carries_the_fasting_history_over_30_days(db: None) -> None:  # noqa: ARG001
    _, n_fasting = _seed_fasting_schedule()
    context = build_coach_context(
        "how does fasting affect my recovery?", SENTINEL_USER_ID, SENTINEL_TZ, days=30
    )
    assert "Manual entries" in context  # the intervention log section is present
    fasting_lines = [ln for ln in context.splitlines() if "fasting" in ln.lower()]
    assert len(fasting_lines) >= n_fasting  # the whole schedule, not just the last day
