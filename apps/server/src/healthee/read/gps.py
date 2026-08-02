"""Phone-recorded GPS tracks — ingest + list + route-map detail.

Wraps the v2 science (``derive.gps_scoring.score_track`` /
``derive.gps_detail.gps_track_detail``, ported verbatim in WP2). The ingest path stores
the track and its points, then hands the scoring to ``derive``. All within the caller's
transaction.

Scoring used to LIVE here — this module ran the estimator and denormalised the summary,
and it was the only caller either had. That made an upload the one moment a session could
ever be scored, which is the moment the strap's HR for it is least likely to have synced
(#111: 8 production tracks, zero estimates). Both now live in
``derive/gps_scoring.py``, called from ``derive_day`` as well as from here.
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel

from healthee.derive._common import Cur
from healthee.derive.gps_detail import gps_track_detail
from healthee.derive.gps_scoring import score_track


class GpsTrackIn(BaseModel):
    """POST body: a session window + compact points ``[epoch_s, lat, lng, ele_m|null]``."""

    start_iso: str
    end_iso: str
    points: list[list[float | None]]


def ingest_gps_track(cur: Cur, user_id: UUID, tz: str, req: GpsTrackIn) -> dict:
    """Store a track + its points under ``user_id`` and score it straight away.

    The immediate score is for the response — a run recorded after the strap synced
    should return its number now, not on the next push. It is no longer the ONLY
    scoring: ``derive_day`` picks up whatever this attempt had to refuse (#111).
    """
    pts = [
        p
        for p in req.points
        if len(p) >= 3 and p[0] is not None and p[1] is not None and p[2] is not None
    ]
    if len(pts) < 10:
        return {"ok": False, "reason": f"too few valid points ({len(pts)})"}
    cur.execute(
        "INSERT INTO gps_track (user_id, start_ts, end_ts, source) "
        "VALUES (%s, %s, %s, 'phone') RETURNING id",
        (user_id, datetime.fromisoformat(req.start_iso), datetime.fromisoformat(req.end_iso)),
    )
    inserted = cur.fetchone()
    if inserted is None:  # RETURNING always yields a row; guard for the type-checker
        return {"ok": False, "reason": "track insert failed"}
    track_id = inserted[0]
    cur.executemany(
        "INSERT INTO gps_point (user_id, track_id, ts, lat, lng, ele_m) "
        "VALUES (%s, %s, to_timestamp(%s), %s, %s, %s) ON CONFLICT DO NOTHING",
        [(user_id, track_id, p[0], p[1], p[2], (p[3] if len(p) > 3 else None)) for p in pts],
    )
    vo2 = score_track(cur, user_id, tz, track_id)
    return {"ok": True, "track_id": str(track_id), "points": len(pts), "vo2max": vo2}


def list_gps_tracks(cur: Cur, user_id: UUID, limit: int = 30) -> dict:
    """Recent phone-recorded outdoor workouts (lightweight summary) for the list."""
    cur.execute(
        "SELECT id, start_ts, end_ts, distance_m, duration_s, avg_hr, ele_gain_m, "
        "vo2max_submax, r2 FROM gps_track WHERE user_id = %s "
        "ORDER BY start_ts DESC LIMIT %s",
        (user_id, max(1, min(limit, 100))),
    )
    tracks = [
        {
            "track_id": str(r[0]),
            "start_ts": r[1].isoformat(),
            "end_ts": r[2].isoformat(),
            "distance_km": round(r[3] / 1000.0, 2) if r[3] is not None else None,
            "duration_s": r[4],
            "avg_hr": r[5],
            "ele_gain_m": r[6],
            "vo2max_submax": r[7],
            "r2": r[8],
        }
        for r in cur.fetchall()
    ]
    return {"tracks": tracks}


def gps_detail(cur: Cur, user_id: UUID, track_id: str) -> dict | None:
    """Full GPS track for the route-map view (per-point + summary). None if missing."""
    return gps_track_detail(cur, user_id, track_id)
