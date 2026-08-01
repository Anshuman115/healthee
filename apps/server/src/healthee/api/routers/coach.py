"""The AI coach endpoint — POST /api/coach (Bearer-auth).

Thin (standards §2): authorize + gate → validate the body → call ``run_coach`` →
shape the reply. ``CoachUser`` is the premium gate (``api.gate``): a non-premium owner
gets 402 before a single token is spent, which is the point — the coach is the most
expensive surface in the product (PRICING.md §3.1), and this is the only place its
entitlement is checked (the coach's own tools deliberately do not re-check it).

All grounding, tool-calling, refusal-gating and blocking validation live in
``healthee.insights.coach`` (which reuses the §3 choke-point primitives); nothing
LLM-shaped happens in this router.
"""

from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

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
def post_coach(user: CoachUser, req: CoachRequest) -> dict:
    """Answer the conversation as the grounded coach (validated or honest fallback)."""
    result = run_coach([m.model_dump() for m in req.messages], user.id, user.timezone)
    return {
        "reply": result.reply,
        "citations": result.citations,
        "personal_findings": result.personal_findings,
        "tool_calls": result.tool_calls,
        "refused": result.refused,
        "validated": result.validated,
    }
