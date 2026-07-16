"""The AI coach — a bounded tool-calling loop that CANNOT bypass the validator.

The coach is the flagship honesty surface (INTELLIGENCE §4). It does NOT open a
second, unvalidated LLM path: it reuses the choke-point primitives directly —
``refusals.classify_refusal`` gates the question before any tool runs, and every
final free-text answer is put through ``validator.validate``; a candidate that
fails twice ships ``prompts.FALLBACK``, never raw text. There is exactly one place
a model turn becomes the reply (``_finalize``), and it only returns text that
``_accept`` cleared — so an unvalidated or action-hallucinating answer can never
reach the user (holes #1/#2, and the anti-hallucination rule).

The system message is ``COACH_SYSTEM_PROMPT`` (docs/COACH_PROMPT.md verbatim); the
context is the history-rich ``build_coach_context``; the tools are ``COACH_TOOLS``.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from typing import Any

from healthee.core.logging import get_logger
from healthee.insights import coach_tools, prompts
from healthee.insights.client import LLMClient, coach_model, get_client
from healthee.insights.coach_context import DEFAULT_COACH_DAYS, build_coach_context, coach_evidence
from healthee.insights.coach_prompt import COACH_SYSTEM_PROMPT
from healthee.insights.refusals import classify_refusal
from healthee.insights.validator import ValidationResult, validate

log = get_logger(__name__)

_MAX_ROUNDS = 5  # bound the tool loop (COACH_PROMPT: max ~5 rounds)
_MAX_VALIDATION_RETRIES = 1  # one nudged rewrite, then the honest fallback (blocking)
_HISTORY_LIMIT = 12  # last N conversation turns kept (context-window discipline)

_GREETING = "Ask me anything about your sleep, activity, recovery, or logged routines."

# First-person action claims the coach may only make when a matching action tool
# returned ok THIS turn — the structural half of the anti-hallucination guard.
_ACTION_CLAIM_RE = re.compile(
    r"\bI(?:'ve| have)?\s+(?:just\s+)?(?:logged|recorded|started|ended|stopped|adopted|saved)\b|"
    r"\blogged your\b|\bstarted (?:a|your) fast\b|\bended your fast\b|\badopted (?:the|your)\b",
    re.IGNORECASE,
)


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
    *,
    client: LLMClient | None = None,
    context_days: int = DEFAULT_COACH_DAYS,
) -> CoachResult:
    """Answer the conversation grounded in the person's data + the graded corpus.

    Refusals short-circuit before any tool call; the final answer is always
    validated (or the honest fallback ships). ``client`` is injectable for tests.
    """
    history = _recent(messages)
    question = _last_user(history)
    if not question:
        return CoachResult(reply=_GREETING)
    refusal = classify_refusal(question)
    if refusal is not None:
        log.info("coach refused pre-LLM: domain=%s", refusal.name)
        return CoachResult(reply=refusal.template, refused=True)
    client = client or get_client()
    convo = _initial_messages(history, question, context_days)
    return _loop(client, convo)


def _loop(client: LLMClient, convo: list[dict]) -> CoachResult:
    """The bounded tool loop; every text candidate passes through ``_accept``."""
    acted_ok: set[str] = set()
    invocations: list[dict] = []
    retries = 0
    for _round in range(_MAX_ROUNDS):
        response = client.complete(convo, tools=coach_tools.COACH_TOOLS, model=coach_model())
        if response.tool_calls:
            _run_tools(response, convo, invocations, acted_ok)
            continue
        ok, issues, validation = _accept(response.text, acted_ok)
        if ok:
            return _finalize(response.text, validation, invocations)
        if retries >= _MAX_VALIDATION_RETRIES:
            log.warning("coach answer failed acceptance twice (%s) — honest fallback", issues)
            return CoachResult(reply=prompts.FALLBACK, tool_calls=invocations, validated=False)
        convo.append({"role": "assistant", "content": response.text})
        convo.append({"role": "user", "content": _nudge(issues)})
        retries += 1
    log.warning("coach exhausted %d rounds without a clean answer — fallback", _MAX_ROUNDS)
    return CoachResult(reply=prompts.FALLBACK, tool_calls=invocations, validated=False)


def _run_tools(
    response: Any, convo: list[dict], invocations: list[dict], acted_ok: set[str]
) -> None:
    """Execute each requested tool, append its result, and record ok action tools."""
    convo.append(_assistant_tool_message(response))
    for call in response.tool_calls:
        name = call.function.name
        args = _parse_args(call.function.arguments)
        result = coach_tools.execute_tool(name, args)
        if name in coach_tools.ACTION_TOOLS and result.get("ok"):
            acted_ok.add(name)
        invocations.append({"tool": name, "args": args, "result": result})
        convo.append(
            {"role": "tool", "tool_call_id": call.id, "content": coach_tools.dumps(result)}
        )


def _accept(text: str, acted_ok: set[str]) -> tuple[bool, list[str], ValidationResult]:
    """Gate a text candidate: citation validation AND the anti-hallucination guard."""
    validation = validate(text)
    issues = list(validation.issues)
    if _ACTION_CLAIM_RE.search(text) and not acted_ok:
        issues.append(
            "Claims an action (logged/started/adopted/…) but no action tool returned ok "
            "this turn — never state an action you did not take."
        )
    return (not issues, issues, validation)


def _finalize(text: str, validation: ValidationResult, invocations: list[dict]) -> CoachResult:
    """The ONLY path that turns a model turn into the reply (accepted text only)."""
    return CoachResult(
        reply=text,
        citations=validation.citations,
        personal_findings=validation.personal_findings,
        tool_calls=invocations,
        validated=True,
    )


def _initial_messages(history: list[dict], question: str, context_days: int) -> list[dict]:
    """System (coach prompt + context + evidence) followed by the conversation."""
    context = build_coach_context(question, days=context_days)
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


def _nudge(issues: list[str]) -> str:
    """The retry nudge — reuse the choke point's, listing this turn's issues."""
    return prompts.RETRY_NUDGE.format(issues="\n".join(f"- {i}" for i in issues))


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
