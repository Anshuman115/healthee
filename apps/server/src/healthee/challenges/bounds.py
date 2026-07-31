"""Gate A — the baseline-bounds check the LLM cannot talk its way past.

CHALLENGES.md §5.1: the model authors the challenge, and two deterministic gates
dispose. This is the first of them, and it is the fix legacy never had — legacy only
*instructed* calibration in its prompt (``CALIBRATION``, :218) and never verified it,
so "12,000 steps" on a 3,000-step baseline reached the database.

## Four decisions, each argued because each has a wrong-looking obvious answer

**1. Direction comes from the registry, never from a "+10–30 %" formula.** Half the
registry is ``good="down"`` (#61's cap metrics — alcohol, caffeine), and for those
progressive overload means a **lower** target. So the band is expressed as a fractional
move *in the direction that counts as improvement* and applied as ``baseline × (1 ± d)``.
A band written as "+10–30 %" would ask an owner to drink 30 % MORE.

**1b. A percentage is the wrong SHAPE at a low baseline, so the step has a floor and the
band has a cap** (WP-C3c). ``+30 %`` of 35 MVPA min/week is a minute and a half a day:
nobody feels it and nothing measures it, while the same ``+30 %`` at 140 min/week is a
real push. And the metrics where a low baseline is common are exactly the ones whose
corpus says the dose-response is *steepest at the bottom* — the owner with the most to
gain is the one a percentage band under-serves. So one rule replaces the band's two ends::

    move   = max(fraction × baseline, meaningful_step, rounding_step)
    target = baseline ± move, then capped at the evidence target

with the floor and the target both cited per metric in ``targets`` and both **absent**
for any metric whose corpus states neither. The cap wins over the floor when they
disagree, because arriving at the population target is meaningful by definition even
when the remaining distance is small — and when the remaining distance is under one
rounding step there is nothing left to ask for at all (:func:`at_evidence_target`).
This is what reconciles CHALLENGES.md §1's legacy example (35 min/week ⇒ ~60, floor
governs) with §5.1's band (90 ⇒ ~117, percentage governs; 140 ⇒ 150, cap governs).

**2. Out of band ⇒ REJECT. Nothing here ever clamps.** Clamping is the dangerous
option: if the model wrote *"walk 12,000 steps — a 20 % stretch on your 10,000
baseline"* and we silently stored 3,900, the copy would lie about both numbers. So
``target_value`` is never rewritten by any code path in this package — the stored
number IS the number the model was writing about, which makes "the stored number and
the shipped prose cannot disagree" structural rather than hopeful. A batch that loses
every proposal to this gate is retried ONCE with the violations named
(``generate``), because the honest fix for a bad number is a better number, not a
quieter one.

**3. A thin baseline refuses the metric outright.** No baseline, fewer than
``MIN_COMPARISON_DAYS`` measured days, or a baseline of zero ⇒ there is no band, and
the metric is offered to the model as unavailable with the reason. Calibrating against
noise is how a system produces a confident number about somebody it knows nothing
about. The zero case is not a corner: ``metrics.ManualEntrySource`` zero-fills, so an
owner who never logs caffeine has a baseline of ``0.0`` over seven "measured" days —
indistinguishable from an owner who genuinely abstains, and a cap challenge is
unshippable either way (that limit is stated in ``metrics.py`` for this module to act on).

## What "the copy may not disagree" is enforced as

Decision 2 keeps the stored number honest. :func:`copy_issue` closes the other half —
the model contradicting *itself* by writing one number in ``target_value`` and a
different one in the prose beside it. Rule: in ``title`` / ``why`` /
``expected_outcome``, any numeral at or above the band's low end must EQUAL the target.
A number that big is a target-shaped number; if it is not the target it is either a
second target or a claim about the baseline, and both are the failure this gate exists
to prevent. Numbers below the band (a percentage, a heart rate, a clock hour) pass
untouched. ``how_to`` is deliberately exempt — its numbers are about *method*
("3× 25-min walks"), and for a small-target metric like ``workouts_week`` a method
number is legitimately larger than the target.
"""

from __future__ import annotations

import re
from collections.abc import Callable
from dataclasses import dataclass
from datetime import date
from uuid import UUID

from healthee.challenges.metrics import ROUND_STEP, spec
from healthee.challenges.series import MIN_COMPARISON_DAYS, recent_window
from healthee.challenges.targets import in_cadence, meaningful_step, resolve_target
from healthee.derive._common import Cur

# The progressive-overload band, as a fraction of the owner's own baseline, in the
# direction the metric counts as improvement. CHALLENGES.md §5.1's "roughly +10–30 %"
# taken literally. The ceiling is deliberately BELOW `adapt.OWNER_CEILING_FACTOR`
# (1.5×): a generated target is a guess about a person, an adapted one is a response to
# five days of measured performance, so the engine is allowed to walk a live challenge
# further than generation may reach for on day one.
MIN_STRETCH_FRACTION = 0.10
MAX_STRETCH_FRACTION = 0.30

