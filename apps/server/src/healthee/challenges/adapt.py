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
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from healthee.challenges.evaluate import start_date
from healthee.challenges.metrics import IDEAL, round_target, spec
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
    case: a ``<=`` challenge (easing a cap is a different, unported rule), a
    challenge not yet adopted or already complete, fewer than
    :data:`MIN_ELAPSED_DAYS` days elapsed, a non-positive target, too few logged
    days to be real, or performance inside the productive band.
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
    return _adaptation(challenge["metric"], target, challenge.get("baseline_value"), achieved)


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
    series = metric_series(cur, user_id, tz, challenge["metric"], start - timedelta(days=1))
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
        return _raise_to(metric, target, reason)
    if ratio <= EASE_RATIO:
        return _ease_to(metric, target, baseline_value, achieved, reason)
    return None


def _raise_to(metric: str, target: float, reason: str) -> dict | None:
    """Raise ~+20 %, capped at the metric's evidence ideal (the ceiling guard)."""
    new = target * RAISE_FACTOR
    ideal = IDEAL.get(metric)
    if ideal:
        new = min(new, ideal)
    new = round_target(metric, new)
    if new <= target * MIN_RAISE_GAIN:  # already at the ceiling — no room to grow
        return None
    return {"direction": "up", "suggested": new, "current": target, "reason": reason}


def _ease_to(
    metric: str, target: float, baseline_value: float | None, achieved: float, reason: str
) -> dict | None:
    """Ease ~−15 %, floored just above the owner's own baseline (the floor guard)."""
    floor = float(baseline_value) * EASE_FLOOR_FACTOR if baseline_value else achieved
    new = round_target(metric, max(target * EASE_FACTOR, floor))
    if new >= target * MIN_EASE_DROP:  # already near their baseline — nothing to give
        return None
    return {"direction": "down", "suggested": new, "current": target, "reason": reason}
