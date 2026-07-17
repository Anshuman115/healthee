"""GPS-track derivations: submaximal VO2max + full route detail for the map view.

Both read a recorded outdoor workout (gps_track + gps_point) plus the strap HR over
the same window, replace the phone's barometer-less GPS elevation with a terrain DEM
(dem.py), and interpolate the sparse strap HR (~1/min) across the track. Ported
verbatim from legacy v2 ``derive_vo2max_submax`` and ``gps_track_detail`` — the SQL,
math, and rounding are unchanged; the duplicated HR-interpolation closure is now the
shared ``make_hr_interpolator`` and each function is split into small helpers for the
size gate. Knowledge: [[submaximal_vo2max]], [[grade_adjusted_pace]].

``vo2max_submax`` is stored DELIBERATELY SEPARATE from the live Jurca
``vo2max_estimate`` so estimates can accumulate for validation before any swap.
"""

from __future__ import annotations

import bisect
from collections.abc import Callable
from datetime import datetime
from uuid import UUID
from zoneinfo import ZoneInfo

from healthee.derive._common import Cur, _age, _load_profile, _upsert_daily
from healthee.derive.dem import elevations
from healthee.derive.vo2max_submax import _haversine_m, vo2max_from_track

Point = tuple[float, float, float, float | None]  # (ts_epoch_s, lat, lng, ele_m|None)

_HR_INTERP_EDGE_S = 120  # accept an edge HR sample within 2 min of the query time
_HR_INTERP_GAP_S = 180  # a gap >3 min between HR samples is too large to interpolate
_MIN_HR_SAMPLES_VO2 = 5  # need >=5 HR samples over the window to attempt VO2max
_MOVING_MIN_DIST_M = 0.3  # >~0.3 m between fixes counts as moving
_MIN_PACE_SPEED_MS = 0.3  # below this, no per-segment pace
_MIN_PACE_DIST_KM = 0.05  # need >50 m total before an average pace is meaningful


def make_hr_interpolator(
    hr_ts: list[float], hr_val: list[float]
) -> Callable[[float], float | None]:
    """Build a HR(t) lookup that linearly interpolates between sparse strap samples.

    Returns None outside a 2-min edge tolerance or across a >3-min sample gap, so a
    missing HR stays distinct from an interpolated one.
    """

    def hr_at(t: float) -> float | None:
        if not hr_ts:
            return None
        i = bisect.bisect_left(hr_ts, t)
        if i == 0:
            return hr_val[0] if abs(hr_ts[0] - t) <= _HR_INTERP_EDGE_S else None
        if i >= len(hr_ts):
            return hr_val[-1] if abs(hr_ts[-1] - t) <= _HR_INTERP_EDGE_S else None
        t0, t1 = hr_ts[i - 1], hr_ts[i]
        if t1 - t0 > _HR_INTERP_GAP_S:
            return None
        f = (t - t0) / (t1 - t0)
        return hr_val[i - 1] + f * (hr_val[i] - hr_val[i - 1])

    return hr_at


def _track_window(cur: Cur, user_id: UUID, track_id: str) -> tuple[datetime, datetime] | None:
    """(start_ts, end_ts) for one owner's track, or None if it does not exist."""
    cur.execute(
        "SELECT start_ts, end_ts FROM gps_track WHERE user_id = %s AND id=%s",
        (user_id, track_id),
    )
    tr = cur.fetchone()
    return (tr[0], tr[1]) if tr else None


def _load_points(cur: Cur, user_id: UUID, track_id: str) -> list[Point]:
    """All fixes for a track, time-ordered, as (ts_epoch_s, lat, lng, ele|None)."""
    cur.execute(
        "SELECT extract(epoch FROM ts), lat, lng, ele_m FROM gps_point "
        "WHERE user_id = %s AND track_id=%s ORDER BY ts",
        (user_id, track_id),
    )
    return [
        (float(r[0]), float(r[1]), float(r[2]), float(r[3]) if r[3] is not None else None)
        for r in cur.fetchall()
    ]