# Float slack for the in-band comparison. The band's ends are products of a rounded
# baseline and a fraction, so an exactly-on-the-boundary target must not fail on the
# last bit of a double.
_EPSILON = 1e-6

# The cadences generation may propose. `total` is ABSENT and that is a refusal, not an
# oversight: `series.recent_value` computes a `total` baseline as the trailing SEVEN-day
# sum while `evaluate._cumulative` scores a `total` as the whole-WINDOW total, so for
# any `window_days != 7` the frozen baseline and the target are in different units and
# there is no honest band to check the target against. Generation declines to emit the
# shape rather than calibrate against a mismatched number.
GENERATABLE_CADENCES: frozenset[str] = frozenset({"daily", "weekly"})

# A whole numeral in prose. The lookbehind refuses a digit welded to a letter or to a
# clock's colon (`vo2max`, `spo2`, the `30` of `15:30`); the trailing `(?![\d.])` forces
# the match to be MAXIMAL, so the engine cannot backtrack to a one-digit prefix and
# thereby slip past a rule written as a lookahead. Everything else that must be skipped
# is decided in Python, where it can be read.
_NUMERAL_RE = re.compile(r"(?<![A-Za-z0-9.:])\d[\d,]*(?:\.\d+)?(?![\d.])")
# Citation and personal-finding tokens are stripped before the scan: `[vo2max_estimate]`
# is a citable id, not a number, and the validator already owns those.
_CITATION_RE = re.compile(r"\[[^\]]*\]")


@dataclass(frozen=True)
class Band:
    """The interval a proposed ``target_value`` must land inside, in the metric's units.

    ``low``/``high`` are ordered as numbers, not as difficulty: for a ``good="down"``
    metric ``low`` is the most demanding end (the deepest cut) and ``high`` the gentlest.
    """

    low: float
    high: float

    def contains(self, value: float) -> bool:
        return self.low - _EPSILON <= value <= self.high + _EPSILON


@dataclass(frozen=True)
class Calibration:
    """What Gate A knows about one (metric, cadence) pair for one owner.

    ``band is None`` is a complete answer, not a missing one: ``refusal`` says which
    rule produced it, so the prompt can tell the model the metric is unavailable and a
    rejection can be logged with a reason (standards §Errors).

    ``target``/``target_note`` are the population target the band was capped at, in this
    cadence's units, and the note it came from. ``None`` means the corpus has no target
    for this metric — the band is then bounded only by the owner's own baseline, which is
    an honest bound and not a missing one (``targets.EVIDENCE_TARGET``).
    """

    metric: str
    cadence: str
    baseline: float | None
    baseline_days: int
    band: Band | None
    refusal: str | None
    target: float | None = None
    target_note: str | None = None


def at_evidence_target(metric: str, baseline: float, direction: str, target: float | None) -> bool:
    """True when less than one rounding step of ``metric`` separates ``baseline`` from goal.

    The predicate the cap needs and the reason a capped band can be empty: if the whole
    remaining distance to the population target is smaller than the granularity the metric
    is even expressed in, there is no target to ask for that is not the owner's own
    baseline wearing a rounder number.

    A baseline at or PAST the target is deliberately not "at" it: the cap only ever binds
    while the goal is ahead, so an owner beyond it gets an ordinary baseline-relative band
    (the notes are explicit that 150 min/week is "a floor, not a ceiling"). That they have
    no population gap left is a statement about which lever is worth pulling, and
    ``levers`` is where it belongs — not a refusal to express any challenge at all.
    """
    if target is None:
        return False
    gap = target - baseline if direction == "up" else baseline - target
    return 0 < gap < float(ROUND_STEP.get(metric, 1))


def band_for(
    metric: str,
    baseline: float,
    direction: str,
    *,
    floor: float | None = None,
    target: float | None = None,
) -> Band | None:
    """The progressive-overload interval around ``baseline``, or ``None`` if none exists.

    The move in the improving direction is ``max`` of three lower bounds, each answering a
    different objection to the same number:

    * ``fraction × baseline`` — progressive overload relative to the person (§5.1).
    * ``floor`` — the smallest change the corpus treats as a real dose
      (``targets.MEANINGFUL_STEP``). Absent for most metrics, and absence means
      percentage-only, not zero.
    * the metric's **rounding step** — a band of [2.2, 2.6] on a ``workouts_week``
      baseline of 2 contains no representable target at all, so the only meaningful
      stretch (one more workout) would be rejected as "too ambitious".

    ``target`` then caps the band at the population goal, in the metric's improving
    direction — a ceiling for ``good="up"``, a floor for ``good="down"``. It binds only
    while the goal is ahead of the owner, and it overrides the ``floor`` when the two
    disagree: reaching the evidence target is meaningful whatever the remaining distance,
    right up to the point where that distance is under one rounding step and there is
    nothing left to ask for (:func:`at_evidence_target`).

    A baseline of zero has no band in EITHER direction, and the guard is here rather than
    only in :func:`calibrate` so the property belongs to the rule instead of to one call
    site. Without it a zero baseline would hand back ``[step, step]`` — a target invented
    from a rounding constant, dressed as progressive overload against a person the
    arithmetic knows nothing about.
    """
    if baseline <= 0 or at_evidence_target(metric, baseline, direction, target):
        return None
    step = float(ROUND_STEP.get(metric, 1))
    near = max(baseline * MIN_STRETCH_FRACTION, floor or 0.0, step)
    far = max(baseline * MAX_STRETCH_FRACTION, near)
    if direction == "up":
        ahead = target is not None and target > baseline
        return _clip(Band(low=baseline + near, high=baseline + far), target if ahead else None, min)
    if baseline - near <= 0:
        return None  # one step below their intake is already zero — nothing to cap
    ahead = target is not None and target < baseline
    return _clip(Band(low=baseline - far, high=baseline - near), target if ahead else None, max)


