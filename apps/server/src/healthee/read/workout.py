"""Per-workout detail (``/api/activity/workout``): the minute-resolution HR profile
+ HR-zone minutes + derived metrics (intensity %HRmax, pace, cal/min, session
TRIMP, HR drift). v2-native: the workout row from ``workout``, the HR profile from
the raw ``sample`` table. The session-TRIMP formula ports VERBATIM (Banister).
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from fastapi import HTTPException

from healthee.derive._common import Cur
from healthee.derive.trimp import trimp_total
from healthee.read.common import sport_name
from healthee.read.fitness import cardio_load_payload, vo2max_payload


def workout_detail(cur: Cur, user_id: UUID, tz: str, start: str) -> dict:
    """Workout summary + HR series + zones + derived metrics for one session."""
    ts = _parse_start(start)
    cur.execute(
        "SELECT start_ts, sport, duration_s, calories, distance_m, avg_hr, max_hr, min_hr "
        "FROM workout WHERE user_id = %s AND start_ts >= %s - interval '3 seconds' "
        "AND start_ts <= %s + interval '3 seconds' ORDER BY start_ts LIMIT 1",
        (user_id, ts, ts),
    )
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="workout not found")
    start_ts, sport, dur_s, cal, dist, avg_hr, max_hr, min_hr = row
    end_ts = start_ts + timedelta(seconds=int(dur_s or 0))
    hrs, series = _hr_profile(cur, user_id, tz, start_ts, end_ts)
    hrmax = (cardio_load_payload(cur, user_id, tz) or {}).get("hrmax")
    rhr = (cardio_load_payload(cur, user_id, tz) or {}).get("rhr")
    sex = (vo2max_payload(cur, user_id, tz) or {}).get("sex") or "male"
    zones = _zone_minutes(hrs, hrmax)
    dur_min = round((dur_s or 0) / 60) if dur_s else None
    metrics = _metrics(avg_hr, max_hr, dist, dur_min, cal, hrmax, rhr, sex, hrs, zones)
    return {
        "workout": _workout_block(start_ts, sport, dur_min, cal, dist, avg_hr, max_hr, min_hr),
        "hr_series": series,
        "zones": zones,
        "hrmax": hrmax,
        "metrics": metrics,
    }


def _parse_start(start: str) -> datetime:
    """Accept an ISO timestamp or an epoch-ms string for the workout start."""
    try:
        return datetime.fromisoformat(start)
    except ValueError:
        return datetime.fromtimestamp(int(start) / 1000, tz=UTC)


def _hr_profile(
    cur: Cur, user_id: UUID, tz: str, start_ts: datetime, end_ts: datetime
) -> tuple[list[int], list[dict]]:
    """Minute-resolution HR series over the workout window (raw ``sample`` table)."""
    cur.execute(
        "SELECT ts, value FROM sample WHERE user_id = %s AND metric='hr' "
        "AND value > 30 AND value < 220 AND ts >= %s AND ts <= %s ORDER BY ts",
        (user_id, start_ts, end_ts),
    )
    hrs, series = [], []
    for t, v in cur.fetchall():
        hr = int(v)
        hrs.append(hr)
        off = int((t - start_ts).total_seconds() // 60)
        series.append({"min": off, "hr": hr, "t": t.astimezone(ZoneInfo(tz)).strftime("%H:%M")})
    return hrs, series


def _zone_minutes(hrs: list[int], hrmax: float | None) -> list[int]:
    """Five HR-zone minute buckets (50-60% … 90-100% HRmax)."""
    zones = [0, 0, 0, 0, 0]
    if not hrmax:
        return zones
    for hr in hrs:
        pct = hr / hrmax
        if pct < 0.5:
            continue
        zi = 0 if pct < 0.6 else 1 if pct < 0.7 else 2 if pct < 0.8 else 3 if pct < 0.9 else 4
        zones[zi] += 1
    return zones


def _metrics(avg_hr, max_hr, dist, dur_min, cal, hrmax, rhr, sex, hrs, zones) -> dict:
    """Derived workout metrics (intensity, pace, cal/min, TRIMP, drift, zone)."""
    m: dict = {}
    if avg_hr and hrmax:
        m["avg_pct_hrmax"] = round(100 * avg_hr / hrmax)
        p = avg_hr / hrmax
        m["intensity"] = (
            "Light"
            if p < 0.6
            else "Moderate"
            if p < 0.7
            else "Vigorous"
            if p < 0.8
            else "Hard"
            if p < 0.9
            else "Max"
        )
    if max_hr and hrmax:
        m["max_pct_hrmax"] = round(100 * max_hr / hrmax)
    if dist and dist > 50 and dur_min:
        m["pace_min_per_km"] = round(dur_min / (dist / 1000), 2)
        m["speed_kmh"] = round((dist / 1000) / (dur_min / 60), 1)
    if cal and dur_min:
        m["cal_per_min"] = round(cal / dur_min, 1)
    if hrmax and rhr and hrmax > rhr and hrs:
        m["trimp"] = _session_trimp(hrs, hrmax, rhr, sex)
    if len(hrs) >= 6:
        h = len(hrs) // 2
        m["hr_drift_bpm"] = round(sum(hrs[h:]) / (len(hrs) - h) - sum(hrs[:h]) / h)
    if any(zones):
        m["dominant_zone"] = zones.index(max(zones)) + 1
    return m


def _session_trimp(hrs: list[int], hrmax: float, rhr: float, sex: str) -> float:
    """Banister session TRIMP over the HR samples — the ONE definition, from ``derive/trimp``.

    This used to be a second, hand-rolled copy of the formula with its own coefficient
    table and NO upper clamp on ΔHR, so the same athlete-minute scored differently here
    than in the daily ``cardio_load``. [[training_stress_score]].
    """
    return round(trimp_total(hrs, rhr, hrmax, sex), 1)


def _workout_block(start_ts, sport, dur_min, cal, dist, avg_hr, max_hr, min_hr) -> dict:
    return {
        "start_iso": start_ts.isoformat(),
        "sport": sport,
        "sport_name": sport_name(sport),
        "duration_min": dur_min,
        "calories": int(cal) if cal is not None else None,
        "distance_m": float(dist) if dist is not None else None,
        "avg_hr": int(avg_hr) if avg_hr is not None else None,
        "max_hr": int(max_hr) if max_hr is not None else None,
        "min_hr": int(min_hr) if min_hr is not None else None,
    }
