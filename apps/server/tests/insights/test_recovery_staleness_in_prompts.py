"""A stale recovery score must not reach the model as TODAY's intensity ceiling.

``recovery_score_payload`` has always carried ``date``. Both LLM context builders dropped
it and relabelled the value — ``insights/coach_context`` wrote "## Today's recovery … let
it set intensity advice", ``jobs/recs_context`` wrote "SETS today's intensity ceiling" —
so an unsynced strap fed a days-old score to the model as today's readiness, and it drove
the intensity prescription. This is the worst site in the class: the number never reaches
a UI where a rendered date could rescue it, and the surface it does reach prescribes
training.

These tests assert on the **prompt text**, not on a payload. The defect was never in the
payload — the payload was right — it was in what the model was told, so a test that
checked a dict would have passed throughout.

The fix deliberately KEEPS the number. Deleting a stale recovery would remove the
conservative ceiling ([[recovery_readiness]]: "never prescribe a hard session on low
recovery"), i.e. trade a mislabelled constraint for no constraint — a worse trade. So
each stale case asserts three things together: the "today" claim is gone, the age is
stated, and the score is still there.
"""

from __future__ import annotations

import json
from datetime import date, timedelta

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.insights.coach_context import build_coach_context
from healthee.jobs.recs_context import build_recs_signals
from healthee.read.recovery import STALE_RECOVERY_DIRECTIVE

pytestmark = pytest.mark.integration

_RECOVERY = 72.0
_FACTORS = {
    "factors": {"sleep": {"sub": 60}, "hrv": {"sub": 80}},
    "weights": {"sleep": 0.6, "hrv": 0.4},
}

# The two phrases that made the claim. Asserted as literals rather than imported from the
# modules under test: importing the string would make the assertion a tautology that
# survives any re-wording of the claim itself.
_TODAY_HEADING = "## Today's recovery"
_TODAY_CEILING = "SETS today's intensity ceiling"


def _seed_recovery(day: date) -> None:
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute("DELETE FROM derived_daily WHERE metric = 'recovery_score'")
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
            "VALUES (%s,%s,'recovery_score',%s,%s::jsonb) "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
            (SENTINEL_USER_ID, day, _RECOVERY, json.dumps(_FACTORS)),
        )


def _coach_text() -> str:
    return build_coach_context("what should I do today?", SENTINEL_USER_ID, SENTINEL_TZ, days=30)


# ── the coach's context block ────────────────────────────────────────────────


@pytest.mark.usefixtures("db")
def test_todays_recovery_still_reads_as_todays() -> None:
    """The unaffected path — the fix must not cost the coach its ceiling when data is
    fresh, or these tests would pass by emptying the prompt."""
    _seed_recovery(user_today(SENTINEL_TZ))
    text = _coach_text()

    assert _TODAY_HEADING in text
    assert "live readiness" in text
    assert "72/100" in text
    assert STALE_RECOVERY_DIRECTIVE not in text


@pytest.mark.usefixtures("db")
def test_a_four_day_old_score_is_not_presented_to_the_model_as_today() -> None:
    """THE bug, in the text that actually reaches the LLM."""
    stale_day = user_today(SENTINEL_TZ) - timedelta(days=4)
    _seed_recovery(stale_day)
    text = _coach_text()

    assert _TODAY_HEADING not in text
    assert stale_day.isoformat() in text
    assert "4 day(s) ago" in text
    assert STALE_RECOVERY_DIRECTIVE in text
    # The score itself survives — withholding it would remove the conservative ceiling.
    assert "72/100" in text
    # "Live readiness" only decays on the score's OWN day, so quoting it for an older day
    # would name a number that has not decayed against anything.
    assert "live readiness" not in text


# ── the recommendations engine's signals block ───────────────────────────────


@pytest.mark.usefixtures("db")
def test_the_recs_ceiling_line_is_unchanged_when_the_score_is_todays() -> None:
    _seed_recovery(user_today(SENTINEL_TZ))
    text = build_recs_signals(SENTINEL_USER_ID, SENTINEL_TZ)

    assert _TODAY_CEILING in text
    assert "Never prescribe a hard session on low recovery." in text


@pytest.mark.usefixtures("db")
def test_a_stale_score_does_not_set_todays_ceiling_in_the_recs_prompt() -> None:
    """``RECS_TASK`` tells the model to "respect the recovery ceiling"; this line is where
    the ceiling comes from, so a stale score claiming to BE the ceiling is the whole
    defect. It stays in the prompt, dated, without the claim."""
    stale_day = user_today(SENTINEL_TZ) - timedelta(days=3)
    _seed_recovery(stale_day)
    text = build_recs_signals(SENTINEL_USER_ID, SENTINEL_TZ)

    assert _TODAY_CEILING not in text
    assert stale_day.isoformat() in text
    assert "3 day(s) ago" in text
    assert STALE_RECOVERY_DIRECTIVE in text
    assert "72/100" in text


@pytest.mark.usefixtures("db")
def test_both_surfaces_say_the_same_thing_about_the_same_stale_score() -> None:
    """The coach and the recs engine are separate LLM surfaces enforcing one rule
    (ARCHITECTURE.md §4: "a new rule must be added in both places"). They render it in
    their own voice but must not disagree about whether the score is current."""
    stale_day = user_today(SENTINEL_TZ) - timedelta(days=2)
    _seed_recovery(stale_day)

    coach, recs = _coach_text(), build_recs_signals(SENTINEL_USER_ID, SENTINEL_TZ)
    for text in (coach, recs):
        assert STALE_RECOVERY_DIRECTIVE in text
        assert stale_day.isoformat() in text
    assert _TODAY_HEADING not in coach
    assert _TODAY_CEILING not in recs
