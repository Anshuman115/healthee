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
    and its validation retries are the pipeline's, reserved on top.

## The two phases, and why the notes are sent once (#105)

A coach question is ~3 model calls and the EVIDENCE NOTES block — six full research
notes — used to ride on every one of them: measured, ~33.4k input tokens per call and
65–83% of each prompt (task #23, INTELLIGENCE §3). Only the LAST call writes prose or
cites anything; the gathering rounds pick a tool and read its result. Shipping a library
to a call that produces a function name is the single most expensive habit in the
product.

The loop cannot know in advance which round is the answering one — the model simply
stops calling tools. So the phases are separated by what each round is GIVEN:

  * **gathering** — tools, the owner's data, and the corpus INDEX (every note as one
    line: id, grade, summary). The index is a strict subset of what these rounds already
    received, since the old block listed its un-embedded notes in exactly that form, and
    it is what answers "what should I look up?" — the risk this change had to respect is
    that the corpus may be how the model decides to query HRV for an alcohol question.
    ``get_knowledge`` still pulls any specific note mid-gathering.
  * **answering** — the full ranked notes, appended once as a final user turn, and NO
    tools. Every validation retry is an answering round, so a retry always has them.

The first round that answers instead of calling a tool ends the gathering phase, and its
text is DISCARDED: it was written without the notes it would have to cite, and a cheaper
answer that is less grounded is a loss, not a saving. That costs one extra model call on
a question the model finishes early — priced at the CHEAP prompt, which is the whole
trade. The turn ceiling is unchanged (``turn_budget`` = 22): the extra round is taken
from the gathering allowance the model chose not to spend, so metering, which charges the
QUESTION and not the turn (``api/routers/coach.py``), is untouched.

Everything else — the refusal gate before any tool runs, the hard output guardrails, the
blocking validator on every final free-text answer, the anti-hallucination gate, the one
nudged retry and then ``prompts.FALLBACK`` — is the same code the insight surfaces run.
``tests/insights/test_pipeline_shared.py`` proves it by injecting a stage into the shared
registry and asserting BOTH surfaces obey it, and fails if any surface reaches a
primitive directly.

