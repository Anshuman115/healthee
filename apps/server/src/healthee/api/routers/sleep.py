"""Sleep reads — GET /api/sleep, /api/sleep/health_score, /api/sleep/consistency.

Thin routers over the sleep read services. The consistency endpoint returns the
metric/data content only; its LLM ``action`` / ``tonight`` / ``coach`` fields are
WP5 (insights) and are added there, not here.
"""

from __future__ import annotations

from fastapi import APIRouter

from healthee.core.db import tenant_transaction
from healthee.core.request_auth import CurrentUser
from healthee.insights import coaching
from healthee.read.sleep_extras import sleep_consistency
from healthee.read.sleep_page import sleep_health_score, sleep_page

router = APIRouter(tags=["sleep"])


@router.get("/api/sleep")
def get_sleep(user: CurrentUser, days: int = 30) -> dict:
    """Everything the Sleep page needs (nights + naps + findings + cutoffs)."""
    with tenant_transaction(user.id) as cur:
        return sleep_page(cur, user.id, user.timezone, days)


@router.get("/api/sleep/health_score")
def get_sleep_health_score(user: CurrentUser, days: int = 30) -> dict:
    """Per-night 4-dim sleep-health score + per-dimension raw measurements."""
    with tenant_transaction(user.id) as cur:
        return sleep_health_score(cur, user.id, user.timezone, days)


@router.get("/api/sleep/consistency")
def get_sleep_consistency(user: CurrentUser, days: int = 28) -> dict:
    """Bedtime/wake regularity numbers + surfaced odd nights.

    The ``tonight`` field is the WP5 grounded coaching one-liner: read-only from the
    per-day cache (``None`` until warmed), so this read path never calls the LLM.
    """
    with tenant_transaction(user.id) as cur:
        payload = sleep_consistency(cur, user.id, user.timezone, days)
    payload["tonight"] = coaching.cached_line(user.id, user.timezone, coaching.SLEEP_TONIGHT_KEY)
    return payload
