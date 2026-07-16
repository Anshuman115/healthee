"""Ingest HTTP layer — POST /ingest/helio (Bearer-auth).

Thin by design (standards §2): authorize → validated pydantic body → one domain
call → typed response. No SQL and no business logic here; all of that is in
`healthee.ingest`.
"""

from __future__ import annotations

from fastapi import APIRouter

from healthee.core.request_auth import IngestUser
from healthee.ingest import HelioPayload, IngestSummary, ingest_helio

router = APIRouter(tags=["ingest"])


@router.post("/ingest/helio", response_model=IngestSummary)
def post_helio(user: IngestUser, payload: HelioPayload) -> IngestSummary:
    """Ingest a full push from the mobile app (samples + sleep + workouts +
    daily totals + profile) and return the applied counts.

    The push is attributed to the device token's owner (MULTI_USER.md §7) — every
    row it writes, raw through derived, is written under ``user.id`` in ``user``'s
    local day.
    """
    return ingest_helio(payload, user.id, user.timezone)
