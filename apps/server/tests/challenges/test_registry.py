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
    DerivedSource,
    ManualEntrySource,
    WorkoutCountSource,
    spec,
)
from healthee.challenges.scales import IDEAL, ROUND_STEP, round_target
from healthee.challenges.windowed import WINDOW_HOURS, WindowedManualEntrySource, metric_key

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

# The rebuild's own additions (#61) — the metrics a `<=` cap challenge can bind to.
# Listed separately from the legacy table on purpose: the port's fidelity and the
# rebuild's extensions are different claims and must fail independently.
_CAP_VOCABULARY = {
    "alcohol_units": ("Alcohol", "units", "additive", "down"),
    "caffeine_mg": ("Caffeine", "mg", "level", "down"),
}

# The generated time windows — one per cap metric per hour the cutoff finder tests. Kept
# as a third claim for the same reason the caps are a second one: the port's fidelity,
# the rebuild's caps, and the time predicate must each be able to fail on their own.
_WINDOW_VOCABULARY = {
    metric_key(kind, hour) for kind in ("alcohol", "caffeine") for hour in WINDOW_HOURS
}


def test_the_vocabulary_is_the_legacy_one() -> None:
    """Every label/unit/kind/direction ported verbatim — no metric silently dropped."""
    assert set(_LEGACY_VOCABULARY) <= set(CHALLENGE_METRICS)
    for metric, (label, unit, kind, good) in _LEGACY_VOCABULARY.items():
        entry = CHALLENGE_METRICS[metric]
        assert (entry.label, entry.unit, entry.kind, entry.good) == (label, unit, kind, good)


def test_the_registry_is_the_legacy_vocabulary_plus_the_caps_plus_the_windows() -> None:
    """Nothing else has crept in — a metric nobody reviewed is a challenge nobody can keep."""
    assert set(CHALLENGE_METRICS) == (
        set(_LEGACY_VOCABULARY) | set(_CAP_VOCABULARY) | _WINDOW_VOCABULARY
    )


def test_a_window_inherits_everything_from_the_quantity_it_slices() -> None:
    """Unit, direction and kind come from the base metric, never restated.

    A window that disagreed with its own total about milligrams-versus-cups, or about
    which direction is improvement, would be a second definition of the same quantity
    (CLAUDE.md) — and one of the two would score the owner backwards.
    """
    base = CHALLENGE_METRICS["caffeine_mg"]
    for hour in WINDOW_HOURS:
        entry = CHALLENGE_METRICS[metric_key("caffeine", hour)]
        assert (entry.unit, entry.good, entry.kind) == (base.unit, base.good, base.kind)
        assert entry.source == WindowedManualEntrySource("caffeine", "mg", hour)
        assert entry.label == f"Caffeine after {hour:02d}:00"


def test_a_window_may_only_be_daily() -> None:
    """A period SUM cannot tell an unmeasured day from a zero one (``challenges.windowed``).

    Declared on the entry, so the pair is UNREPRESENTABLE — refused by Gate A, by
    ``adopt`` and by ``evaluate`` — rather than merely never reached, which is the same
    treatment #67 gave a weekly ``sri``.
    """
    for metric in _WINDOW_VOCABULARY:
        assert CHALLENGE_METRICS[metric].cadences == frozenset({"daily"})


def test_a_window_reads_self_logged_data_and_never_zero_fills_it() -> None:
    """The two logged sources are distinct TYPES, which is what keeps them distinct.

    ``WindowedManualEntrySource`` is deliberately not a subclass: an
    ``isinstance(source, ManualEntrySource)`` dispatch anywhere in the tree would
    otherwise sweep a window into the zero-filling reader it exists to refuse.
    """
    windows = {
        m for m, e in CHALLENGE_METRICS.items() if isinstance(e.source, WindowedManualEntrySource)
    }
    zero_filled = {
        m for m, e in CHALLENGE_METRICS.items() if isinstance(e.source, ManualEntrySource)
    }

    assert windows == _WINDOW_VOCABULARY
    assert zero_filled == set(_CAP_VOCABULARY)
    assert windows.isdisjoint(zero_filled)


def test_the_cap_metrics_point_downward_and_bind_to_a_logged_kind() -> None:
    """`good="down"` is the whole reason they exist: legacy's vocabulary was all "up".

    Without a downward metric a `<=` challenge had nothing to bind to, which is how
    the comparator went untested on a cumulative cadence for so long (#61).
    """
    for metric, (label, unit, kind, good) in _CAP_VOCABULARY.items():
        entry = CHALLENGE_METRICS[metric]
        assert (entry.label, entry.unit, entry.kind, entry.good) == (label, unit, kind, good)
        assert isinstance(entry.source, ManualEntrySource)
        assert entry.source.unit == unit, "the source unit must be the target's unit"

    assert CHALLENGE_METRICS["alcohol_units"].source == ManualEntrySource("alcohol", "units")
    assert CHALLENGE_METRICS["caffeine_mg"].source == ManualEntrySource("caffeine", "mg")


