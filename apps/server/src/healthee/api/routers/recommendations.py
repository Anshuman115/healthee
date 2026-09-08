"""Recommendation history uses the same AI entitlement as today's action."""

from datetime import date
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from healthee.api.gate import DailyActionUser
from healthee.core.db import tenant_transaction
from healthee.read import recommendations

router = APIRouter(tags=["recommendations"])


class Recommendation(BaseModel):
    id: int
    date: date
    rank: int
    action: str
    rationale: str | None
    expected_effect: str | None
    category: str | None
    evidence_grade: int | None
    research_note_ids: list[str]
    signal_source: str | None
    adopted: bool | None


class RecommendationHistory(BaseModel):
    recommendations: list[Recommendation]
    days: int
    offset: int


class AdoptionResult(BaseModel):
    ok: bool
    id: int
    adopted: bool


@router.get("/api/recommendations")
def get_history(
    user: DailyActionUser,
    days: Annotated[int, Query(ge=1, le=180)] = 30,
    offset: Annotated[int, Query(ge=0, le=10000)] = 0,
) -> RecommendationHistory:
    with tenant_transaction(user.id) as cur:
        rows = recommendations.history(cur, user.id, user.timezone, days, offset)
    return RecommendationHistory(
        recommendations=[Recommendation.model_validate(r) for r in rows], days=days, offset=offset
    )


@router.post("/api/recommendations/{rec_id}/adopt")
def adopt(user: DailyActionUser, rec_id: int) -> AdoptionResult:
    return _update_adoption(user.id, rec_id, True)


@router.post("/api/recommendations/{rec_id}/dismiss")
def dismiss(user: DailyActionUser, rec_id: int) -> AdoptionResult:
    return _update_adoption(user.id, rec_id, False)


def _update_adoption(user_id: UUID, rec_id: int, adopted: bool) -> AdoptionResult:
    with tenant_transaction(user_id) as cur:
        if not recommendations.set_adoption(cur, user_id, rec_id, adopted):
            raise HTTPException(status_code=404, detail="Recommendation not found")
    return AdoptionResult(ok=True, id=rec_id, adopted=adopted)
