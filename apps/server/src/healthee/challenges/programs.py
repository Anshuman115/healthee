"""The program state machine: ``suggested → active → completed | stalled | abandoned``.

WP-C4, CHALLENGES.md §2.3. ``ladder`` moves a live program on; this is what an owner
does to one — take it on, stop it, look at it. The split is ``lifecycle``/``store``'s
again: the rules that answer "may this happen" read as rules when the advancement
arithmetic is not mixed into them.

## What adopting a ladder costs, and why

A rung is a live commitment and is counted like one. Adopting a program therefore needs
a free slot under the per-owner ``lifecycle.MAX_ACTIVE`` cap, and the cap is not
sidestepped later: advancement is normally net-zero (one rung closes as the next opens),
and where it is not — a standalone challenge adopted into the freed slot — the ladder
HOLDS rather than making the owner the one person carrying four commitments
(``rung.hold_for``).

Only one ladder at a time (``ladder.MAX_ACTIVE_PROGRAMS``). Two concurrent programs would
put two multi-week arcs over one person's weeks and hand the outcome ledger two
overlapping before/afters to attribute — the §2.1 problem, in its most avoidable form.

## Two structural rules a stored ladder must satisfy before it may start

Checked at adopt rather than trusted from the row, exactly as ``lifecycle.adopt`` checks
``allows_cadence``: a stored row is not proof it is expressible.

* **Every rung is ``>=``.** The failure branch is ``adapt.deload_target``, which is the
  adapter's ease — and the adapter leaves ``<=`` caps alone because the corpus supplies
  no rule for loosening one (§5.2). A ladder containing a cap would therefore have a rung
  whose failure could not be answered, and a ladder without a deload is exactly legacy's
  forward-only behaviour. Refusing the shape is honest; inventing a cap-easing rule to
  support it would not be. *This is a real capability limit and it is stated as one: a
  progressive caffeine-cut ladder is not expressible today.*
* **Every rung's ``(metric, cadence)`` pair is expressible** (#67) — the same check, on
  every rung rather than one challenge.

## Reads are pure

:func:`list_programs` never advances anything, for the reasons ``challenges/lifecycle.py``
sets out at length. A ladder whose rung finished shows here with the rung still active
and ``days_left: 0`` until the nightly chain closes it — a true statement about a row
that has not been frozen yet, which writing from a GET is not.
"""

from __future__ import annotations

from datetime import UTC, date, datetime
from typing import Any
from uuid import UUID

from healthee.challenges import ladder, lifecycle, program_store
from healthee.challenges import rung as rung_rules
from healthee.challenges.ledger import by_challenge
from healthee.challenges.metrics import CHALLENGE_METRICS, allows_cadence
from healthee.core.logging import get_logger
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur

log = get_logger(__name__)

# How many finished ladders a list read carries back. Every list is windowed
# (standards §Performance); a life of use accumulates them.
_RECENT_PROGRAMS = 5

_FINISHED = ("completed", "stalled", "abandoned")

_ABANDONED_BY_OWNER = "you stopped this ladder."


def adopt(cur: Cur, user_id: UUID, tz: str, program_id: int, today: date | None = None) -> dict:
    """Take on a suggested ladder and start its first rung. Never raises on a rule.

    ``finalize_due`` runs first for the same reason it does in ``lifecycle.adopt``: the
    cap is computed from the active count, and a challenge that finished but has not been
    closed would cost the owner a slot they should have back.

    The first rung is started through ``rung.start_rung``, so it is recalibrated against
    the owner's CURRENT baseline and freezes its own — the same treatment every later rung
    gets. There is no special first-rung path, because a special path is a second one.

    **The refusal order is the most fundamental true reason first**, the same rule
    ``screen`` applies to a rejected proposal, and here it goes: the LADDER (is this a
    shape we can run at all — true whoever is asking), then the OWNER'S LADDER STATE (are
    they already climbing one — true whatever these rungs contain), then their WEEK (the
    holds). Reversing the last two would tell somebody who already has a program that
    their second one clashes with their first one's rung, which is true and useless.
    """
    today = today or user_today(tz)
    lifecycle.finalize_due(cur, user_id, tz, today)
    program = program_store.fetch(cur, user_id, program_id)
    if program is None:
        return _refused("not_found", "no such program")
    if program["status"] != "suggested":
        return _refused("not_suggested", f"program is {program['status']}, not suggested")
    rungs = program_store.rungs(cur, user_id, program_id)
    refusal = _shape_refusal(rungs) or _capacity_refusal(cur, user_id, tz, rungs, today)
    if refusal is not None:
        return refusal
    if not program_store.mark_adopted(cur, user_id, program_id, datetime.now(tz=UTC)):
        return _refused("not_suggested", "program was adopted by another request")
    started = rung_rules.start_rung(cur, user_id, tz, rungs[0], today)
    log.info("program %s adopted by %s (first rung %s)", program_id, user_id, started["rung_id"])
    return {"ok": True, "program": _detail(cur, user_id, tz, program_id, today), "started": started}


