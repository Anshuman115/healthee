"""The grounded-ask choke point — the path the non-conversational LLM surfaces take.

⚠ It is NOT literally "the single path every LLM surface goes through", though this
docstring said so and `INTELLIGENCE.md` §4 still implies it. **The coach does not call
`grounded_ask`** — `insights/coach.py` drives its own tool-calling loop and invokes the
choke point's PRIMITIVES directly (`validate`, `check_output`, the refusal classifier).
It is enforced-equivalent, not routed-through, and every rule added here must be mirrored
there or the coach silently misses it. That is not hypothetical: the output guardrail
(step 4) had to be added in both places, and a test pins the coach's copy so it cannot rot.

Stating it plainly because a docstring claiming a guarantee the code does not have is how
the next reader mis-reasons — the same shape as `is_refusal` documenting "exact" while it
did a substring match, which was a total validation bypass. Collapsing the coach onto this
function is real work and is tracked separately; until then, believe this paragraph, not §4.

INTELLIGENCE §3, in order:
  1. deterministic refusal pre-classifier (5 domains) — hits bypass the LLM entirely;
  2. v2-native context + manifest-ranked retrieval → the system/user messages;
  3. one LLM completion;
  4. hard OUTPUT GUARDRAILS (``output_guard``) — a documented forbidden output is
     blocked outright, with no retry, whatever its citations or validation outcome;
  5. BLOCKING validator — one retry with a nudge, then an honest FALLBACK. The
     unvalidated text NEVER ships (the fix for legacy's advisory validation, hole #2).

Steps 1 and 4 are the two halves of the code guardrail: step 1 guards the QUESTION,
step 4 guards the ANSWER. Step 4 runs BEFORE the validator on purpose — a forbidden
output is not a grounding problem to be nudged out of the model, it is a floor.

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
from healthee.insights.output_guard import check_output
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
        # The hard floor: a forbidden output never ships and is never retried into
        # existence — it does not matter what it cited or whether it would validate.
        broken = check_output(response.text)
        if broken is not None:
            return GroundedResult(text=broken.response, refused=True, validated=False)
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
