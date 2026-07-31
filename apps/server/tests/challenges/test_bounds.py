"""Gate A — the baseline-bounds rules, known-value tested without a database.

These are the rules a live commitment's number is decided by, so they are pinned as
arithmetic rather than through the pipeline: a band that quietly widened would still let
every integration test pass while shipping a target nobody could hit.

The direction cases are the point. Half the registry is ``good="down"`` (#61's cap
metrics), and a band expressed as "+10-30 %" would ask an owner to drink MORE.
"""

from __future__ import annotations

from healthee.challenges.bounds import (
    MAX_STRETCH_FRACTION,
    MIN_STRETCH_FRACTION,
    Band,
    Calibration,
    band_for,
    copy_issue,
    target_issue,
)


def _cal(metric: str, baseline: float, cadence: str = "daily") -> Calibration:
    """A calibration built from the real band rule — never a hand-written interval."""
    direction = "down" if metric in ("alcohol_units", "caffeine_mg") else "up"
    return Calibration(metric, cadence, baseline, 7, band_for(metric, baseline, direction), None)


# ── direction: `good="up"` stretches UP ────────────────────────────────────────


def test_an_up_metric_band_sits_above_the_owners_baseline() -> None:
    band = band_for("steps_total", 3000.0, "up")
    assert band is not None
    assert band.low == 3000.0 * (1 + MIN_STRETCH_FRACTION)
    assert band.high == 3000.0 * (1 + MAX_STRETCH_FRACTION)


def test_the_brief_example_is_rejected_twelve_thousand_on_a_three_thousand_baseline() -> None:
    issue = target_issue(_cal("steps_total", 3000.0), 12000.0)
    assert issue is not None
    assert "outside the progressive-overload band" in issue


def test_a_target_at_the_owners_own_baseline_is_not_a_challenge() -> None:
    assert target_issue(_cal("steps_total", 3000.0), 3000.0) is not None


def test_an_in_band_up_target_is_accepted_unchanged() -> None:
    assert target_issue(_cal("steps_total", 3000.0), 3500.0) is None


# ── direction: `good="down"` stretches DOWN ────────────────────────────────────


def test_a_down_metric_band_sits_below_the_owners_baseline() -> None:
    # 400 mg, 25 mg step: the step is smaller than a 10 % cut, so the raw fractions bind.
    band = band_for("caffeine_mg", 400.0, "down")
    assert band is not None
    assert band.high == 400.0 * (1 - MIN_STRETCH_FRACTION)
    assert band.low == 400.0 * (1 - MAX_STRETCH_FRACTION)


def test_a_down_metric_band_is_widened_by_the_rounding_step_too() -> None:
    # 200 mg, 25 mg step: a 10 % cut is 20 mg, less than one step, so the gentle end
    # moves out to the first representable cut (175) rather than an unreachable 180.
    band = band_for("caffeine_mg", 200.0, "down")
    assert band is not None
    assert band.high == 175.0 and band.low == 140.0


def test_raising_a_cap_is_rejected_not_treated_as_overload() -> None:
    """The trap: a band written as "+10-30 %" would ACCEPT 240 mg on a 200 mg habit."""
    issue = target_issue(_cal("caffeine_mg", 200.0), 240.0)
    assert issue is not None
    assert "outside the progressive-overload band" in issue


def test_cutting_a_cap_too_far_is_rejected_too() -> None:
    assert target_issue(_cal("caffeine_mg", 200.0), 50.0) is not None


def test_an_in_band_down_target_is_accepted_unchanged() -> None:
    assert target_issue(_cal("caffeine_mg", 200.0), 150.0) is None


def test_a_cap_one_step_from_zero_has_no_band_at_all() -> None:
    """One UK unit a week, rounding step one: the only cut available is to zero."""
    assert band_for("alcohol_units", 1.0, "down") is None


# ── the rounding step widens the band, never narrows it ────────────────────────


def test_a_coarse_metric_band_is_widened_to_hold_one_representable_target() -> None:
    """2 workouts/week: the raw band [2.2, 2.6] contains no multiple of the 1-step."""
    band = band_for("workouts_week", 2.0, "up")
    assert band is not None
    assert band.low == 3.0 and band.high == 3.0
    assert target_issue(_cal("workouts_week", 2.0, "weekly"), 3.0) is None
    assert target_issue(_cal("workouts_week", 2.0, "weekly"), 4.0) is not None


# ── thin / absent baselines refuse the metric ──────────────────────────────────


def test_a_calibration_with_no_band_refuses_every_target() -> None:
    thin = Calibration("steps_total", "daily", None, 2, None, "thin_baseline")
    issue = target_issue(thin, 5000.0)
    assert issue is not None
    assert "thin_baseline" in issue


def test_a_zero_baseline_has_no_proportional_band_in_either_direction() -> None:
    """An owner who never logs caffeine reads as 0.0 over seven zero-filled days.

    The ``up`` half matters just as much: without the guard the step-widening would
    return ``[250, 250]`` for a zero step baseline — a target made of a rounding
    constant, presented as a stretch on data we do not have.
    """
    assert band_for("caffeine_mg", 0.0, "down") is None
    assert band_for("steps_total", 0.0, "up") is None


# ── the copy may not name a number the row does not hold ───────────────────────


def test_copy_restating_a_different_target_is_rejected() -> None:
    cal = _cal("steps_total", 3000.0)
    issue = copy_issue(cal, 3500.0, "Walk 12,000 steps — a 20% stretch on your baseline.")
    assert issue is not None
    assert "12,000" in issue and "3500" in issue


def test_copy_naming_a_false_baseline_is_rejected() -> None:
    cal = _cal("steps_total", 3000.0)
    assert copy_issue(cal, 3500.0, "A stretch on your 10,000-step baseline.") is not None


def test_copy_repeating_the_stored_target_is_allowed() -> None:
    cal = _cal("steps_total", 3000.0)
    assert copy_issue(cal, 3500.0, "3500 steps is the ask.") is None


def test_percentages_clock_times_and_metric_names_are_not_rival_targets() -> None:
    cal = _cal("steps_total", 3000.0)
    text = "A 20% stretch, after 15:00, tracked via vo2max and spo2 [sleep_score_4dim]."
    assert copy_issue(cal, 3500.0, text) is None


def test_small_numbers_below_the_band_pass_untouched() -> None:
    cal = _cal("tst_min", 220.0)
    assert copy_issue(cal, 250.0, "Aim for the 7-9 hour band; 30 minutes earlier helps.") is None


def test_a_citation_id_carrying_digits_is_never_read_as_a_quantity() -> None:
    cal = _cal("workouts_week", 2.0, "weekly")  # band [3, 3] — a very low floor
    assert copy_issue(cal, 3.0, "Steadier weeks [sleep_health_score_4dim].") is None


def test_the_band_object_is_inclusive_at_both_ends() -> None:
    band = Band(low=10.0, high=20.0)
    assert band.contains(10.0) and band.contains(20.0)
    assert not band.contains(9.0) and not band.contains(21.0)
