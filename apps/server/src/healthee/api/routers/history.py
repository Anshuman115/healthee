"""Metric history + profile reads — GET /api/history, GET /api/profile (Bearer-auth)."""

from __future__ import annotations

from fastapi import APIRouter

from healthee.core.db import transaction
from healthee.core.request_auth import CurrentUser
from healthee.read.history import history, profile

router = APIRouter(tags=["history"])


@router.get("/api/history")
def get_history(user: CurrentUser, metric: str, days: int = 90) -> dict:
    """Daily series for a metric over a bounded range."""
    with transaction() as cur:
        return history(cur, user.id, user.timezone, metric, days)


@router.get("/api/profile")
def get_profile(user: CurrentUser) -> dict:
    """Stored profile (restores it after an app reinstall)."""
    with transaction() as cur:
        return profile(cur, user.id)
