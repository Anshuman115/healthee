"""Liveness/readiness probe — GET /healthz (no auth).

Reports whether the app is up AND its database is reachable. The deploy
healthcheck needs the DB signal, so an unreachable DB returns 503 (not a 200
with a sad body) — that is what makes the container roll back on a bad DB.
"""

from __future__ import annotations

from fastapi import APIRouter, Response, status
from pydantic import BaseModel

from healthee.core.db import transaction
from healthee.core.logging import get_logger

log = get_logger(__name__)

router = APIRouter(tags=["health"])


class HealthStatus(BaseModel):
    """Health probe body: overall status plus the DB check result."""

    status: str
    db: str


def _db_ok() -> bool:
    """Return True if a trivial query succeeds on a pooled connection.

    Any failure is logged (this is a health surface — never a silent swallow)
    and reported as a down DB.
    """
    try:
        with transaction() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
    except Exception as exc:  # health probe reports failure, never raises out
        log.warning("healthz db check failed: %s", exc)
        return False
    return True


@router.get("/healthz", response_model=HealthStatus)
def healthz(response: Response) -> HealthStatus:
    """Return 200 when the app and DB are healthy, 503 when the DB is down."""
    if _db_ok():
        return HealthStatus(status="ok", db="ok")
    response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return HealthStatus(status="degraded", db="fail")