def _load_hr(
    cur: Cur, user_id: UUID, start_ts: datetime, end_ts: datetime
) -> tuple[list[float], list[float]]:
    """(timestamps, values) for bounded HR samples across the track window."""
    cur.execute(
        "SELECT extract(epoch FROM ts), value FROM sample "
        "WHERE user_id = %s AND metric='hr' AND value BETWEEN 30 AND 220 "
        "AND ts BETWEEN %s AND %s ORDER BY ts",
        (user_id, start_ts, end_ts),
    )
    rows = cur.fetchall()
    return [float(r[0]) for r in rows], [float(r[1]) for r in rows]


def _dem_corrected(points: list[Point]) -> tuple[list[Point], str, int]:
    """Replace GPS elevation with DEM terrain elevation (per-point GPS fallback).

    Returns (points, grade_source, dem_hits): grade_source is "dem" when the DEM
    covered most points, else "gps_elevation".
    """
    dem, dem_hits = elevations([(p[1], p[2]) for p in points])
    corrected: list[Point] = [
        (p[0], p[1], p[2], (dem[i] if dem[i] is not None else p[3])) for i, p in enumerate(points)
    ]
    grade_source = "dem" if dem_hits > len(points) // 2 else "gps_elevation"
    return corrected, grade_source, dem_hits


def derive_vo2max_submax(cur: Cur, user_id: UUID, tz: str, track_id: str) -> dict:
    """Submaximal HR-vs-pace VO2max for one GPS track; stored as ``vo2max_submax``.

    Returns {"ok": True, ...} with the estimate + fit diagnostics, or {"ok": False,
    "reason": ...} when the track/HR/profile are missing or the fit is unusable.
    [[submaximal_vo2max]].
    """
    window = _track_window(cur, user_id, track_id)
    if not window:
        return {"ok": False, "reason": "track not found"}
    start_ts, end_ts = window
    points = _load_points(cur, user_id, track_id)
    if len(points) < 10:
        return {"ok": False, "reason": "too few GPS points"}
    points, grade_source, dem_hits = _dem_corrected(points)
    hr_ts, hr_val = _load_hr(cur, user_id, start_ts, end_ts)
    if len(hr_ts) < _MIN_HR_SAMPLES_VO2:
        return {"ok": False, "reason": "no HR for this window (was the strap worn?)"}
    day = start_ts.astimezone(ZoneInfo(tz)).date()
    prof = _load_profile(cur, user_id, tz, day)
    if not prof:
        return {"ok": False, "reason": "no profile"}
    hrmax = 208 - 0.7 * _age(prof["dob"], day)  # Tanaka 2001
    res, status = vo2max_from_track(points, make_hr_interpolator(hr_ts, hr_val), hrmax)
    if not res:
        return {"ok": False, "reason": status}
    _upsert_daily(
        cur,
        user_id,
        day,
        "vo2max_submax",
        res.vo2max,
        {
            "method": "submaximal_gps",
            "r2": res.r2,
            "n_windows": res.n_windows,
            "hr_range": res.hr_range,
            "speed_kmh": res.speed_kmh_mean,
            "hrmax_tanaka": round(hrmax, 1),
            "track_id": str(track_id),
            "grade_source": grade_source,
            "dem_hits": dem_hits,
        },
    )
    return {
        "ok": True,
        "vo2max_submax": res.vo2max,
        "r2": res.r2,
        "n_windows": res.n_windows,
        "hr_range": res.hr_range,
        "speed_kmh": res.speed_kmh_mean,
        "grade_source": grade_source,
    }


