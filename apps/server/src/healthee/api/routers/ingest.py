"""Ingest HTTP layer — POST /ingest/helio (Bearer-auth).

Thin by design (standards §2): authorize → validated pydantic body → one domain
call → typed response. No SQL and no business logic here; all of that is in
`healthee.ingest`.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends

from healthee.core.auth import require_token
from healthee.ingest import HelioPayload, IngestSummary, ingest_helio

router = APIRouter(tags=["ingest"])


@router.post(
    "/ingest/helio",
    response_model=IngestSummary,
    dependencies=[Depends(require_token)],
)
def post_helio(payload: HelioPayload) -> IngestSummary:
    """Ingest a full push from the mobile app (samples + sleep + workouts +
    daily totals + profile) and return the applied counts."""
    return ingest_helio(payload)