def test_the_cap_kinds_are_the_kinds_the_guidance_is_denominated_in() -> None:
    """Alcohol guidance is weekly (a sum); caffeine guidance is a daily dose (a level).

    Getting this backwards would express a target in units nobody's advice uses.
    """
    assert CHALLENGE_METRICS["alcohol_units"].kind == "additive"
    assert CHALLENGE_METRICS["caffeine_mg"].kind == "level"


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


def test_workouts_are_the_only_workout_counted_source() -> None:
    """Workout counts have no daily-metric equivalent, so they keep legacy's special case."""
    special = {m for m, e in CHALLENGE_METRICS.items() if isinstance(e.source, WorkoutCountSource)}
    assert special == {"workouts_week"}
    source = CHALLENGE_METRICS["workouts_week"].source
    assert isinstance(source, WorkoutCountSource)
    assert source.min_duration_s == 600


def test_only_the_cap_metrics_read_self_logged_data() -> None:
    """A `ManualEntrySource` zero-fills absent days; a device metric must NEVER do that.

    "No `derived_daily` row" means the strap had nothing to say — turning that into a
    0 would score a day with no data as a day of doing nothing.
    """
    logged = {m for m, e in CHALLENGE_METRICS.items() if isinstance(e.source, ManualEntrySource)}
    assert logged == set(_CAP_VOCABULARY)


def test_every_metric_has_a_rounding_step() -> None:
    """Without one, an adapted target lands on a number like "7,943"."""
    assert set(ROUND_STEP) == set(CHALLENGE_METRICS)


def test_ideals_are_a_subset_of_the_registry() -> None:
    """The adapter's ceiling may only be keyed by a metric that exists."""
    assert set(IDEAL) <= set(CHALLENGE_METRICS)


def test_one_metric_never_carries_two_different_good_values() -> None:
    """A ceiling and a target answer different questions; they may not disagree (#67).

    ``IDEAL`` bounds what the ADAPTER may raise a live commitment to;
    ``targets.EVIDENCE_TARGET`` is where the corpus says the returns are and caps what
    GENERATION may propose. Both are "good enough" expressed as a number, so two values
    for one metric is two definitions of good — the thing CLAUDE.md forbids outright.

    It was live: ``sri`` sat at 85 here against the note's 70, so the engine refused to
    propose an SRI target above 70 and would then ratchet an adopted one to 84. 85 was
    also uncited — no line of ``[sleep_regularity_index]`` contains it.

    Scoped to the OVERLAP on purpose. ``workouts_week`` (no note) and ``tst_min``
    (resolved per owner) are deliberately in one table only, and this test must not
    pressure anyone into inventing an entry to make it pass.
    """
    from healthee.challenges.targets import EVIDENCE_TARGET

    shared = set(IDEAL) & set(EVIDENCE_TARGET)
    assert shared == {"mvpa_min", "steps_total", "sri"}
    for metric in sorted(shared):
        assert IDEAL[metric] == EVIDENCE_TARGET[metric].value, (
            f"{metric} has two different 'good' values: "
            f"ceiling {IDEAL[metric]} vs target {EVIDENCE_TARGET[metric].value}"
        )


def test_the_sri_ceiling_is_the_number_its_note_actually_states() -> None:
    """``SRI_GOOD = 70.0`` (Windred 2024) — hardcoded here, not read from the table.

    Pinned as a literal precisely because the table is what could drift: asserting
    ``IDEAL["sri"] == IDEAL["sri"]`` through any indirection would survive the bug this
    replaces. 70 is the note's own constant and the threshold the 4-dim regularity
    dimension already gates on. The note's other SRI figures are DESCRIPTIVE — a cohort
    median of 81.0 [IQR 73.8-86.3] — and describe what is typical, not what is good.
    """
    assert IDEAL["sri"] == 70.0


def test_no_cap_metric_carries_an_evidence_ideal() -> None:
    """`IDEAL` bounds a RAISE, and there is nothing to raise a `good="down"` metric toward.

    An entry here would be read by `adapt._ceiling` as a ceiling to climb to — i.e.
    the engine nudging an owner's alcohol target UP toward an "ideal".
    """
    downward = {m for m, e in CHALLENGE_METRICS.items() if e.good == "down"}
    assert downward == {"alcohol_units", "caffeine_mg"} | _WINDOW_VOCABULARY
    assert downward.isdisjoint(IDEAL)


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
        ("alcohol_units", 5.4, 5.0),  # step 1
        ("caffeine_mg", 187.0, 175.0),  # step 25 → 7.48 → 7 × 25
    ],
)
def test_round_target_known_values(metric: str, value: float, expected: float) -> None:
    """Hand-computed against the per-metric step (legacy `_ROUND_STEP`)."""
    assert round_target(metric, value) == expected
