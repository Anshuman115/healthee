"""Starting one rung: may it begin, and at what number.

WP-C4, split from :mod:`healthee.challenges.ladder` on the seam the two questions
already have. That module decides **when** the ladder moves — what a settled rung means,
whether a failure earns a deload or ends the program. This one decides **whether and how
the next rung actually begins**, which is a different question with different inputs
(the owner's week, their current baseline) and a different reason to change.

Both halves of it are fixes CHALLENGES.md §2.3 asks for, and neither invents a rule:

* :func:`hold_for` is the recovery guard, the per-owner cap and the duplicate-commitment
  rule, READ rather than restated. A ladder that advances through poor recovery is
  exactly the ratchet ``recovery_guard`` was built to stop, and it was built to be read
  by more than one surface.
* :func:`recalibrated_target` is ``bounds.calibrate`` — Gate A's band, read at the moment
  the rung starts instead of frozen when it was designed. Legacy calibrated rung 4
  against a person four weeks in the past.
"""

from __future__ import annotations

import math
from datetime import UTC, date, datetime
from uuid import UUID

from healthee.challenges import commitment, program_store, store
from healthee.challenges.bounds import Band, calibrate
from healthee.challenges.evaluate import start_date
from healthee.challenges.lifecycle import MAX_ACTIVE, window_end
from healthee.challenges.metrics import spec
from healthee.challenges.program_store import DELOAD
from healthee.challenges.recovery_guard import HARD_TRAINING_LEVERS, hold_reason, recovery_state
from healthee.challenges.scales import ROUND_STEP
from healthee.challenges.series import recent_value
from healthee.core.logging import get_logger
from healthee.derive._common import Cur

log = get_logger(__name__)

# The three reasons a rung may not start. `too_many_active` and `duplicate_commitment`
# reuse the challenge lifecycle's own words on purpose: they are the SAME two rules, met
# through a different door, and `api.validation` already maps both to a 409 a client can
# tell apart (#72's argument, unchanged).
UNDER_RECOVERED = "under_recovered"
TOO_MANY_ACTIVE = "too_many_active"
DUPLICATE_COMMITMENT = "duplicate_commitment"

# The recalibration verdicts, in the metric's own improving direction.
IN_BAND = "inside_the_current_band"
WITHIN_REACH = "already_within_reach"
TOO_FAR = "beyond_todays_band"
DELOAD_KEEPS_ITS_TARGET = "a_deload_is_not_recalibrated"


def hold_for(cur: Cur, user_id: UUID, tz: str, rung: dict, today: date) -> tuple[str, str] | None:
    """Why ``rung`` may not start right now, as ``(reason, sentence)``, or ``None``.

    Two forms of the same answer because it has two audiences, and neither may be
    derived from the other: ``programs.adopt`` refuses with the REASON (a client has to
    tell "you are full" from "you are already doing that" — the distinction #72 was
    careful to keep), and ``ladder``'s activation step stores the SENTENCE, because
    ``program.hold_reason`` is read by a person.

    Three causes, each a rule that already exists somewhere else and is READ here rather
    than restated:

    * **Recovery** (``recovery_guard``) — a ladder that advances through poor recovery is
      exactly the ratchet that guard was built to stop. It is applied only to a
      ``standard`` rung, because [[recovery_readiness]] D8 says recovery *eases or holds*
      and never escalates: withholding a DELOAD would withhold the ease itself, which is
      the same asymmetry ``adapt`` keeps ("it blocks raises, never eases"). The metric
      check comes before the read for the same reason it does there — two queries on a
      nightly path that can only change the answer for a training lever.
    * **The per-owner cap** (``lifecycle.MAX_ACTIVE``) — a rung IS a live commitment and
      is counted like one. Adopting a program takes a slot and advancement is normally
      net-zero (one rung closes as the next opens), but a standalone challenge adopted in
      between can fill it, and the ladder waits its turn rather than making the owner the
      one person holding four commitments.
    * **A clashing commitment** (``commitment.clashing``, #72) — the owner has taken on
      the same behaviour separately. Two live rules over the same rows is one commitment
      scored twice, whichever door it came through.

    All three are HOLDS, not failures: the program stays active, the next tick asks
    again, and the ladder resumes by itself when the reason clears.
    """
    if rung["kind"] != DELOAD and rung["metric"] in HARD_TRAINING_LEVERS:
        recovery, illness = recovery_state(cur, user_id, tz, today)
        reason = hold_reason(rung["metric"], recovery, illness)
        if reason is not None:
            return UNDER_RECOVERED, (
                f"the next rung asks for more {spec(rung['metric']).label.lower()} and "
                f"{reason} — more load is not what your recovery is asking for "
                f"[recovery_readiness]"
            )
    active = store.count_active(cur, user_id)
    if active >= MAX_ACTIVE:
        return TOO_MANY_ACTIVE, (
            f"you are already running {active} of {MAX_ACTIVE} challenges, so the next "
            "rung waits until one of them ends"
        )
    clash = commitment.clashing(rung["metric"], store.active_metrics(cur, user_id))
    if clash is not None:
        return DUPLICATE_COMMITMENT, (
            f"you are separately running a challenge on {clash}, which is the same "
            "behaviour this rung measures — the ladder waits rather than scoring it twice"
        )
    return None