def _shape_refusal(rungs: list[dict]) -> dict | None:
    """Why this ladder could never run, whoever is asking. Checked before any owner state.

    A stored row is not proof it is expressible — the same reason ``lifecycle.adopt``
    re-checks ``allows_cadence`` on a challenge it is about to start.
    """
    if not rungs:
        return _refused("no_rungs", "this program has no rungs")
    for rung in rungs:
        shape = _rung_shape_issue(rung)
        if shape is not None:
            return _refused("not_ladderable", shape)
    return None


def _capacity_refusal(
    cur: Cur, user_id: UUID, tz: str, rungs: list[dict], today: date
) -> dict | None:
    """Why this owner may not start it right now, or ``None``.

    The second half is ``rung.hold_for``, not a rule of this module's own: the cap, the
    duplicate check and the recovery guard are the SAME three questions advancement asks
    on every later rung, and a ladder that could be *adopted* under conditions that would
    *hold* it would start life paused.
    """
    if program_store.count_active_programs(cur, user_id) >= ladder.MAX_ACTIVE_PROGRAMS:
        return _refused("program_active", "you are already running a program")
    held = rung_rules.hold_for(cur, user_id, tz, rungs[0], today)
    return None if held is None else _refused(held[0], held[1])


def _rung_shape_issue(rung: dict) -> str | None:
    """Why this rung could never be run as part of a ladder, or ``None``.

    ``comparator`` is the one that is specific to programs (module docstring — a cap has
    no ease rule, so its failure could not be answered). The metric and cadence checks are
    ``lifecycle.adopt``'s, applied to every rung rather than to one challenge.
    """
    if rung["metric"] not in CHALLENGE_METRICS:
        return f"rung {rung['rung_index']}: {rung['metric']} is not a trackable metric"
    if rung["comparator"] != ">=":
        return (
            f"rung {rung['rung_index']}: a '{rung['comparator']}' cap cannot be a ladder "
            "rung — there is no evidenced rule for easing one, so a rung that timed out "
            "unmet could not be deloaded"
        )
    if not allows_cadence(rung["metric"], rung["cadence"]):
        return (
            f"rung {rung['rung_index']}: {rung['metric']} cannot be a {rung['cadence']} challenge"
        )
    return None


def abandon(cur: Cur, user_id: UUID, tz: str, program_id: int, today: date | None = None) -> dict:
    """Stop a live ladder at the owner's request. Its live rung is still frozen.

    Giving up is a result: the rung goes through ``lifecycle.abandon``, which writes its
    outcome exactly as it would for a standalone challenge, so the ledger records how far
    they actually got. Remaining locked rungs stay locked — they are a truthful record of
    a ladder that was designed and not climbed, and the program's terminal status is what
    makes them unreachable.
    """
    today = today or user_today(tz)
    program = program_store.fetch(cur, user_id, program_id)
    if program is None:
        return _refused("not_found", "no such program")
    if program["status"] != "active":
        return _refused("not_active", f"program is {program['status']}, not active")
    for rung in program_store.rungs(cur, user_id, program_id):
        if rung["status"] != "active":
            continue
        result = lifecycle.abandon(cur, user_id, tz, int(rung["id"]), today)
        if not result["ok"]:
            # We read this rung as active inside this very transaction, so a refusal here
            # is a broken invariant rather than a rule outcome — and swallowing it would
            # end the program with an unfrozen rung, i.e. a week with no ledger entry.
            raise RuntimeError(f"rung {rung['id']} could not be abandoned: {result['reason']}")
    if not program_store.mark_ended(
        cur, user_id, program_id, "abandoned", _ABANDONED_BY_OWNER, datetime.now(tz=UTC)
    ):
        return _refused("not_active", "program stopped being active")
    log.info("program %s abandoned by %s", program_id, user_id)
    return {"ok": True, "program": _detail(cur, user_id, tz, program_id, today)}