def _clip(band: Band, cap: float | None, toward: Callable[[float, float], float]) -> Band:
    """Pull both ends of ``band`` back to ``cap`` — ``min`` going up, ``max`` going down.

    Both ends move, so a band whose gentle end already overshot the goal collapses onto
    the goal rather than straddling it. Ordering survives because ``min``/``max`` against
    one constant is monotone.
    """
    if cap is None:
        return band
    return Band(low=toward(band.low, cap), high=toward(band.high, cap))


def calibrate(
    cur: Cur, user_id: UUID, tz: str, metric: str, cadence: str, today: date
) -> Calibration:
    """Read ``user_id``'s own baseline for one (metric, cadence) and derive its band.

    The baseline is :func:`series.recent_window` — the SAME estimator ``lifecycle.adopt``
    freezes onto the row, so the number this gate bounds against and the number the
    ledger later judges the outcome by cannot be computed two different ways.
    """
    if cadence not in GENERATABLE_CADENCES:
        return Calibration(metric, cadence, None, 0, None, "cadence_not_generatable")
    baseline, days = recent_window(cur, user_id, tz, metric, cadence, today)
    if baseline is None or days < MIN_COMPARISON_DAYS:
        return Calibration(metric, cadence, baseline, days, None, "thin_baseline")
    if baseline <= 0:
        # Zero is a real reading, not a gap — and there is no proportional band around
        # it. Inventing a starter number here would be neither evidence nor personal.
        return Calibration(metric, cadence, baseline, days, None, "no_baseline_signal")
    goal = resolve_target(cur, user_id, metric, today)
    target = None if goal is None else in_cadence(goal, cadence)
    note = None if goal is None or target is None else goal.note_id
    direction = spec(metric).good
    band = band_for(
        metric, baseline, direction, floor=meaningful_step(metric, cadence), target=target
    )
    refusal = _no_band_reason(metric, baseline, direction, target) if band is None else None
    return Calibration(metric, cadence, baseline, days, band, refusal, target, note)


def _no_band_reason(metric: str, baseline: float, direction: str, target: float | None) -> str:
    """Which rule emptied the band — the same predicate :func:`band_for` decided by."""
    if at_evidence_target(metric, baseline, direction, target):
        return "already_at_the_evidence_target"
    return "nothing_to_cap"


def target_issue(calibration: Calibration, target: float) -> str | None:
    """The reason ``target`` may not ship for this owner, or ``None`` if it may.

    Never returns a corrected number, because nothing here corrects one (module
    docstring, decision 2).
    """
    if calibration.band is None:
        return (
            f"{calibration.metric}/{calibration.cadence}: no target can be calibrated "
            f"({calibration.refusal})"
        )
    if not calibration.band.contains(target):
        return (
            f"{calibration.metric}/{calibration.cadence}: target {target:g} is outside the "
            f"progressive-overload band {calibration.band.low:g}–{calibration.band.high:g} "
            f"for your baseline of {calibration.baseline:g}"
        )
    return None


def copy_issue(calibration: Calibration, target: float, text: str) -> str | None:
    """The reason this copy contradicts the stored target, or ``None``.

    See the module docstring for why "any numeral at or above the band's low end must
    equal the target" is the rule, and why ``how_to`` is not passed here.
    """
    band = calibration.band
    if band is None:
        return None  # nothing shippable anyway — `target_issue` already refused it
    prose = _CITATION_RE.sub(" ", text)
    for match in _NUMERAL_RE.finditer(prose):
        if _is_not_a_quantity(prose[match.end() :]):
            continue
        value = float(match.group().replace(",", ""))
        if value + _EPSILON >= band.low and abs(value - target) > _EPSILON:
            return (
                f"{calibration.metric}: copy names {match.group()} but the stored target "
                f"is {target:g} — the number the user reads must be the number we store"
            )
    return None


def _is_not_a_quantity(after: str) -> bool:
    """True when what follows a numeral proves it is not a target-shaped quantity.

    A percentage ("a 20 % stretch") is a RELATIVE statement about the target, not a
    rival target. A clock hour ("caffeine after 15:00") is a time of day. A digit run
    that continues into a word is part of an identifier, not a number.
    """
    is_clock_hour = after[:1] == ":" and after[1:2].isdigit()
    return after[:1].isalpha() or after.lstrip()[:1] == "%" or is_clock_hour
