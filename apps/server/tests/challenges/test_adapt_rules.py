"""Known-value tests for the calibration RULE — the arithmetic that moves a live target.

Every number below is hand-computed from the ported constants (raise at ≥1.2×,
ease at ≤0.7×, ×1.2 / ×0.85, per-metric rounding, the evidence-ideal ceiling and
the own-baseline floor). This is the part of the system that changes a commitment
the user already agreed to, so "predictable and explainable" is a requirement, not
a nicety (CHALLENGES.md §5.2) — and it is testable without a database because the
rule is separated from the read.
"""

from __future__ import annotations

import pytest

from healthee.challenges.adapt import (
    EASE_FACTOR,
    EASE_RATIO,
    MIN_ELAPSED_DAYS,
    OWNER_CEILING_FACTOR,
    RAISE_FACTOR,
    RAISE_RATIO,
    _adaptation,
)


def test_the_thresholds_are_the_documented_ones() -> None:
    """CHALLENGES.md §5.2 states these numbers to the user; they are the contract."""
    assert (RAISE_RATIO, RAISE_FACTOR) == (1.2, 1.2)
    assert (EASE_RATIO, EASE_FACTOR) == (0.7, 0.85)
    assert MIN_ELAPSED_DAYS == 5


# ── raising ──────────────────────────────────────────────────────────────────


def test_raises_at_exactly_the_threshold_ratio() -> None:
    """6000 / 5000 = 1.20 — the boundary is inclusive.

    5000 × 1.2 = 6000, under the 8000-step ceiling, and 6000 is already a whole
    250-step multiple. 6000 > 5000 × 1.04, so there is room to move.
    """
    result = _adaptation("steps_total", target=5000.0, baseline_value=None, achieved=6000.0)
    assert result == {
        "direction": "up",
        "suggested": 6000.0,
        "current": 5000.0,
        "reason": "averaging 6000 vs 5000 target",
    }


def test_does_not_raise_just_below_the_threshold() -> None:
    """5990 / 5000 = 1.198 — inside the productive band, so the target stands."""
    assert _adaptation("steps_total", target=5000.0, baseline_value=None, achieved=5990.0) is None


def test_the_ceiling_caps_a_raise_at_the_evidence_ideal() -> None:
    """7500 × 1.2 = 9000, but the steps ideal is 8000 — the raise stops there.

    Without the ceiling this suggests 9000: the guard is what stops a target running
    away from the person as they get better at it.
    """
    result = _adaptation("steps_total", target=7500.0, baseline_value=None, achieved=9500.0)
    assert result is not None
    assert result["suggested"] == 8000.0


def test_no_raise_when_the_ceiling_leaves_no_room() -> None:
    """At 7900 steps the 8000 ceiling is only +1.3 % away — under the +4 % floor.

    Churning a live commitment for a rounding step's worth of difference is worse
    than leaving it alone.
    """
    assert _adaptation("steps_total", target=7900.0, baseline_value=None, achieved=10000.0) is None


# ── the owner-relative ceiling (metrics with no evidence ideal) ──────────────
#
# `active_calories` and `cardio_load` have no population target, so legacy bounded
# them with nothing at all: +20 % per recalibration, indefinitely. The replacement
# is a bound against the owner's OWN frozen baseline.


def test_the_owner_ceiling_is_the_documented_multiple() -> None:
    """A guard on what the engine may do unattended — never surfaced as evidence."""
    assert OWNER_CEILING_FACTOR == 1.5


def test_a_metric_with_no_ideal_is_capped_at_a_multiple_of_the_owners_baseline() -> None:
    """Baseline 400 ⇒ ceiling 600. 550 × 1.2 = 660, so the raise stops at 600.

    Unbounded, this suggests 660 — and would suggest 792 five days later.
    """
    result = _adaptation("active_calories", target=550.0, baseline_value=400.0, achieved=700.0)
    assert result is not None
    assert result["suggested"] == 600.0


def test_a_raise_below_the_owner_ceiling_is_untouched_by_it() -> None:
    """Baseline 400 ⇒ ceiling 600; 450 × 1.2 = 540 is comfortably under it.

    The ceiling must bound the runaway case without flattening ordinary progression.
    """
    result = _adaptation("active_calories", target=450.0, baseline_value=400.0, achieved=600.0)
    assert result is not None
    assert result["suggested"] == 540.0


def test_no_raise_at_all_without_an_ideal_or_a_baseline() -> None:
    """Nothing to bound against ⇒ leave the commitment alone, do not guess.

    "Not enough data" beats an optimistic guess — and the optimistic guess here is a
    target that climbs 20 % every five days with nothing to stop it.
    """
    assert _adaptation("cardio_load", target=50.0, baseline_value=None, achieved=100.0) is None


def test_the_evidence_ideal_still_wins_where_one_exists() -> None:
    """A cited ceiling outranks the owner-relative one — steps stop at 8000, not 1.5×.

    Baseline 7000 would give an owner ceiling of 10500; the note-backed 8000 holds.
    """
    result = _adaptation("steps_total", target=7500.0, baseline_value=7000.0, achieved=9500.0)
    assert result is not None
    assert result["suggested"] == 8000.0


