"""Workout detail — GET /api/activity/workout?start=… (Bearer-auth)."""

from __future__ import annotations

from fastapi import APIRouter

from healthee.core.db import tenant_transaction
from healthee.core.request_auth import CurrentUser
from healthee.read.workout import workout_detail

router = APIRouter(tags=["workouts"])


@router.get("/api/activity/workout")
def get_workout(user: CurrentUser, start: str) -> dict:
    """Per-workout summary + minute HR profile + zones + derived metrics."""
    with tenant_transaction(user.id) as cur:
        return workout_detail(cur, user.id, user.timezone, start)
