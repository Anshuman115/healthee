"""Gate A — the baseline-bounds check the LLM cannot talk its way past.

CHALLENGES.md §5.1: the model authors the challenge, and two deterministic gates
dispose. This is the first of them, and it is the fix legacy never had — legacy only
*instructed* calibration in its prompt (``CALIBRATION``, :218) and never verified it,
so "12,000 steps" on a 3,000-step baseline reached the database.

## Three decisions, each argued because each has a wrong-looking obvious answer

**1. Direction comes from the registry, never from a "+10–30 %" formula.** Half the
registry is ``good="down"`` (#61's cap metrics — alcohol, caffeine), and for those
progressive overload means a **lower** target. So the band is expressed as a fractional
move *in the direction that counts as improvement* and applied as ``baseline × (1 ± d)``.
A band written as "+10–30 %" would ask an owner to drink 30 % MORE.

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
from dataclasses import dataclass
from datetime import date
from uuid import UUID

from healthee.challenges.metrics import ROUND_STEP, spec
from healthee.challenges.series import MIN_COMPARISON_DAYS, recent_window
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
    """

    metric: str
    cadence: str
    baseline: float | None
    baseline_days: int
    band: Band | None
    refusal: str | None


def band_for(metric: str, baseline: float, direction: str) -> Band | None:
    """The progressive-overload interval around ``baseline``, or ``None`` if none exists.

    Widened, never narrowed, by the metric's rounding step: a band of [2.2, 2.6] on a
    ``workouts_week`` baseline of 2 contains no representable target at all (the step is
    1), so the only meaningful stretch — one more workout — would be rejected as "too
    ambitious". The step-widening moves the near end out to the first representable
    stretch and takes the far end with it.

    A baseline of zero has no band in EITHER direction, and the guard is here rather than
    only in :func:`calibrate` so the property belongs to the rule instead of to one call
    site. Without it a zero baseline would hand back ``[step, step]`` — a target invented
    from a rounding constant, dressed as progressive overload against a person the
    arithmetic knows nothing about.
    """
    if baseline <= 0:
        return None
    step = float(ROUND_STEP.get(metric, 1))
    if direction == "up":
        low = max(baseline * (1 + MIN_STRETCH_FRACTION), baseline + step)
        return Band(low=low, high=max(baseline * (1 + MAX_STRETCH_FRACTION), low))
    high = min(baseline * (1 - MIN_STRETCH_FRACTION), baseline - step)
    if high <= 0:
        return None  # one step below their intake is already zero — nothing to cap
    return Band(low=min(baseline * (1 - MAX_STRETCH_FRACTION), high), high=high)


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
    band = band_for(metric, baseline, spec(metric).good)
    refusal = None if band else "nothing_to_cap"
    return Calibration(metric, cadence, baseline, days, band, refusal)


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
