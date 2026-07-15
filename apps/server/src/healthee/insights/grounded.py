"""The grounded-ask choke point — THE single path every LLM surface goes through.

INTELLIGENCE §3, in order:
  1. deterministic refusal pre-classifier (5 domains) — hits bypass the LLM entirely;
  2. v2-native context + manifest-ranked retrieval → the system/user messages;
  3. one LLM completion;
  4. BLOCKING validator — one retry with a nudge, then an honest FALLBACK. The
     unvalidated text NEVER ships (the fix for legacy's advisory validation, hole #2).

Every surface (sleep/activity/metric/workout insights, notable, and — via the
``allow_tools`` seam — the coach in WP5b) calls ``grounded_ask``; none of them
talk to the LLM directly. That is how the coach inherits citation validation
(hole #1: legacy's coach was the one surface with none).
"""

from __future__ import annotations

from dataclasses import dataclass, field

from healthee.core.logging import get_logger
from healthee.insights import prompts
from healthee.insights.client import DEFAULT_MODEL, LLMClient, get_client
from healthee.insights.context import build_context
from healthee.insights.refusals import classify_refusal
from healthee.insights.retrieval import evidence_section
from healthee.insights.validator import validate

log = get_logger(__name__)

_MAX_RETRIES = 1  # one nudged retry, then the honest fallback (blocking)


@dataclass
class GroundedResult:
    """What every LLM surface receives: validated text + its grounding metadata."""

    text: str
    citations: list[str] = field(default_factory=list)
    personal_findings: list[str] = field(default_factory=list)
    grade_floor: str | None = None
    refused: bool = False
    validated: bool = True


def _build_messages(question: str, metrics: list[str], context_days: int) -> list[dict]:
    """System prompt + one user payload (v2 context + ranked evidence + the task)."""
    context_md = build_context(days=context_days, question=question)
    evidence_md, top_ids = evidence_section(question, metrics)
    log.info("grounded context: %d evidence notes in full", len(top_ids))
    user = f"# CONTEXT\n\n{context_md}\n\n{evidence_md}\n\n# USER QUESTION / TASK\n\n{question}"
    return [
        {"role": "system", "content": prompts.SYSTEM_PROMPT},
        {"role": "user", "content": user},
    ]


def grounded_ask(
    question: str,
    *,
    metrics: list[str] | None = None,
    context_days: int = 14,
    allow_tools: bool = False,  # noqa: ARG001 — WP5b coach seam; tool loop lands there
    model: str = DEFAULT_MODEL,
    client: LLMClient | None = None,
) -> GroundedResult:
    """Answer ``question`` grounded in the user's v2 data + the graded corpus.

    ``allow_tools`` is the reserved seam the coach (WP5b) will use to run its
    tool loop through this same pipeline; the insight surfaces call with it False.
    ``client`` is injectable so tests run a deterministic stub with no network.
    """
    refusal = classify_refusal(question)
    if refusal is not None:
        log.info("refused pre-LLM: domain=%s", refusal.name)
        return GroundedResult(text=refusal.template, refused=True)

    client = client or get_client()
    messages = _build_messages(question, metrics or [], context_days)
    return _complete_with_validation(client, messages, model)


def _complete_with_validation(
    client: LLMClient, messages: list[dict], model: str
) -> GroundedResult:
    """Run the completion, validate, retry once, else return the honest fallback."""
    retries = 0
    while True:
        response = client.complete(messages, model=model)
        result = validate(response.text)
        if result.ok:
            return GroundedResult(
                text=response.text,
                citations=result.citations,
                personal_findings=result.personal_findings,
                grade_floor=result.grade_floor,
            )
        if retries >= _MAX_RETRIES:
            log.warning("validation failed twice (%s) — returning honest fallback", result.issues)
            return GroundedResult(text=prompts.FALLBACK, validated=False)
        nudge = prompts.RETRY_NUDGE.format(issues="\n".join(f"- {i}" for i in result.issues))
        messages = [
            *messages,
            {"role": "assistant", "content": response.text},
            {"role": "user", "content": nudge},
        ]
        retries += 1
