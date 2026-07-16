"""Activity tab — GET /api/activity (Bearer-auth). Thin router over the read service."""

from __future__ import annotations

from fastapi import APIRouter

from healthee.core.db import tenant_transaction
from healthee.core.request_auth import CurrentUser
from healthee.read.activity import activity_snapshot

router = APIRouter(tags=["activity"])


@router.get("/api/activity")
def get_activity(user: CurrentUser) -> dict:
    """Cardiorespiratory fitness + weekly inputs + training-load + workouts."""
    with tenant_transaction(user.id) as cur:
        return activity_snapshot(cur, user.id, user.timezone)
