"""The choke point's STAGES — the one body both LLM surfaces run (INTELLIGENCE §3).

Until this module existed the coach was *enforced-equivalent* to the choke point rather
than *routed through* it: ``grounded.py`` and ``coach.py` each called the primitives
(``classify_refusal``, ``check_output``, ``validate``, the honest fallback) in their own
order, from their own loop. The rule that followed — "every rule added to the choke point
must be mirrored in the coach" — was enforced by a human remembering, and it had already
been missed once: the hard output guardrail had to be written in two places.

The split existed for a real reason: the coach needs a bounded TOOL LOOP and
``grounded_ask`` does not. So the fork was moved rather than removed. Everything the two
surfaces share lives here as one code path; the only difference either surface expresses
is *how one model turn is produced* (:class:`Turn`) and *how its messages are laid out*.

Stage order, and where each one now lives:

  1. question gate ......... :func:`check_question`  (``refusals.classify_refusal``)
  2. context ............... :func:`user_context`    (``context.build_context``)
  3. retrieval ............. :func:`evidence`        (``retrieval.evidence_section``)
  4. LLM turn .............. :func:`complete`        (the ONE transport call)
  5. hard output guardrail . ``_output_guard_gate``  — BLOCKING, never retried
  6. blocking validator .... ``_validator_gate``     — prose or JSON
  7. anti-hallucination .... ``_action_claim_gate``  — an action claim needs a tool
  8. answer shape .......... ``_structure_gate``     — a structured surface's own contract
  9. gather → answer → nudge → fallback ... :func:`drive` — unvalidated text NEVER ships

Stages 5–8 are a REGISTRY (:func:`answer_gates`), not a hardcoded sequence, and stage 1
is one too (:func:`question_gates`). That is what makes the acceptance bar mechanical: a
stage added to a registry reaches every surface by construction, and
``tests/insights/test_pipeline_shared.py`` proves it by injecting one and asserting BOTH
surfaces obey it. Its companion — an AST guard in the same file — asserts that no module
except this one reaches a primitive directly, so a stage cannot be re-added to one side
only without failing a test.

Stage 5 runs BEFORE stage 6 on purpose: a forbidden output is not a grounding problem to
nudge the model out of, it is a floor (INTELLIGENCE §3, ``output_guard``'s docstring).
"""

from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from uuid import UUID

from healthee.core.config import get_settings
from healthee.core.logging import get_logger
from healthee.insights import prompts
from healthee.insights.action_claims import claim_issues
from healthee.insights.client import ChatResponse, LLMClient
from healthee.insights.context import build_context
from healthee.insights.output_guard import check_output
from healthee.insights.refusals import Domain, classify_refusal
from healthee.insights.retrieval import evidence_section
from healthee.insights.validator import ValidationResult, validate, validate_json

log = get_logger(__name__)


def validation_retries() -> int:
    """How many NUDGED REWRITES one answer gets before the honest fallback ships.

    It was the constant ``MAX_VALIDATION_RETRIES = 1``, set when a retry cost real money
    on the tier we ran then; it is now ``LLM_VALIDATION_RETRIES`` (default **2**), and
    ``core.config`` carries why that is one setting rather than a per-model price table.

    A retry is what FIXES the failures this pipeline actually has — measured (INTELLIGENCE
    §9.1, §9.5), ~80 % of everything the product paid for and never shipped failed on
    citation or grade-calibration WORDING, which a nudge naming the exact issue repairs.
    Only a candidate that already failed spends one, and the budget is RESERVED on top of
    the gathering allowance (:func:`turn_budget`), never taken from it. Zero is legal and
    means "one attempt, then the fallback"; no value reaches the floor, which is that
    unvalidated text never ships.
    """
    return max(0, get_settings().llm_validation_retries)


# ── Stage 1 · the question gate ──────────────────────────────────────────────

QuestionGate = Callable[[str], Domain | None]

