"""#69 — what a WEEKLY or TOTAL target can actually be recalibrated on.

CHALLENGES.md §5.1a carried a warning that reads, in full: *"for a cumulative `>=`,
averaging ≥ RAISE_RATIO × target implies the total is already ≥ target, which means the
challenge is complete — so no weekly/total raise is reachable through real progress"*,
and concluded that *"for weekly and total challenges the opening target is effectively
permanent"*.

**That is false, and this module is the arithmetic that shows it.** The implication only
holds once the elapsed days have caught up with the period the target is denominated
over. ``adapt._achieved`` scales the daily mean up to the whole period — it is a PACE,
"if they keep this up they will do X per week" — while ``evaluate`` sums only the days
that have actually happened. Those two are equal at the end of the period and nowhere
before it, and the gap between them is exactly the window in which a raise is reachable::

    achieved = mean × span          (the pace, over the target's own period)
    current  = mean × elapsed       (what they have actually banked so far)

    raise fires   ⟺ mean × span    ≥ RAISE_RATIO × target
    complete      ⟺ mean × elapsed ≥ target

    ⇒ a raise is reachable while  elapsed < span / RAISE_RATIO

For ``weekly`` that is ``7 / 1.2 ≈ 5.83`` days, and ``MIN_ELAPSED_DAYS`` is 5 — so the
reachable window is real but narrow (days 5 and, with a missing day or two, 6). For
``total`` it is ``window_days / 1.2``, i.e. the first **83 %** of the window: on a 30-day
total, days 5 through 24.

The ease side was never in question and is reachable throughout, for both cadences.

**The decision this pins (option (b) of #69, for a corrected reason):** partial-window
pace adaptation is not a change to make — it is what the engine already does. What was
missing was the evidence that it works, which is why these are known-value tests: each
one states its own arithmetic, so a future edit to ``RAISE_RATIO``, ``_achieved``'s
scaling or ``_period_total``'s clamp moves a number a reader can check rather than
silently re-opening the question.

Auto-skips without a reachable TimescaleDB.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges.adapt import suggest_adaptation
from healthee.challenges.evaluate import evaluate_challenge
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.db import migrate

pytestmark = pytest.mark.integration

_START = date(2026, 3, 1)
_ADOPTED = datetime(2026, 3, 1, 6, 0, tzinfo=UTC)  # 11:30 IST on 03-01


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _challenge(**overrides) -> dict:
    return {
        "metric": "mvpa_min",
        "comparator": ">=",
        "target_value": 100.0,
        "cadence": "weekly",
        "window_days": 14,
        "adopted_at": _ADOPTED,
        "baseline_value": None,
    } | overrides


def _run(cur, challenge: dict, per_day: float, days: int, today: date) -> tuple[dict, dict | None]:
    """Seed ``days`` days at ``per_day``, then score and ask for a recalibration.

    Both halves come from the real read path and the progress handed to the adapter is
    the one ``evaluate`` produced — the two are only meaningful together, because the
    whole question is whether ``complete`` closes the door before the raise opens it.
    """
    _seed.seed_metric(
        cur,
        _seed.OWNER,
        challenge["metric"],
        {_START + timedelta(days=i): per_day for i in range(days)},
    )
    progress = evaluate_challenge(cur, _seed.OWNER, SENTINEL_TZ, challenge, today=today)
    return progress, suggest_adaptation(cur, _seed.OWNER, SENTINEL_TZ, challenge, progress, today)


# ── weekly: the raise IS reachable, in a narrow window ───────────────────────


def test_a_weekly_target_can_be_raised_on_day_five(clean_db: None) -> None:  # noqa: ARG001
    """18 min/day on day 5: pace 126/week beats a 100 target, banked 90 does not.

    The case CHALLENGES.md §5.1a said could not exist. ``achieved = 18 × 7 = 126``, ratio
    1.26 ≥ ``RAISE_RATIO``; ``current = 18 × 5 = 90`` < 100, so the challenge is still
    running and there is a live target to move. The raise is ``100 × 1.2 = 120``, under
    the 150 MVPA ceiling and a whole 5-minute rounding step above it.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        progress, adaptation = _run(cur, _challenge(), 18.0, 5, date(2026, 3, 5))
    assert (progress["current"], progress["complete"]) == (90.0, False)
    assert adaptation is not None
    assert (adaptation["direction"], adaptation["suggested"]) == ("up", 120.0)
    assert adaptation["reason"] == "averaging 126min vs 100min target"


