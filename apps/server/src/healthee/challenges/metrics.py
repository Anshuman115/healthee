"""The challenge metric registry — the vocabulary a challenge may bind to.

Every challenge is a **measurable rule** (``metric`` + ``comparator`` +
``target_value`` over a ``cadence``/``window_days``), so a challenge that does not
bind to a machine-trackable metric is a promise we cannot keep (CHALLENGES.md §1).
This module is the single place that says which metrics those are and where each
one's daily value actually comes from.

Ported from legacy ``llm/challenges.py`` (``CHALLENGE_METRICS`` :27, ``_IDEAL``
:148, ``_ROUND_STEP`` :536, ``_MIN_WORKOUT_S`` :38). The *values* — labels, units,
kinds, ideals, rounding steps — are verbatim. What changed is the **source**
binding, because legacy's storage no longer exists:

* Legacy read every metric from ``metric_sample`` (a v1 compat VIEW the rebuild
  dropped) and took "the last sample of the day" as the day's value. The rebuild
  stores ``derived_daily (user_id, day, metric, value, flags)`` — already exactly
  one canonical row per owner-day — so that last-sample-wins rule is gone rather
  than ported.
* ``tst_min`` is NOT a canonical daily metric in the rebuild (it is absent from
  ``analytics.metrics.V2_DAILY_METRICS``): the derive layer carries total sleep
  time as a *flag* on the ``sleep_health_score_4dim`` row for the wake date
  (``derive/sleep_score.py:129``). It therefore binds to a flag source, not a row
  source — ONE canonical definition of sleep duration (CLAUDE.md), the same one
  ``read/health_metrics.py`` and ``derive/recovery.py`` read.
* ``workouts_week`` keeps legacy's special case: it counts rows in ``workout``,
  which has no daily-metric equivalent.

## The rebuild's own additions — the CAP metrics (#61)

Legacy's vocabulary is entirely ``good="up"``, so a ``<=`` challenge had nothing
to bind to: "keep weekly alcohol under 5 units" was unexpressible, and the
comparator was therefore never exercised on a cumulative cadence (which is how
``evaluate._cumulative`` came to ignore it — #61). ``alcohol_units`` and
``caffeine_mg`` are the two quantities the rebuild can genuinely track downward,
because ``manual_entry`` already stores them with an amount and a unit
(``read/logs.py``; the legacy client's own defaults were mg and UK units).

They also make the personal-cutoff findings actionable: ``analytics/cutoffs.py``
earns statements like "alcohol after 20:00 costs you HRV", and CHALLENGES.md §5.1
makes those findings a first-class generation input — which needs a metric a cap
challenge can bind to.

**What is deliberately NOT here.** A *time-of-day* rule ("no caffeine after
15:00") is exactly what a cutoff finding suggests, and the registry cannot
express it: a ``ChallengeMetric`` yields one number per day, and there is no
predicate dimension for "…logged after hour H". Faking it as a daily quantity
would score an owner who drank three coffees before noon as a failure, so it is
left out until the registry can carry a predicate rather than shipped wrong.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

# Sub-10-minute bouts are auto-detected movement noise, not real workouts.
# Verbatim from legacy `_MIN_WORKOUT_S` (:38).
MIN_WORKOUT_S = 600


@dataclass(frozen=True)
class DerivedSource:
    """A ``derived_daily`` row for the owner's local day.

    ``flag_key`` selects a numeric field of that row's ``flags`` JSON instead of
    its ``value`` column — the shape total sleep time is stored in.
    """

    metric: str
    flag_key: str | None = None


@dataclass(frozen=True)
class WorkoutCountSource:
    """Count of qualifying ``workout`` rows on the owner's local day."""

    min_duration_s: int = MIN_WORKOUT_S


@dataclass(frozen=True)
class ManualEntrySource:
    """Daily SUM of ``manual_entry.amount`` for one self-logged ``kind``.

    The owner is the sensor for these, not the strap, and two consequences follow
    that the device-backed sources do not have:

    * **A day with no entry is a ZERO, not a gap.** The reader zero-fills the
      window (``series._manual_sums``) — otherwise a cap challenge would be
      unscoreable in the one case that matters: an owner who abstained logs
      nothing, and "no row" would read as "no data" and score no hit at all. This
      is the SAME reading ``analytics/cutoffs.py`` already takes of these tables
      (a night with no substance event is a *control* night, not a discarded one),
      so the rebuild keeps one interpretation of an absent manual entry.
    * **The unit is part of the binding.** ``manual_entry.unit`` is whatever the
      client sent, so the reader sums only rows in this source's unit (or with no
      unit — the client's default IS this unit, and the legacy CLI omitted it).
      A row in some other unit is skipped rather than converted: turning "2 cups"
      into milligrams would be inventing a number.

    The honest limit, stated once here so the generation layer (WP-C3) can weigh
    it: a self-logged cap is only as good as the owner's logging, and unlogged
    intake is indistinguishable from none.
    """

    kind: str
    unit: str


MetricSource = DerivedSource | WorkoutCountSource | ManualEntrySource


@dataclass(frozen=True)
class ChallengeMetric:
    """One trackable metric a challenge may target.

    ``kind`` is how a period's value is formed from its days: ``additive`` sums
    them (weekly MVPA minutes), ``level`` averages them (a per-day step count).
    ``good`` is the direction that counts as improvement.
    """

    label: str
    unit: str
    kind: Literal["additive", "level"]
    good: Literal["up", "down"]
    source: MetricSource


