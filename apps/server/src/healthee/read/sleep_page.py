"""The Sleep page (``/api/sleep``) and per-night score list (``/api/sleep/health_score``).

v2-native: main sleep sessions from ``sleep_session`` (typed stage minutes + the
``stages`` hypnogram), derived per-night metrics from ``derived_daily``, and sleep-
window physiology averaged over the ``sample`` table. Naps are the sessions the
strap tagged ``kind='nap'`` — no time-of-day heuristic.
"""

from __future__ import annotations

from uuid import UUID

from healthee.core.tenancy import USER_TODAY_SQL
from healthee.derive._common import Cur
from healthee.read.findings import sleep_findings
from healthee.read.sleep_common import (
    SLEEP_CUTOFFS,
    SLEEP_RESEARCH_NOTES,
    derived_night_pivot,
    main_sessions,
    stage_timeline,
    stage_totals,
)


def _clamp_days(days: int) -> int:
    """Bound the requested window to [1, 365] nights."""
    return max(1, min(int(days), 365))


# Metrics feeding the per-night derived pivot on the full Sleep page.
_SLEEP_PAGE_METRICS = (
    "sleep_health_score_4dim",
    "sleep_dim_duration",
    "sleep_dim_efficiency",
    "sleep_dim_timing",
    "sleep_dim_regularity",
    "sleep_regularity_index",
    "hrv_sleep_avg",
    "rhr_daily",
)
# Health-score list uses only the score + dims + SRI (legacy shape has no HRV/RHR).
_HEALTH_SCORE_METRICS = (
    "sleep_health_score_4dim",
    "sleep_dim_duration",
    "sleep_dim_efficiency",
    "sleep_dim_timing",
    "sleep_dim_regularity",
    "sleep_regularity_index",
)
_HEALTH_SCORE_FIELDS = (
    "score",
    "point_duration",
    "point_efficiency",
    "point_timing",
    "point_regularity",
    "tst_min",
    "tib_min",
    "efficiency_pct",
    "midpoint_local",
    "sri",
    "session_source",
)


def sleep_health_score(cur: Cur, user_id: UUID, tz: str, days: int = 30) -> dict:
    """Per-night 4-dim score + per-dimension raw measurements (``/api/sleep/health_score``)."""
    days = _clamp_days(days)
    pivot = derived_night_pivot(cur, user_id, tz, days, _HEALTH_SCORE_METRICS)
    nights = [
        {"date": d, **{k: row.get(k) for k in _HEALTH_SCORE_FIELDS}} for d, row in pivot.items()
    ]
    nights.sort(key=lambda r: r["date"], reverse=True)
    return {"nights": nights, "cutoffs": SLEEP_CUTOFFS, "research_notes": SLEEP_RESEARCH_NOTES}


def sleep_page(cur: Cur, user_id: UUID, tz: str, days: int = 30) -> dict:
    """Everything the Sleep page needs in one call (``/api/sleep``)."""
    days = _clamp_days(days)
    nights = _session_nights(cur, user_id, tz, days)
    pivot = derived_night_pivot(cur, user_id, tz, days, _SLEEP_PAGE_METRICS)
    for date_iso, derived in pivot.items():
        nights.setdefault(date_iso, _stub_night(date_iso)).update(
            {k: v for k, v in derived.items() if k in _DERIVED_NIGHT_FIELDS}
        )
    _apply_physiology(cur, user_id, tz, days, nights)
    nights_list = sorted(nights.values(), key=lambda r: r["date"], reverse=True)
    return {
        "nights": nights_list,
        "naps": _naps(cur, user_id, tz, days),
        "cutoffs": SLEEP_CUTOFFS,
        "findings": sleep_findings(cur, user_id),
        "research_notes": SLEEP_RESEARCH_NOTES,
    }


_DERIVED_NIGHT_FIELDS = (
    "score",
    "point_duration",
    "point_efficiency",
    "point_timing",
    "point_regularity",
    "sri",
    "hrv_sleep_avg",
    "rhr",
    "tst_min",
    "tib_min",
    "efficiency_pct",
    "midpoint_local",
)


