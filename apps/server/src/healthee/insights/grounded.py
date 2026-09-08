"""The grounded-ask entry point for the NON-CONVERSATIONAL LLM surfaces.

The stages this function is named after no longer live here: they live in
``pipeline.py``, which the coach runs too. This module is now one of two thin
compositions over that shared body — it contributes a message layout (system prompt +
one user payload) and a single-completion turn, and nothing else. ``coach.py``
contributes a different layout and a bounded tool loop. Every honesty stage — the
refusal gate, the context and retrieval builders, the LLM transport, the hard output
guardrails, the blocking validator, the anti-hallucination gate, the nudge-then-fallback
policy — is one code path shared by both.

One stage needs a fact only a surface can supply, and this module supplies it: the
personal-claims gate (#129) asks which owner-subjects a candidate talks about that the
owner has no stored data for. ``personal_claims.subjects_without_data`` is computed per
attempt in :func:`_complete_with_validation`. It used to be computed by the coach alone,
which made ``personal_claims.issues`` return on its first line for every surface here —
a registered gate that could not fire. The declared half of that gate stays coach-only
(nothing here has a claims contract to declare with); the TEXTUAL backstop, which was
built to be independent of the declaration, now runs on both.

That is the fix for a real hazard, not a tidy-up. The coach used to re-implement this
sequence from the same primitives: enforced-equivalent, not routed-through, so every new
rule had to be mirrored by hand and one already had been (the output guardrail, written
twice). A stage added to ``pipeline.answer_gates()`` now reaches both surfaces by
construction, and ``tests/insights/test_pipeline_shared.py`` fails if either surface
stops inheriting one or reaches for a primitive directly.

The surfaces that call ``grounded_ask``: sleep/activity/metric/workout insights
(``surfaces``), ``notable``, the sleep-tonight coaching line (``coaching``), the one
morning generation that feeds both the Telegram briefing and ``/api/today``'s action
(``morning``, #95), ``jobs.recs`` and challenge/program generation
(``challenges.generate``, ``challenges.program_generate``). The coach reaches the same
stages through ``run_coach``. Nothing else may talk to the LLM at all.
"""

from __future__ import annotations

import json
from collections.abc import Sequence
from dataclasses import dataclass, field
from uuid import UUID

from healthee.analytics import coverage
from healthee.core.logging import get_logger
from healthee.insights import personal_claims, pipeline, prompts
from healthee.insights.client import LLMClient, get_client

log = get_logger(__name__)


@dataclass
class GroundedResult:
    """What every LLM surface receives: validated text + its grounding metadata.

    ``data`` is the parsed object when ``response_format="json"`` validated —
    JSON surfaces (recs) consume it directly instead of re-parsing ``text``. It
    stays ``None`` for the prose path and for any refusal / honest fallback.

    ``data_coverage`` is INTELLIGENCE §3's third piece of response metadata, and the last
    one to exist (#89): how many days of each metric the answer's window actually held
    (``analytics.coverage``). It is a property of the DATA, not of the answer, so it is
    present on an honest fallback too — "we could not ground this, and you have 3 of 14
    days of it" is two facts, and the second is the one that says whether asking again
    tomorrow would help. It stays ``None`` only for a pre-LLM refusal, where no context
    was ever built.
    """

    text: str
    citations: list[str] = field(default_factory=list)
    personal_findings: list[str] = field(default_factory=list)
    grade_floor: str | None = None
    refused: bool = False
    validated: bool = True
    data: dict | None = None
    data_coverage: dict | None = None


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
    result = _complete_with_validation(client, messages, user_id, tz, model, response_format)
    # Over the metrics THIS surface declared, across the window it asked for — so the
    # coverage figure and the context the model saw describe the same days.
    result.data_coverage = coverage.measured_payload(user_id, tz, metrics or [], context_days)
    return result


@dataclass
class _Candidate:
    """The per-attempt facts this surface owns, read by the gates at judgement time.

    One field today: which owner-subjects the CURRENT candidate talks about that the
    owner has no stored data for. It has to live across the two calls because the
    pipeline's ``Loop`` produces the text in ``next_turn`` and judges it in
    ``context()``, and the answer being judged is the one this was computed from.
    """

    without_data: frozenset[str] = frozenset()


def _complete_with_validation(
    client: LLMClient,
    messages: list[dict],
    user_id: UUID,
    tz: str,
    model: str | None,
    response_format: str | None = None,
) -> GroundedResult:
    """Drive the shared pipeline with a one-completion turn, then shape the result."""
    json_mode = response_format == "json"
    client_format = {"type": "json_object"} if json_mode else None
    candidate = _Candidate()

    def next_turn(_tools_allowed: bool) -> pipeline.Turn:
        # This surface has no tools, so it never spends a gathering round and the
        # driver's ``tools_allowed`` flag has nothing to vary: every turn is an answer.
        response = pipeline.complete(client, messages, model=model, response_format=client_format)
        # Gathered here rather than in the gate because only the surface knows the owner
        # (#129), and per attempt rather than once, because a nudged rewrite is a
        # different answer that may talk about different subjects. `asserted` is empty:
        # these surfaces declare no claims contract, so the DECLARED half has nothing to
        # check and the TEXTUAL backstop is the whole of what runs here. That is a real
        # guarantee rather than a partial one — `personal_claims._candidates` was built
        # to be independent of the declaration, and leaving it uncomputed here was the
        # early return that made the gate inert on every surface but the coach.
        candidate.without_data = personal_claims.subjects_without_data(
            user_id, tz, (), response.text or ""
        )
        return pipeline.Turn(text=response.text)

    def nudge(text: str, issues: Sequence[str]) -> None:
        messages.extend(pipeline.nudge_turns(text, issues))

    outcome = pipeline.drive(
        pipeline.Loop(
            next_turn=next_turn,
            nudge=nudge,
            label="grounded_ask",
            context=lambda: pipeline.AnswerContext(
                json_mode=json_mode, without_data=candidate.without_data
            ),
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
