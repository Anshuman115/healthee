"""Metric history + profile reads — GET /api/history, GET /api/profile (Bearer-auth)."""

from __future__ import annotations

from fastapi import APIRouter

from healthee.api.validation import require_known_metric
from healthee.core.db import tenant_transaction
from healthee.core.request_auth import CurrentUser
from healthee.read.history import history, profile

router = APIRouter(tags=["history"])


@router.get("/api/history")
def get_history(user: CurrentUser, metric: str, days: int = 90) -> dict:
    """Daily series for a metric over a bounded range."""
    require_known_metric(metric)
    with tenant_transaction(user.id) as cur:
        return history(cur, user.id, user.timezone, metric, days)


@router.get("/api/profile")
def get_profile(user: CurrentUser) -> dict:
    """Stored profile (restores it after an app reinstall)."""
    with tenant_transaction(user.id) as cur:
        return profile(cur, user.id, user.timezone)
