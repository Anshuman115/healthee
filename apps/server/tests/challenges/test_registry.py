"""The metric registry pins the legacy vocabulary AND its v2 source bindings.

The registry is what makes a challenge auto-trackable, so the failure this suite
exists to catch is a metric that *looks* registered but resolves to nothing the
rebuild stores — a challenge that can never be scored, presented as one that can.
No database needed: every assertion is about the registry itself.
"""

from __future__ import annotations

import pytest

from healthee.analytics.metrics import V2_DAILY_METRICS
from healthee.challenges.metrics import (
    CADENCES,
    CHALLENGE_METRICS,
    COMPARATORS,
    IDEAL,
    ROUND_STEP,
    DerivedSource,
    WorkoutCountSource,
    round_target,
    spec,
)

# The legacy vocabulary, retyped by hand from `llm/challenges.py:27` so this table
# is an INDEPENDENT copy of the source of truth, not an echo of the port.
_LEGACY_VOCABULARY = {
    "mvpa_min": ("MVPA", "min", "additive", "up"),
    "steps_total": ("Steps", "", "level", "up"),
    "active_calories": ("Active calories", "kcal", "level", "up"),
    "cardio_load": ("Cardio load", "", "level", "up"),
    "tst_min": ("Sleep", "min", "level", "up"),
    "sri": ("Sleep regularity", "", "level", "up"),
    "workouts_week": ("Workouts", "", "additive", "up"),
}


def test_the_vocabulary_is_the_legacy_one() -> None:
    """Every label/unit/kind/direction ported verbatim — no metric silently dropped."""
    assert set(CHALLENGE_METRICS) == set(_LEGACY_VOCABULARY)
    for metric, (label, unit, kind, good) in _LEGACY_VOCABULARY.items():
        entry = CHALLENGE_METRICS[metric]
        assert (entry.label, entry.unit, entry.kind, entry.good) == (label, unit, kind, good)


def test_every_derived_source_resolves_to_a_real_v2_metric() -> None:
    """A registry entry must name a metric the rebuild actually writes.

    `derived_daily` rows are only ever written for the canonical v2 set, so a
    `DerivedSource` naming anything else reads zero rows forever — the challenge
    would score 0 % and look like a user who never tried.
    """
    for metric, entry in CHALLENGE_METRICS.items():
        if isinstance(entry.source, DerivedSource):
            assert entry.source.metric in V2_DAILY_METRICS, (
                f"{metric} binds to {entry.source.metric!r}, which derive never writes"
            )


def test_sleep_duration_binds_to_the_flag_not_a_metric_row() -> None:
    """`tst_min` is the one entry whose legacy binding does NOT exist in v2.

    Sleep duration is not in `V2_DAILY_METRICS`; the derive layer stores it on the
    `sleep_health_score_4dim` row's flags. Binding it as a plain metric row — the
    literal legacy port — would read nothing at all.
    """
    assert "tst_min" not in V2_DAILY_METRICS
    source = CHALLENGE_METRICS["tst_min"].source
    assert isinstance(source, DerivedSource)
    assert (source.metric, source.flag_key) == ("sleep_health_score_4dim", "tst_min")


def test_workouts_are_the_only_non_derived_source() -> None:
    """Workout counts have no daily-metric equivalent, so they keep legacy's special case."""
    special = {m for m, e in CHALLENGE_METRICS.items() if isinstance(e.source, WorkoutCountSource)}
    assert special == {"workouts_week"}
    source = CHALLENGE_METRICS["workouts_week"].source
    assert isinstance(source, WorkoutCountSource)
    assert source.min_duration_s == 600


def test_every_metric_has_a_rounding_step() -> None:
    """Without one, an adapted target lands on a number like "7,943"."""
    assert set(ROUND_STEP) == set(CHALLENGE_METRICS)


def test_ideals_are_a_subset_of_the_registry() -> None:
    """The adapter's ceiling may only be keyed by a metric that exists."""
    assert set(IDEAL) <= set(CHALLENGE_METRICS)


def test_unknown_metric_raises_rather_than_scoring_zero() -> None:
    """ "Not trackable" and "no progress" are different states (standards §errors)."""
    with pytest.raises(KeyError):
        spec("happiness")


def test_vocabulary_constants() -> None:
    """The rule shapes and directions a challenge may take (legacy :40, :41)."""
    assert set(CADENCES) == {"daily", "weekly", "total"}
    assert set(COMPARATORS) == {">=", "<="}


@pytest.mark.parametrize(
    ("metric", "value", "expected"),
    [
        ("steps_total", 7943.0, 8000.0),  # step 250 → 31.77 → 32 × 250
        ("steps_total", 7800.0, 7750.0),  # 31.2 → 31 × 250
        ("mvpa_min", 63.0, 65.0),  # step 5 → 12.6 → 13 × 5
        ("tst_min", 421.0, 420.0),  # step 5 → 84.2 → 84 × 5
        ("sri", 78.4, 78.0),  # step 1
        ("workouts_week", 3.4, 3.0),  # step 1
        ("active_calories", 434.0, 430.0),  # step 10 → 43.4 → 43 × 10
        ("cardio_load", 63.0, 65.0),  # step 5 → 12.6 → 13 × 5
    ],
)
def test_round_target_known_values(metric: str, value: float, expected: float) -> None:
    """Hand-computed against the per-metric step (legacy `_ROUND_STEP`)."""
    assert round_target(metric, value) == expected
