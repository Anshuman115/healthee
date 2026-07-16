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

import json
from dataclasses import dataclass, field
from uuid import UUID

from healthee.core.logging import get_logger
from healthee.insights import prompts
from healthee.insights.client import LLMClient, get_client
from healthee.insights.context import build_context
from healthee.insights.refusals import classify_refusal
from healthee.insights.retrieval import evidence_section
from healthee.insights.validator import validate, validate_json

log = get_logger(__name__)

_MAX_RETRIES = 1  # one nudged retry, then the honest fallback (blocking)


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
    context_md = build_context(user_id, tz, days=context_days, question=question)
    evidence_md, top_ids = evidence_section(question, metrics)
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
    allow_tools: bool = False,  # noqa: ARG001 — WP5b coach seam; tool loop lands there
    response_format: str | None = None,
    model: str | None = None,
    client: LLMClient | None = None,
) -> GroundedResult:
    """Answer ``question`` grounded in ``user_id``'s v2 data + the graded corpus.

    ``user_id``/``tz`` scope every context read to the owner and anchor its day
    boundaries; the callers hardwire the sentinel until 6.4 supplies the real user.

    ``response_format="json"`` switches on the JSON output seam: the client is
    asked for a JSON object and the answer is checked by the JSON-aware validator
    (``validate_json``); the parsed object comes back on ``result.data``. The
    default (``None``) is the unchanged prose path. ``allow_tools`` is the
    reserved seam the coach (WP5b) will use to run its tool loop through this same
    pipeline. ``client`` is injectable so tests run a deterministic stub.
    """
    refusal = classify_refusal(question)
    if refusal is not None:
        log.info("refused pre-LLM: domain=%s", refusal.name)
        return GroundedResult(text=refusal.template, refused=True)

    client = client or get_client()
    messages = _build_messages(question, user_id, tz, metrics or [], context_days)
    return _complete_with_validation(client, messages, model, response_format)


def _complete_with_validation(
    client: LLMClient, messages: list[dict], model: str | None, response_format: str | None = None
) -> GroundedResult:
    """Run the completion, validate, retry once, else return the honest fallback."""
    json_mode = response_format == "json"
    client_format = {"type": "json_object"} if json_mode else None
    retries = 0
    while True:
        response = client.complete(messages, model=model, response_format=client_format)
        result = validate_json(response.text) if json_mode else validate(response.text)
        if result.ok:
            return GroundedResult(
                text=response.text,
                citations=result.citations,
                personal_findings=result.personal_findings,
                grade_floor=result.grade_floor,
                data=json.loads(response.text) if json_mode else None,
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
