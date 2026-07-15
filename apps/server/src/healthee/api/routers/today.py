"""Today snapshot — GET /api/today (Bearer-auth).

Thin (standards §2): authorize → one cursor → the read service → the payload. The
response is a large nested aggregate whose shape is pinned by the contract
snapshot test rather than a pydantic model (a 25-key nested model would be more
brittle than the golden snapshot it duplicates)."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from healthee.core.auth import require_token
from healthee.core.db import transaction
from healthee.read.today import today_snapshot

router = APIRouter(tags=["today"], dependencies=[Depends(require_token)])


@router.get("/api/today")
def get_today() -> dict:
    """Aggregated snapshot for the Today page."""
    with transaction() as cur:
        return today_snapshot(cur)
