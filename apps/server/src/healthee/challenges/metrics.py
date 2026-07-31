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

## The time predicate — the WINDOWED metrics

A *time-of-day* rule ("no caffeine after 16:00") is what a cutoff finding
naturally suggests, and it used to be unexpressible here — so WP-C5's
``create_challenge`` refused the shape rather than degrade it into a daily total
(which scores three morning coffees as a failure and one 23:00 coffee as a pass).

It is expressible now, as an ORDINARY registry entry: a ``good="down"`` cap whose
source restricts the day's sum to entries at or after one hour of the owner's own
clock. Nothing downstream forks. The catalogue below is generated from the logged
substances the cutoff finder analyses, at the hours it tests. The argument — why
an unlogged day is NOT a zero here, why a window may only be ``daily``, and what
the corpus does and does not supply — is in
:mod:`healthee.challenges.windowed`.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

from healthee.challenges.windowed import (
    WINDOW_HOURS,
    WINDOW_SUBSTANCES,
    WindowedManualEntrySource,
    metric_key,
    metric_label,
)

# Sub-10-minute bouts are auto-detected movement noise, not real workouts.
# Verbatim from legacy `_MIN_WORKOUT_S` (:38).
MIN_WORKOUT_S = 600

# The rule shapes a challenge may take. Verbatim from legacy `_CADENCES` (:40) /
# `_COMPARATORS` (:41). `daily` = hit the target on each of `window_days` days;
# `weekly` = a rolling 7-day total; `total` = a cumulative total over the window.
CADENCES: frozenset[str] = frozenset({"daily", "weekly", "total"})
COMPARATORS: frozenset[str] = frozenset({">=", "<="})

# The period a `weekly` cadence is denominated over — BOTH the rolling window
# `evaluate._period_total` sums and the span `series.recent_window` builds a weekly
# baseline from. It lives here, in the module with no dependencies, because those two
# numbers must be the same number: a target summed over seven days and a baseline
# summed over some other count are not comparable, which is exactly the bug `total`
# shipped with (#65).
WEEKLY_DAYS = 7


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


MetricSource = DerivedSource | WorkoutCountSource | ManualEntrySource | WindowedManualEntrySource


# Which cadences a metric may be expressed in (#67). A `weekly` or `total` rule SUMS
# the days in its period — in `evaluate._period_total` when it scores, and in
# `series.recent_window` when it builds the baseline that target is calibrated against
# — so a metric may only carry those cadences if adding its days together yields a
# quantity that means something.
#
# `sri` is the one that does not. A Sleep Regularity Index is a 0-100 SCORE of how
# alike consecutive days are; seven of them added together is ~490 of nothing.
# `targets._LEVEL` already refuses to convert the SRI target into weekly units for
# exactly this reason — which is what left `(sri, weekly)` calibratable against a ~490
# baseline with NO population cap to bound it, i.e. a target the model could invent and
# Gate A would wave through. Declaring it here makes the pair UNREPRESENTABLE (refused
# at adopt, refused by Gate A, and a raise at evaluation) rather than merely unreached.
_ACCUMULABLE = CADENCES
_A_SCORE = frozenset({"daily"})
# A TIME WINDOW is daily-only for a different reason, kept separate so neither name has
# to answer for the other: a period SUM cannot tell an unmeasured day from a zero one, so
# seven days of silence would total 0 and report a cap kept (`windowed`'s docstring).
_A_WINDOW = frozenset({"daily"})


@dataclass(frozen=True)
class ChallengeMetric:
    """One trackable metric a challenge may target.

    ``good`` is the direction that counts as improvement. ``cadences`` is the set of
    rule shapes this metric can honestly take (see ``_A_SCORE`` above); it has no
    default, so a metric added to the registry has to decide rather than inherit
    "all three" from whoever wrote the dataclass.

    ``kind`` is a PORT RECORD, not a rule: it is legacy's own additive/level tag,
    retained because ``tests/challenges/test_registry.py`` pins the ported vocabulary
    against a hand-retyped copy of `llm/challenges.py:27`. Nothing reads it, and its
    stated semantics would be wrong if anything did — ``steps_total`` is tagged
    ``level`` and every ``weekly`` rule sums it. Period aggregation is ``cadences``
    plus ``evaluate._period_total``, in one place, enforced.
    """

    label: str
    unit: str
    kind: Literal["additive", "level"]
    good: Literal["up", "down"]
    source: MetricSource
    cadences: frozenset[str]


