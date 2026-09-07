"""Sleep reads — GET /api/sleep, /api/sleep/health_score, /api/sleep/consistency.

Thin routers over the sleep read services. The consistency endpoint returns the
metric/data content only; its LLM ``action`` / ``tonight`` / ``coach`` fields are
WP5 (insights) and are added there, not here.

``tonight`` is the one LLM-authored field on an otherwise free surface, so it is
OMITTED for a non-premium owner exactly as ``/api/today``'s ``action`` is (``api.gate``,
MULTI_USER.md §12.7). ``PRICING.md`` §1a never names this line — it lists only the daily
action — which is a gap in the doc rather than a second product: both come from
``insights.coaching.warm_lines`` and carry one entitlement.
"""

from __future__ import annotations

from fastapi import APIRouter

from healthee.api.gate import DAILY_ACTION, SLEEP_CONSISTENCY_AI_FIELDS, gate_free_payload
from healthee.api.validation import require_reference_day
from healthee.core.db import tenant_transaction
from healthee.core.request_auth import CurrentUser
from healthee.insights import coaching
from healthee.read.sleep_extras import sleep_consistency
from healthee.read.sleep_page import sleep_health_score, sleep_page

router = APIRouter(tags=["sleep"])


@router.get("/api/sleep")
def get_sleep(user: CurrentUser, days: int = 30, day: str | None = None) -> dict:
    """Everything the Sleep page needs (nights + naps + findings + cutoffs), as of a day.

    ``days`` is the window's LENGTH and ``day`` is where it ends, so the two compose:
    ``days=30&day=2026-07-29`` is the thirty nights up to and including 29 July.
    """
    as_of = require_reference_day(day, user.timezone)
    with tenant_transaction(user.id) as cur:
        return sleep_page(cur, user.id, user.timezone, days, as_of)


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
    return gate_free_payload(user, payload, SLEEP_CONSISTENCY_AI_FIELDS, DAILY_ACTION)
