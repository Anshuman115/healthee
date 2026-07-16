"""Phone-recorded GPS tracks — POST /api/workout/gps, GET /api/workout/gps,
GET /api/workout/gps/{track_id} (Bearer-auth). Thin over the GPS read service."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from healthee.core.auth import require_token
from healthee.core.db import transaction
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.read.gps import GpsTrackIn, gps_detail, ingest_gps_track, list_gps_tracks

router = APIRouter(tags=["gps"], dependencies=[Depends(require_token)])


@router.post("/api/workout/gps")
def post_gps_track(req: GpsTrackIn) -> dict:
    """Store an outdoor-workout GPS track and run its submaximal VO2max.

    TODO(6.4): write under the authenticated `RequestUser.id`, not the sentinel.
    """
    with transaction() as cur:
        return ingest_gps_track(cur, SENTINEL_USER_ID, req)


@router.get("/api/workout/gps")
def get_gps_tracks(limit: int = 30) -> dict:
    """Recent phone-recorded outdoor workouts (lightweight summary)."""
    with transaction() as cur:
        return list_gps_tracks(cur, limit)


@router.get("/api/workout/gps/{track_id}")
def get_gps_track(track_id: str) -> dict:
    """Full GPS track for the route-map view (per-point + summary)."""
    with transaction() as cur:
        detail = gps_detail(cur, track_id)
    if not detail:
        raise HTTPException(status_code=404, detail="track not found")
    return detail
