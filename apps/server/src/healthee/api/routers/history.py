"""Metric history + profile reads — GET /api/history, GET /api/profile (Bearer-auth)."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Query
from pydantic import BaseModel

from healthee.api.validation import require_known_metric
from healthee.core.db import tenant_transaction
from healthee.core.request_auth import CurrentUser
from healthee.read.history import history, profile
from healthee.read.history_logs import history_logs
from healthee.read.profile_edit import ProfileEdit, ProfileEditResult, edit_profile

router = APIRouter(tags=["history"])


class AccountIdentity(BaseModel):
    """Stable authenticated namespace for durable device-owned upload queues."""

    user_id: UUID
    timezone: str


@router.get("/api/account", response_model=AccountIdentity)
def get_account(user: CurrentUser) -> AccountIdentity:
    return AccountIdentity(user_id=user.id, timezone=user.timezone)


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


@router.patch("/api/profile", response_model=ProfileEditResult)
def patch_profile(user: CurrentUser, edit: ProfileEdit) -> ProfileEditResult:
    """Save explicitly supplied demographics and an optional new weigh-in."""
    with tenant_transaction(user.id) as cur:
        return edit_profile(cur, user.id, edit)


class LogMarker(BaseModel):
    day: str
    kind: str
    count: int


class HistoryLogMarkers(BaseModel):
    markers: list[LogMarker]


@router.get("/api/history/logs")
def get_history_logs(
    user: CurrentUser, days: Annotated[int, Query(ge=1, le=1825)] = 90
) -> HistoryLogMarkers:
    with tenant_transaction(user.id) as cur:
        return HistoryLogMarkers.model_validate(history_logs(cur, user.id, user.timezone, days))
