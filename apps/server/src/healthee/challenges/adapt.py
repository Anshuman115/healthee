"""The auto-calibration engine — keep a live challenge in the productive-struggle zone.

Ported from legacy ``llm/challenges.py::_adapt`` (:547), the piece CHALLENGES.md
§5.2 confirms as a keeper. Three properties make it trustworthy and all three
survive the port:

1. **Deterministic** — a rule over measured adherence, never an LLM judgement. A
   commitment the user agreed to may only move for a reason we can state
   ("you beat this for five days, so I raised it").
2. **Server-authoritative** — computed here from the owner's own rows; a client may
   *request* an adaptation, it can never dictate the number.
3. **Relative to the person** — the ease floor is the owner's OWN frozen baseline,
   not a population ideal.

This function only ever SUGGESTS. Applying the suggestion is a lifecycle concern
(WP-C2) and, per §5.2, a raise is surfaced for one-tap confirmation rather than
applied silently under the user.

Changed from legacy: the challenge arrives as a mapping instead of a positional
row tuple read through an index map (``_iC``), the owner and zone are threaded in,
and the threshold arithmetic is split into a pure helper so the rules can be
known-value tested without a database. The thresholds, factors, guards and
rounding steps are verbatim.

One rule is NOT legacy's, and it is a deliberate behaviour change (#61): a raise
is bounded for **every** metric. Legacy capped only the metrics in ``IDEAL``, so
``active_calories`` and ``cardio_load`` could be raised +20 % indefinitely — see
:data:`OWNER_CEILING_FACTOR` for the owner-relative bound that replaces "unbounded"
and for why "no basis for a ceiling" now means "do not raise".

## The recovery guard — a raise is a claim the owner's data may contradict

The second rule that is not legacy's, and the one this module was missing. A raise
says *"you can absorb more"*. For a training-stimulus metric that is precisely the
claim an under-recovered owner's own rows deny — and somebody can beat an MVPA or
cardio-load target **because** they are overtraining, so performance alone is the
wrong evidence for the conclusion. WP-C3c already refused to OFFER those levers
under exactly these conditions; the adapter would happily ratchet one that had been
adopted the week before. Same rule, one definition, now read by both
(:mod:`healthee.challenges.recovery_guard`).

Three properties of the guard, each deliberate:

* **It blocks raises, never eases.** Easing a target for somebody whose recovery is
  poor is the correct and kind behaviour and must keep working —
  [[recovery_readiness]] D8 says recovery *eases or holds*, it never escalates.
* **It is scoped to the training-load metrics**, not applied blanket. A raise on
  sleep or regularity is recovery-*supporting*, and blocking it would withhold the
  one thing that helps. ``recovery_guard.HARD_TRAINING_LEVERS`` argues the set.
* **A blocked raise is EXPLAINED, not silent.** It returns a ``direction:
  "withheld"`` adaptation with ``suggested: None`` and the reason, because "not
  raising this while your recovery is low" is both more useful and more honest than
  no suggestion at all. ``None`` keeps its one meaning — "performance is inside the
  productive band" — instead of quietly acquiring a second.
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from healthee.challenges.evaluate import start_date
from healthee.challenges.metrics import IDEAL, round_target, spec
from healthee.challenges.recovery_guard import HARD_TRAINING_LEVERS, hold_reason, recovery_state
from healthee.challenges.series import metric_series
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur

# Performance ratios (achieved / target) that trigger a recalibration, and the
# factors applied. Verbatim from legacy (:577, :578, :586, :589).
RAISE_RATIO = 1.2  # averaging ≥1.2× target ⇒ it has gone stale
RAISE_FACTOR = 1.2  # …so raise ~+20 %
EASE_RATIO = 0.7  # averaging ≤0.7× target ⇒ they are failing out
EASE_FACTOR = 0.85  # …so ease ~−15 %

# Days a challenge must have run before performance means anything (:557).
MIN_ELAPSED_DAYS = 5

# The floor an ease may never go below: 5 % above the owner's OWN frozen baseline,
# so easing can never hand back a target they had already beaten before adopting
# (:588). Falls back to what they are actually achieving when no baseline exists.
EASE_FLOOR_FACTOR = 1.05

# "No room to move" guards — a change smaller than these is noise, and churning a
# live commitment for a rounding-step's worth of difference is worse than leaving
# it alone. Verbatim from legacy (:583, :590).
MIN_RAISE_GAIN = 1.04  # a raise must land >4 % above the current target
MIN_EASE_DROP = 0.97  # an ease must land >3 % below it

# The raise ceiling for a metric with NO entry in `IDEAL`, expressed against the
# owner's own frozen baseline. `active_calories` and `cardio_load` are the two: both
# are individual-load quantities with no population target, so legacy left them
# UNBOUNDED — and an unbounded ceiling on a +20 %-per-recalibration rule compounds
# (five raises is 2.5×), which is how an engine walks a real person into a hole while
# every individual step looks reasonable.
#
# NOT EVIDENCE — the same status as `IDEAL["workouts_week"]`, and stated here so
# nobody mistakes it for one: no note in the corpus prescribes a personal training-load
# or active-energy ceiling, so none is cited and this number is never surfaced as a
# target or a rationale. It is a bound on what the ENGINE may do unattended, chosen to
# sit just above CHALLENGES.md §5.1's +10–30 % progressive-overload band so the adapter
# can traverse that band and then stop.
#
# The companion rule matters as much as the number: with no ideal AND no baseline there
# is nothing owner-relative to bound against, and the engine declines to raise at all
# rather than guessing — "not enough data" beats an optimistic guess (CLAUDE.md).
OWNER_CEILING_FACTOR = 1.5

# The three directions an adaptation can carry. `withheld` is not a fourth kind of
# recalibration — it is a raise that the recovery guard refused, reported so a surface
# can say why instead of showing nothing. Its `suggested` is `None`, which is what
# `lifecycle.apply_adaptation` keys the refusal off: there is no number to apply.
UP = "up"
DOWN = "down"
WITHHELD = "withheld"


def suggest_adaptation(
    cur: Cur,
    user_id: UUID,
    tz: str,
    challenge: dict,
    progress: dict,
    today: date | None = None,
) -> dict | None:
    """A ``{direction, suggested, current, reason}`` recalibration, or ``None``.

    ``None`` means "leave the target alone" and is the answer in every thin-signal
    case: a ``<=`` challenge, a challenge not yet adopted or already complete,
    fewer than
    :data:`MIN_ELAPSED_DAYS` days elapsed, a non-positive target, too few logged
    days to be real, or performance inside the productive band.

    A ``direction`` of :data:`WITHHELD` (with ``suggested: None``) is the fourth
    answer: performance earned a raise and the owner's recovery data refuses it. It
    is reported rather than swallowed into ``None`` so the reason survives to a
    surface — see the module docstring.

    The ``<=`` exclusion is a decision, not an omission (#61 made caps expressible
    on every cadence). Tightening a cap on a good week would punish the owner for
    complying, and loosening one would hand back the exact allowance they committed
    to cut; neither has a rule behind it the way progressive overload does. A cap's
    target moves when the owner changes it.
    """
    if challenge["comparator"] != ">=" or progress.get("complete"):
        return None
    adopted_at = challenge.get("adopted_at")
    target = float(challenge["target_value"])
    if adopted_at is None or target <= 0:
        return None
    today = today or user_today(tz)
    start = start_date(adopted_at, tz, today)
    elapsed = (today - start).days + 1
    if elapsed < MIN_ELAPSED_DAYS:
        return None
    achieved = _achieved(cur, user_id, tz, challenge, start, today, elapsed)
    if achieved is None:
        return None
    metric = challenge["metric"]
    adaptation = _adaptation(metric, target, challenge.get("baseline_value"), achieved)
    if adaptation is None or adaptation["direction"] != UP:
        return adaptation  # an ease is never guarded — see the module docstring
    return _recovery_checked(cur, user_id, tz, metric, today, adaptation)


def _recovery_checked(
    cur: Cur, user_id: UUID, tz: str, metric: str, today: date, raised: dict
) -> dict:
    """``raised``, unless this owner's own recovery data contradicts what it claims.

    The read is LAZY and deliberately so: it costs two queries, it runs on every
    active challenge of every feed request, and it can only change the answer for a
    training-load metric that has *already* earned a raise. Everything else returns
    before touching the database (standards §Performance — the feed is a read path).
    """
    if metric not in HARD_TRAINING_LEVERS:
        return raised
    recovery, illness = recovery_state(cur, user_id, tz, today)
    hold = hold_reason(metric, recovery, illness)
    if hold is None:
        return raised
    return {
        "direction": WITHHELD,
        "suggested": None,
        "current": raised["current"],
        "reason": (
            f"not raising this while {hold} — you are {raised['reason']}, "
            f"but more load is not what your recovery is asking for [recovery_readiness]"
        ),
    }


def _achieved(
    cur: Cur, user_id: UUID, tz: str, challenge: dict, start: date, today: date, elapsed: int
) -> float | None:
    """What the owner is actually averaging, expressed in the TARGET's units.

    A ``weekly`` target is a 7-day total and a ``total`` target is a whole-window
    total, so the daily mean is scaled to match before it is compared — comparing a
    daily average against a weekly target would read as a 7× failure. Verbatim from
    legacy (:563–573).

    ``None`` when fewer than half the elapsed days (minimum three) carry data:
    adapting a commitment on two logged days would be a confident call on noise.
    """
    series = metric_series(
        cur, user_id, tz, challenge["metric"], start - timedelta(days=1), until=today
    )
    values = [v for day, v in series.items() if start <= day <= today]
    if len(values) < max(3, elapsed // 2):
        return None
    mean = sum(values) / len(values)
    cadence = challenge["cadence"]
    if cadence == "weekly":
        return mean * 7
    if cadence == "total":
        return mean * int(challenge.get("window_days") or 7)
    return mean


def _adaptation(
    metric: str, target: float, baseline_value: float | None, achieved: float
) -> dict | None:
    """The pure threshold rule: measured performance → a new target, or ``None``.

    Separated from the read so the calibration rules — the part a user's live
    commitment moves on — are known-value testable without a database.
    """
    ratio = achieved / target
    unit = spec(metric).unit
    reason = f"averaging {round(achieved)}{unit} vs {round(target)}{unit} target"
    if ratio >= RAISE_RATIO:
        return _raise_to(metric, target, baseline_value, reason)
    if ratio <= EASE_RATIO:
        return _ease_to(metric, target, baseline_value, achieved, reason)
    return None


def _ceiling(metric: str, baseline_value: float | None) -> float | None:
    """The highest target a raise may reach, or ``None`` when there is no basis for one.

    The metric's evidence ideal if it has one; otherwise a bound relative to the
    owner's OWN frozen baseline (:data:`OWNER_CEILING_FACTOR`), which is the only
    honest anchor available for a quantity with no population target. ``None`` means
    "we cannot say", and its caller declines to raise rather than raising unbounded.
    """
    ideal = IDEAL.get(metric)
    if ideal:
        return ideal
    if baseline_value:
        return float(baseline_value) * OWNER_CEILING_FACTOR
    return None


def _raise_to(metric: str, target: float, baseline_value: float | None, reason: str) -> dict | None:
    """Raise ~+20 %, capped by :func:`_ceiling` — evidence ideal or owner-relative."""
    ceiling = _ceiling(metric, baseline_value)
    if ceiling is None:  # no ideal and no baseline — nothing to bound a raise against
        return None
    new = round_target(metric, min(target * RAISE_FACTOR, ceiling))
    if new <= target * MIN_RAISE_GAIN:  # already at the ceiling — no room to grow
        return None
    return {"direction": UP, "suggested": new, "current": target, "reason": reason}


def _ease_to(
    metric: str, target: float, baseline_value: float | None, achieved: float, reason: str
) -> dict | None:
    """Ease ~−15 %, floored just above the owner's own baseline (the floor guard)."""
    floor = float(baseline_value) * EASE_FLOOR_FACTOR if baseline_value else achieved
    new = round_target(metric, max(target * EASE_FACTOR, floor))
    if new >= target * MIN_EASE_DROP:  # already near their baseline — nothing to give
        return None
    return {"direction": DOWN, "suggested": new, "current": target, "reason": reason}
