"""An active illness flag must override push-style recovery guidance.

`/api/today` returns BOTH `recovery_score.guidance` and `illness_flag` in the same
payload. Before this suite, an owner with an active illness flag could be told "a
good day to push: intervals or a harder session are on the table" on the same screen
that shows their illness flag — the guidance was a static band→string map that never
took `illness_flag` as an input. Both halves are deterministic and free-tier, so the
contradiction needed no LLM to fire and no subscription to reach a user.

The seeded fixture is the bug: `seed_all` writes recovery 72 (band "high") AND an
active moderate illness flag for today, which is exactly the shape that produced the
committed contract snapshot's contradiction.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import timedelta

import pytest
from tests.contracts import seed

from healthee.core.db import admin_connection, tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.read.recovery import recovery_score_payload
from healthee.read.today import today_snapshot

pytestmark = pytest.mark.integration

_PUSH_PHRASES = ("good day to push", "a harder session", "intervals")


def _assert_no_push(guidance: str) -> None:
    """No phrasing that invites a hard session may survive an active illness flag."""
    for phrase in _PUSH_PHRASES:
        assert phrase not in guidance, (
            f"push guidance survived an active illness flag: {guidance!r}"
        )


@pytest.fixture
def seeded(db) -> Iterator[None]:  # noqa: ARG001 — db fixture provides/skips the DB
    seed.seed_all()
    yield


def _set_illness(severity: str | None, *, days_ago: int = 0) -> None:
    """Replace the seeded owner's illness flag (or clear it entirely)."""
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM illness_flag WHERE user_id = %s", (SENTINEL_USER_ID,))
        if severity is None:
            return
        cur.execute(
            "INSERT INTO illness_flag (user_id, date, severity, rr_delta_bpm, temp_delta_c, "
            "sustained, research_note_ids) VALUES (%s,%s,%s,2.4,0.35,true,%s)",
            (
                SENTINEL_USER_ID,
                user_today(SENTINEL_TZ) - timedelta(days=days_ago),
                severity,
                ["respiratory_rate_normal", "skin_temp_signals"],
            ),
        )


def _guidance() -> str:
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        payload = recovery_score_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload is not None
    return payload["guidance"]


def test_high_recovery_plus_active_high_flag_does_not_advise_pushing(seeded: None) -> None:
    """The bug, at its worst: "well recovered, go push" while actively flagged ill."""
    _set_illness("high")
    _assert_no_push(_guidance())


def test_high_recovery_plus_active_moderate_flag_does_not_advise_pushing(seeded: None) -> None:
    _set_illness("moderate")
    _assert_no_push(_guidance())


def test_the_override_says_why_and_keeps_the_number(seeded: None) -> None:
    """The honest shape: the GUIDANCE changes, the recovery number is not dropped."""
    _set_illness("high")
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        payload = recovery_score_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload is not None
    assert payload["recovery"] == 72  # the measured number is still reported
    assert payload["band"] == "high"  # and so is its band — we don't fake a low score
    assert "illness" in payload["guidance"].lower()


def test_no_active_flag_leaves_the_guidance_unchanged(seeded: None) -> None:
    """No regression: without a flag the ported band text is exactly as before."""
    _set_illness(None)
    guidance = _guidance()
    assert guidance.startswith("Well recovered — a good day to push")


def test_a_flag_older_than_the_window_does_not_override(seeded: None) -> None:
    """The boundary: `illness_flag_payload` reads the last 2 days; day 3 is not active."""
    _set_illness("high", days_ago=3)
    assert _guidance().startswith("Well recovered — a good day to push")


def test_a_flag_at_the_edge_of_the_window_still_overrides(seeded: None) -> None:
    """...but a 2-day-old flag IS active, and must still override."""
    _set_illness("high", days_ago=2)
    assert "illness" in _guidance().lower()


def test_today_never_contradicts_its_own_illness_card(seeded: None) -> None:
    """The real defect: both blocks ship in ONE payload and must not disagree."""
    _set_illness("high")
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        payload = today_snapshot(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload["illness_flag"] is not None
    assert payload["illness_flag"]["severity"] == "high"
    _assert_no_push(payload["recovery_score"]["guidance"])
