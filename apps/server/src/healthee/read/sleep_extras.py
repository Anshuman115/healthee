"""Today-page sleep blocks + sleep regularity (``/api/sleep/consistency`` core).

``last_sleep`` / ``last_sleep_extras`` / ``sleep_history_7d`` / ``sleep_health_today``
feed ``/api/today``; ``sleep_consistency`` feeds the consistency endpoint (its LLM
"action"/"tonight"/"coach" fields are WP5 and added there, not here). v2-native:
``sleep_session`` typed columns + hypnogram, ``derived_daily``, raw ``sample``.
"""

from __future__ import annotations

import statistics
from datetime import datetime

from healthee.derive._common import Cur
from healthee.read.sleep_common import (
    SLEEP_CUTOFFS,
    SLEEP_RESEARCH_NOTES,
    stage_timeline,
    stage_totals,
)


def latest_main_session(cur: Cur) -> tuple | None:
    """The most recent main sleep session (raw sleep_session row) or None."""
    cur.execute(
        "SELECT start_ts, end_ts, light_min, deep_min, rem_min, wake_min, score, stages "
        "FROM sleep_session WHERE kind='main' ORDER BY start_ts DESC LIMIT 1",
    )
    return cur.fetchone()


def last_sleep(session: tuple | None) -> dict | None:
    """The Today ``last_sleep`` block from a main-session row (stages + totals)."""
    if session is None:
        return None
    start_ts, end_ts, light, deep, rem, wake, score, stages = session
    return {
        "start_iso": start_ts.isoformat(),
        "end_iso": end_ts.isoformat(),
        "duration_min": (light or 0) + (deep or 0) + (rem or 0),  # TST (v2: no summary blob)
        "score": score,
        "avg_hr": None,  # v2 avg_hr lives on the session row; see last_sleep_extras
        "totals": stage_totals(light, deep, rem, wake),
        "stages": stage_timeline(stages, start_ts),
    }


def last_sleep_extras(cur: Cur, start_ts: datetime, end_ts: datetime) -> dict:
    """SpO2 / breathing / skin-temp / HRV averaged across the last-sleep window."""
    cur.execute(
        "SELECT ROUND(AVG(CASE WHEN metric='spo2' THEN value END))::int, "
        "  MIN(CASE WHEN metric='spo2' THEN value END)::int, "
        "  ROUND(AVG(CASE WHEN metric='respiratory_rate' THEN value END))::int, "
        "  ROUND(AVG(CASE WHEN metric='skin_temp_c' THEN value END)::numeric, 1), "
        "  ROUND(AVG(CASE WHEN metric='hrv' THEN value END))::int "
        "FROM sample WHERE ts >= %s AND ts < %s",
        (start_ts, end_ts),
    )
    spo2_avg, spo2_min, resp, temp, hrv = cur.fetchone() or (None, None, None, None, None)
    return {
        "spo2_avg": int(spo2_avg) if spo2_avg is not None else None,
        "spo2_min": int(spo2_min) if spo2_min is not None else None,
        "respiratory_rate": int(resp) if resp is not None else None,
        "skin_temp_c": float(temp) if temp is not None else None,
        "hrv_rmssd_ms": int(hrv) if hrv is not None else None,
    }


def sleep_history_7d(cur: Cur) -> list[dict]:
    """Last 7 nights of main sleep for the mini history bar."""
    cur.execute(
        "SELECT DISTINCT ON ((end_ts AT TIME ZONE 'Asia/Kolkata')::date) "
        "  (end_ts AT TIME ZONE 'Asia/Kolkata')::date, "
        "  light_min, deep_min, rem_min, wake_min, score "
        "FROM sleep_session WHERE kind='main' "
        "  AND (end_ts AT TIME ZONE 'Asia/Kolkata')::date > (current_date - 8) "
        "ORDER BY (end_ts AT TIME ZONE 'Asia/Kolkata')::date, (end_ts - start_ts) DESC",
    )
    rows = cur.fetchall()
    rows.sort(key=lambda r: r[0])
    return [
        {
            "date": d.isoformat(),
            "duration_min": (light or 0) + (deep or 0) + (rem or 0),
            "score": score,
            "light": light or 0,
            "deep": deep or 0,
            "rem": rem or 0,
            "awake": wake or 0,
        }
        for d, light, deep, rem, wake, score in rows
    ]


def sleep_health_today(cur: Cur) -> dict | None:
    """Latest 4-dim sleep-health score + per-dimension breakdown for Today."""
    cur.execute(
        "SELECT day, metric, value, flags FROM derived_daily "
        "WHERE metric IN ('sleep_health_score_4dim','sleep_dim_duration','sleep_dim_efficiency',"
        "  'sleep_dim_timing','sleep_dim_regularity','sleep_regularity_index') "
        "ORDER BY day DESC LIMIT 100",
    )
    rows = cur.fetchall()
    if not rows:
        return None
    latest_day = rows[0][0]
    out = _blank_health_today(latest_day.isoformat())
    for d, metric, value, flags in rows:
        if d != latest_day:
            continue
        _fold_health_today(out, metric, float(value), flags or {})
    return out if out["score"] is not None else None


