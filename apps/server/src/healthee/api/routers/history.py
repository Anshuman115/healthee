"""Metric history + profile reads — GET /api/history, GET /api/profile (Bearer-auth)."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from healthee.api.validation import require_known_metric, require_metric_list
from healthee.core.db import tenant_transaction
from healthee.core.request_auth import CurrentUser
from healthee.read.history import history, history_batch, profile
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
def get_history(
    user: CurrentUser,
    metric: str | None = None,
    metrics: str | None = None,
    days: int = 90,
) -> dict:
    """Daily series for one metric, or for a list of them in a single read.

    ``?metric=steps_total`` answers ``{metric, series}`` — the metric-detail
    screen's form, unchanged. ``?metrics=a,b,c`` answers ``{days, series}`` with
    ``series`` keyed by metric — the dated-history panels' form, which exists
    because six screens want five to nine series each and one round trip per
    series is thirty to fifty of them for one screen.

    Exactly one of the two is required. Neither is a 422 rather than a default,
    because "every metric" is a query nobody should be able to ask by accident.

    Returns ``dict`` rather than a response model: the batch is keyed by metric
    name, so a model would either lose the keys to a ``dict[str, …]`` alias that
    documents nothing or pin one field per metric and rot on the next one. The
    contract snapshots in ``packages/contracts`` are the pin, which is the
    documented exception in standards section 2.
    """
    if (metric is None) == (metrics is None):
        raise HTTPException(status_code=422, detail="give exactly one of 'metric' or 'metrics'")
    if metric is not None:
        require_known_metric(metric)
        with tenant_transaction(user.id) as cur:
            return history(cur, user.id, user.timezone, metric, days)
    wanted = require_metric_list(metrics or "")
    with tenant_transaction(user.id) as cur:
        return history_batch(cur, user.id, user.timezone, wanted, days)


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
