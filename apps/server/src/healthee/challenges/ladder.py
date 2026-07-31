"""Advancement — the fix for everything legacy's ``_advance_program`` got wrong.

WP-C4, CHALLENGES.md §2.3. Legacy's ladder (``llm/challenges.py:1091``) did four things
this module deliberately does not:

1. it advanced when ``days_left <= 0`` **whatever the metric had done**, and recorded the
   rung ``"completed"`` regardless — so a rung the owner FAILED became a success in the
   ledger and the ladder pushed them up anyway;
2. it had **no way back**: no repeat, no deload, no ramp-down, forward only;
3. it froze every rung's target at design time, so rung 4 was calibrated against a
   baseline from four weeks earlier;
4. it never asked whether the owner could absorb the next step.

## The governing rule: this module ORCHESTRATES, it does not score

Nothing here evaluates a challenge, decides a terminal status, freezes an outcome,
calibrates a band, or computes an ease. Every one of those already exists and is tested,
and a second copy is how this track has repeatedly ended up with two definitions of one
number. So:

* **A rung is closed by ``lifecycle.finalize_due``, exactly like a standalone challenge.**
  That is where fix (1) comes from and it needed no code: ``terminal_status`` already
  answers ``completed`` / ``expired`` honestly, ``ledger`` already maps ``expired`` to
  ``unmet_timed_out``, and both already run in the nightly chain. Advancement therefore
  reads a rung's **stored** status rather than re-evaluating it — which also makes this
  function idempotent and free of any ordering dependency on the step before it.
* **An ease is ``adapt.deload_target``** — the adapter's own −15 % and, critically, its
  own floor, which may never hand back a target the owner had already beaten.
* **A recalibration is ``bounds.calibrate``** — Gate A's band, the same one generation is
  bounded by, read at the moment the rung actually starts.
* **A hold is ``recovery_guard.hold_reason``** — the one definition of "do not push this
  owner harder right now", already read by ``levers`` and ``adapt``.

## The state machine

The ladder has one active rung at a time, or none while it waits::

    (locked rung exists)
        │  hold_for() says no  ──────────────► advancement_held   (program stays active,
        │                                       retried on the next tick, resumes when
        │                                       the reason clears)
        └► activate: recalibrate → freeze baseline → status='active'

    active rung ── finalize_due ─► completed ─► activate the next locked rung
                                              └─ none left ─► program completed
                                ─► expired   ─► deload, or stall (below)
                                ─► abandoned ─► program abandoned with it

## Failure: an INSERTED deload rung, not a repeat — and the ledger is the tiebreak

A repeat (re-arming the failed row at an eased target) is simpler and **cannot be
recorded**. ``challenge_outcome`` is keyed on ``challenge_id`` and written
``ON CONFLICT DO NOTHING`` on purpose — an outcome is a historical record, not a
mutable one — so a second run of one row either produces no second outcome or overwrites
the first. Both lose the fact that a deload happened, which is precisely the fact the
ledger exists to keep.

An inserted rung is a new ``challenge`` row: its own frozen baseline, its own outcome,
its own place in the order. The ladder then reads back, in ``rung_index`` order, as the
story it actually was — ``met → unmet_timed_out → (deload) met → met``. The cost is
renumbering, and it is a cost worth paying: ``rung_index`` is an ORDERING, ids are
identity, and the outcome ledger stores no index at all.

## Giving up: a ladder that eases forever is its own failure mode

Two triggers, both honest, both ending the program as ``stalled`` (never ``completed``,
and never ``abandoned`` — the owner did not quit):

* **No room left to ease** — ``deload_target`` returns ``None`` because the adapter's
  floor is already at or above the failed target. The next step down would be at or below
  what they were doing before the ladder started, so there is no easier version to offer.
* **Ground down** — :data:`MAX_CONSECUTIVE_DELOADS` deloads have already timed out unmet
  in an unbroken run. Three failures at progressively easier targets is enough evidence
  that the answer is not a smaller number, and continuing would be the grind CHALLENGES.md
  §2.3 names as the thing to avoid.
"""

from __future__ import annotations

from datetime import UTC, date, datetime
from uuid import UUID

from healthee.challenges import program_store
from healthee.challenges.adapt import deload_target
from healthee.challenges.program_store import DELOAD, LOCKED
from healthee.challenges.rung import hold_for, start_rung
from healthee.core.logging import get_logger
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur

log = get_logger(__name__)

