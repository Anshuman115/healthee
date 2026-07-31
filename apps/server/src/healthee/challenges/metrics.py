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


MetricSource = DerivedSource | WorkoutCountSource


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
    # No note supports a specific weekly SESSION count (the evidence is in minutes,
    # not sessions), so this one is practitioner consensus, not a cited ideal. It is
    # used ONLY as the adapter's ceiling and is never surfaced as an evidence target.
    "workouts_week": 4.0,
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