_QUESTION_GATES: tuple[QuestionGate, ...] = (classify_refusal,)


def question_gates() -> tuple[QuestionGate, ...]:
    """The gates run over the QUESTION before any context build or model call."""
    return _QUESTION_GATES


def check_question(question: str) -> Domain | None:
    """The first refusal domain ``question`` hits, or None when it may be answered.

    A hit short-circuits the whole pipeline — the model is never called, so it cannot be
    prompted, jailbroken or cajoled past a hard guardrail (INTELLIGENCE §3 step 1).
    """
    for gate in question_gates():
        hit = gate(question)
        if hit is not None:
            return hit
    return None


# ── Stages 2–4 · context, retrieval, transport ───────────────────────────────


def user_context(question: str, user_id: UUID, tz: str, *, days: int) -> str:
    """The owner's v2-native context markdown — THE context stage for every surface.

    A one-line seam on purpose: it is what makes "context" a stage both surfaces provably
    share rather than two call sites that happen to agree today.
    """
    return build_context(user_id, tz, days=days, question=question)


def evidence(question: str, metrics: Sequence[str] | None = None) -> tuple[str, list[str]]:
    """The manifest-ranked EVIDENCE NOTES section + the ids embedded in full."""
    return evidence_section(question, list(metrics or []))


def complete(
    client: LLMClient,
    messages: list[dict],
    *,
    tools: list[dict] | None = None,
    model: str | None = None,
    response_format: dict | None = None,
) -> ChatResponse:
    """The ONE call into the LLM transport — the seam a cost/budget stage plugs into."""
    return client.complete(messages, tools=tools, model=model, response_format=response_format)


# ── Stages 5–7 · the answer gates ────────────────────────────────────────────


@dataclass(frozen=True)
class AnswerContext:
    """The per-surface facts the shared gates need — defaults are the STRICTEST reading.

    ``json_mode`` selects the validator flavour. ``acted_ok`` names the action tools that
    returned ok this turn; a surface with no tools leaves it empty, which is not an
    exemption but the strictest possible setting — every action claim is then an issue.

    ``structure_issues`` is how a surface whose model output has a CONTRACT reports that
    the contract was broken (``coach_answer``). Carried here rather than raised where it
    is found, so the driver's one policy — nudge, then the honest fallback — applies to it
    exactly as it applies to a missing citation instead of a second retry loop growing
    beside the shared one. Empty is the truth for a surface that has no structure.
    """

    json_mode: bool = False
    acted_ok: frozenset[str] = frozenset()
    structure_issues: tuple[str, ...] = ()


@dataclass(frozen=True)
class Block:
    """A hard stop: this exact response ships, and the model is NEVER nudged toward another."""

    name: str
    response: str


@dataclass(frozen=True)
class GateOutcome:
    """What one gate concluded: a hard block, retryable issues, or nothing at all.

    ``validation`` is how the validator gate publishes the citations / personal findings /
    grade floor the surfaces put on their result — no other gate needs to set it.
    """

    block: Block | None = None
    issues: tuple[str, ...] = ()
    validation: ValidationResult | None = None


AnswerGate = Callable[[str, AnswerContext], GateOutcome]


def _output_guard_gate(text: str, ctx: AnswerContext) -> GateOutcome:  # noqa: ARG001
    """Hard output guardrails — blocking, whatever the text cited or would validate."""
    rule = check_output(text)
    if rule is None:
        return GateOutcome()
    return GateOutcome(block=Block(rule.name, rule.response))


def _validator_gate(text: str, ctx: AnswerContext) -> GateOutcome:
    """The blocking citation validator — prose or JSON, same honesty rules."""
    result = validate_json(text) if ctx.json_mode else validate(text)
    return GateOutcome(issues=tuple(result.issues), validation=result)