# How many deloads may time out unmet in an unbroken run before the ladder stops. Two
# deloads means three failures in a row (the original rung plus both eased retries), each
# at a lower target than the last. PROVISIONAL, like every constant in `targets`: the
# outcome ledger records every one of those rungs with its target and its status, so
# "how many eased retries actually convert" becomes a query rather than an opinion once
# there are rows. It is not tuned by pooling owners (CHALLENGES.md §5.1a).
MAX_CONSECUTIVE_DELOADS = 2

# One active ladder per OWNER. Legacy's was global because legacy had one user; a cap
# that leaked across tenants would let one owner's program lock every other owner out.
MAX_ACTIVE_PROGRAMS = 1

# The rung statuses that mean "this one is over" — `0009`'s vocabulary, and the reason
# advancement can read a stored status instead of re-scoring anything.
_SETTLED = ("completed", "expired", "abandoned")

# The event vocabulary. Named rather than typed inline so the chain step, the endpoints
# and the tests all describe one advancement the same way.
RUNG_ACTIVATED = "rung_activated"
RUNG_DELOADED = "rung_deloaded"
ADVANCEMENT_HELD = "advancement_held"
PROGRAM_ENDED = "program_ended"

# What the owner is told when a ladder ends by itself. Plain sentences rather than codes,
# because `program.ended_reason` is read by a person and an unexplained "stalled" is the
# silent degraded state standards §Errors forbids.
_STALLED_GROUND_DOWN = (
    "three rungs in a row ran out of time unmet, each at an easier target than the last. "
    "Easing it again would keep asking for something these weeks say is not landing, so "
    "the ladder ends here rather than grinding."
)
_STALLED_NO_ROOM = (
    "the next step down would be at or below what you were already doing before this "
    "ladder started, so there is no easier version of it left to offer honestly."
)
_ABANDONED_WITH_RUNG = "its live rung was abandoned, so the ladder ended with it."


def advance_due(cur: Cur, user_id: UUID, tz: str, today: date | None = None) -> list[dict]:
    """Move ``user_id``'s live ladder on by whatever its rungs now say. Idempotent.

    Returns one event per thing that happened (empty is the normal answer). Runs as a
    step of the nightly chain, AFTER ``lifecycle.finalize_due`` has closed whatever
    ended — but it does not depend on that order: its input is the rungs' stored
    statuses, so a run before the close simply finds an active rung and does nothing.

    Deliberately NOT run from a read (``programs.list_programs`` is pure), for the reasons
    ``challenges/lifecycle.py`` sets out: a GET that writes is not cacheable, races
    itself, and only advances the ladder of an owner who happens to be looking — which is
    never the owner whose program is quietly stuck.
    """
    today = today or user_today(tz)
    program = program_store.active_program(cur, user_id)
    if program is None:
        return []
    rungs = program_store.rungs(cur, user_id, int(program["id"]))
    if any(rung["status"] == "active" for rung in rungs):
        return []  # still running — nothing has settled to advance on
    settled = _last_settled(rungs)
    if settled is not None and settled["status"] == "abandoned":
        return [_end(cur, user_id, program, "abandoned", _ABANDONED_WITH_RUNG)]
    events: list[dict] = []
    if (
        settled is not None
        and settled["status"] == "expired"
        and not _already_deloaded(rungs, settled)
    ):
        events.append(_answer_failure(cur, user_id, tz, program, rungs, settled, today))
        if events[-1]["event"] == PROGRAM_ENDED:
            return events
        rungs = program_store.rungs(cur, user_id, int(program["id"]))
    return events + _activate_next(cur, user_id, tz, program, rungs, today)


def _last_settled(rungs: list[dict]) -> dict | None:
    """The highest-indexed rung that has ended — the one the ladder must answer for.

    ``rungs`` arrives in ``rung_index`` order and a ladder is climbed in that order, so
    the last settled rung is the most recent one. Reading the ORDER rather than a
    timestamp is what keeps this consistent with the renumbering a deload performs.
    """
    settled = [rung for rung in rungs if rung["status"] in _SETTLED]
    return settled[-1] if settled else None


def _already_deloaded(rungs: list[dict], failed: dict) -> bool:
    """Has this failure already been answered with a deload?

    The idempotency guard, and it needs no extra column: a deload is only ever inserted
    DIRECTLY after the rung it eases, so "the rung at ``index + 1`` is a deload" is an
    exact record of "we have been here". Without it, a failure whose deload could not be
    activated (a hold) would grow a second deload on every nightly tick.
    """
    after = int(failed["rung_index"]) + 1
    return any(int(r["rung_index"]) == after and r["kind"] == DELOAD for r in rungs)


