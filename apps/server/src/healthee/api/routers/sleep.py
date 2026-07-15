"""Sleep reads — GET /api/sleep, /api/sleep/health_score, /api/sleep/consistency.

Thin routers over the sleep read services. The consistency endpoint returns the
metric/data content only; its LLM ``action`` / ``tonight`` / ``coach`` fields are
WP5 (insights) and are added there, not here.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends

from healthee.core.auth import require_token
from healthee.core.db import transaction
from healthee.read.sleep_extras import sleep_consistency
from healthee.read.sleep_page import sleep_health_score, sleep_page

router = APIRouter(tags=["sleep"], dependencies=[Depends(require_token)])


@router.get("/api/sleep")
def get_sleep(days: int = 30) -> dict:
    """Everything the Sleep page needs (nights + naps + findings + cutoffs)."""
    with transaction() as cur:
        return sleep_page(cur, days)


@router.get("/api/sleep/health_score")
def get_sleep_health_score(days: int = 30) -> dict:
    """Per-night 4-dim sleep-health score + per-dimension raw measurements."""
    with transaction() as cur:
        return sleep_health_score(cur, days)


@router.get("/api/sleep/consistency")
def get_sleep_consistency(days: int = 28) -> dict:
    """Bedtime/wake regularity numbers + surfaced odd nights.

    WP5: the ``action`` / ``tonight`` / ``coach`` LLM fields are added by insights.
    """
    with transaction() as cur:
        return sleep_consistency(cur, days)
