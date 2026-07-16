"""Workout detail — GET /api/activity/workout?start=… (Bearer-auth)."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from healthee.core.auth import require_token
from healthee.core.db import transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.read.workout import workout_detail

router = APIRouter(tags=["workouts"], dependencies=[Depends(require_token)])


@router.get("/api/activity/workout")
def get_workout(start: str) -> dict:
    """Per-workout summary + minute HR profile + zones + derived metrics."""
    # 6.4: source the owner + tz from the authenticated user.
    with transaction() as cur:
        return workout_detail(cur, SENTINEL_USER_ID, SENTINEL_TZ, start)
