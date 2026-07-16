"""Activity tab — GET /api/activity (Bearer-auth). Thin router over the read service."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from healthee.core.auth import require_token
from healthee.core.db import transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.read.activity import activity_snapshot

router = APIRouter(tags=["activity"], dependencies=[Depends(require_token)])


@router.get("/api/activity")
def get_activity() -> dict:
    """Cardiorespiratory fitness + weekly inputs + training-load + workouts."""
    # 6.4: source the owner + tz from the authenticated user.
    with transaction() as cur:
        return activity_snapshot(cur, SENTINEL_USER_ID, SENTINEL_TZ)
