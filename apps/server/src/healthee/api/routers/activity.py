"""Activity tab — GET /api/activity (Bearer-auth). Thin router over the read service.

``day=YYYY-MM-DD`` answers for that day (``docs/AS_OF_DAY.md``); absent, for the owner's
today.
"""

from __future__ import annotations

from fastapi import APIRouter

from healthee.api.validation import require_reference_day
from healthee.core.db import tenant_transaction
from healthee.core.request_auth import CurrentUser
from healthee.read.activity import activity_snapshot

router = APIRouter(tags=["activity"])


@router.get("/api/activity")
def get_activity(user: CurrentUser, day: str | None = None) -> dict:
    """Cardiorespiratory fitness + weekly inputs + training-load + workouts, as of a day."""
    as_of = require_reference_day(day, user.timezone)
    with tenant_transaction(user.id) as cur:
        return activity_snapshot(cur, user.id, user.timezone, as_of)