def _answer_failure(  # noqa: PLR0913 — the failure branch needs all of its context
    cur: Cur, user_id: UUID, tz: str, program: dict, rungs: list[dict], failed: dict, today: date
) -> dict:
    """Deload, or give up — the branch legacy did not have at all.

    Order matters: the ground-down check comes first because it is about the LADDER's
    history and is true whatever number an ease would produce, while "no room to ease" is
    about this one rung. Reporting the more fundamental reason is the same ordering rule
    ``screen`` applies to a rejected proposal.
    """
    if _deloads_in_run(rungs, failed) >= MAX_CONSECUTIVE_DELOADS:
        return _end(cur, user_id, program, "stalled", _STALLED_GROUND_DOWN)
    eased = deload_target(cur, user_id, tz, failed, today)
    if eased is None:
        return _end(cur, user_id, program, "stalled", _STALLED_NO_ROOM)
    program_id, index = int(program["id"]), int(failed["rung_index"])
    program_store.shift_rungs_after(cur, user_id, program_id, index)
    rung_id = program_store.insert_rung(
        cur, user_id, program_id, index + 1, failed, target_value=eased, kind=DELOAD
    )
    log.info(
        "program %s: rung %s timed out unmet at %s — deload rung %s inserted at %s for %s",
        program_id,
        failed["id"],
        failed["target_value"],
        rung_id,
        eased,
        user_id,
    )
    return {
        "event": RUNG_DELOADED,
        "program_id": program_id,
        "after_rung_id": int(failed["id"]),
        "rung_id": rung_id,
        "target": eased,
    }


def _deloads_in_run(rungs: list[dict], failed: dict) -> int:
    """Deloads inside the unbroken run of UNMET rungs ending at ``failed``.

    Consecutive rather than per-program on purpose. A five-rung ladder where rungs 1 and 3
    each needed one deload and then landed is a ladder that is working exactly as designed;
    a total cap would punish it for the same evidence that shows the deload doing its job.
    What says "this person is stuck" is failing *here*, repeatedly — so the run resets the
    moment a rung is met.
    """
    stop = int(failed["rung_index"])
    deloads = 0
    for rung in reversed([r for r in rungs if int(r["rung_index"]) <= stop]):
        if rung["status"] != "expired":
            break
        deloads += 1 if rung["kind"] == DELOAD else 0
    return deloads


def _activate_next(
    cur: Cur, user_id: UUID, tz: str, program: dict, rungs: list[dict], today: date
) -> list[dict]:
    """Start the next locked rung, hold, or finish the ladder."""
    program_id = int(program["id"])
    following = next((rung for rung in rungs if rung["status"] == LOCKED), None)
    if following is None:
        return [_end(cur, user_id, program, "completed", None)]
    held = hold_for(cur, user_id, tz, following, today)
    if held is not None:
        reason, sentence = held
        program_store.set_hold(cur, user_id, program_id, sentence)
        log.info("program %s advancement held for %s: %s", program_id, user_id, sentence)
        return [
            {
                "event": ADVANCEMENT_HELD,
                "program_id": program_id,
                "rung_id": int(following["id"]),
                "reason": reason,
                "message": sentence,
            }
        ]
    started = start_rung(cur, user_id, tz, following, today)
    program_store.set_hold(cur, user_id, program_id, None)
    return [{"event": RUNG_ACTIVATED, "program_id": program_id} | started]


def _end(cur: Cur, user_id: UUID, program: dict, status: str, reason: str | None) -> dict:
    """Close the ladder, honestly. ``reason`` is required for everything but a finish."""
    program_id = int(program["id"])
    if not program_store.mark_ended(cur, user_id, program_id, status, reason, datetime.now(tz=UTC)):
        raise RuntimeError(f"program {program_id} was no longer active when it was closed")
    log.info("program %s ended as %s for %s (%s)", program_id, status, user_id, reason or "-")
    return {
        "event": PROGRAM_ENDED,
        "program_id": program_id,
        "status": status,
        "reason": reason,
    }


__all__ = [
    "ADVANCEMENT_HELD",
    "MAX_ACTIVE_PROGRAMS",
    "MAX_CONSECUTIVE_DELOADS",
    "PROGRAM_ENDED",
    "RUNG_ACTIVATED",
    "RUNG_DELOADED",
    "advance_due",
]
