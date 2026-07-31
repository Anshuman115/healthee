"""WP-C4b — grounded PROGRAM generation. The model designs a ladder; the gates dispose.

``generate``'s twin, deliberately the same pipeline shape (read the world → ask the choke
point → screen → persist), because the two differ in exactly one place and everything
else being identical is what keeps that one difference legible:

* **Gate A binds rung 1 only.** Every later rung is bounded at ACTIVATION by
  ``rung.recalibrated_target``. ``challenges/program_screen.py`` argues it in full — it is
  the whole reason this WP was split out of WP-C4.
* **Gate B is unchanged**: the batch runs through ``insights.grounded_ask`` with a
  blocking validator, which had to learn the ladder's JSON shape
  (``validator._JSON_SHAPES``). A shape the validator does not know FAILS CLOSED, which
  WP-C3 pinned — so registering it was not optional.

Everything else is read from where it already lives: the lever ranking and the calibration
table are ``gen_context.build_generation_context``'s (the same context the challenge
prompt gets), the shape rule that makes a rung runnable is ``programs.rung_shape_issue``'s,
the per-rung challenge gates are ``screen.proposal_issue``'s, and the rows are
``program_store``'s.

## One ladder, not a menu

One is all an owner may run (``ladder.MAX_ACTIVE_PROGRAMS``), so a menu of ladders would
be a lot of output tokens spent on a choice the engine caps at one. It is also why an
owner who is already climbing is refused BEFORE the model is asked: nothing they could be
offered is adoptable until the current one ends.

## Lazy only, and premium-gated by nothing

Same as ``generate``: no scheduler hook (spending tokens on a ladder nobody asked for is
money spent to show somebody nothing), and no premium gate, because 6.6 does not exist
(``MULTI_USER.md`` §12) and a comment claiming a gate that is not there is worse than a
missing gate.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from uuid import UUID

from healthee.challenges import (
    commitment,
    gen_context,
    gen_prompt,
    lifecycle,
    program_store,
    programs,
    store,
)
from healthee.challenges import ladder as ladder_rules
from healthee.challenges.generate import CONTEXT_DAYS, GENERATION_METRICS
from healthee.challenges.program_prompt import program_task
from healthee.challenges.program_screen import screen_program
from healthee.challenges.program_store import STANDARD
from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur
from healthee.insights.client import LLMClient
from healthee.insights.grounded import grounded_ask

log = get_logger(__name__)

# The named refusals decided BEFORE the model is asked — `generate.PRE_LLM_REFUSALS`'s
# twin, and read by the endpoint's budget for the same reason: neither costs a token.
PRE_LLM_REFUSALS: frozenset[str] = frozenset({"program_active", "no_calibratable_metric"})

# One re-ask when the design was rejected by the deterministic gates, with the violations
# named — `generate._MAX_BOUNDS_RETRIES`'s reasoning, unchanged. Bounded at one because a
# model that ignored the printed rules twice will not honour them on a third ask, and no
# ladder is an honest answer.
_MAX_SHAPE_RETRIES = 1


@dataclass(frozen=True)
class _Attempt:
    """What one round of ask-and-screen produced.

    ``grounded`` is separate from ``design is None`` because the two failures are
    different states and the caller must be able to say which (standards §Errors): Gate B
    refusing (nothing was grounded) is not the same answer as a design the shape gates
    threw out, and only the second one has reasons to report.
    """

    grounded: bool
    design: dict | None = None
    issues: list[str] = field(default_factory=list)


def generate_program(
    user_id: UUID,
    tz: str,
    *,
    intent: str | None = None,
    client: LLMClient | None = None,
    model: str | None = None,
    today: date | None = None,
) -> dict:
    """Design, gate and persist ONE suggested ladder for an owner. Never raises on a rule.

    Returns ``{"ok": True, "generated": 0|1, "rejected": [...], "program": row|None}`` or a
    named refusal ``{"ok": False, "reason": …, "error": …}``. ``rejected`` is part of the
    ANSWER, not only a log line — an empty answer with no reason is the silent degraded
    state §2.5 forbids.
    """
    today = today or user_today(tz)
    prepared = _prepare(user_id, tz, today)
    if "error" in prepared:
        return prepared
    attempt = _author(user_id, tz, prepared, intent=intent, client=client, model=model)
    if not attempt.grounded:
        return _refused("no_grounded_output", "the evidence base could not ground a program")
    return _persist(user_id, tz, today, attempt)


def _prepare(user_id: UUID, tz: str, today: date) -> dict:
    """The pre-LLM read: close what has ended, check they have room, build the context.

    ``finalize_due`` runs first for the reason it does everywhere on this track — a rung
    or a challenge that finished but has not been closed would misreport what the owner is
    carrying, and here that decides whether they are offered a ladder at all.

    The duplicate check is against ACTIVE metrics only, matching ``rung.hold_for`` exactly
    rather than widening to suggestions: the rule that will actually stop this ladder
    starting is that one, and generation must not be stricter than the door it leads to.
    """
    with tenant_transaction(user_id) as cur:
        lifecycle.finalize_due(cur, user_id, tz, today)
        if program_store.count_active_programs(cur, user_id) >= ladder_rules.MAX_ACTIVE_PROGRAMS:
            return _refused("program_active", "you are already climbing a ladder")
        active_metrics = store.active_metrics(cur, user_id)
        context, calibrations, analysis = gen_context.build_generation_context(
            cur, user_id, tz, today, active_metrics
        )
    if not any(c.band for c in calibrations.values()):
        return _refused("no_calibratable_metric", "no metric has enough of this owner's data")
    return {
        "context": context,
        "calibrations": calibrations,
        "claimed_metrics": active_metrics,
        "blocked": analysis.blocked_metrics(),
    }


def _author(
    user_id: UUID,
    tz: str,
    prepared: dict,
    *,
    intent: str | None,
    client: LLMClient | None,
    model: str | None,
) -> _Attempt:
    """Ask, screen, and (at most once) re-ask with the shape violations named."""
    task = program_task(intent)
    issues: list[str] = []
    for attempt in range(_MAX_SHAPE_RETRIES + 1):
        result = grounded_ask(
            f"{task}\n\n{prepared['context']}",
            user_id,
            tz,
            metrics=GENERATION_METRICS,
            context_days=CONTEXT_DAYS,
            response_format="json",
            client=client,
            model=model,
        )
        if result.refused or not result.validated or result.data is None:
            log.info("program generation for %s: no grounded output", user_id)
            return _Attempt(grounded=False)
        design, issues = screen_program(
            result.data, prepared["calibrations"], prepared["claimed_metrics"], prepared["blocked"]
        )
        for issue in issues:  # rejections are logged, never swallowed (standards §Errors)
            log.info("program design rejected for %s: %s", user_id, issue)
        if design is not None or attempt >= _MAX_SHAPE_RETRIES:
            return _Attempt(grounded=True, design=design, issues=issues)
        task = program_task(intent) + gen_prompt.REJECTION_NUDGE.format(
            issues="\n".join(f"- {i}" for i in issues)
        )
    return _Attempt(grounded=True, issues=issues)


def _persist(user_id: UUID, tz: str, today: date, attempt: _Attempt) -> dict:
    """Write the ladder that survived the gates — replacing whatever was on offer.

    The world is re-read HERE, inside the write transaction, for the reason ``generate``
    states: the model was thinking outside it, and both facts this design rests on can
    have moved. A program adopted meanwhile means there is no room; a standalone challenge
    adopted on the ladder's metric means the first rung would be one commitment scored
    twice (``commitment.clashing``, #72).

    A run that produced no design leaves the existing suggestion alone — the delete is the
    first half of a replacement and there is nothing to replace with.
    """
    design = attempt.design
    rejected = list(attempt.issues)
    if design is None:
        log.info("program generation for %s produced nothing — what was on offer stands", user_id)
        return _nothing(rejected)
    with tenant_transaction(user_id) as cur:
        clash = _late_clash(cur, user_id, design["program"]["goal_metric"])
        if clash is not None:
            rejected.append(clash)
            return _nothing(rejected)
        program_store.delete_suggested_programs(cur, user_id)
        program_id = program_store.insert_program(cur, user_id, design["program"])
        for index, rung in enumerate(design["rungs"]):
            program_store.insert_rung(
                cur,
                user_id,
                program_id,
                index,
                rung,
                target_value=float(rung["target_value"]),
                kind=STANDARD,
            )
        stored = programs.detail(cur, user_id, tz, program_id, today)
    log.info("program %s designed for %s (%d rungs)", program_id, user_id, len(design["rungs"]))
    return {"ok": True, "generated": 1, "rejected": rejected, "program": stored}


def _late_clash(cur: Cur, user_id: UUID, metric: str) -> str | None:
    """What was taken while the model was thinking, as a sentence — or ``None``."""
    if program_store.count_active_programs(cur, user_id) >= ladder_rules.MAX_ACTIVE_PROGRAMS:
        return "a ladder was adopted by the time the model finished thinking"
    clash = commitment.clashing(metric, store.active_metrics(cur, user_id))
    if clash is not None:
        return f"{metric} was already spoken for by {clash} by the time the model finished"
    return None


def _nothing(rejected: list[str]) -> dict:
    """The honest empty answer: no ladder, and the reasons there is none."""
    return {"ok": True, "generated": 0, "rejected": rejected, "program": None}


def _refused(reason: str, message: str) -> dict:
    """A rule outcome — explicit and named, matching ``generate``'s refusal shape."""
    return {"ok": False, "reason": reason, "error": message}