Every message this loop sends is laid out by ``coach_messages`` (the system message is
``COACH_SYSTEM_PROMPT``, docs/COACH_PROMPT.md verbatim; the context is the history-rich
``build_coach_context``); the tools are ``COACH_TOOLS``.
"""

from __future__ import annotations

import json
from collections.abc import Sequence
from dataclasses import dataclass, field
from typing import Any
from uuid import UUID

from healthee.analytics import coverage
from healthee.core.logging import get_logger
from healthee.insights import coach_messages, coach_tools, pipeline
from healthee.insights.client import LLMClient, coach_model, get_client
from healthee.insights.coach_context import DEFAULT_COACH_DAYS

log = get_logger(__name__)

# The GATHERING allowance — rounds the model may spend running tools instead of
# answering. It is a ceiling, not a spend: narrow questions were measured converging in
# TWO rounds against a live instance (docs/VERIFICATION_2026_08_01.md §7) and never touch
# the rest, and an unused round costs nothing. It used to be 5
# AND it doubled as the answer budget, so a question that legitimately needed five rounds
# of data exited having never been asked for an answer, and a four-round one reached its
# single answer attempt with zero validation retries left. `MAX_VALIDATION_RETRIES` is
# now reserved on top of this by `pipeline.drive`, so gathering can be generous without
# taking grounding tolerance away from exactly the questions that need it most.
GATHERING_ROUNDS = 20


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
    history = coach_messages.recent_turns(messages)
    question = coach_messages.last_user(history)
    if not question:
        return CoachResult(reply=coach_messages.GREETING)
    refusal = pipeline.check_question(question)
    if refusal is not None:
        log.info("coach refused pre-LLM: domain=%s", refusal.name)
        return CoachResult(reply=refusal.template, refused=True)
    client = client or get_client()
    convo = coach_messages.initial_messages(history, question, user_id, tz, context_days)
    result = _loop(client, convo, coach_messages.evidence_turn(question), user_id, tz)
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


def _loop(
    client: LLMClient, convo: list[dict], evidence: dict, user_id: UUID, tz: str
) -> CoachResult:
    """The bounded tool loop, driven by the shared pipeline (one gate set, one policy)."""
    tool_loop = _ToolLoop(client=client, convo=convo, evidence=evidence, user_id=user_id, tz=tz)
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

    It holds the state a bounded tool loop needs across turns: the conversation, the
    prepared evidence turn and whether it has been sent, which action tools returned ok
    (the anti-hallucination gate reads it at judgement time), every invocation made (so a
    repeat is recognisable), whether the gathering phase has ended, and whether the tools
    have already been withdrawn (so the "answer now" instruction is said exactly once).

    ``evidence`` is built by ``coach_messages.evidence_turn`` and handed in whole rather than
    retrieved here: the loop owns the SEQUENCE, the choke point owns retrieval.
    """

    client: LLMClient
    convo: list[dict]
    evidence: dict
    user_id: UUID
    tz: str
    invocations: list[dict] = field(default_factory=list)
    acted_ok: set[str] = field(default_factory=set)
    seen_calls: set[tuple[str, str]] = field(default_factory=set)
    gathering_done: bool = False
    evidence_sent: bool = False
    tools_withdrawn: bool = False

    def next_turn(self, tools_allowed: bool) -> pipeline.Turn:
        """One model turn: a gathering round while the phase lasts, otherwise the answer."""
        if tools_allowed and not self.gathering_done:
            return self._gather_turn()
        return self._answer_turn(tools_allowed)

    def _gather_turn(self) -> pipeline.Turn:
        """A tool round: tools offered, no note bodies, and no answer is kept from it."""
        response = pipeline.complete(
            self.client, self.convo, tools=coach_tools.COACH_TOOLS, model=coach_model()
        )
        if response.tool_calls:
            return pipeline.Turn(text=None, progressed=self._run_tools(response))
        self.gathering_done = True
        log.info("coach: the model stopped calling tools — gathering over, sending the notes")
        return pipeline.Turn(text=None)

    def _answer_turn(self, tools_allowed: bool) -> pipeline.Turn:
        """The answering round: the full notes, no tools. Every validation retry is one."""
        if not tools_allowed:
            self._withdraw_tools()
        self._send_evidence()
        response = pipeline.complete(self.client, self.convo, tools=None, model=coach_model())
        if response.tool_calls:
            # Unreachable through the real transport (no `tools=` is sent, so none can be
            # requested) and deliberately NOT executed: this round's output is not going
            # to be used, and running an action tool for it would be a write the owner
            # never hears about. The driver turns a text-less tool-less turn into the
            # honest fallback, which is the right end for a model ignoring the withdrawal.
            log.warning("coach: a tool call arrived on a tool-less round — ignored, not run")
            return pipeline.Turn(text=None)
        return pipeline.Turn(text=response.text)

    def _send_evidence(self) -> None:
        """Put the full research notes into the conversation, once, before the first answer."""
        if self.evidence_sent:
            return
        self.evidence_sent = True
        self.convo.append(self.evidence)

    def nudge(self, text: str, issues: Sequence[str]) -> None:
        """Carry a failed candidate back to the model (shared wording, shared policy)."""
        self.convo.extend(pipeline.nudge_turns(text, issues))

    def answer_context(self) -> pipeline.AnswerContext:
        """Read at judgement time, not loop entry — ``acted_ok`` grows as tools run."""
        return pipeline.AnswerContext(acted_ok=frozenset(self.acted_ok))

    def _withdraw_tools(self) -> None:
        """Tell the model, once, that it must answer with what it already has."""
        if self.tools_withdrawn:
            return
        self.tools_withdrawn = True
        self.convo.append({"role": "user", "content": coach_messages.ANSWER_NOW})

    def _run_tools(self, response: Any) -> bool:
        """Execute each requested tool; return whether the round learned anything new.

        A round is "no progress" only when EVERY call in it repeats an invocation already
        made — same tool, same arguments, hence the same answer. One repeat alongside a
        genuinely new call is still a round that gathered something.
        """
        self.convo.append(coach_messages.assistant_tool_message(response))
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


def _parse_args(raw: str | None) -> dict:
    """Parse a tool call's JSON arguments; a malformed blob degrades to empty args."""
    try:
        parsed = json.loads(raw or "{}")
    except (json.JSONDecodeError, TypeError) as exc:
        log.warning("coach tool arguments unparseable (%s) — using empty args", exc)
        return {}
    return parsed if isinstance(parsed, dict) else {}
