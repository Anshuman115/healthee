"""#65 — a ``total`` baseline is the CHALLENGE's window, not a hardcoded seven days.

``series.recent_value`` used to build a ``total`` baseline from the trailing seven days
while ``evaluate._period_total`` scores a ``total`` over the whole window. For any
``window_days != 7`` those are different units compared as if they were the same, and
the mismatch reached three surfaces at once:

1. ``challenge.baseline_value``, frozen at adopt and never recomputed;
2. ``ledger._improvement_pct``, which divided one unit by the other and published the
   result — on the one surface that must not lie;
3. ``adapt._ease_to``'s floor, which at 21 days sat a THIRD of where it belonged, and
   with it the guarantee that an ease can never hand back a target the owner had
   already beaten before they adopted anything.

Every number below is hand-computed from a shaped series, so an off-by-one in the span
changes the expected value rather than hiding inside a flat average. The 7-day and
21-day cases are asserted side by side because seven is the exact window at which the
bug is invisible.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges import confounds, ledger, lifecycle
from healthee.challenges.adapt import _adaptation
from healthee.challenges.evaluate import evaluate_challenge
from healthee.challenges.series import baseline_span, recent_value
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.db import migrate

pytestmark = pytest.mark.integration

IST = SENTINEL_TZ
_METRIC = "cardio_load"  # a plain `derived_daily` row, and one with no evidence ideal
_START = date(2026, 3, 1)
_ADOPTED = datetime(2026, 3, 1, 6, 0, tzinfo=UTC)  # 11:30 IST on 03-01


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _days(cur, first: date, values: list[float], metric: str = _METRIC) -> None:
    _seed.seed_metric(
        cur, _seed.OWNER, metric, {first + timedelta(days=i): v for i, v in enumerate(values)}
    )


# ── the span itself, as a known-value rule ───────────────────────────────────


def test_the_baseline_span_is_the_scoring_window_for_every_cadence() -> None:
    """``daily``/``weekly`` are fixed periods; ``total`` is whatever the challenge is.

    This is the whole fix in one assertion: the baseline covers exactly the days the
    target is scored over, so the two are the same unit by construction rather than by
    coincidence at ``window_days == 7``.
    """
    assert baseline_span("daily", 21) == 7
    assert baseline_span("weekly", 21) == 7
    assert baseline_span("total", 7) == 7
    assert baseline_span("total", 21) == 21
    assert baseline_span("total", 1) == 1


def test_a_total_span_with_no_window_raises_rather_than_defaulting() -> None:
    """A missing window is an error, not a seven.

    A default is precisely what turned a missing input into a wrong number the first
    time — and a wrong number here is a wrong number on the ledger. "No data" and
    "operation failed" are different states (standards §Errors).
    """
    with pytest.raises(ValueError, match="window_days"):
        baseline_span("total", None)


# ── the baseline the owner's rows actually produce ───────────────────────────


def test_a_total_baseline_covers_the_window_at_seven_days_and_at_twenty_one(
    clean_db: None,  # noqa: ARG001
) -> None:
    """A shaped month: 1/day through 03-23, then 10/day for the last seven days.

    * ``total`` over 7 → 03-24…03-30 → 7 × 10 = **70**
    * ``total`` over 21 → 03-10…03-30 → 14 × 1 + 7 × 10 = **84**

    Seven was the window at which the old code was accidentally right, so it is
    asserted next to 21 rather than instead of it: a fix that hardcoded 21 would pass
    the second assertion and fail the first.
    """
    ref = date(2026, 3, 31)
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _START, [1.0] * 23 + [10.0] * 7)
        seven = recent_value(cur, _seed.OWNER, IST, _METRIC, "total", ref, 7)
        twenty_one = recent_value(cur, _seed.OWNER, IST, _METRIC, "total", ref, 21)
        weekly = recent_value(cur, _seed.OWNER, IST, _METRIC, "weekly", ref)
        daily = recent_value(cur, _seed.OWNER, IST, _METRIC, "daily", ref)
    assert (seven, twenty_one) == (70.0, 84.0)
    # The other two cadences are fixed periods and must not have moved.
    assert (weekly, daily) == (70.0, 10.0)


def test_the_frozen_baseline_and_the_scored_total_are_the_same_number(
    clean_db: None,  # noqa: ARG001
) -> None:
    """21 flat days before the challenge, 21 identical days inside it — same figure.

    The claim a ``total`` challenge makes is "reach this much over the window", so its
    baseline has to be "this much is what you were already doing over a window". At
    12/day both are **252**. Under the old seven-day span the baseline read 84 and the
    owner was handed a target calibrated against a third of their real output.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _START - timedelta(days=21), [12.0] * 21)
        _days(cur, _START, [12.0] * 21)
        baseline = recent_value(cur, _seed.OWNER, IST, _METRIC, "total", _START, 21)
        progress = evaluate_challenge(
            cur,
            _seed.OWNER,
            IST,
            {
                "metric": _METRIC,
                "comparator": ">=",
                "target_value": 300.0,
                "cadence": "total",
                "window_days": 21,
                "adopted_at": _ADOPTED,
            },
            today=_START + timedelta(days=20),
        )
    assert baseline == 252.0
    assert progress["current"] == baseline


