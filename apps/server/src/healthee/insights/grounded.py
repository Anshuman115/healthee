"""The grounded-ask entry point for the NON-CONVERSATIONAL LLM surfaces.

The stages this function is named after no longer live here: they live in
``pipeline.py``, which the coach runs too. This module is now one of two thin
compositions over that shared body — it contributes a message layout (system prompt +
one user payload) and a single-completion turn, and nothing else. ``coach.py``
contributes a different layout and a bounded tool loop. Every honesty stage — the
refusal gate, the context and retrieval builders, the LLM transport, the hard output
guardrails, the blocking validator, the anti-hallucination gate, the nudge-then-fallback
policy — is one code path shared by both.

That is the fix for a real hazard, not a tidy-up. The coach used to re-implement this
sequence from the same primitives: enforced-equivalent, not routed-through, so every new
rule had to be mirrored by hand and one already had been (the output guardrail, written
twice). A stage added to ``pipeline.answer_gates()`` now reaches both surfaces by
construction, and ``tests/insights/test_pipeline_shared.py`` fails if either surface
stops inheriting one or reaches for a primitive directly.

The surfaces that call ``grounded_ask``: sleep/activity/metric/workout insights
(``surfaces``), ``notable``, the daily coaching lines (``coaching``), the two job
surfaces (``jobs.recs``, ``jobs.briefing``) and challenge/program generation
(``challenges.generate``, ``challenges.program_generate``). The coach reaches the same
stages through ``run_coach``. Nothing else may talk to the LLM at all.
"""

from __future__ import annotations

import json
from collections.abc import Sequence
from dataclasses import dataclass, field
from uuid import UUID

from healthee.core.logging import get_logger
from healthee.insights import pipeline, prompts
from healthee.insights.client import LLMClient, get_client

log = get_logger(__name__)


@dataclass
class GroundedResult:
    """What every LLM surface receives: validated text + its grounding metadata.

    ``data`` is the parsed object when ``response_format="json"`` validated —
    JSON surfaces (recs) consume it directly instead of re-parsing ``text``. It
    stays ``None`` for the prose path and for any refusal / honest fallback.
    """

    text: str
    citations: list[str] = field(default_factory=list)
    personal_findings: list[str] = field(default_factory=list)
    grade_floor: str | None = None
    refused: bool = False
    validated: bool = True
    data: dict | None = None


def _build_messages(
    question: str, user_id: UUID, tz: str, metrics: list[str], context_days: int
) -> list[dict]:
    """System prompt + one user payload (v2 context + ranked evidence + the task)."""
    context_md = pipeline.user_context(question, user_id, tz, days=context_days)
    evidence_md, top_ids = pipeline.evidence(question, metrics)
    log.info("grounded context: %d evidence notes in full", len(top_ids))
    user = f"# CONTEXT\n\n{context_md}\n\n{evidence_md}\n\n# USER QUESTION / TASK\n\n{question}"
    return [
        {"role": "system", "content": prompts.SYSTEM_PROMPT},
        {"role": "user", "content": user},
    ]


def grounded_ask(
    question: str,
    user_id: UUID,
    tz: str,
    *,
    metrics: list[str] | None = None,
    context_days: int = 14,
    response_format: str | None = None,
    model: str | None = None,
    client: LLMClient | None = None,
) -> GroundedResult:
    """Answer ``question`` grounded in ``user_id``'s v2 data + the graded corpus.

    ``user_id``/``tz`` scope every context read to the owner and anchor its day
    boundaries.

    ``response_format="json"`` switches on the JSON output seam: the client is
    asked for a JSON object and the answer is checked by the JSON-aware validator
    (``validate_json``); the parsed object comes back on ``result.data``. The
    default (``None``) is the unchanged prose path. ``client`` is injectable so
    tests run a deterministic stub.

    There is deliberately no tool-calling seam here. The coach's loop is expressed as a
    ``pipeline.Loop`` instead, because the two surfaces differ in their message LAYOUT as
    well as their turn shape — folding both into one signature would produce a function
    whose arguments contradict each other, which is worse than two short compositions
    over one shared body.
    """
    refusal = pipeline.check_question(question)
    if refusal is not None:
        log.info("refused pre-LLM: domain=%s", refusal.name)
        return GroundedResult(text=refusal.template, refused=True)

    client = client or get_client()
    messages = _build_messages(question, user_id, tz, metrics or [], context_days)
    return _complete_with_validation(client, messages, model, response_format)


def _complete_with_validation(
    client: LLMClient, messages: list[dict], model: str | None, response_format: str | None = None
) -> GroundedResult:
    """Drive the shared pipeline with a one-completion turn, then shape the result."""
    json_mode = response_format == "json"
    client_format = {"type": "json_object"} if json_mode else None

    def next_turn(_tools_allowed: bool) -> pipeline.Turn:
        # This surface has no tools, so it never spends a gathering round and the
        # driver's ``tools_allowed`` flag has nothing to vary: every turn is an answer.
        response = pipeline.complete(client, messages, model=model, response_format=client_format)
        return pipeline.Turn(text=response.text)

    def nudge(text: str, issues: Sequence[str]) -> None:
        messages.extend(pipeline.nudge_turns(text, issues))

    outcome = pipeline.drive(
        pipeline.Loop(
            next_turn=next_turn,
            nudge=nudge,
            label="grounded_ask",
            context=lambda: pipeline.AnswerContext(json_mode=json_mode),
        )
    )
    return _result(outcome, json_mode)


def _result(outcome: pipeline.Outcome, json_mode: bool) -> GroundedResult:
    """Shape one pipeline outcome into this surface's result object."""
    if outcome.refused:
        return GroundedResult(text=outcome.text, refused=True, validated=False)
    if not outcome.validated or outcome.validation is None:
        return GroundedResult(text=prompts.FALLBACK, validated=False)
    return GroundedResult(
        text=outcome.text,
        citations=outcome.validation.citations,
        personal_findings=outcome.validation.personal_findings,
        grade_floor=outcome.validation.grade_floor,
        data=json.loads(outcome.text) if json_mode else None,
    )