def start_rung(cur: Cur, user_id: UUID, tz: str, rung: dict, today: date) -> dict:
    """Recalibrate, freeze the baseline, and set the rung running. Returns what changed.

    Mirrors ``lifecycle.adopt`` step for step — the same estimator, the same anchor, the
    same window arithmetic — because a rung is a challenge and starting one must not mean
    two different things.
    """
    target, recalibration = recalibrated_target(cur, user_id, tz, rung, today)
    window_days = int(rung["window_days"])
    adopted_at = datetime.now(tz=UTC)
    baseline = recent_value(cur, user_id, tz, rung["metric"], rung["cadence"], today, window_days)
    start = start_date(adopted_at, tz, today)
    started = program_store.activate_rung(
        cur,
        user_id,
        int(rung["id"]),
        adopted_at,
        window_end(start, tz, window_days),
        baseline,
        target,
    )
    if not started:
        # The row was not locked when we got here, which means something else advanced
        # this ladder concurrently. Not a rule outcome and not recoverable by guessing —
        # the transaction rolls back and the next tick sees a consistent world.
        raise RuntimeError(f"rung {rung['id']} was no longer locked when activation ran")
    log.info(
        "program %s: rung %s activated at %s (designed %s, baseline %s) for %s",
        rung["program_id"],
        rung["id"],
        target,
        rung["target_value"],
        baseline,
        user_id,
    )
    return {"rung_id": int(rung["id"]), "target": target, "recalibration": recalibration}


def recalibrated_target(
    cur: Cur, user_id: UUID, tz: str, rung: dict, today: date
) -> tuple[float, dict]:
    """The target this rung should actually run at, against the owner's CURRENT baseline.

    Fix (3), and the whole of it. Legacy froze rung 4's number when the ladder was
    designed, so it was calibrated against a person four weeks in the past. Here the band
    is read when the rung STARTS, from ``bounds.calibrate`` — the same Gate A band
    generation is bounded by, not a second rule.

    Outcomes, all reported so a surface can say which:

    * **a deload rung — not recalibrated at all.** The single most important line in this
      function, and it was found by composing the two rules on real numbers. A deload's
      target was computed from the owner's CURRENT data seconds earlier by
      ``adapt.deload_target``, so there is no staleness to fix and re-deriving it through
      a second rule would be exactly the two-answers-to-one-question failure this WP is
      told to avoid. Worse, the two rules disagree *systematically*: the band's low end is
      ``baseline + meaningful_step`` (1,000 steps/day, ``targets.MEANINGFUL_STEP``) while
      an ease floors at ``baseline × 1.05`` (250), so recalibrating a deload would snap it
      straight back up to a number ABOVE the one the owner had just failed — cancelling
      every deload for ``steps_total`` and making the whole failure branch dead code. The
      band is the *progressive-overload* band: it exists to stop an ask being too small to
      matter, which is not the question a step back is answering. Same asymmetry the
      recovery guard keeps: recalibration steps a rung UP, never back.
    * **inside the band** — leave it. The designed number is still a fair ask.
    * **already within reach** — the owner has moved past it. That is information, not a
      reason to shrug: the target rises to the gentle end of today's band, so the rung is
      still a step up from where they are rather than a lap of honour. This is the case
      the ladder was previously blind to.
    * **beyond today's band** — a bigger ask than a progressive-overload step from where
      they are now. The target comes DOWN to the band's demanding end. A ladder that
      keeps its design-time ambition after the owner has regressed is the ratchet §2.3
      exists to remove.
    * **no band at all** — too little of their data to calibrate against
      (``bounds.calibrate``'s own refusals). The designed number stands, and the refusal
      travels with it so nothing claims a recalibration that did not happen.

    **Moving the number here is not a breach of ``bounds``' reject-never-clamp rule.**
    That rule protects the model's COPY from disagreeing with the stored target at
    GENERATION time, where a proposal is one package of number-and-prose. By construction
    the copy contains no number (``bounds.copy_issue`` enforces it), which is exactly why
    ``store.set_target`` may already move a live target when the adapter recalibrates.
    """
    stored = float(rung["target_value"])
    if rung["kind"] == DELOAD:
        return stored, {"applied": False, "reason": DELOAD_KEEPS_ITS_TARGET, "target": stored}
    calibration = calibrate(cur, user_id, tz, rung["metric"], rung["cadence"], today)
    band = calibration.band
    if band is None:
        return stored, {"applied": False, "reason": calibration.refusal, "target": stored}
    common = {"designed": stored, "baseline": calibration.baseline}
    if band.contains(stored):
        return stored, {"applied": False, "reason": IN_BAND, "target": stored} | common
    moved = _snap_into(rung["metric"], band, stored)
    return moved, {"applied": True, "reason": _verdict(rung["metric"], band, stored)} | common | {
        "target": moved
    }


def _verdict(metric: str, band: Band, stored: float) -> str:
    """Which side of today's band the designed target fell on, in the IMPROVING direction.

    ``Band.low``/``high`` are ordered as numbers, not as difficulty (``bounds.Band``), so
    for a ``good="down"`` metric the demanding end is ``low``. Reading the direction off
    the registry is what stops "the owner has already passed this" from meaning the
    opposite thing on a cap.
    """
    beaten = stored < band.low if spec(metric).good == "up" else stored > band.high
    return WITHIN_REACH if beaten else TOO_FAR


def _snap_into(metric: str, band: Band, value: float) -> float:
    """Pull ``value`` to the nearer end of ``band``, on the metric's own rounding step.

    Rounded INWARD (up at the low end, down at the high end) rather than to-nearest,
    because to-nearest can land a hair outside a band narrower than one step and hand
    back a number Gate A would itself reject. Where no step multiple fits inside the band
    at all, the band's end is used verbatim — it is derived from a rounded baseline
    already, so it is a human number even when it is not a multiple.
    """
    step = float(ROUND_STEP.get(metric, 1))
    below = value < band.low
    edge = band.low if below else band.high
    snapped = math.ceil(edge / step) * step if below else math.floor(edge / step) * step
    return snapped if band.contains(snapped) else edge
