"""The AI coach — the tool-calling surface, ROUTED THROUGH the shared choke point.

The coach is the flagship honesty surface (INTELLIGENCE §4). It used to be
*enforced-equivalent* to the choke point rather than *routed through* it: it called the
same primitives (``classify_refusal``, ``check_output``, ``validate``, the honest
fallback) from its own loop, in its own order, so every rule added to the choke point
had to be mirrored here by hand — and one already had been (the output guardrail, in two
places). That mirror rule is gone. Every honesty stage now lives once, in
``pipeline.py``, and this module contributes exactly two things ``grounded_ask`` cannot:

  * a message LAYOUT — coach persona + context in the system turn, conversation after it;
  * a bounded TOOL LOOP, expressed as ``pipeline.Loop.next_turn`` returning
    ``Turn(text=None)`` for a round that ran tools instead of answering.

Everything else — the refusal gate before any tool runs, the hard output guardrails, the
blocking validator on every final free-text answer, the anti-hallucination gate, the one
nudged retry and then ``prompts.FALLBACK`` — is the same code the insight surfaces run.
``tests/insights/test_pipeline_shared.py`` proves it by injecting a stage into the shared
registry and asserting BOTH surfaces obey it, and fails if any surface reaches a
primitive directly.

The system message is ``COACH_SYSTEM_PROMPT`` (docs/COACH_PROMPT.md verbatim); the
context is the history-rich ``build_coach_context``; the tools are ``COACH_TOOLS``.
"""

from __future__ import annotations

import json
from collections.abc import Sequence
from dataclasses import dataclass, field
from typing import Any
from uuid import UUID

from healthee.core.logging import get_logger
from healthee.insights import coach_tools, pipeline
from healthee.insights.client import LLMClient, coach_model, get_client
from healthee.insights.coach_context import DEFAULT_COACH_DAYS, build_coach_context, coach_evidence
from healthee.insights.coach_prompt import COACH_SYSTEM_PROMPT

log = get_logger(__name__)

_MAX_ROUNDS = 5  # bound the tool loop (COACH_PROMPT: max ~5 rounds)
_HISTORY_LIMIT = 12  # last N conversation turns kept (context-window discipline)

_GREETING = "Ask me anything about your sleep, activity, recovery, or logged routines."


@dataclass
class CoachResult:
    """The coach's reply plus its grounding + which tools actually ran this turn."""

    reply: str
    citations: list[str] = field(default_factory=list)
    personal_findings: list[str] = field(default_factory=list)
    tool_calls: list[dict] = field(default_factory=list)
    refused: bool = False
    validated: bool = True


def run_coach(
    messages: list[dict],
    user_id: UUID,
    tz: str,
    *,
    client: LLMClient | None = None,
    context_days: int = DEFAULT_COACH_DAYS,
) -> CoachResult:
    """Answer the conversation grounded in ``user_id``'s data + the graded corpus.

    Refusals short-circuit before any tool call; the final answer is always
    validated (or the honest fallback ships). ``client`` is injectable for tests.
    Every tool the loop runs acts on ``user_id`` only — the coach can neither read
    nor write another owner's data.
    """
    history = _recent(messages)
    question = _last_user(history)
    if not question:
        return CoachResult(reply=_GREETING)
    refusal = pipeline.check_question(question)
    if refusal is not None:
        log.info("coach refused pre-LLM: domain=%s", refusal.name)
        return CoachResult(reply=refusal.template, refused=True)
    client = client or get_client()
    convo = _initial_messages(history, question, user_id, tz, context_days)
    return _loop(client, convo, user_id, tz)


