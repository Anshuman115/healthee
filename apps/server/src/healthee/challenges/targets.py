"""Where the evidence says the returns are — targets, curve shapes, meaningful steps.

WP-C3c. One place for every number that says something about the POPULATION rather
than about this owner, so that "which lever is worth pulling" (``levers``) and "how far
may one pull it" (``bounds``) read the same constants and cannot drift apart.

## Three different things, deliberately kept apart

* :data:`EVIDENCE_TARGET` — where the corpus says the returns are. It is the ceiling a
  generated target may not leap past (a ``good="up"`` metric) or the floor it may not cut
  below (``good="down"``), and it is the denominator of the gap :mod:`levers` ranks by.
* :data:`CURVE` — the SHAPE of the dose-response, and only where a note states one. This
  is what makes "the least active person has the most to gain" a claim we can cite rather
  than an intuition, and it is why a percentage-only step is the wrong rule at the bottom.
* :data:`MEANINGFUL_STEP` — the smallest change in the metric that the corpus treats as a
  real dose. **Only defined where a note attaches an outcome to an increment.**

## Why this is not ``metrics.IDEAL``

``IDEAL`` is the ceiling ``adapt`` may never raise a LIVE target past, ported verbatim
from legacy, and it deliberately contains one entry that is **not evidence** at all
(``workouts_week: 4`` — practitioner consensus, no note, and its own comment says so).
A table that grounds a claim to the owner cannot contain a number with nothing behind it,
so this one is built from the notes up and is SMALLER: ``workouts_week`` has no evidence
target here, and ``tst_min``'s is resolved per owner (below). The two tables are not
merged because they answer different questions — *where are the returns* versus *how far
may the engine move a live commitment unattended*.

But different questions may not yield different NUMBERS for the same metric. This
paragraph used to record ``sri`` as an accepted divergence (70 here, 85 in ``IDEAL``) —
and 85 traced to no line of any note, so what it recorded was a bug, not a decision
(#67). Wherever a metric appears in BOTH tables the values now agree, and
``tests/challenges/test_registry.py`` fails the build if they stop agreeing; the
divergence that remains is only about MEMBERSHIP (``workouts_week`` and ``tst_min`` are
here or there, not in both with two values).

## PROVISIONAL BY CONSTRUCTION

Every number here is a defensible guess, not a tuned parameter. The targets and the curve
shapes are cited and stable; the **meaningful steps are anchored, not derived** — the
corpus says a few minutes a day of vigorous activity is a real dose, it does not say that
25 min/week is the smallest weekly increment worth committing to. Nobody has tuned these
against outcomes because nobody has the outcomes yet.

**The outcome ledger is the tuning mechanism**, and it already records everything needed:
``challenge_outcome`` freezes ``target``, ``baseline``, ``status``, ``adherence`` and
``improvement_pct`` per challenge. Once there are enough rows, the question "which step
sizes actually get completed AND moved the metric" is a query, not an opinion:

.. code-block:: sql

    SELECT metric,
           width_bucket((target - baseline) / NULLIF(baseline, 0), 0, 1, 10) AS step_bucket,
           count(*)                                   AS n,
           avg((status = 'met')::int)                 AS met_rate,
           avg(adherence)                             AS adherence,
           avg(improvement_pct)                       AS improvement
    FROM challenge_outcome
    WHERE data_confidence = 'ok'
    GROUP BY metric, step_bucket
    ORDER BY metric, step_bucket;

A step size that is completed but moves nothing was too small; one that moves the metric
but is abandoned was too big. Retuning means editing THIS file and nothing else.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from uuid import UUID

from healthee.challenges.metrics import CHALLENGE_METRICS
from healthee.derive._common import Cur

# ── the population targets ────────────────────────────────────────────────────

# Where the evidence says the returns are, in the metric's own units and over its
# NATURAL period (see `Target.period`). A metric absent from this table has no
# population target we can source — it is not ranked as a lever and its band is not
# capped, which is an honest output and not a gap to fill in later with a guess.


@dataclass(frozen=True)
class Target:
    """One population target: the number, the period it is denominated over, its note."""

    value: float
    period: str  # "day" | "week" | "level" — see `in_cadence`
    note_id: str


# "level" means the number is a SCORE, not an accumulable quantity: a weekly SRI is not
# seven daily SRIs added up, so a level target simply does not exist in weekly units.
_LEVEL = "level"

EVIDENCE_TARGET: dict[str, Target] = {
    # WHO 2020's lower bound, and the note is explicit that it is a floor and not a
    # ceiling — "most of the benefit banked in the first 150".
    "mvpa_min": Target(150.0, "week", "mvpa_minutes_mortality"),
    # The mortality plateau for adults under 60. The note refuses "10,000" outright as a
    # marketing artifact and gives ~7,000–8,000 as the reference; 8,000 is the upper end
    # of that band and the figure the 51 %-reduction comparison (Paluch 2022) is drawn at.
    "steps_total": Target(8000.0, "day", "steps_mortality"),
    # `SRI_GOOD` — the threshold the note pins (Windred 2024) and the same number the
    # 4-dim regularity dimension already gates on, so this is not a second definition.
    "sri": Target(70.0, _LEVEL, "sleep_regularity_index"),
    # `tst_min` is ABSENT on purpose: its target is the owner's OWN age-banded sleep need
    # (`resolve_target`), because a per-owner number already exists and a constant here
    # would be a second definition of "how much sleep this person needs".
    #
    # `workouts_week`, `active_calories` and `cardio_load` are absent because no note
    # supports one. The nearest candidate — WHO's ≥2 days/week of muscle-strengthening
    # [strength_training_mortality] — does not bind: `workouts_week` counts ALL workouts,
    # so scoring it against a STRENGTH guideline would credit two easy rides as met.
    #
    # `alcohol_units` and `caffeine_mg` are absent because the two intake notes are about
    # DOSE-AND-TIMING relative to bedtime, not a daily or weekly total. There is no
    # population cap in this corpus to cut toward, so a cap challenge is bounded only by
    # the owner's own baseline — which is the honest bound anyway.
}


def resolve_target(cur: Cur, user_id: UUID, metric: str, today: date) -> Target | None:
    """The population target for ``metric``, resolved for THIS owner where it is personal.

    Only ``tst_min`` is personal: sleep need is age-banded (NSF 2015) and the derive layer
    already writes it per owner as ``sleep_need_min`` [[sleep_need_debt]]. Reading that row
    rather than hardcoding 8 h keeps ONE definition of the owner's sleep target — the same
    number ``derive/recovery.py`` scores their sleep against. No row ⇒ **no target**: we do
    not know their age band, and inventing one to fill the gap is exactly the confident
    guess this product refuses.
    """
    if metric != "tst_min":
        return EVIDENCE_TARGET.get(metric)
    cur.execute(
        "SELECT value FROM derived_daily WHERE user_id = %s AND metric = 'sleep_need_min' "
        "AND day <= %s ORDER BY day DESC LIMIT 1",
        (user_id, today),
    )
    row = cur.fetchone()
    return None if row is None else Target(float(row[0]), "day", "sleep_need_debt")


# ── the shape of the curve ────────────────────────────────────────────────────

# What the corpus says about MARGINAL return at a given position on the curve. Encoded
# only where a note states a shape; every value below quotes the sentence it came from.
STEEPEST_AT_LOW = "steepest_at_low"
MONOTONE = "monotone"
U_SHAPED = "u_shaped"
UNKNOWN = "unknown"


@dataclass(frozen=True)
class Curve:
    """The dose-response shape for one metric, and the note that states it."""

    shape: str
    note_id: str | None


CURVE: dict[str, Curve] = {
    # "Dose-response is steepest in the 0 → 150 min/week range" — Garcia 2023, quoted
    # verbatim in the note's evidence section. This is the whole reason a percentage band
    # under-serves the least-active owner: they are standing on the steep part.
    "mvpa_min": Curve(STEEPEST_AT_LOW, "mvpa_minutes_mortality"),
    # "The biggest marginal gains come from moving a *sedentary* person up toward the
    # first few thousand steps"; "the steepest risk reduction is in moving *off* the
    # sedentary floor"; diminishing returns above the plateau.
    "steps_total": Curve(STEEPEST_AT_LOW, "steps_mortality"),
    # "risk falls monotonically as regularity rises" (Windred 2024). Monotone is a real
    # shape claim and it earns SRI a ranked gap — but it says nothing about WHERE the
    # marginal return is largest, so it does not earn the bottom-of-curve promotion.
    "sri": Curve(MONOTONE, "sleep_regularity_index"),
    # U-shaped: both short (<6 h) and long (>9 h) sleep carry higher risk than 7–8 h. The
    # consequence for a lever is direction-critical — a gap only exists BELOW the band,
    # and the long tail is read as a marker of illness, not a thing to chase.
    "tst_min": Curve(U_SHAPED, "sleep_duration_mortality"),
    # Everything else is `UNKNOWN` by absence: `cardio_load` and `active_calories` are
    # individual-load quantities with no population dose-response at all, `workouts_week`
    # counts sessions where the evidence is denominated in minutes, and the two intake
    # notes evidence timing-and-dose near bedtime rather than a daily-total curve.
}


def curve_of(metric: str) -> Curve:
    """The dose-response shape for ``metric`` — ``UNKNOWN`` when no note states one."""
    return CURVE.get(metric, Curve(UNKNOWN, None))


# ── the smallest change worth committing to ───────────────────────────────────

# A percentage of a low baseline is noise: +30 % of 35 MVPA min/week is 1.5 minutes a
# day, which nobody feels and nothing measures. The floor is what stops the calibration
# rule from asking for noise — and it exists ONLY where the corpus attaches an outcome to
# an increment of this size. A metric absent here gets no floor and is calibrated by
# percentage alone (`bounds.band_for`), which is the honest answer, not a missing one.
#
# ⚠ ANCHORED, NOT DERIVED, AND PROVISIONAL — see the module docstring. The corpus
# supports the ORDER OF MAGNITUDE of each number below; it does not pin the number. The
# outcome ledger is what will.
MEANINGFUL_STEP: dict[str, Target] = {
    # ~3.5 min/day. [mvpa_minutes_mortality] evidences benefit at doses of a few minutes a
    # day — Stamatakis 2022's VILPA finding is a MEDIAN 4.4 min/day (HR 0.62 for all-cause
    # mortality vs none) with bouts "as short as 1–2 minutes" counting — so a few minutes
    # a day is a real dose rather than a rounding error. 25 min/week sits inside that
    # evidenced range. It is also, deliberately, the number that reconciles legacy's
    # canonical example (35 min/week ⇒ ~60, not 150 — CHALLENGES.md §1).
    "mvpa_min": Target(25.0, "week", "mvpa_minutes_mortality"),
    # [steps_mortality]: "each additional 1,000 steps/day is associated with ~6–14 % lower
    # mortality". This is the one floor the corpus states as an increment directly, and
    # the note's own coaching directive agrees with its size ("on a low-step day
    # (<4,000), nudge toward ≥6,000 next — the largest marginal gain").
    "steps_total": Target(1000.0, "day", "steps_mortality"),
    # NOTHING ELSE HAS ONE, and each absence is a decision:
    # * `tst_min` — the corpus gives a BAND (7–8 h) and a threshold (<6 h), never a
    #   per-minute gradient. It also does not need one: sleep baselines are hundreds of
    #   minutes, so 10 % is already 20+ minutes of sleep. The percentage rule is only
    #   wrong-shaped where the baseline is small.
    # * `sri` — monotone, with no statement about marginal return per point. A floor here
    #   would be a number about a 0–100 index that no study measured.
    # * `workouts_week`, `alcohol_units` — their rounding step is 1 whole session/unit,
    #   which is already the smallest change either metric can express.
    # * `caffeine_mg`, `active_calories`, `cardio_load` — no dose-response evidence for
    #   the daily total at all.
}


def in_cadence(target: Target, cadence: str) -> float | None:
    """``target`` converted into the units ``series.recent_window`` reports for ``cadence``.

    A ``daily`` baseline is the AVERAGE of the trailing days and a ``weekly`` one is their
    SUM, so a per-day number multiplies by seven going up and a per-week number divides by
    seven coming down. That is arithmetic on one claim, not a second claim.

    A ``_LEVEL`` target does not convert: SRI 70 is a score, and seven of them added
    together is not a weekly anything. It returns ``None`` for a weekly cadence rather
    than a number that would look usable.
    """
    if target.period == _LEVEL:
        return target.value if cadence == "daily" else None
    per_week = target.value * 7 if target.period == "day" else target.value
    return per_week if cadence == "weekly" else per_week / 7


def meaningful_step(metric: str, cadence: str) -> float | None:
    """The smallest change in ``metric`` worth asking for, in ``cadence``'s units."""
    step = MEANINGFUL_STEP.get(metric)
    return None if step is None else in_cadence(step, cadence)


def natural_cadence(metric: str) -> str:
    """The cadence ``metric``'s population target is denominated in.

    The WHO MVPA target is a WEEKLY total; the steps plateau and the sleep need are
    per-DAY; an SRI score is a level. So a gap on MVPA is only meaningful weekly and a
    gap on steps only daily — reading either in the other cadence multiplies or divides
    the owner's distance to the goal by seven. Metrics with no target answer ``daily``,
    which is the cadence their baseline is a level in.
    """
    target = EVIDENCE_TARGET.get(metric)
    return "weekly" if target is not None and target.period == "week" else "daily"


def unranked_metrics() -> frozenset[str]:
    """Registry metrics with no population target — no gap is computable for these.

    Named as a function rather than a constant so it cannot fall out of step with the
    registry: a metric added to ``CHALLENGE_METRICS`` without a sourced target appears
    here automatically, which is the honest default.
    """
    targeted = set(EVIDENCE_TARGET) | {"tst_min"}
    return frozenset(m for m in CHALLENGE_METRICS if m not in targeted)
