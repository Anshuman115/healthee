"""WP-C3c — the one calibration rule, as known values.

CHALLENGES.md §1 and §5.1 used to contradict each other: §5.1 specified a ~+10-30 % band
while §1 quoted legacy's canonical example ("a sedentary user at 35 MVPA min/week should
get ~60-80, NOT 150") — which is +71 % to +129 %. They are both right, and the three
cases below are why: a percentage is the wrong SHAPE at a low baseline (+30 % of 35 is a
minute and a half a day) and the right one in the middle, and neither may run past the
evidence target.

    move   = max(fraction x baseline, meaningful_step, rounding_step)
    target = baseline +- move, capped at the evidence target

Pinned as arithmetic, with no database, because these are the numbers a person is asked
to live by for a fortnight — a floor that quietly changed would still leave every
integration test green while changing what everybody is asked to do.
"""

from __future__ import annotations

from healthee.challenges.bounds import at_evidence_target, band_for
from healthee.challenges.metrics import CHALLENGE_METRICS, ROUND_STEP
from healthee.challenges.targets import (
    CURVE,
    EVIDENCE_TARGET,
    MEANINGFUL_STEP,
    STEEPEST_AT_LOW,
    curve_of,
    in_cadence,
    meaningful_step,
    unranked_metrics,
)

# The MVPA row of the calibration table, weekly. Read from the SHIPPED tables rather
# than restated, so the worked cases below pin the constants a person is actually asked
# to live by — a floor pinned only as a local literal would let the real one drift.
MVPA_FLOOR = meaningful_step("mvpa_min", "weekly")
MVPA_TARGET = in_cadence(EVIDENCE_TARGET["mvpa_min"], "weekly")


def test_the_mvpa_row_is_the_one_the_worked_cases_below_assume() -> None:
    assert (MVPA_FLOOR, MVPA_TARGET) == (25.0, 150.0)


def _mvpa_band(baseline: float):
    return band_for("mvpa_min", baseline, "up", floor=MVPA_FLOOR, target=MVPA_TARGET)


# -- the three cases the reconciliation is built on ----------------------------


def test_a_sedentary_mvpa_baseline_is_governed_by_the_floor_not_the_percentage() -> None:
    """35 min/week: +30 % is 10.5 min/week — a minute and a half a day, i.e. noise.

    This is legacy's canonical example (CHALLENGES.md §1) and the case a percentage band
    serves worst, on the metric whose own note says the dose-response is STEEPEST here.
    """
    band = _mvpa_band(35.0)
    assert band is not None
    assert (band.low, band.high) == (60.0, 60.0)
    # The percentage alone would have asked for this, and nobody would have felt it.
    assert 35.0 * 1.30 < 50.0


def test_a_middling_mvpa_baseline_is_governed_by_the_percentage() -> None:
    """90 min/week: 30 % is 27 min, past the 25-min floor, so overload takes over."""
    band = _mvpa_band(90.0)
    assert band is not None
    assert (band.low, band.high) == (115.0, 117.0)


def test_an_mvpa_baseline_near_the_target_is_capped_at_the_target() -> None:
    """140 min/week: the step would reach 165-182; the WHO 150 stops it dead.

    The cap OVERRIDES the floor here, and that is the intended precedence — arriving at
    the population target is meaningful by definition, whatever distance was left.
    """
    band = _mvpa_band(140.0)
    assert band is not None
    assert (band.low, band.high) == (150.0, 150.0)


def test_an_mvpa_baseline_inside_one_rounding_step_of_the_target_has_no_band() -> None:
    """148 min/week: two minutes short of the goal is not a fortnight's commitment."""
    assert _mvpa_band(148.0) is None
    assert at_evidence_target("mvpa_min", 148.0, "up", MVPA_TARGET)


def test_a_baseline_past_the_target_is_still_calibratable_just_not_capped() -> None:
    """The note calls 150 "a floor, not a ceiling", so passing it is not a refusal.

    That such an owner has no population gap LEFT is a statement about which lever is
    worth pulling, and ``levers`` is where it is made — not here, as an inability to
    express any MVPA challenge at all.
    """
    band = _mvpa_band(200.0)
    assert band is not None
    assert (band.low, band.high) == (225.0, 260.0)
    assert not at_evidence_target("mvpa_min", 200.0, "up", MVPA_TARGET)


# -- direction: a cap moves DOWN, and its evidence target is a FLOOR -----------


def test_a_down_metric_step_has_the_same_shape_pointing_the_other_way() -> None:
    """A floor on a cap metric is a minimum CUT — 20 units off a 100-unit habit.

    The gentle end is governed by the floor (10 % of 100 is under it) and the deep end
    by the percentage, which is the mirror image of the ``mvpa_min`` middle case.
    """
    band = band_for("alcohol_units", 100.0, "down", floor=20.0)
    assert band is not None
    assert (band.low, band.high) == (70.0, 80.0)


