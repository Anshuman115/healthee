"""The route-map read for one recorded outdoor workout — per-point detail + summary.

Split out of ``derive/gps.py`` when the second VO2max estimator (#114) pushed that file
past the 400-line limit. It was the right seam anyway, and the old module docstring said
so out loud: "session-measured VO2max + full route detail for the map view" is two
reasons to change in one file. What lives here answers "what did this route look like";
what stays in ``gps.py`` answers "what does this session say about the owner's fitness".

Ported verbatim from legacy v2 ``gps_track_detail`` — the SQL, math and rounding are
unchanged, and this split moved the code without editing it. The track loaders and the
HR interpolator stay in ``gps.py`` because the derivation owns them; they are imported
here under their existing names rather than renamed, matching how ``gps.py`` already
imports ``_haversine_m`` from the science module. Knowledge: [[grade_adjusted_pace]],
[[submaximal_vo2max]], [[hr_reserve_vo2max]].
"""

from __future__ import annotations

from collections.abc import Callable
from uuid import UUID

from healthee.derive._common import Cur
from healthee.derive.dem import elevations
from healthee.derive.gps import (
    METHOD_GRADED,
    Point,
    _load_hr,
    _load_points,
    _track_window,
    make_hr_interpolator,
)
from healthee.derive.vo2max_submax import _haversine_m

_MOVING_MIN_DIST_M = 0.3  # >~0.3 m between fixes counts as moving
_MIN_PACE_SPEED_MS = 0.3  # below this, no per-segment pace
_MIN_PACE_DIST_KM = 0.05  # need >50 m total before an average pace is meaningful


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
    """Read back the stored VO2max_submax result for this track, if any.

    ``r2`` and ``hr_range`` are null on a reserve-derived row because that method has
    no regression — an absent diagnostic, not a zero. ``method`` says which instrument
    read the session; rows written before #114 have no flag and are all graded fits.
    """
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
        "method": f.get("method", METHOD_GRADED),
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
        # How many of those fixes got a heart rate off the interpolator. The app states
        # this number in words — "This route has N matched heart-rate points. A fitness
        # estimate is withheld until coverage is sufficient." — and used to COUNT IT
        # ITSELF off the points array. That was correct only while the array was the
        # whole track; `read/gps.py` now thins it for the map, so the count has to come
        # from the side that still sees every fix. It is a fact about the recording, not
        # about the response, and it belongs beside `n_points` for the same reason.
        "n_hr_points": len(hrs),
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