def _blank_health_today(date_iso: str) -> dict:
    return {
        "date": date_iso,
        "score": None,
        "max_score": 4,
        "point_duration": None,
        "point_efficiency": None,
        "point_timing": None,
        "point_regularity": None,
        "tst_min": None,
        "tib_min": None,
        "efficiency_pct": None,
        "midpoint_local": None,
        "sri": None,
        "session_source": None,
        "research_notes": SLEEP_RESEARCH_NOTES,
        "cutoffs": SLEEP_CUTOFFS,
    }


_POINT_FIELDS = {
    "sleep_dim_duration": "point_duration",
    "sleep_dim_efficiency": "point_efficiency",
    "sleep_dim_timing": "point_timing",
    "sleep_dim_regularity": "point_regularity",
}


def _fold_health_today(out: dict, metric: str, value: float, flags: dict) -> None:
    if metric == "sleep_health_score_4dim":
        out["score"] = int(value)
    elif metric in _POINT_FIELDS:
        out[_POINT_FIELDS[metric]] = int(value)
    elif metric == "sleep_regularity_index":
        out["sri"] = round(value, 1)
    for k in ("tst_min", "tib_min", "efficiency_pct", "midpoint_local", "session_source"):
        if out[k] is None and flags.get(k) is not None:
            out[k] = flags.get(k)
    if out["sri"] is None and flags.get("sri") is not None:
        out["sri"] = round(float(flags["sri"]), 1)


def _clk(total_min: float) -> str:
    """Minutes-past-midnight → HH:MM clock string (mod 24h)."""
    t = round(total_min) % 1440
    return f"{t // 60:02d}:{t % 60:02d}"


def _pct(xs: list[int], p: float) -> int:
    sx = sorted(xs)
    return sx[round((len(sx) - 1) * p)]


def sleep_consistency(cur: Cur, days: int = 28) -> dict:
    """Bedtime/wake REGULARITY over the last ``days`` nights (main sleep only):
    median bedtime, onset/wake spread vs the ~1-hour target, and the odd nights
    SURFACED (not hidden). [[sleep_regularity_index]], [[sleep_timing_chronotype]]."""
    days = max(7, min(int(days or 28), 90))
    cur.execute(
        "SELECT (start_ts AT TIME ZONE 'Asia/Kolkata')::date, "
        "  start_ts AT TIME ZONE 'Asia/Kolkata', end_ts AT TIME ZONE 'Asia/Kolkata' "
        "FROM sleep_session WHERE kind='main' AND start_ts >= now() - (%s || ' days')::interval "
        "ORDER BY start_ts",
        (days,),
    )
    rows = cur.fetchall()
    if len(rows) < 3:
        return {"days": days, "nights": len(rows), "note": "not enough nights to assess"}
    # onset anchored at 18:00 (minutes past 6 PM) so evening→morning doesn't wrap.
    onset = [((s.hour * 60 + s.minute) - 1080) % 1440 for _, s, _ in rows]
    wake = [(e.hour * 60 + e.minute) for _, _, e in rows]
    return _consistency_payload(cur, days, rows, onset, wake)


def _consistency_payload(
    cur: Cur, days: int, rows: list, onset: list[int], wake: list[int]
) -> dict:
    """Assemble the regularity numbers + surfaced odd nights + SRI (verbatim math)."""
    med_on = statistics.median(onset)
    on_band_h = (_pct(onset, 0.9) - _pct(onset, 0.1)) / 60.0
    irregular = []
    for (d, _s, _e), o in zip(rows, onset, strict=True):
        delta = (o - med_on) / 60.0
        if abs(delta) > 2:
            irregular.append(
                {"date": d.isoformat(), "bedtime": _clk(1080 + o), "delta_h": round(delta, 1)}
            )
    irregular.sort(key=lambda x: -abs(x["delta_h"]))
    cur.execute(
        "SELECT value FROM derived_daily WHERE metric='sleep_regularity_index' "
        "ORDER BY day DESC LIMIT 1",
    )
    r = cur.fetchone()
    sri = round(float(r[0]), 1) if r else None
    median_bed_min = (1080 + round(med_on)) % 1440
    band = (
        "tight — top-quintile territory (~1 h band)"
        if on_band_h <= 1.5
        else "moderate — pull it under ~1 h"
        if on_band_h <= 2.5
        else "loose (~3 h+) — your biggest lever"
    )
    return {
        "days": days,
        "nights": len(rows),
        "median_bedtime": _clk(1080 + med_on),
        "mean_wake": _clk(statistics.mean(wake)),
        "onset_sd_min": round(statistics.pstdev(onset), 1),
        "onset_band_h": round(on_band_h, 1),
        "onset_range_h_raw": round((max(onset) - min(onset)) / 60.0, 1),
        "wake_sd_min": round(statistics.pstdev(wake), 1),
        "sri": sri,
        "late": median_bed_min < 360,
        "onset_band": band,
        "irregular_nights": irregular[:6],
        "irregular_count": len(irregular),
        "target": "keep sleep & wake within a ~1-hour band, weekends included",
    }