def test_a_down_metric_is_capped_by_its_evidence_floor_not_its_ceiling() -> None:
    """The direction trap for the CAP: an ``<=`` target may not be cut past the goal.

    A 55-unit habit with a 20-unit floor would land on 35; a population floor of 45
    pulls it back UP to 45. A ``min`` here — the arithmetic an ``up`` metric uses —
    would have driven the owner below a limit the evidence never asked them to pass.
    """
    band = band_for("alcohol_units", 55.0, "down", floor=20.0, target=45.0)
    assert band is not None
    assert (band.low, band.high) == (45.0, 45.0)
    # And within one rounding step of the floor there is nothing left to cut.
    assert band_for("alcohol_units", 45.5, "down", floor=20.0, target=45.0) is None
    assert at_evidence_target("alcohol_units", 45.5, "down", 45.0)


def test_no_shipped_cap_metric_actually_has_an_evidence_target() -> None:
    """The rule above is exercised by constants, because the corpus supplies none.

    Neither intake note gives a daily or weekly TOTAL to cut toward — both are about
    dose and timing relative to bedtime — so a cap challenge is bounded by the owner's
    own baseline alone. Asserted rather than left implicit: the day a note earns one,
    this test is what says the table must be updated deliberately.
    """
    caps = [m for m, s in CHALLENGE_METRICS.items() if s.good == "down"]
    assert caps  # the registry still has cap metrics at all
    assert all(m not in EVIDENCE_TARGET for m in caps)


# -- no dose-response evidence => no floor, no ranking -------------------------


def test_a_metric_with_no_dose_response_evidence_gets_no_floor() -> None:
    """``cardio_load`` and ``active_calories`` are individual-load quantities.

    No note attaches an outcome to an increment of either, so there is no floor to cite
    and the percentage rule is the whole rule. Asserted, not incidental.
    """
    for metric in ("cardio_load", "active_calories"):
        assert meaningful_step(metric, "daily") is None
        assert curve_of(metric).shape == "unknown"
        assert curve_of(metric).note_id is None
        band = band_for(metric, 100.0, "up", floor=meaningful_step(metric, "daily"))
        assert band is not None
        assert (band.low, band.high) == (110.0, 130.0)


def test_a_metric_with_no_population_target_is_not_rankable() -> None:
    """The honest output for a metric the evidence cannot place: no gap, no rank."""
    unranked = unranked_metrics()
    assert {"cardio_load", "active_calories", "workouts_week"} <= unranked
    assert {"mvpa_min", "steps_total", "sri", "tst_min"}.isdisjoint(unranked)


def test_every_floor_and_target_cites_a_note_that_exists() -> None:
    """Standards §"every constant derived from research cites its note", enforced."""
    from healthee.insights import manifest

    known = manifest.note_ids()
    for table in (EVIDENCE_TARGET, MEANINGFUL_STEP):
        for metric, target in table.items():
            assert target.note_id in known, f"{metric} cites a note nobody can look up"
    for metric, curve in CURVE.items():
        assert curve.note_id in known, f"{metric}'s curve cites a note nobody can look up"


def test_only_the_metrics_whose_notes_state_it_claim_a_steep_bottom() -> None:
    """The curve claim is the load-bearing one — it is why a floor exists at all."""
    steep = {m for m, c in CURVE.items() if c.shape == STEEPEST_AT_LOW}
    assert steep == {"mvpa_min", "steps_total"}
    # ...and those are exactly the metrics that earned a floor.
    assert set(MEANINGFUL_STEP) == steep


# -- units: one claim, two cadences -------------------------------------------


def test_a_per_day_constant_becomes_a_per_week_one_by_arithmetic_not_by_a_new_claim() -> None:
    """A ``weekly`` baseline is the SUM of seven days, so a daily floor multiplies by 7."""
    assert meaningful_step("steps_total", "daily") == 1000.0
    assert meaningful_step("steps_total", "weekly") == 7000.0
    assert meaningful_step("mvpa_min", "weekly") == 25.0
    assert meaningful_step("mvpa_min", "daily") == 25.0 / 7


def test_a_score_target_does_not_exist_in_weekly_units() -> None:
    """Seven SRI scores added together is not a weekly anything, so there is no target."""
    sri = EVIDENCE_TARGET["sri"]
    assert in_cadence(sri, "daily") == 70.0
    assert in_cadence(sri, "weekly") is None


def test_the_steps_target_is_the_notes_reference_band_not_the_marketing_number() -> None:
    """[steps_mortality] refuses "10,000" outright; the reference is ~7,000-8,000."""
    assert EVIDENCE_TARGET["steps_total"].value == 8000.0
    assert in_cadence(EVIDENCE_TARGET["steps_total"], "weekly") == 56000.0


def test_every_target_and_floor_is_representable_at_its_metrics_rounding_step() -> None:
    """A goal the owner cannot be asked for in whole steps is a goal we cannot state."""
    for table in (EVIDENCE_TARGET, MEANINGFUL_STEP):
        for metric, target in table.items():
            step = ROUND_STEP.get(metric, 1)
            assert target.value % step == 0, f"{metric}: {target.value} is not a multiple of {step}"