# ── the SRI ceiling: the number its note actually states (#67) ───────────────
#
# `IDEAL["sri"]` was 85 with "[sleep_regularity_index]" cited beside it, and 85 appears
# nowhere in that note. The value is now `SRI_GOOD = 70.0` (Windred 2024), the same
# threshold the 4-dim regularity dimension gates on and the same one generation caps a
# proposed SRI target at. These are known values because a ceiling change moves a live
# commitment somebody already agreed to: every number below is hand-computed from
# ×1.2, the 70 ceiling, SRI's rounding step of 1, and the +4 % room guard.


def test_an_sri_raise_well_under_the_ceiling_is_untouched_by_it() -> None:
    """50 × 1.2 = 60, nowhere near 70 — the ceiling must not flatten ordinary progress."""
    result = _adaptation("sri", target=50.0, baseline_value=None, achieved=65.0)
    assert result is not None
    assert result["suggested"] == 60.0


def test_the_sri_ceiling_stops_a_raise_at_the_notes_threshold() -> None:
    """62 × 1.2 = 74.4 — the 70 ceiling stops it, and 70 is >4 % above 62 so it ships.

    THE regression: under the old 85 this suggested 74, fifteen points past the number
    generation treats as the goal and four past the threshold the note states at all.
    """
    result = _adaptation("sri", target=62.0, baseline_value=None, achieved=80.0)
    assert result is not None
    assert result["suggested"] == 70.0


def test_the_last_sri_target_the_ceiling_still_leaves_room_above() -> None:
    """67: the raise lands on 70 and 67 × 1.04 = 69.68, so 70 clears the room guard."""
    result = _adaptation("sri", target=67.0, baseline_value=None, achieved=90.0)
    assert result is not None
    assert result["suggested"] == 70.0


def test_one_point_higher_there_is_no_room_left_to_raise_sri() -> None:
    """68 is the boundary the other way: 68 × 1.04 = 70.72, and the ceiling is 70."""
    assert _adaptation("sri", target=68.0, baseline_value=None, achieved=90.0) is None


def test_an_sri_target_already_at_the_ceiling_is_left_alone() -> None:
    """At 70 there is nothing above to raise to — under the old 85 this became 84."""
    assert _adaptation("sri", target=70.0, baseline_value=None, achieved=95.0) is None


def test_an_sri_target_is_still_easeable_below_the_ceiling() -> None:
    """A ceiling bounds raises only: 60 × 0.85 = 51, floored at 40 × 1.05 = 42.

    Worth pinning because lowering a ceiling is exactly the change that could
    accidentally freeze a metric — an owner failing an SRI target must still get relief.
    """
    result = _adaptation("sri", target=60.0, baseline_value=40.0, achieved=40.0)
    assert result is not None
    assert (result["direction"], result["suggested"]) == ("down", 51.0)


# ── easing ───────────────────────────────────────────────────────────────────


def test_eases_at_exactly_the_threshold_ratio() -> None:
    """70 / 100 = 0.70 — inclusive. 100 × 0.85 = 85, above the 52.5 floor (50 × 1.05).

    85 is already a whole 5-minute multiple and is >3 % below 100, so it ships.
    """
    result = _adaptation("mvpa_min", target=100.0, baseline_value=50.0, achieved=70.0)
    assert result == {
        "direction": "down",
        "suggested": 85.0,
        "current": 100.0,
        "reason": "averaging 70min vs 100min target",
    }


def test_does_not_ease_just_above_the_threshold() -> None:
    """71 / 100 = 0.71 — still productive struggle, not failure."""
    assert _adaptation("mvpa_min", target=100.0, baseline_value=50.0, achieved=71.0) is None


def test_the_floor_keeps_an_ease_above_the_owners_own_baseline() -> None:
    """Baseline 88 ⇒ floor 92.4, which beats the −15 % figure of 85; rounds to 90.

    Easing below what they were already doing before adopting would hand back a
    target they had beaten — the calibration is relative to the person, and the
    floor is what makes that true in the downward direction too.
    """
    result = _adaptation("mvpa_min", target=100.0, baseline_value=88.0, achieved=30.0)
    assert result is not None
    assert result["suggested"] == 90.0


def test_no_ease_when_the_floor_leaves_no_room() -> None:
    """Baseline 95 ⇒ floor 99.75 → rounds to 100: the target already IS their baseline."""
    assert _adaptation("mvpa_min", target=100.0, baseline_value=95.0, achieved=30.0) is None


def test_without_a_baseline_the_floor_is_what_they_are_achieving() -> None:
    """No frozen baseline ⇒ floor 30, so the −15 % figure of 85 wins."""
    result = _adaptation("mvpa_min", target=100.0, baseline_value=None, achieved=30.0)
    assert result is not None
    assert result["suggested"] == 85.0


# ── the productive band ──────────────────────────────────────────────────────


@pytest.mark.parametrize("achieved", [80.0, 100.0, 119.0])
def test_no_adaptation_inside_the_productive_band(achieved: float) -> None:
    """0.7 < ratio < 1.2 is exactly where a challenge should be left alone."""
    assert _adaptation("mvpa_min", target=100.0, baseline_value=50.0, achieved=achieved) is None
