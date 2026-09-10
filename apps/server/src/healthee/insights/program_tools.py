"""The coach's two PROGRAM tools — `create_program` and `adopt_program`.

A challenge is one behaviour for a week. A **program** is a multi-week ladder with
progressive overload: rungs that get harder, recalibrated against the owner's own
baseline as they climb. `challenges/program_generate.py` designs one, and until now
nothing but `POST /api/programs/generate` could ask it to — so an owner could say
"build me a twelve-week plan" to the coach and the coach could only describe one.

## Why these CALL the generator instead of designing a ladder themselves

Exactly the argument `challenge_tools` makes, and it is stronger here because a
program is longer. The coach supplies INTENT and nothing else: it does not choose
the metric, the rung targets, the progression rate or the number of weeks. The
generator picks the lever, computes every target from that owner's measured
baseline, screens the design against the evidence base, and refuses outright when
it cannot ground or cannot track what was asked for
(`challenges/program_screen.py`).

A model inventing "add 10% a week for twelve weeks" would be inventing a training
load for a person whose data it has not read, and it would look exactly as
confident as a computed one. Progressive overload has a note behind it
(`[progressive_overload]`); a number pulled out of a conversation does not.

## Designing is not starting

`create_program` stores the ladder `suggested`, with every rung `locked`.
`adopt_program` is a separate consent and a separate call, and it is the one that
recalibrates the first rung against the baseline at that moment. The coach shows
what was designed and starts it only if the person says yes — the same two-consent
shape the challenge tools use, for the same reason.

Adoption can be refused for a reason that is about the person and not the ladder:
no room (the challenge cap, a live program, a commitment on the same behaviour),
or a recovery state that says this is not the week to start climbing
(`challenges/recovery_guard.py`). Those refusals are answers and are reported as
such.
"""

from __future__ import annotations

from typing import Any
from uuid import UUID

from healthee.challenges import budget, program_generate, programs
from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger
from healthee.insights.challenge_match import refused
from healthee.insights.tool_spec import function_tool

log = get_logger(__name__)

CREATE = "create_program"
ADOPT = "adopt_program"

#: The names this module answers for. `coach_tools.execute_tool` routes on it.
TOOL_NAMES: frozenset[str] = frozenset({CREATE, ADOPT})

#: Both act on the owner's data, so both are anti-hallucination gated like the
#: challenge pair — the coach may not say a ladder exists unless one came back.
ACTION_TOOLS: frozenset[str] = TOOL_NAMES

PROGRAM_TOOLS: list[dict] = [
    function_tool(
        CREATE,
        "Ask for a NEW multi-week training ladder to be designed for this person "
        "('build me a 12-week plan', 'I want to get to a 10k'). Pass their INTENT in "
        "their own words: you do not choose the metric, the weekly targets, the "
        "progression rate or the number of weeks. The generator picks the lever, "
        "computes every rung from their own measured baseline, and returns nothing at "
        "all when it cannot ground or cannot track what they asked for. Report the "
        "ladder it returns — never one you designed. It is stored as a SUGGESTION and "
        "is not started.",
        {
            "intent": {
                "type": "string",
                "description": "what the person asked for, in their words",
            }
        },
        ["intent"],
    ),
    function_tool(
        ADOPT,
        "Start a ladder that was already designed or suggested — the ids are in your "
        "context. Only when they say yes. Starting recalibrates the first rung against "
        "their baseline right now, so report the target this returns rather than the "
        "one the design showed. It can be refused because of THEM and not the ladder "
        "(no room, or recovery says not this week); say which reason came back.",
        {
            "program_id": {
                "type": "integer",
                "description": "the id of the suggested ladder to start",
            }
        },
        ["program_id"],
    ),
]


def execute(name: str, args: dict[str, Any], user_id: UUID, tz: str) -> dict:
    """Dispatch one of :data:`TOOL_NAMES`, scoped to ``user_id``.

    An unrecognised name is a routing bug in ``coach_tools``, not a model mistake,
    so it raises rather than degrading into an honest-looking error dict.
    """
    if name == CREATE:
        return create_program(user_id, tz, str(args.get("intent") or ""))
    if name == ADOPT:
        return adopt_program(user_id, tz, args.get("program_id"))
    raise ValueError(f"{name} is not a program tool")


def create_program(user_id: UUID, tz: str, intent: str) -> dict:
    """Design a ladder for ``user_id`` from their stated ``intent``.

    Charges the shared generation budget, so a ladder designed in chat costs the
    owner the same unit an in-app design does (#78) — the coach is not a way around
    the cap, and a person who spends their designs talking has spent them.

    A design the shape gates threw out comes back as `ok` with nothing created and
    the reasons named: the pipeline worked and the model's ladder did not, and those
    are different answers.
    """
    intent = intent.strip()
    if not intent:
        return refused("no_intent", "say what the person actually asked for")
    result = budget.spend_then_run(
        user_id,
        tz,
        lambda: program_generate.generate_program(user_id, tz, intent=intent),
        program_generate.PRE_LLM_REFUSALS,
    )
    if not result.get("ok"):
        return result
    program = result.get("program")
    if not program:
        return {
            "ok": True,
            "created": False,
            "rejected": list(result.get("rejected") or []),
            "note": "nothing was designed. Say so and say why — the reasons above are "
            "the answer, not a failure to hide. Do not offer a ladder of your own.",
        }
    return {
        "ok": True,
        "created": True,
        "program": program,
        "status": "suggested",
        "note": "designed as a SUGGESTION — not started, every rung locked. Report the "
        "rungs exactly as stored: they were computed from their own baseline. Call "
        "adopt_program only if they say yes.",
    }


def adopt_program(user_id: UUID, tz: str, program_id: Any) -> dict:
    """Start a suggested ladder. Returns the stored result or a named refusal.

    ``require_ok`` is deliberately NOT used: the HTTP layer turns a refusal into a
    409 because a client needs a status code, and the coach needs the opposite — a
    reason it can read aloud. `programs.adopt` already returns one.
    """
    if not isinstance(program_id, int):
        return refused("no_program_id", "pass the id of the ladder they mean")
    with tenant_transaction(user_id) as cur:
        result = programs.adopt(cur, user_id, tz, program_id)
    if not result.get("ok"):
        log.info("coach adopt_program refused for %s: %s", user_id, result.get("reason"))
    return result
