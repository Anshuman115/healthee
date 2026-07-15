"""Manual logging — POST /api/log, GET /api/log/recent (Bearer-auth).

Thin: the POST body is a pydantic ``LogRequest``; both handlers open one
transaction and call the read service (writes go to ``manual_entry`` / ``weight_log``).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends

from healthee.core.auth import require_token
from healthee.core.db import transaction
from healthee.read.logs import LogRequest, log_recent, record_log

router = APIRouter(tags=["logs"], dependencies=[Depends(require_token)])


@router.post("/api/log")
def post_log(req: LogRequest) -> dict:
    """Record a manual log (caffeine/alcohol/meditation/exercise/weight/fasting…)."""
    with transaction() as cur:
        return record_log(cur, req)


@router.get("/api/log/recent")
def get_log_recent(days: int = 7) -> dict:
    """Recent manual logs + current fasting status."""
    with transaction() as cur:
        return log_recent(cur, days)
