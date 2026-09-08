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
from uuid import UUID, uuid4

from healthee.derive._common import Cur
from healthee.derive.gps_detail import gps_track_detail
from healthee.derive.gps_scoring import score_track
from healthee.read.gps_request import GpsTrackIn

# The most fixes the route-map read will SEND. 2,000, and it is the app's own number:
# `features/gps/route_map.dart::RouteMap.maxDrawnPoints` already thins to exactly this
# before drawing, with the argument written out there — a long run is tens of thousands
# of fixes and the box is a few hundred pixels wide, so most of them are sub-pixel. The
# client was therefore discarding ~26,800 of the 28,800 points it had just downloaded.
# Taking the app's constant rather than inventing a second one is the point: two numbers
# for "how many fixes can be drawn" would be two answers to one question, and the smaller
# would silently win.
MAX_MAP_POINTS = 2000


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
        "INSERT INTO gps_track (id, user_id, start_ts, end_ts, source) "
        "VALUES (%s, %s, %s, %s, 'phone') ON CONFLICT (id) DO NOTHING RETURNING id",
        (
            req.client_id or uuid4(),
            user_id,
            datetime.fromisoformat(req.start_iso),
            datetime.fromisoformat(req.end_iso),
        ),
    )
    inserted = cur.fetchone()
    if inserted is None:
        return _recorded_track(cur, user_id, req)
    track_id = inserted[0]
    cur.executemany(
        "INSERT INTO gps_point (user_id, track_id, ts, lat, lng, ele_m) "
        "VALUES (%s, %s, to_timestamp(%s), %s, %s, %s) ON CONFLICT DO NOTHING",
        [(user_id, track_id, p[0], p[1], p[2], (p[3] if len(p) > 3 else None)) for p in pts],
    )
    vo2 = score_track(cur, user_id, tz, track_id)
    return {"ok": True, "track_id": str(track_id), "points": len(pts), "vo2max": vo2}


def _recorded_track(cur: Cur, user_id: UUID, req: GpsTrackIn) -> dict:
    """An acknowledged retry never mutates the first stored recording."""
    cur.execute(
        "SELECT id FROM gps_track WHERE user_id = %s AND id = %s AND start_ts = %s AND end_ts = %s",
        (
            user_id,
            req.client_id,
            datetime.fromisoformat(req.start_iso),
            datetime.fromisoformat(req.end_iso),
        ),
    )
    row = cur.fetchone()
    if row is None:
        return {"ok": False, "reason": "recording identity conflict"}
    cur.execute(
        "SELECT count(*) FROM gps_point WHERE user_id = %s AND track_id = %s", (user_id, row[0])
    )
    count = cur.fetchone()
    return {"ok": True, "track_id": str(row[0]), "points": count[0] if count else 0, "vo2max": None}


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


def _thinned(points: list[dict]) -> list[dict]:
    """``points`` sampled down to :data:`MAX_MAP_POINTS`, BOTH ENDS retained.

    Identical rule to the app's ``RouteMap.displayPoints``, deliberately: this is the
    same decision, moved to the side of the wire where it saves the bytes. Every returned
    point is a real fix with its own measured elevation, interpolated HR and segment pace
    — nothing is averaged, interpolated or invented, so what the map draws is a SAMPLE of
    the recording rather than a smoothing of it.
    """
    if len(points) <= MAX_MAP_POINTS:
        return points
    last = len(points) - 1
    return [points[round(i * last / (MAX_MAP_POINTS - 1))] for i in range(MAX_MAP_POINTS)]


def gps_detail(cur: Cur, user_id: UUID, track_id: str) -> dict | None:
    """Full GPS track for the route-map view (per-point + summary). None if missing.

    ## The READ-SIDE bound the audit found missing (`PERF_AUDIT.md` B4)

    ``gps_track_detail`` returns every stored fix, and the only bound anywhere was at
    ingest: ``read/gps_request.py`` caps a submitted track at 28,800 points (8 h at
    1 Hz). Measured at that cap: **2,282,548 → 158,913 bytes, 14.4× smaller.** The audit
    called that byte figure SUSPECTED; it is now confirmed, and it is 2.2 MB down a phone
    connection for one screen.

    ⚠ **The LATENCY does not move, and the endpoint is still over its budget.** Measured
    p50 across calls 2-5 (the first is ~5.3 s, cold DEM): **144.9 ms → 148.5 ms**, which
    is the same number inside the noise. Serialising the array was never the cost — the
    cost is loading all 28,800 rows, looking up a DEM elevation for each, interpolating a
    heart rate onto each and walking the segments for pace, all of which happens before
    anything here can thin the result. So a maximal track still misses p95 < 100 ms.
    Moving the bound EARLIER, into ``_load_points``, would fix that and is deliberately
    not done: every summary figure is computed over the points that were loaded, so a
    strided load would silently change the distance, the moving time, the pace and the
    elevation gain this endpoint reports — a science change, which `CLAUDE.md` requires
    be its own PR with known-value tests.

    **The bound is applied HERE and not in ``gps_track_detail``, and that is load-bearing.**
    ``derive/gps_scoring.py`` calls that same function to score the session, and a
    submaximal VO2max fitted to one point in fourteen is a different measurement wearing
    the same name. The science reads every fix; the map reads a sample of them.

    **Every summary number stays computed over the WHOLE track** — distance, moving time,
    pace, HR, elevation gain and loss, and ``n_points``, which therefore keeps meaning
    *fixes recorded* and not *fixes returned*. ``points_returned`` and
    ``points_decimated`` say the difference out loud, the way
    ``correlations.MAX_REPORTED_PAIRS`` ships ``points_truncated`` beside a scatter that
    holds fewer points than its own ``n_samples``. That flag is not decoration: the app's
    route card prints "Phone GPS · N fixes", and a count taken from the returned array
    would report a 28,800-fix run as a 2,000-fix one — the recording misdescribed to the
    person who made it.
    """
    detail = gps_track_detail(cur, user_id, track_id)
    if detail is None:
        return None
    points = detail["points"]
    detail["points"] = _thinned(points)
    detail["summary"]["points_returned"] = len(detail["points"])
    detail["summary"]["points_decimated"] = len(detail["points"]) < len(points)
    return detail
