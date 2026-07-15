"""Grounded insight reads — the LLM surfaces, all behind the §3 choke point.

Thin (standards §2): authorize → call one insight service → return its payload.
No prompt-building, grounding, or SQL here — that lives in ``healthee.insights``.
Each surface caches per day, so a second same-day call returns the cached text
without a second LLM generation.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends

from healthee.core.auth import require_token
from healthee.insights import surfaces
from healthee.insights.notable import notable

router = APIRouter(tags=["insights"], dependencies=[Depends(require_token)])


@router.get("/api/sleep/insight")
def get_sleep_insight(refresh: bool = False) -> dict:
    """Grounded analysis of recent sleep (cached per day)."""
    return surfaces.sleep_insight(refresh=refresh)


@router.get("/api/activity/insight")
def get_activity_insight(refresh: bool = False) -> dict:
    """Grounded activity/fitness coaching (cached per day)."""
    return surfaces.activity_insight(refresh=refresh)


@router.get("/api/metric/insight")
def get_metric_insight(metric: str, label: str = "", refresh: bool = False) -> dict:
    """Grounded per-metric interpretation; empty text when data is too thin."""
    return surfaces.metric_insight(metric, label, refresh=refresh)


@router.get("/api/activity/workout/insight")
def get_workout_insight(start: str, refresh: bool = False) -> dict:
    """Grounded coach review of one workout (cached per workout)."""
    return surfaces.workout_insight(start, refresh=refresh)


@router.get("/api/notable")
def get_notable(refresh: bool = False) -> dict:
    """Notable shifts across daily metrics, each with a grounded meaning (cached/day)."""
    return notable(refresh=refresh)
