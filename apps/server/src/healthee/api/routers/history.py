"""Metric history + profile reads — GET /api/history, GET /api/profile (Bearer-auth)."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from healthee.core.auth import require_token
from healthee.core.db import transaction
from healthee.read.history import history, profile

router = APIRouter(tags=["history"], dependencies=[Depends(require_token)])


@router.get("/api/history")
def get_history(metric: str, days: int = 90) -> dict:
    """Daily series for a metric over a bounded range."""
    with transaction() as cur:
        return history(cur, metric, days)


@router.get("/api/profile")
def get_profile() -> dict:
    """Stored profile (restores it after an app reinstall)."""
    with transaction() as cur:
        return profile(cur)