def _session_nights(cur: Cur, user_id: UUID, tz: str, days: int) -> dict[str, dict]:
    """One main session per wake-date → the session half of each night's payload."""
    out: dict[str, dict] = {}
    for local_date, start_ts, end_ts, light, deep, rem, wake, score, stages in main_sessions(
        cur, user_id, tz, days
    ):
        date_iso = local_date.isoformat()
        night = _stub_night(date_iso)
        night.update(
            {
                "session_source": "zepp_cloud",
                "start_iso": start_ts.isoformat(),
                "end_iso": end_ts.isoformat(),
                "duration_min": (light or 0)
                + (deep or 0)
                + (rem or 0),  # TST (v2: no summary blob)
                "zepp_score": score,
                "stages": stage_totals(light, deep, rem, wake),
                "stage_timeline": stage_timeline(stages, start_ts),
            }
        )
        out[date_iso] = night
    return out


def _stub_night(date_iso: str) -> dict:
    """A night payload with every field defaulted (session + derived + physiology)."""
    return {
        "date": date_iso,
        "session_source": None,
        "start_iso": None,
        "end_iso": None,
        "duration_min": None,
        "zepp_score": None,
        "stages": {"light": 0, "deep": 0, "rem": 0, "awake": 0},
        "stage_timeline": [],
        "score": None,
        "point_duration": None,
        "point_efficiency": None,
        "point_timing": None,
        "point_regularity": None,
        "tst_min": None,
        "tib_min": None,
        "efficiency_pct": None,
        "midpoint_local": None,
        "sri": None,
        "hrv_sleep_avg": None,
        "rhr": None,
        "spo2_avg": None,
        "spo2_min": None,
        "respiratory_rate": None,
        "skin_temp_c": None,
    }


def _apply_physiology(cur: Cur, user_id: UUID, tz: str, days: int, nights: dict[str, dict]) -> None:
    """Average SpO2 / breathing / skin-temp inside each main-session window (v2 raw
    ``sample`` metrics: spo2, respiratory_rate, skin_temp_c)."""
    for local_date, start_ts, end_ts, *_rest in main_sessions(cur, user_id, tz, days):
        row = nights.get(local_date.isoformat())
        if row is None:
            continue
        cur.execute(
            "SELECT ROUND(AVG(CASE WHEN metric='spo2' THEN value END)::numeric,1), "
            "  MIN(CASE WHEN metric='spo2' THEN value END), "
            "  ROUND(AVG(CASE WHEN metric='respiratory_rate' THEN value END)::numeric,1), "
            "  ROUND(AVG(CASE WHEN metric='skin_temp_c' AND value>25 THEN value END)::numeric,1) "
            "FROM sample WHERE user_id = %s AND ts >= %s AND ts < %s",
            (user_id, start_ts, end_ts),
        )
        spo2_avg, spo2_min, resp, temp = cur.fetchone() or (None, None, None, None)
        row["spo2_avg"] = float(spo2_avg) if spo2_avg is not None else None
        row["spo2_min"] = int(spo2_min) if spo2_min is not None else None
        row["respiratory_rate"] = float(resp) if resp is not None else None
        row["skin_temp_c"] = float(temp) if temp is not None else None


def _naps(cur: Cur, user_id: UUID, tz: str, days: int) -> list[dict]:
    """Sessions the strap tagged ``kind='nap'`` (>=5 min), newest first."""
    cur.execute(
        "SELECT start_ts, end_ts, (start_ts AT TIME ZONE %s)::date, "
        "  EXTRACT(EPOCH FROM (end_ts - start_ts))::int / 60, "
        "  TO_CHAR((start_ts + (end_ts - start_ts)/2) AT TIME ZONE %s, 'HH24:MI'), "
        "  stages "
        "FROM sleep_session WHERE user_id = %s AND kind='nap' "
        # `start_ts` is timestamptz: comparing it to a DATE would make Postgres cast
        # that date at the SESSION's timezone (UTC), reintroducing the very bug this
        # anchor fixes. So the owner's window-start date is turned into an absolute
        # instant IN THEIR ZONE — `::timestamp` makes it their local midnight, and
        # `AT TIME ZONE %s` binds that wall-clock time back to a real instant.
        f"  AND start_ts > (({USER_TODAY_SQL} - %s::int)::timestamp AT TIME ZONE %s) "
        "  AND EXTRACT(EPOCH FROM (end_ts - start_ts)) / 60 >= 5 "
        "ORDER BY start_ts DESC",
        (tz, tz, user_id, tz, days, tz),
    )
    return [
        {
            "start_iso": start_ts.isoformat(),
            "end_iso": end_ts.isoformat(),
            "source": "zepp_cloud",
            "date": local_date.isoformat(),
            "duration_min": int(dur),
            "midpoint_local": mid,
            "stages": stages or [],
        }
        for start_ts, end_ts, local_date, dur, mid, stages in cur.fetchall()
    ]
