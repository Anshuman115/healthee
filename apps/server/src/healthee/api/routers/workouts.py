"""Workout detail — GET /api/activity/workout?start=… (Bearer-auth)."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from healthee.core.auth import require_token
from healthee.core.db import transaction
from healthee.read.workout import workout_detail

router = APIRouter(tags=["workouts"], dependencies=[Depends(require_token)])


@router.get("/api/activity/workout")
def get_workout(start: str) -> dict:
    """Per-workout summary + minute HR profile + zones + derived metrics."""
    with transaction() as cur:
        return workout_detail(cur, start)