def list_programs(cur: Cur, user_id: UUID, tz: str, today: date | None = None) -> dict:
    """The owner's ladders: the live one, what is on offer, and what recently ended.

    A PURE READ (module docstring). ``active`` is a single object or ``None`` rather than
    a list, because one is the rule and a list would invite a client to render a state
    the engine refuses to produce.
    """
    today = today or user_today(tz)
    live = program_store.active_program(cur, user_id)
    return {
        "active": None if live is None else _serialize(cur, user_id, tz, live, today),
        "suggested": [
            _serialize(cur, user_id, tz, program, today)
            for program in program_store.by_status(cur, user_id, ("suggested",))
        ],
        "recent": [
            _serialize(cur, user_id, tz, program, today)
            for program in program_store.by_status(cur, user_id, _FINISHED, _RECENT_PROGRAMS)
        ],
        "max_active_programs": ladder.MAX_ACTIVE_PROGRAMS,
    }


def _detail(cur: Cur, user_id: UUID, tz: str, program_id: int, today: date) -> dict:
    """One program as the write endpoints return it — re-read, so the client sees stored."""
    program = program_store.fetch(cur, user_id, program_id)
    if program is None:  # the row we just wrote must be visible on this cursor
        raise RuntimeError(f"program {program_id} vanished inside its own transaction")
    return _serialize(cur, user_id, tz, program, today)


def _serialize(cur: Cur, user_id: UUID, tz: str, program: dict, today: date) -> dict[str, Any]:
    """One ladder with its rungs in order, each carrying what is true of it.

    **This is how the outcome ledger tells the story.** Every rung that ended carries its
    frozen ``outcome``, read in ONE statement for the whole ladder
    (``ledger.by_challenge``), so the sequence reads back in ``rung_index`` order as what
    actually happened — ``met``, then ``unmet_timed_out``, then a ``deload`` rung that was
    ``met``, then the rung above it. A repeat-in-place could not produce that sequence at
    all (``ladder``'s docstring argues why), which is what decided the design.

    The live rung carries ``progress`` — and it is ``lifecycle.progress_of``, the same
    function the challenges feed renders an active challenge with, so the rung shows the
    same numbers and the same pending recalibration on both surfaces. A rung IS an
    ordinary active challenge: the adapter tunes it like any other, and a second
    progress function here would be two surfaces free to disagree about what one
    commitment is doing.
    """
    rungs = program_store.rungs(cur, user_id, int(program["id"]))
    outcomes = by_challenge(cur, user_id, [int(rung["id"]) for rung in rungs])
    return program | {
        "rungs": [_rung(cur, user_id, tz, rung, outcomes, today) for rung in rungs],
        "rung_count": len(rungs),
        "settled_rungs": sum(1 for rung in rungs if int(rung["id"]) in outcomes),
    }


def _rung(
    cur: Cur, user_id: UUID, tz: str, rung: dict, outcomes: dict[int, dict], today: date
) -> dict[str, Any]:
    """One rung, plus its live progress or its frozen outcome — never both, never neither.

    A locked rung has neither, and that is the honest answer: it has not run, so there is
    nothing to score and nothing to record. Both keys are present and ``null`` rather than
    absent, so a client's parser sees one shape for every rung.
    """
    progress = (
        lifecycle.progress_of(cur, user_id, tz, rung, today) if rung["status"] == "active" else None
    )
    return rung | {"progress": progress, "outcome": outcomes.get(int(rung["id"]))}


def _refused(reason: str, message: str) -> dict:
    """A rule outcome — explicit and named, never an empty success (standards §Errors)."""
    return {"ok": False, "reason": reason, "error": message}
