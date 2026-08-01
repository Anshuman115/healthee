"""The AI coach endpoint — POST /api/coach (Bearer-auth).

Thin (standards §2): authorize + gate → validate the body → call ``run_coach`` →
shape the reply. ``CoachUser`` is the premium gate (``api.gate``): a non-premium owner
gets 402 before a single token is spent, which is the point — the coach is the most
expensive surface in the product (PRICING.md §3.1), and this is the only place its
entitlement is checked (the coach's own tools deliberately do not re-check it).

## What one free coach QUESTION is (6.6a-2)

``PRICING.md`` §1a meters a free owner at one coach question per rolling seven days, and
the unit is this **request** — one turn — not one LLM call. A tool-calling turn can make
up to 22 (``insights.coach.GATHERING_ROUNDS`` + the reserved validation attempts);
metering calls would charge a curious question twenty times and an incurious one once,
which is not a promise anybody could read off the pricing page. That separation is what
lets the gathering allowance be generous: the ledger is keyed to the question, so a
question that genuinely needs the data costs the owner exactly what a trivial one does.
The gate charges the turn; this handler refunds it when the turn produced
no answer, and the two cases are exactly the ones the coach itself already names:
``refused`` (classified out of scope before any model ran — no tokens, no answer) and
``validated=False`` (the honest fallback shipped, which is the product working correctly
and still not what the owner asked for). A transport failure refunds too, on its way out.


All grounding, tool-calling, refusal-gating and blocking validation live in
``healthee.insights.coach``, which is one of the two entry points into the shared §3
choke point (``insights.pipeline``); nothing LLM-shaped happens in this router.
"""

from __future__ import annotations

from fastapi import APIRouter, Request
from pydantic import BaseModel

from healthee.api import gate
from healthee.api.gate import CoachUser
from healthee.insights.coach import run_coach

router = APIRouter(tags=["coach"])


class CoachMessage(BaseModel):
    """One conversation turn from the client."""

    role: str
    content: str


class CoachRequest(BaseModel):
    """POST body: the running conversation (system turns are ignored server-side)."""

    messages: list[CoachMessage] = []


@router.post("/api/coach")
def post_coach(request: Request, user: CoachUser, req: CoachRequest) -> dict:
    """Answer the conversation as the grounded coach (validated or honest fallback)."""
    try:
        result = run_coach([m.model_dump() for m in req.messages], user.id, user.timezone)
    except Exception:
        # Not a swallow — it is re-raised unchanged for the error handler to log and
        # report. The refund is the only thing that must happen before it leaves, because
        # a free owner's week has already been charged by the gate.
        gate.refund_ai_use(request, user)
        raise
    if result.refused or not result.validated:
        gate.refund_ai_use(request, user)
    return {
        "reply": result.reply,
        "citations": result.citations,
        "personal_findings": result.personal_findings,
        # The weakest grade among the cited notes — INTELLIGENCE §3's promised response
        # metadata. It was computed on every answer and dropped here (#84), so the
        # flagship surface shipped citations with no statement of how firm they are.
        # `null` = nothing gradeable was cited, which is not the same as a weak grade.
        "grade_floor": result.grade_floor,
        # INTELLIGENCE §3's third piece of response metadata (#89): how many days of each
        # metric this turn read the window actually held (`analytics.coverage`).
        "data_coverage": result.data_coverage,
        "tool_calls": result.tool_calls,
        "refused": result.refused,
        "validated": result.validated,
    }