# The metric vocabulary. Labels/units/kinds/directions verbatim from legacy
# `CHALLENGE_METRICS` (:27); every `source` verified against the rebuild's schema
# — see the module docstring for the three that could not bind row-for-row.
CHALLENGE_METRICS: dict[str, ChallengeMetric] = {
    "mvpa_min": ChallengeMetric(
        label="MVPA", unit="min", kind="additive", good="up", source=DerivedSource("mvpa_min")
    ),
    "steps_total": ChallengeMetric(
        label="Steps", unit="", kind="level", good="up", source=DerivedSource("steps_total")
    ),
    "active_calories": ChallengeMetric(
        label="Active calories",
        unit="kcal",
        kind="level",
        good="up",
        source=DerivedSource("active_calories"),
    ),
    "cardio_load": ChallengeMetric(
        label="Cardio load", unit="", kind="level", good="up", source=DerivedSource("cardio_load")
    ),
    "tst_min": ChallengeMetric(
        label="Sleep",
        unit="min",
        kind="level",
        good="up",
        source=DerivedSource("sleep_health_score_4dim", flag_key="tst_min"),
    ),
    "sri": ChallengeMetric(
        label="Sleep regularity",
        unit="",
        kind="level",
        good="up",
        source=DerivedSource("sleep_regularity_index"),
    ),
    "workouts_week": ChallengeMetric(
        label="Workouts", unit="", kind="additive", good="up", source=WorkoutCountSource()
    ),
    # The two cap metrics (see the module docstring). `good="down"` is the whole
    # point: these are the first entries a `<=` challenge can bind to.
    "alcohol_units": ChallengeMetric(
        label="Alcohol",
        unit="units",
        # Additive because the health guidance for alcohol is denominated per WEEK,
        # so a period's value is the sum of its days.
        kind="additive",
        good="down",
        source=ManualEntrySource(kind="alcohol", unit="units"),
    ),
    "caffeine_mg": ChallengeMetric(
        label="Caffeine",
        unit="mg",
        # Level, not additive: caffeine guidance is a DAILY dose, so a period's
        # value is the average of its days rather than their total.
        kind="level",
        good="down",
        source=ManualEntrySource(kind="caffeine", unit="mg"),
    ),
}

# The rule shapes a challenge may take. Verbatim from legacy `_CADENCES` (:40) /
# `_COMPARATORS` (:41). `daily` = hit the target on each of `window_days` days;
# `weekly` = a rolling 7-day total; `total` = a cumulative total over the window.
CADENCES: frozenset[str] = frozenset({"daily", "weekly", "total"})
COMPARATORS: frozenset[str] = frozenset({">=", "<="})

# Evidence "ideal" per metric — the CEILING the adapter may never raise a target
# past (`adapt.suggest_adaptation`). Values verbatim from legacy `_IDEAL` (:148);
# the citations are this port's addition (standards §"every constant derived from
# research cites its note"). A metric absent here has no ceiling, exactly as in
# legacy — `active_calories` and `cardio_load` are individual-load quantities with
# no population target to anchor one, so none was invented.
IDEAL: dict[str, float] = {
    "mvpa_min": 150.0,  # WHO weekly MVPA target [mvpa_minutes_mortality]
    "steps_total": 8000.0,  # daily-steps mortality plateau [steps_mortality]
    "tst_min": 450.0,  # 7.5 h, mid-band of the U-curve [sleep_duration_mortality]
    "sri": 85.0,  # strong regularity [sleep_regularity_index]
    # NOT EVIDENCE, and it must never be presented as such. No note in the corpus
    # supports a specific weekly SESSION count — the evidence is denominated in
    # minutes, not sessions — so this is practitioner consensus with no citation
    # behind it. It exists solely as `adapt._raise_to`'s ceiling (a guard on how far
    # the engine may move a target by itself) and is never read by a surface that
    # shows the owner a target, a rationale, or a research note.
    "workouts_week": 4.0,
    # The cap metrics are deliberately absent: IDEAL is the ceiling on RAISING a
    # target, and a `good="down"` metric has no ceiling to raise toward. Their
    # adapter guard is `adapt.OWNER_CEILING_FACTOR` (owner-relative), if it ever
    # applies at all — `suggest_adaptation` leaves `<=` challenges alone.
}

# Rounding granularity per metric, so an adapted target stays a human number
# ("8,000 steps", not "7,943"). Verbatim from legacy `_ROUND_STEP` (:536).
ROUND_STEP: dict[str, float] = {
    "steps_total": 250,
    "mvpa_min": 5,
    "tst_min": 5,
    "sri": 1,
    "workouts_week": 1,
    "active_calories": 10,
    "cardio_load": 5,
    "alcohol_units": 1,  # a UK unit is the smallest meaningful step
    "caffeine_mg": 25,  # ~a quarter of a filter coffee; "200 mg", not "187 mg"
}


def spec(metric: str) -> ChallengeMetric:
    """The registry entry for ``metric``.

    Raises ``KeyError`` for an unknown metric rather than returning an empty spec:
    legacy fell back to ``{}``, which scored an untrackable challenge as 0 % forever
    and looked like "no progress" instead of "this cannot be tracked" (standards
    §"errors are never swallowed" — "no data" and "failed" are different states).
    """
    try:
        return CHALLENGE_METRICS[metric]
    except KeyError:
        raise KeyError(f"{metric!r} is not a trackable challenge metric") from None


def round_target(metric: str, value: float) -> float:
    """Round ``value`` to the metric's human step. Verbatim from legacy ``_round_target``."""
    step = ROUND_STEP.get(metric, 1)
    return float(round(value / step) * step)
