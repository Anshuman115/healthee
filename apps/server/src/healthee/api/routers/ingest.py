"""Ingest HTTP layer — POST /ingest/helio (Bearer-auth).

Thin by design (standards §2): authorize → validated pydantic body → one domain
call → typed response. No SQL and no business logic here; all of that is in
`healthee.ingest`.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends

from healthee.core.auth import require_token
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.ingest import HelioPayload, IngestSummary, ingest_helio

router = APIRouter(tags=["ingest"])


@router.post(
    "/ingest/helio",
    response_model=IngestSummary,
    dependencies=[Depends(require_token)],
)
def post_helio(payload: HelioPayload) -> IngestSummary:
    """Ingest a full push from the mobile app (samples + sleep + workouts +
    daily totals + profile) and return the applied counts.

    TODO(6.4): attribute the push to the device token's owner
    (`resolve_device_token` → user UUID) instead of the sentinel; the shared-token
    `require_token` dep carries no identity (MULTI_USER.md §7).
    """
    return ingest_helio(payload, SENTINEL_USER_ID, SENTINEL_TZ)
