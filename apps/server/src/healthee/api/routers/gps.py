"""Phone-recorded GPS tracks — POST /api/workout/gps, GET /api/workout/gps,
GET /api/workout/gps/{track_id} (Bearer-auth). Thin over the GPS read service."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from healthee.core.db import transaction
from healthee.core.request_auth import CurrentUser
from healthee.read.gps import GpsTrackIn, gps_detail, ingest_gps_track, list_gps_tracks

router = APIRouter(tags=["gps"])


@router.post("/api/workout/gps")
def post_gps_track(user: CurrentUser, req: GpsTrackIn) -> dict:
    """Store an outdoor-workout GPS track and run its submaximal VO2max."""
    with transaction() as cur:
        return ingest_gps_track(cur, user.id, user.timezone, req)


@router.get("/api/workout/gps")
def get_gps_tracks(user: CurrentUser, limit: int = 30) -> dict:
    """Recent phone-recorded outdoor workouts (lightweight summary)."""
    with transaction() as cur:
        return list_gps_tracks(cur, user.id, limit)


@router.get("/api/workout/gps/{track_id}")
def get_gps_track(user: CurrentUser, track_id: str) -> dict:
    """Full GPS track for the route-map view (per-point + summary).

    A track owned by someone else is 404, not 403: the owner filter is inside
    ``gps_detail``, so another tenant's id simply does not resolve — the endpoint
    cannot confirm the track exists at all (MULTI_USER.md §10).
    """
    with transaction() as cur:
        detail = gps_detail(cur, user.id, track_id)
    if not detail:
        raise HTTPException(status_code=404, detail="track not found")
    return detail