def _loop(client: LLMClient, convo: list[dict], user_id: UUID, tz: str) -> CoachResult:
    """The bounded tool loop, driven by the shared pipeline (one gate set, one policy)."""
    acted_ok: set[str] = set()
    invocations: list[dict] = []

    def next_turn() -> pipeline.Turn:
        response = pipeline.complete(
            client, convo, tools=coach_tools.COACH_TOOLS, model=coach_model()
        )
        if response.tool_calls:
            _run_tools(response, convo, invocations, acted_ok, user_id, tz)
            return pipeline.Turn(text=None)  # the round produced no answer — ask again
        return pipeline.Turn(text=response.text)

    def nudge(text: str, issues: Sequence[str]) -> None:
        convo.extend(pipeline.nudge_turns(text, issues))

    outcome = pipeline.drive(
        pipeline.Loop(
            next_turn=next_turn,
            nudge=nudge,
            label="coach",
            max_turns=_MAX_ROUNDS,
            context=lambda: pipeline.AnswerContext(acted_ok=frozenset(acted_ok)),
        )
    )
    return _result(outcome, invocations)


def _result(outcome: pipeline.Outcome, invocations: list[dict]) -> CoachResult:
    """The ONLY path that turns a pipeline outcome into the reply (accepted text only)."""
    if outcome.refused:
        return CoachResult(
            reply=outcome.text, tool_calls=invocations, refused=True, validated=False
        )
    if not outcome.validated or outcome.validation is None:
        return CoachResult(reply=outcome.text, tool_calls=invocations, validated=False)
    return CoachResult(
        reply=outcome.text,
        citations=outcome.validation.citations,
        personal_findings=outcome.validation.personal_findings,
        tool_calls=invocations,
        validated=True,
    )


def _run_tools(
    response: Any,
    convo: list[dict],
    invocations: list[dict],
    acted_ok: set[str],
    user_id: UUID,
    tz: str,
) -> None:
    """Execute each requested tool, append its result, and record ok action tools."""
    convo.append(_assistant_tool_message(response))
    for call in response.tool_calls:
        name = call.function.name
        args = _parse_args(call.function.arguments)
        result = coach_tools.execute_tool(name, args, user_id, tz)
        if name in coach_tools.ACTION_TOOLS and result.get("ok"):
            acted_ok.add(name)
        invocations.append({"tool": name, "args": args, "result": result})
        convo.append(
            {"role": "tool", "tool_call_id": call.id, "content": coach_tools.dumps(result)}
        )


def _initial_messages(
    history: list[dict], question: str, user_id: UUID, tz: str, context_days: int
) -> list[dict]:
    """System (coach prompt + context + evidence) followed by the conversation."""
    context = build_coach_context(question, user_id, tz, days=context_days)
    evidence = coach_evidence(question)
    system = f"{COACH_SYSTEM_PROMPT}\n\n# THE USER'S DATA (CONTEXT)\n\n{context}\n\n{evidence}"
    return [{"role": "system", "content": system}, *history]


def _assistant_tool_message(response: Any) -> dict:
    """Rebuild the assistant turn that requested tools (OpenAI tool-call shape)."""
    return {
        "role": "assistant",
        "content": response.text or "",
        "tool_calls": [
            {
                "id": call.id,
                "type": "function",
                "function": {"name": call.function.name, "arguments": call.function.arguments},
            }
            for call in response.tool_calls
        ],
    }


def _parse_args(raw: str | None) -> dict:
    """Parse a tool call's JSON arguments; a malformed blob degrades to empty args."""
    try:
        parsed = json.loads(raw or "{}")
    except (json.JSONDecodeError, TypeError) as exc:
        log.warning("coach tool arguments unparseable (%s) — using empty args", exc)
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _recent(messages: list[dict]) -> list[dict]:
    """Keep the last N well-formed turns (role+content) — bound the token cost."""
    clean = [
        {"role": m["role"], "content": m["content"]}
        for m in messages
        if m.get("role") in ("user", "assistant") and m.get("content")
    ]
    return clean[-_HISTORY_LIMIT:]


def _last_user(history: list[dict]) -> str:
    """The most recent user message text, or '' if there is none."""
    return next((m["content"] for m in reversed(history) if m["role"] == "user"), "")