def _build_detail_points(
    pts: list[Point], ele: list[float | None], hr_at: Callable[[float], float | None]
) -> tuple[list[dict], float, float, float, float, list[float], list[float]]:
    """Per-point rows + running totals (distance, gain, loss, moving_s, HRs, eles)."""
    out: list[dict] = []
    dist_m = gain = loss = moving_s = 0.0
    hrs: list[float] = []
    eles: list[float] = []
    prev: Point | None = None
    prev_e: float | None = None
    for i, p in enumerate(pts):
        h = hr_at(p[0])
        e = ele[i]
        seg_pace = None  # min/km for this segment
        if prev is not None:
            d = _haversine_m(prev[1], prev[2], p[1], p[2])
            dt = p[0] - prev[0]
            dist_m += d
            if dt > 0 and d > _MOVING_MIN_DIST_M:  # moving
                moving_s += dt
                spd = d / dt  # m/s
                if spd > _MIN_PACE_SPEED_MS:
                    seg_pace = round((1000.0 / spd) / 60.0, 2)
        if prev_e is not None and e is not None:
            de = e - prev_e
            gain += de if de > 0 else 0.0
            loss += -de if de < 0 else 0.0
        out.append(
            {
                "t": round(p[0]),
                "lat": round(p[1], 6),
                "lng": round(p[2], 6),
                "ele": round(e, 1) if e is not None else None,
                "hr": round(h) if h is not None else None,
                "pace": seg_pace,
            }
        )
        if h is not None:
            hrs.append(h)
        if e is not None:
            eles.append(e)
        prev = p
        prev_e = e
    return out, dist_m, gain, loss, moving_s, hrs, eles


def _read_submax(cur: Cur, user_id: UUID, track_id: str) -> dict | None:
    """Read back the stored VO2max_submax result for this track, if any."""
    cur.execute(
        "SELECT value, flags FROM derived_daily "
        "WHERE user_id = %s AND metric='vo2max_submax' "
        "AND flags->>'track_id'=%s ORDER BY day DESC LIMIT 1",
        (user_id, str(track_id)),
    )
    vr = cur.fetchone()
    if not vr:
        return None
    f = vr[1] or {}
    return {
        "vo2max": vr[0],
        "r2": f.get("r2"),
        "n_windows": f.get("n_windows"),
        "hr_range": f.get("hr_range"),
        "speed_kmh": f.get("speed_kmh"),
        "grade_source": f.get("grade_source"),
    }


def _detail_summary(
    pts: list[Point],
    out: list[dict],
    dist_m: float,
    gain: float,
    loss: float,
    moving_s: float,
    hrs: list[float],
    eles: list[float],
    vo2: dict | None,
) -> dict:
    """Assemble the track summary block (distances, pace, HR, elevation, VO2max)."""
    dur_s = pts[-1][0] - pts[0][0]
    dist_km = dist_m / 1000.0
    avg_pace = (
        round((moving_s / 60.0) / dist_km, 2)
        if dist_km > _MIN_PACE_DIST_KM and moving_s > 0
        else None
    )
    return {
        "distance_km": round(dist_km, 2),
        "duration_s": int(dur_s),
        "moving_s": int(moving_s),
        "avg_pace_min_km": avg_pace,
        "avg_hr": round(sum(hrs) / len(hrs)) if hrs else None,
        "max_hr": round(max(hrs)) if hrs else None,
        "ele_gain_m": round(gain),
        "ele_loss_m": round(loss),
        "ele_min": round(min(eles)) if eles else None,
        "ele_max": round(max(eles)) if eles else None,
        "n_points": len(out),
        "vo2max": vo2,
    }


def gps_track_detail(cur: Cur, user_id: UUID, track_id: str) -> dict | None:
    """Full detail for one recorded outdoor workout — for the route-map view.

    Per-point [t, lat, lng, DEM-corrected ele, interpolated hr, pace] plus a
    summary (distance, moving time, pace, HR, elevation gain/loss, and the stored
    vo2max_submax). None if the track or its points are missing. Pure read.
    """
    window = _track_window(cur, user_id, track_id)
    if not window:
        return None
    start_ts, end_ts = window
    pts = _load_points(cur, user_id, track_id)
    if len(pts) < 2:
        return None
    dem, _ = elevations([(p[1], p[2]) for p in pts])
    ele = [dem[i] if dem[i] is not None else pts[i][3] for i in range(len(pts))]
    hr_at = make_hr_interpolator(*_load_hr(cur, user_id, start_ts, end_ts))
    out, dist_m, gain, loss, moving_s, hrs, eles = _build_detail_points(pts, ele, hr_at)
    vo2 = _read_submax(cur, user_id, track_id)
    return {
        "track_id": str(track_id),
        "start_ts": start_ts.isoformat(),
        "end_ts": end_ts.isoformat(),
        "points": out,
        "summary": _detail_summary(pts, out, dist_m, gain, loss, moving_s, hrs, eles, vo2),
    }