def test_the_same_pace_on_day_seven_has_completed_instead(clean_db: None) -> None:  # noqa: ARG001
    """Two days later the pace has become the result: 126 banked ⇒ complete ⇒ no raise.

    This is the boundary, and it is the reason option (b) is right rather than a
    resignation. Once the period has elapsed, a weekly target that is being beaten is not
    a target that has gone stale — it is a commitment that has been MET, which
    ``lifecycle.terminal_status`` closes and the ledger records as ``met``. Raising it
    then would move the goalposts on something already achieved, and the honest next step
    is a new challenge calibrated against the new baseline, not a bigger number on the
    old one.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        progress, adaptation = _run(cur, _challenge(), 18.0, 7, date(2026, 3, 7))
    assert (progress["current"], progress["complete"]) == (126.0, True)
    assert adaptation is None


# ── total: reachable across most of the window ───────────────────────────────


def test_a_total_target_can_be_raised_a_third_of_the_way_in(clean_db: None) -> None:  # noqa: ARG001
    """15/day on day 10 of a 30-day total: pace 450 vs a 300 target, banked only 150.

    ``total`` scales by the challenge's whole window (``series.baseline_span``, #65), so
    the pace runs ahead of the banked figure for the first ``window / RAISE_RATIO`` = 25
    days. ``cardio_load`` has no evidence ideal, so the raise is bounded by the
    owner-relative ceiling instead: a frozen baseline of 400 allows 600, and
    ``300 × 1.2 = 360`` is comfortably under it.
    """
    challenge = _challenge(
        metric="cardio_load",
        cadence="total",
        target_value=300.0,
        window_days=30,
        baseline_value=400.0,
    )
    with tenant_transaction(_seed.OWNER) as cur:
        progress, adaptation = _run(cur, challenge, 15.0, 10, date(2026, 3, 10))
    assert (progress["current"], progress["complete"]) == (150.0, False)
    assert adaptation is not None
    assert (adaptation["direction"], adaptation["suggested"]) == ("up", 360.0)


# ── the ease side was never in doubt, for either cadence ─────────────────────


@pytest.mark.parametrize(
    ("cadence", "window_days", "target", "expected"),
    [
        # weekly: 5/day ⇒ pace 35/week against a 100 target, ratio 0.35 ≤ EASE_RATIO. The
        # ease lands on 100 × 0.85 = 85, above the 50 × 1.05 = 52.5 baseline floor.
        ("weekly", 14, 100.0, 85.0),
        # total: 5/day over a 30-day window ⇒ pace 150 against a 300 target, ratio 0.5.
        # The target has to grow with the span or the SAME five minutes a day would read
        # as beating it — which is the units point #65 made and the reason the raise
        # cases above are denominated so carefully.
        ("total", 30, 300.0, 255.0),
    ],
)
def test_a_cumulative_target_that_is_being_missed_still_eases(
    clean_db: None,  # noqa: ARG001
    cadence: str,
    window_days: int,
    target: float,
    expected: float,
) -> None:
    """Falling short is measurable from day five whatever the cadence — no window closes.

    The half of #69 nothing ever disputed, pinned anyway: the asymmetry the warning
    described (raises unreachable, eases fine) is not what the code does, and a test that
    only covered the raise would leave a reader assuming it.
    """
    challenge = _challenge(
        cadence=cadence, window_days=window_days, target_value=target, baseline_value=50.0
    )
    with tenant_transaction(_seed.OWNER) as cur:
        progress, adaptation = _run(cur, challenge, 5.0, 7, date(2026, 3, 7))
    assert progress["complete"] is False
    assert adaptation is not None
    assert (adaptation["direction"], adaptation["suggested"]) == ("down", expected)
