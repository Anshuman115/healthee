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
    ``Turn(text=None)`` for a round that ran tools instead of answering — and
    ``Turn(progressed=False)`` when that round only repeated calls it had already made.
    The gathering allowance (:data:`GATHERING_ROUNDS`) is the coach's alone; the answer
    and its validation retries are the pipeline's, reserved on top;
  * an answer CONTRACT — the model returns claims as data and ``coach_answer`` renders
    the prose, so a claim cannot reach the owner without the ids it rests on (#128). The
    contract is the coach's, but nothing about the gates is: the rendered text is what
    every stage judges, and a broken contract enters the same registry as any other issue.

Everything else — the refusal gate before any tool runs, the hard output guardrails, the
blocking validator on every final answer, the anti-hallucination gate, the nudged
retries and then ``prompts.FALLBACK`` — is the same code the insight surfaces run.
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

from healthee.analytics import coverage
from healthee.core.logging import get_logger
from healthee.insights import coach_answer, coach_tools, pipeline, prompts
from healthee.insights.client import LLMClient, coach_model, get_client
from healthee.insights.coach_context import DEFAULT_COACH_DAYS, build_coach_context, coach_evidence
from healthee.insights.coach_prompt import COACH_SYSTEM_PROMPT

log = get_logger(__name__)

# The GATHERING allowance — rounds the model may spend running tools instead of
# answering. It is a ceiling, not a spend: narrow questions were measured converging in
# TWO rounds against a live instance (docs/VERIFICATION_2026_08_01.md §7) and never touch
# the rest, and an unused round costs nothing. It used to be 5
# AND it doubled as the answer budget, so a question that legitimately needed five rounds
# of data exited having never been asked for an answer, and a four-round one reached its
# single answer attempt with zero validation retries left. `pipeline.validation_retries`
# is now reserved on top of this by `pipeline.drive`, so gathering can be generous without
# taking grounding tolerance away from exactly the questions that need it most.
GATHERING_ROUNDS = 20
_HISTORY_LIMIT = 12  # last N conversation turns kept (context-window discipline)

_GREETING = "Ask me anything about your sleep, activity, recovery, or logged routines."

# Said once, when the gathering allowance runs out (or the loop stalls) and the tools are
# withdrawn. Without it the model would face a silent, unexplained loss of its tools; with
# it the last round is a real answer attempt instead of a wasted one. It asks for honesty
# about the gap rather than a guess — the validator would refuse the guess anyway, but a
# refused answer the owner never sees is a worse outcome than a plainly stated limit.
_ANSWER_NOW = (
    "You have no more tool calls available. Answer the question now using only the data "
    "already in this conversation. If something you wanted is missing, say plainly what "
    "you could not check — do not estimate or invent a number."
)

# JSON mode, but ONLY on a round that offers no tools. The two are not reliably
# combinable across the providers behind OpenRouter (a JSON-constrained response and a
# function call are two different things for a model to emit), and a round that answers
# is exactly a round that ran out of tools to offer or chose not to use them. Asking for
# both on every round would risk the tool loop itself to tidy a format the instruction
# already gets right; `coach_answer._json_object` covers the rest.
_JSON_OBJECT = {"type": "json_object"}


@dataclass
class CoachResult:
    """The coach's reply plus its grounding + which tools actually ran this turn.

    ``grade_floor`` is the WEAKEST evidence grade among the answer's valid citations —
    the floor the whole reply rests on, not an average and not the best note in it. The
    validator has always computed it (``validator._grade_floor``) and every other surface
    already carries it; the coach — the surface where an owner most needs to know how
    firm the ground is — dropped it on the floor (#84). ``None`` means the answer cited
    nothing gradeable, which is a different statement from a weak grade and stays
    distinguishable.

    ``data_coverage`` is §3's third piece of metadata (#89): how many days of each metric
    this turn READ the window actually held (:func:`_metrics_read`). ``None`` only for a
    greeting or a pre-LLM refusal — the two replies that rest on no data at all.
    """

    reply: str
    citations: list[str] = field(default_factory=list)
    personal_findings: list[str] = field(default_factory=list)
    grade_floor: str | None = None
    tool_calls: list[dict] = field(default_factory=list)
    refused: bool = False
    validated: bool = True
    data_coverage: dict | None = None


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
    result = _loop(client, convo, user_id, tz)
    result.data_coverage = coverage.measured_payload(
        user_id, tz, _metrics_read(result.tool_calls), context_days
    )
    return result


def _metrics_read(invocations: list[dict]) -> list[str]:
    """The metrics this turn's tools actually read — the answer's own data scope.

    The coach declares no metric list the way ``grounded_ask`` does, and picking one for
    it would be inventing a scope. It does not need one: COACH_PROMPT's absolute rule is
    that NUMBERS COME ONLY FROM TOOL RESULTS, so the metrics the tools read are exactly
    the metrics the answer's numbers came from (INTELLIGENCE §4).

    Empty when the turn read none — a real state (the answer came from the standing
    context and the corpus), and ``coverage.payload`` keeps it distinguishable from
    "we have no data" by still naming the window.
    """
    return [
        metric
        for call in invocations
        if (metric := str(call.get("args", {}).get("metric", "")).strip())
    ]


def _loop(client: LLMClient, convo: list[dict], user_id: UUID, tz: str) -> CoachResult:
    """The bounded tool loop, driven by the shared pipeline (one gate set, one policy)."""
    tool_loop = _ToolLoop(client=client, convo=convo, user_id=user_id, tz=tz)
    outcome = pipeline.drive(
        pipeline.Loop(
            next_turn=tool_loop.next_turn,
            nudge=tool_loop.nudge,
            label="coach",
            max_gathering_turns=GATHERING_ROUNDS,
            context=tool_loop.answer_context,
        )
    )
    return _result(outcome, tool_loop.invocations)


@dataclass
class _ToolLoop:
    """The coach's turn shape — the ONE thing ``grounded_ask`` cannot express.

    It holds the state a bounded tool loop needs across turns: the conversation, which
    action tools returned ok (the anti-hallucination gate reads it at judgement time),
    every invocation made (so a repeat is recognisable), and whether the tools have
    already been withdrawn (so the "answer now" instruction is said exactly once).
    """

    client: LLMClient
    convo: list[dict]
    user_id: UUID
    tz: str
    invocations: list[dict] = field(default_factory=list)
    acted_ok: set[str] = field(default_factory=set)
    seen_calls: set[tuple[str, str]] = field(default_factory=set)
    tools_withdrawn: bool = False
    raw_answer: str = ""
    structure_issues: tuple[str, ...] = ()

    def next_turn(self, tools_allowed: bool) -> pipeline.Turn:
        """One model turn: run any tools it asked for, or RENDER the answer it returned.

        The turn the driver judges is the rendered prose, never the payload: every answer
        gate reads the words the owner would actually see. What the payload was is carried
        separately, on :meth:`answer_context`, so a broken contract is an issue rather
        than a silent degradation back to free text.
        """
        if not tools_allowed:
            self._withdraw_tools()
        tools = coach_tools.COACH_TOOLS if tools_allowed else None
        response = pipeline.complete(
            self.client,
            self.convo,
            tools=tools,
            model=coach_model(),
            response_format=None if tools_allowed else _JSON_OBJECT,
        )
        if response.tool_calls:
            progressed = self._run_tools(response)
            return pipeline.Turn(text=None, progressed=progressed)
        return pipeline.Turn(text=self._rendered(response.text))

    def _rendered(self, raw: str) -> str:
        """The answer as prose, with its structural issues recorded for the gate.

        An unparseable payload hands the RAW text on rather than nothing, so the hard
        output guardrails still see whatever the model wrote — but the structure gate has
        an issue by then, so it can never ship. "Fall back to prose" is deliberately not a
        branch here: it would reinstate the uncited-claim path on exactly the turns where
        the model was already ignoring instructions.
        """
        self.raw_answer = raw or ""
        answer, self.structure_issues = coach_answer.parse(self.raw_answer)
        return coach_answer.render(answer) if answer is not None else self.raw_answer

    def nudge(self, text: str, issues: Sequence[str]) -> None:  # noqa: ARG002
        """Carry the failed PAYLOAD back to the model, in its own contract's words.

        The payload, not ``text``: the model is being asked to correct a JSON object, and
        showing it prose it never wrote is an invitation to answer in prose next time.
        """
        self.convo.extend(
            pipeline.nudge_turns(self.raw_answer, issues, template=prompts.STRUCTURED_RETRY_NUDGE)
        )

    def answer_context(self) -> pipeline.AnswerContext:
        """Read at judgement time, not loop entry — ``acted_ok`` grows as tools run."""
        return pipeline.AnswerContext(
            acted_ok=frozenset(self.acted_ok), structure_issues=self.structure_issues
        )

    def _withdraw_tools(self) -> None:
        """Tell the model, once, that it must answer with what it already has."""
        if self.tools_withdrawn:
            return
        self.tools_withdrawn = True
        self.convo.append({"role": "user", "content": _ANSWER_NOW})

    def _run_tools(self, response: Any) -> bool:
        """Execute each requested tool; return whether the round learned anything new.

        A round is "no progress" only when EVERY call in it repeats an invocation already
        made — same tool, same arguments, hence the same answer. One repeat alongside a
        genuinely new call is still a round that gathered something.
        """
        self.convo.append(_assistant_tool_message(response))
        fresh = False
        for call in response.tool_calls:
            name = call.function.name
            args = _parse_args(call.function.arguments)
            fresh |= self._record_call(name, args)
            result = coach_tools.execute_tool(name, args, self.user_id, self.tz)
            if name in coach_tools.ACTION_TOOLS and result.get("ok"):
                self.acted_ok.add(name)
            self.invocations.append({"tool": name, "args": args, "result": result})
            self.convo.append(
                {"role": "tool", "tool_call_id": call.id, "content": coach_tools.dumps(result)}
            )
        return fresh

    def _record_call(self, name: str, args: dict) -> bool:
        """Remember this exact invocation; False when it has been made before."""
        signature = (name, json.dumps(args, sort_keys=True, default=str))
        if signature in self.seen_calls:
            log.info("coach repeated tool call: %s — no new information this round", name)
            return False
        self.seen_calls.add(signature)
        return True


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
        grade_floor=outcome.validation.grade_floor,
        tool_calls=invocations,
        validated=True,
    )


def _initial_messages(
    history: list[dict], question: str, user_id: UUID, tz: str, context_days: int
) -> list[dict]:
    """System (coach prompt + context + evidence + the output contract) then the conversation.

    ``COACH_SYSTEM_PROMPT`` is ``docs/COACH_PROMPT.md`` verbatim and is pinned
    byte-for-byte by a test; the answer contract is APPENDED here exactly as the context
    and evidence blocks are, so the voice document stays the voice document and the
    envelope lives with the parser that enforces it (``coach_answer.ANSWER_SHAPE``).
    """
    context = build_coach_context(question, user_id, tz, days=context_days)
    evidence = coach_evidence(question)
    system = (
        f"{COACH_SYSTEM_PROMPT}\n\n# THE USER'S DATA (CONTEXT)\n\n{context}\n\n{evidence}"
        f"\n\n{coach_answer.ANSWER_SHAPE}"
    )
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
