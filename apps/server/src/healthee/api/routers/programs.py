"""Programs — the multi-week ladder: the feed and the two lifecycle writes.

Thin (standards §2): auth dep → one domain call inside one owner-scoped transaction →
shape the response. No business logic, no SQL; every rule lives in
``healthee.challenges.{programs,ladder,rung}``.

Three things this router deliberately does NOT have:

* **A "next rung" endpoint.** Advancement is not a client action. It is a deterministic
  consequence of what the rungs did, computed once per owner per THEIR local day in the
  nightly chain (``jobs/chain.py::step_challenges``), so a ladder moves whether or not
  anybody opens the app — which is exactly the owner whose program is quietly stuck.
  Exposing it would also make a GET-shaped action a write, which is the pattern
  ``challenges/lifecycle.py`` argues against at length.
* **Any target, anywhere.** A rung's number is recalibrated server-side against the
  owner's own current baseline when it starts (``rung.recalibrated_target``). As with
  ``POST …/adapt``, the way to guarantee a client cannot dictate it is to give it
  nowhere to put one.
* **A premium gate.** 6.6 is not built (`MULTI_USER.md` §12): there is no `subscription`
  table and no `require_ai_access`, so these endpoints are reachable by any
  authenticated owner — exactly like every other AI surface today. Programs are premium
  per PRICING §1a and the gate threads through here when 6.6 lands. Noted rather than
  faked, because a comment claiming a gate that is not there is worse than no gate.

## The response models (standards §2 — small, stable payloads are typed)

Same three rules the challenges router states and for the same reasons: field order and
optionality mirror the source (``program_store.COLUMNS`` and ``db/schema.sql``), a
nullable field is required-and-nullable rather than defaulted, and ``extra="forbid"``
turns a domain field that stopped being modelled into a loud test failure instead of a
key that silently vanished from the wire.

:class:`Rung` reuses the challenges router's ``Challenge`` model rather than restating
23 fields: a rung IS a challenge row, and two models over one shape is the drift this
whole track keeps having to un-write.
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter

from healthee.api.gate import ChallengeUser
from healthee.api.routers.challenges import Challenge, Outcome, Progress, _Wire
from healthee.api.validation import require_ok
from healthee.challenges import programs
from healthee.core.db import tenant_transaction

router = APIRouter(tags=["programs"])


class Rung(Challenge):
    """One rung: a ``challenge`` row, plus whatever is true of it right now.

    ``progress`` and ``outcome`` are both present on every rung and both nullable,
    because a rung is in exactly one of three states and a client parses one shape:
    ``locked`` has neither (it has not run, so there is nothing to score and nothing to
    record), ``active`` has progress, and a settled rung has its frozen outcome.

    ``progress`` is the challenges feed's own shape, adaptation included, because it is
    computed by the same ``lifecycle.progress_of``: a rung is an ordinary active
    challenge, the adapter tunes it like any other, and the two surfaces must not be
    free to disagree about what one commitment is doing.
    """

    progress: Progress | None
    outcome: Outcome | None


class Program(_Wire):
    """One ladder, exactly as ``program_store`` reads it, with its rungs in order.

    ``hold_reason`` is the field worth reading twice. It is non-null when advancement is
    PAUSED — low recovery, an illness flag, a full challenge cap, or a standalone
    commitment on the same behaviour — and the ladder resumes by itself when the reason
    clears. A surface that renders a held program as simply "in progress" would hide the
    one thing the owner can act on, so the reason is on the wire rather than in a log.

    ``ended_reason`` is its terminal counterpart: why a ``stalled`` ladder stopped. A
    ``stalled`` status with no explanation is precisely the silent degraded state
    standards §Errors forbids.
    """

    id: int
    created_at: datetime
    title: str
    why: str
    goal: str | None
    goal_metric: str | None
    category: str | None
    weeks: int | None
    status: str
    adopted_at: datetime | None
    completed_at: datetime | None
    ended_at: datetime | None
    ended_reason: str | None
    hold_reason: str | None
    rungs: list[Rung]
    rung_count: int
    settled_rungs: int


class ProgramFeed(_Wire):
    """``GET /api/programs`` — the live ladder, what is on offer, what recently ended.

    ``active`` is a single object or null rather than a list: one live program per owner
    is the rule (``ladder.MAX_ACTIVE_PROGRAMS``), and a list would invite a client to
    render a state the engine refuses to produce.
    """

    active: Program | None
    suggested: list[Program]
    recent: list[Program]
    max_active_programs: int


class Recalibration(_Wire):
    """What happened to a rung's designed target when it actually started.

    ``applied`` false with a ``reason`` is a complete answer, not a missing one: the
    designed number was still inside today's band, or the owner's data was too thin to
    calibrate against at all (``bounds.calibrate``'s own refusals travel through here
    unchanged). ``designed``/``baseline`` are absent in the no-band case — there was no
    band to state them against — which is why both are nullable.
    """

    applied: bool
    reason: str | None
    target: float
    designed: float | None = None
    baseline: float | None = None


class StartedRung(_Wire):
    """The first rung ``adopt`` set running, and the number it settled on."""

    rung_id: int
    target: float
    recalibration: Recalibration


class AdoptResult(_Wire):
    """``adopt`` — the STORED ladder plus what starting it did.

    ``ok`` is ``Literal[True]``-shaped in spirit: a refusal never reaches this model,
    because :func:`require_ok` has already turned it into a 4xx.
    """

    ok: bool
    program: Program
    started: StartedRung


class ProgramResult(_Wire):
    """``abandon`` — the stored ladder, so a client renders what actually landed."""

    ok: bool
    program: Program


@router.get("/api/programs", response_model=ProgramFeed)
def get_programs(user: ChallengeUser) -> ProgramFeed:
    """The owner's ladders. A pure read — it never advances one (``challenges/ladder.py``).

    A ladder whose rung has run out therefore still shows that rung as active, with
    ``days_left: 0``, until the nightly chain closes and advances it. That is a true
    statement about a row that has not been frozen yet; writing from a GET is not.
    """
    with tenant_transaction(user.id) as cur:
        feed = programs.list_programs(cur, user.id, user.timezone)
    return ProgramFeed.model_validate(feed)


@router.post("/api/programs/{program_id}/adopt", response_model=AdoptResult)
def post_adopt(user: ChallengeUser, program_id: int) -> AdoptResult:
    """Take on a suggested ladder and start its first rung.

    409 when the owner has no room (the challenge cap, a live program, a commitment on
    the same behaviour) or when their recovery says this is not the week to start a
    training ladder — each with the reason that produced it, so a client can say which.
    """
    # `require_ok` stays INSIDE the transaction: a refusal is an exception, and the
    # rollback it triggers is what un-does `adopt`'s `finalize_due` writes.
    with tenant_transaction(user.id) as cur:
        result = require_ok(programs.adopt(cur, user.id, user.timezone, program_id))
    return AdoptResult.model_validate(result)


@router.post("/api/programs/{program_id}/abandon", response_model=ProgramResult)
def post_abandon(user: ChallengeUser, program_id: int) -> ProgramResult:
    """Stop a live ladder. Its running rung is still frozen — giving up is a result."""
    with tenant_transaction(user.id) as cur:
        result = require_ok(programs.abandon(cur, user.id, user.timezone, program_id))
    return ProgramResult.model_validate(result)