def test_adopt_freezes_the_window_scaled_baseline_onto_the_row(clean_db: None) -> None:  # noqa: ARG001
    """The endpoint that made this reachable: 21 days at 12/day freeze as 252, not 84.

    ``POST /api/challenges/{id}/adopt`` accepts any seeded ``total`` challenge, and the
    number it writes is the anchor every later claim rests on — it is captured once and
    never recomputed, so a wrong scale here is permanent.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _START - timedelta(days=21), [12.0] * 21)
        cid = _seed.seed_challenge(
            cur, _seed.OWNER, metric=_METRIC, cadence="total", window_days=21, target_value=300.0
        )
        result = lifecycle.adopt(cur, _seed.OWNER, IST, cid, today=_START)
        stored = _seed.stored(cur, _seed.OWNER, cid)
    assert result["ok"] is True
    assert stored["baseline_value"] == 252.0


# ── the ease floor: the guarantee that was void ──────────────────────────────


def test_the_ease_floor_cannot_hand_back_a_target_the_owner_already_beat(
    clean_db: None,  # noqa: ARG001
) -> None:
    """21 days at 21/day is a 441 baseline. An ease off a 500 target may not go below it.

    Hand-computed: the floor is 441 × 1.05 = 463.05, which beats the −15 % figure of
    425, and rounds to the metric's 5-unit step ⇒ **465** — above the 441 they were
    already doing, which is the entire point of the floor.

    The baseline is read from the owner's real rows rather than asserted as a literal,
    so this test fails if the span regresses even though the arithmetic below is pure.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _START - timedelta(days=21), [21.0] * 21)
        baseline = recent_value(cur, _seed.OWNER, IST, _METRIC, "total", _START, 21)
    assert baseline == 441.0
    eased = _adaptation(_METRIC, target=500.0, baseline_value=baseline, achieved=210.0)
    assert eased is not None
    assert (eased["direction"], eased["suggested"]) == ("down", 465.0)
    assert eased["suggested"] > baseline


def test_the_seven_day_scaling_is_what_voided_that_guarantee(clean_db: None) -> None:  # noqa: ARG001
    """The bug, named: the same owner's baseline read as 147, and the ease lands at 425.

    425 is BELOW the 441 they had already achieved over a 21-day window before adopting
    anything — an "ease" that hands back a target they had beaten. Asserted explicitly
    so the regression has a test that describes it, not just one that forbids it.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _START - timedelta(days=21), [21.0] * 21)
        seven_day_sum = recent_value(cur, _seed.OWNER, IST, _METRIC, "weekly", _START)
    assert seven_day_sum == 147.0
    eased = _adaptation(_METRIC, target=500.0, baseline_value=seven_day_sum, achieved=210.0)
    assert eased is not None
    assert eased["suggested"] == 425.0 < 441.0


# ── the ledger: two sides of a before/after in one unit ──────────────────────


def test_the_ledger_compares_a_total_before_and_after_in_the_same_unit(
    clean_db: None,  # noqa: ARG001
) -> None:
    """10/day for the 21 days before, 15/day for the 21 days of the challenge ⇒ +50 %.

    210 → 315 is a 50 % improvement. Under the old span the "after" side was the
    trailing SEVEN days (105) against a whole-window "before" (210), and the ledger
    published **−50 %** — a sign flip, on the surface CHALLENGES.md §2.1 exists to keep
    honest.
    """
    end = _START + timedelta(days=20)
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _START - timedelta(days=21), [10.0] * 21)
        _days(cur, _START, [15.0] * 21)
        cid = _seed.seed_challenge(
            cur,
            _seed.OWNER,
            status="active",
            metric=_METRIC,
            cadence="total",
            window_days=21,
            target_value=300.0,
            adopted_at=_ADOPTED,
            baseline_value=210.0,
        )
        challenge = _seed.stored(cur, _seed.OWNER, cid)
        outcome = ledger.freeze(
            cur, _seed.OWNER, IST, challenge, {}, "completed", _START, end + timedelta(days=1)
        )
    assert (outcome["baseline"], outcome["final"]) == (210.0, 315.0)
    assert outcome["improvement_pct"] == 50.0
    assert outcome["data_confidence"] == "ok"


def test_the_regression_confound_scales_a_total_baseline_by_its_own_window(
    clean_db: None,  # noqa: ARG001
) -> None:
    """A perfectly ordinary owner must not be flagged as starting from an outlier.

    ``confounds`` compares the frozen baseline against a 90-day per-DAY history, so a
    period sum has to be divided by the days it spans. Alternating 10/20 gives a median
    of 15 and a MAD of 5; a 21-day total baseline of 315 is 15/day — **z = 0**, exactly
    average, no confound.

    Divided by a hardcoded seven it reads as 45/day and lands at z ≈ 4, so every long
    cumulative challenge would carry ``at_risk: true`` — a caveat attached to an outcome
    that has nothing wrong with it, which is its own kind of dishonesty.
    """
    history = [10.0 if i % 2 else 20.0 for i in range(90)]
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _START - timedelta(days=90), history)
        challenge = {
            "metric": _METRIC,
            "cadence": "total",
            "window_days": 21,
            "baseline_value": 315.0,
        }
        verdict = confounds.regression_to_mean(cur, _seed.OWNER, IST, challenge, _START)
    assert verdict["assessed"] is True
    assert (verdict["long_run_median"], verdict["baseline_z"]) == (15.0, 0.0)
    assert verdict["at_risk"] is False