# The metric vocabulary. Labels/units/kinds/directions verbatim from legacy
# `CHALLENGE_METRICS` (:27); every `source` verified against the rebuild's schema
# — see the module docstring for the three that could not bind row-for-row.
CHALLENGE_METRICS: dict[str, ChallengeMetric] = {
    "mvpa_min": ChallengeMetric(
        label="MVPA",
        unit="min",
        kind="additive",
        good="up",
        source=DerivedSource("mvpa_min"),
        cadences=_ACCUMULABLE,
    ),
    "steps_total": ChallengeMetric(
        label="Steps",
        unit="",
        kind="level",
        good="up",
        source=DerivedSource("steps_total"),
        cadences=_ACCUMULABLE,
    ),
    "active_calories": ChallengeMetric(
        label="Active calories",
        unit="kcal",
        kind="level",
        good="up",
        source=DerivedSource("active_calories"),
        cadences=_ACCUMULABLE,
    ),
    "cardio_load": ChallengeMetric(
        label="Cardio load",
        unit="",
        kind="level",
        good="up",
        source=DerivedSource("cardio_load"),
        cadences=_ACCUMULABLE,
    ),
    "tst_min": ChallengeMetric(
        label="Sleep",
        unit="min",
        kind="level",
        good="up",
        source=DerivedSource("sleep_health_score_4dim", flag_key="tst_min"),
        cadences=_ACCUMULABLE,
    ),
    "sri": ChallengeMetric(
        label="Sleep regularity",
        unit="",
        kind="level",
        good="up",
        source=DerivedSource("sleep_regularity_index"),
        # The one score in the registry — see `_A_SCORE`. A weekly SRI is not seven
        # daily SRIs added up, so the pair simply does not exist.
        cadences=_A_SCORE,
    ),
    "workouts_week": ChallengeMetric(
        label="Workouts",
        unit="",
        kind="additive",
        good="up",
        source=WorkoutCountSource(),
        cadences=_ACCUMULABLE,
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
        cadences=_ACCUMULABLE,
    ),
    "caffeine_mg": ChallengeMetric(
        label="Caffeine",
        unit="mg",
        # Level, not additive: caffeine guidance is a DAILY dose, so a period's
        # value is the average of its days rather than their total.
        kind="level",
        good="down",
        source=ManualEntrySource(kind="caffeine", unit="mg"),
        # Milligrams DO add up over a week even though the guidance is per-day, so a
        # cumulative cap ("stay under 1,400 mg this week") is a real, scoreable rule.
        cadences=_ACCUMULABLE,
    ),
}

# The windowed catalogue, GENERATED rather than typed out: one entry per (logged
# substance the cutoff finder analyses) × (hour it tests). Everything except the source
# and the cadence set is the base metric's own, so a window cannot come to disagree with
# the quantity it is a slice of — same unit, same direction, same rounding step.
WINDOW_BASES: dict[str, ManualEntrySource] = {
    metric: entry.source
    for metric, entry in CHALLENGE_METRICS.items()
    if isinstance(entry.source, ManualEntrySource) and entry.source.kind in WINDOW_SUBSTANCES
}

CHALLENGE_METRICS |= {
    metric_key(source.kind, hour): ChallengeMetric(
        label=metric_label(CHALLENGE_METRICS[base].label, hour),
        unit=source.unit,
        kind=CHALLENGE_METRICS[base].kind,
        good=CHALLENGE_METRICS[base].good,
        source=WindowedManualEntrySource(source.kind, source.unit, hour),
        cadences=_A_WINDOW,
    )
    for base, source in WINDOW_BASES.items()
    for hour in WINDOW_HOURS
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


def allows_cadence(metric: str, cadence: str) -> bool:
    """Whether ``metric`` can honestly be expressed at ``cadence`` (``ChallengeMetric``)."""
    return cadence in spec(metric).cadences


def validate_cadence(metric: str, cadence: str) -> str:
    """``cadence`` if ``metric`` may take it, else raise — never a silently-scored pair.

    Raising is the same choice :func:`spec` already makes for an unknown metric and
    ``evaluate._validated`` makes for an unknown cadence, and for the same reason: a
    period value is the SUM of its days, so a cadence a metric cannot be summed over
    does not produce a slightly-wrong number, it produces a number in no unit at all
    (#67 — a weekly ``sri`` baseline of ~490). "No data" and "cannot be tracked" are
    different states from "0 %" (standards §Errors).
    """
    allowed = spec(metric).cadences
    if cadence not in allowed:
        raise ValueError(
            f"{metric!r} cannot be expressed as a {cadence!r} challenge "
            f"(its days do not add up to a quantity; it takes {sorted(allowed)})"
        )
    return cadence