def _action_claim_gate(text: str, ctx: AnswerContext) -> GateOutcome:
    """Never claim an action no tool performed this turn (``action_claims``)."""
    return GateOutcome(issues=tuple(claim_issues(text, ctx.acted_ok)))


def _structure_gate(text: str, ctx: AnswerContext) -> GateOutcome:  # noqa: ARG001
    """The surface's own answer CONTRACT — a shape that was not honoured is an issue.

    It reads the context, not the text, because the contract is about the payload the
    MODEL produced while ``text`` is what the surface RENDERED from it
    (``coach_answer.render``). Both are checked: the rendered prose faces every gate above
    unchanged, and this one says whether what it came from was what was asked for.
    """
    return GateOutcome(issues=ctx.structure_issues)


_ANSWER_GATES: tuple[AnswerGate, ...] = (
    _output_guard_gate,  # the floor FIRST — a forbidden answer is never nudged
    _validator_gate,
    _action_claim_gate,
    _structure_gate,
)


def answer_gates() -> tuple[AnswerGate, ...]:
    """The gates run over every text candidate, in order. THE seam a new stage enters by."""
    return _ANSWER_GATES


@dataclass(frozen=True)
class Verdict:
    """The folded outcome of every answer gate over one candidate."""

    block: Block | None = None
    issues: tuple[str, ...] = ()
    validation: ValidationResult | None = None

    @property
    def ok(self) -> bool:
        """True only when nothing blocked and no gate raised an issue (blocking)."""
        return self.block is None and not self.issues


def judge(text: str, ctx: AnswerContext) -> Verdict:
    """Run every answer gate over ``text``; a block short-circuits the rest."""
    issues: list[str] = []
    validation: ValidationResult | None = None
    for gate in answer_gates():
        outcome = gate(text, ctx)
        if outcome.block is not None:
            return Verdict(block=outcome.block, validation=outcome.validation or validation)
        issues.extend(outcome.issues)
        if outcome.validation is not None:
            validation = outcome.validation
    return Verdict(issues=tuple(issues), validation=validation)


# ── Stage 8 · the loop policy: gather, then answer, nudge once, then fall back ─


@dataclass(frozen=True)
class Turn:
    """One model turn: an answer candidate, or ``None`` when the turn produced none.

    ``text=None`` is how a surface says "I handled that turn myself — ask again". The
    coach returns it after running tool calls; that is the ONLY shape the tool loop
    takes in this module, which is why the loop is a parameter and not a fork.

    ``progressed=False`` on such a turn says "that round added nothing new" — the surface
    knows what a repeat looks like (the coach: same tool, same arguments), the driver
    knows what to do about it (stop gathering and force the answer). A loop that is not
    making progress should end on its own rather than run out of budget.
    """

    text: str | None
    progressed: bool = True


@dataclass(frozen=True)
class Outcome:
    """What the shared driver concluded — each surface shapes its own result from this."""

    text: str
    validation: ValidationResult | None = None
    refused: bool = False
    validated: bool = True


@dataclass(frozen=True)
class Loop:
    """A surface's three differences: produce a turn, carry a nudge back, describe itself.

    ``context`` is a callable rather than a value because the coach's ``acted_ok`` grows
    as tools run — it must be read at judgement time, not at loop entry.

    ``next_turn`` is asked with ``tools_allowed``: True while the gathering allowance
    lasts, False once it is spent (or the loop stalled). A tool-less surface ignores it;
    the coach stops offering ``tools=`` and tells the model to answer with what it has.

    ``max_gathering_turns`` is the allowance for rounds that run tools instead of
    answering. It defaults to 0 — a surface with no tools can never spend one — and it
    is NOT the answer budget: :func:`validation_retries` is reserved on top of it by
    :func:`drive`, so a question that needed twenty rounds of data arrives at its answer
    with exactly the same grounding tolerance as a trivial one.
    """

    next_turn: Callable[[bool], Turn]
    nudge: Callable[[str, Sequence[str]], None]
    label: str
    max_gathering_turns: int = 0
    context: Callable[[], AnswerContext] = field(default=AnswerContext)


