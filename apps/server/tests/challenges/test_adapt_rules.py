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
