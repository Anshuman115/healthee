"""Today snapshot — GET /api/today (Bearer-auth).

Thin (standards §2): authorize → one cursor → the read service → the payload. The
response is a large nested aggregate whose shape is pinned by the contract
snapshot test rather than a pydantic model (a 25-key nested model would be more
brittle than the golden snapshot it duplicates)."""

from __future__ import annotations

from fastapi import APIRouter

from healthee.core.db import transaction
from healthee.core.request_auth import CurrentUser
from healthee.insights import coaching
from healthee.read.today import today_snapshot

router = APIRouter(tags=["today"])


@router.get("/api/today")
def get_today(user: CurrentUser) -> dict:
    """Aggregated snapshot for the Today page + the grounded daily action line.

    The ``action`` is the WP5 coaching one-liner: read-only from the per-day cache
    (``None`` until the scheduler warms it), so this read path never calls the LLM.
    """
    with transaction() as cur:
        payload = today_snapshot(cur, user.id, user.timezone)
    payload["action"] = coaching.cached_line(user.id, user.timezone, coaching.DAILY_ACTION_KEY)
    return payload