def turn_budget(loop: Loop) -> int:
    """The hard ceiling on LLM calls for one run: gathering + the reserved answers.

    A ceiling, not a spend. Nothing consumes a gathering round unless the model actually
    asked for a tool, and the two answer attempts are the same two every surface gets.
    """
    return loop.max_gathering_turns + validation_retries() + 1


@dataclass
class _Progress:
    """The driver's running state — how much gathering happened, how many retries, stalled."""

    gathered: int = 0
    retries: int = 0
    stalled: bool = False

    def may_gather(self, loop: Loop) -> bool:
        """True while this run may still spend a round on tools instead of an answer."""
        return not self.stalled and self.gathered < loop.max_gathering_turns

    def note_round(self, loop: Loop, turn: Turn) -> None:
        """Count one gathering round, and latch the stall when it added nothing new."""
        self.gathered += 1
        if turn.progressed:
            return
        self.stalled = True
        log.info(
            "%s: gathering round %d repeated an earlier call — forcing the answer",
            loop.label,
            self.gathered,
        )


def drive(loop: Loop) -> Outcome:
    """Run turns until one clears every gate, is blocked, or the honest fallback ships.

    Gathering and validation are two budgets, not one counter. They used to share
    ``max_turns``, which produced two defects at once: a question needing the full
    allowance of tool rounds exited having NEVER been asked for an answer, and a
    data-heavy question reached its one answer attempt with zero retries left while a
    trivial one kept them all. The questions needing the most data got the least
    grounding tolerance — exactly backwards.

    The fallback is still here and nowhere else: unvalidated text never ships
    (INTELLIGENCE §3, hole #2), and a blocked answer is returned without a retry.
    """
    state = _Progress()
    for _turn_no in range(turn_budget(loop)):
        tools_allowed = state.may_gather(loop)
        turn = loop.next_turn(tools_allowed)
        if turn.text is None:
            if not tools_allowed:
                log.warning("%s: a tool-less turn produced no answer — honest fallback", loop.label)
                return Outcome(text=prompts.FALLBACK, validated=False)
            state.note_round(loop, turn)
            continue
        outcome = _settle(loop, turn.text, state)
        if outcome is not None:
            return outcome
    log.warning("%s: exhausted its turn budget without a clean answer — fallback", loop.label)
    return Outcome(text=prompts.FALLBACK, validated=False)


def _settle(loop: Loop, text: str, state: _Progress) -> Outcome | None:
    """Judge one answer candidate; None means "nudged — ask the model again"."""
    verdict = judge(text, loop.context())
    if verdict.block is not None:
        return Outcome(text=verdict.block.response, refused=True, validated=False)
    if verdict.ok:
        return Outcome(text=text, validation=verdict.validation)
    if state.retries >= validation_retries():
        log.warning(
            "%s: candidate failed the gates on every attempt (%s) — honest fallback",
            loop.label,
            verdict.issues,
        )
        return Outcome(text=prompts.FALLBACK, validated=False)
    loop.nudge(text, verdict.issues)
    state.retries += 1
    return None


def nudge_turns(text: str, issues: Sequence[str], *, template: str | None = None) -> list[dict]:
    """The two conversation turns that carry a failed candidate back to the model.

    ``template`` lets a surface state the fix in ITS OWN output contract's terms: telling
    the coach to "end every sentence with a `[note_id]`" would be instructions for a
    format it no longer writes. The POLICY (one nudge per failed attempt, then the honest
    fallback) stays here and is shared; only the wording is the surface's.
    """
    listed = "\n".join(f"- {issue}" for issue in issues)
    return [
        {"role": "assistant", "content": text},
        {"role": "user", "content": (template or prompts.RETRY_NUDGE).format(issues=listed)},
    ]
