"""The Sleep page (``/api/sleep``) and per-night score list (``/api/sleep/health_score``).

v2-native: main sleep sessions from ``sleep_session`` (typed stage minutes + the
``stages`` hypnogram), derived per-night metrics from ``derived_daily``, and sleep-
window physiology averaged over the ``sample`` table. Naps are the sessions the
strap tagged ``kind='nap'`` — no time-of-day heuristic.
"""

from __future__ import annotations

from datetime import date
from uuid import UUID

from healthee.core.tenancy import AS_OF_DAY_SQL, reference_day
from healthee.derive._common import Cur
from healthee.read.common import as_of_block
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


def sleep_health_score(
    cur: Cur, user_id: UUID, tz: str, days: int = 30, day: date | None = None
) -> dict:
    """Per-night 4-dim score + per-dimension raw measurements (``/api/sleep/health_score``)."""
    days = _clamp_days(days)
    pivot = derived_night_pivot(cur, user_id, days, _HEALTH_SCORE_METRICS, reference_day(day, tz))
    nights = [
        {"date": d, **{k: row.get(k) for k in _HEALTH_SCORE_FIELDS}} for d, row in pivot.items()
    ]
    nights.sort(key=lambda r: r["date"], reverse=True)
    return {"nights": nights, "cutoffs": SLEEP_CUTOFFS, "research_notes": SLEEP_RESEARCH_NOTES}


def sleep_page(cur: Cur, user_id: UUID, tz: str, days: int = 30, day: date | None = None) -> dict:
    """Everything the Sleep page needs in one call (``/api/sleep``), as of a day.

    The window is the ``days`` nights ENDING at ``day``, so a past-day answer is a
    shorter list of the same nights rather than the same list re-dated. Nothing here is
    interpolated: a night with no session and no derived row simply is not in ``nights``,
    exactly as it is not today.
    """
    days = _clamp_days(days)
    as_of = reference_day(day, tz)
    # Read the session list ONCE: `_session_nights` and `_apply_physiology` each used
    # to issue this same query with the same arguments.
    sessions = main_sessions(cur, user_id, tz, days, as_of)
    nights = _session_nights(sessions)
    pivot = derived_night_pivot(cur, user_id, days, _SLEEP_PAGE_METRICS, as_of)
    for date_iso, derived in pivot.items():
        nights.setdefault(date_iso, _stub_night(date_iso)).update(
            {k: v for k, v in derived.items() if k in _DERIVED_NIGHT_FIELDS}
        )
    _apply_physiology(cur, user_id, nights, sessions)
    nights_list = sorted(nights.values(), key=lambda r: r["date"], reverse=True)
    return {
        "date": as_of.isoformat(),
        "as_of": as_of_block(cur, user_id, tz, as_of),
        "nights": nights_list,
        "naps": _naps(cur, user_id, tz, days, as_of),
        "cutoffs": SLEEP_CUTOFFS,
        "findings": sleep_findings(cur, user_id, tz, day=as_of),
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


def _session_nights(sessions: list[tuple]) -> dict[str, dict]:
    """One main session per wake-date → the session half of each night's payload."""
    out: dict[str, dict] = {}
    for local_date, start_ts, end_ts, light, deep, rem, wake, score, stages in sessions:
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


def _apply_physiology(
    cur: Cur, user_id: UUID, nights: dict[str, dict], sessions: list[tuple]
) -> None:
    """Average SpO2 / breathing / skin-temp inside each main-session window (v2 raw
    ``sample`` metrics: spo2, respiratory_rate, skin_temp_c).

    ONE query for every night. This ran a query PER NIGHT, so `/api/sleep` issued
    `nights + 7` statements — 372 on a year of data, growing with the owner's history
    forever (standards §1: "bound the round-trips … no N+1"). Same batching idea as
    `latest_derived_many` / `derived_series_many` on the Today page.

    The windows ride in as three parallel arrays and `unnest` back into rows, so each
    night still aggregates over its OWN [start, end) — a LATERAL-free join that keeps
    the per-window index seeks. A night with no samples still yields a row of NULLs
    (LEFT JOIN), exactly as the per-night `fetchone()` did.
    """
    windows = [
        (local_date.isoformat(), start_ts, end_ts)
        for local_date, start_ts, end_ts, *_rest in sessions
        if local_date.isoformat() in nights
    ]
    if not windows:
        return
    dates, starts, ends = (list(col) for col in zip(*windows, strict=True))
    cur.execute(
        "SELECT w.date_iso, "
        "  ROUND(AVG(CASE WHEN s.metric='spo2' THEN s.value END)::numeric,1), "
        "  MIN(CASE WHEN s.metric='spo2' THEN s.value END), "
        "  ROUND(AVG(CASE WHEN s.metric='respiratory_rate' THEN s.value END)::numeric,1), "
        "  ROUND(AVG(CASE WHEN s.metric='skin_temp_c' AND s.value>25 THEN s.value END)::numeric,1) "
        "FROM unnest(%s::text[], %s::timestamptz[], %s::timestamptz[]) "
        "     AS w(date_iso, start_ts, end_ts) "
        "LEFT JOIN sample s ON s.user_id = %s "
        # The outer bound is implied by the per-window ones, so it removes no row —
        # it is there to give the hypertable a constant `ts` range to prune chunks on
        # (the note at the top of read/today_series.py documents the same trap).
        "  AND s.ts >= %s AND s.ts < %s "
        "  AND s.ts >= w.start_ts AND s.ts < w.end_ts "
        "GROUP BY w.date_iso",
        (dates, starts, ends, user_id, min(starts), max(ends)),
    )
    for date_iso, spo2_avg, spo2_min, resp, temp in cur.fetchall():
        row = nights[date_iso]
        row["spo2_avg"] = float(spo2_avg) if spo2_avg is not None else None
        row["spo2_min"] = int(spo2_min) if spo2_min is not None else None
        row["respiratory_rate"] = float(resp) if resp is not None else None
        row["skin_temp_c"] = float(temp) if temp is not None else None


def _naps(cur: Cur, user_id: UUID, tz: str, days: int, as_of: date) -> list[dict]:
    """Sessions the strap tagged ``kind='nap'`` (>=5 min) in the window, newest first.

    **A nap is shaped exactly like a night.** This used to select the ``stages`` JSONB
    and ship it under the key ``stages`` — but on a night that key holds the per-stage
    TOTALS (``stage_totals``) and the hypnogram travels separately as
    ``stage_timeline``. So the one field a nap stage-bar reads was a raw
    ``[[startMs, endMs, type]]`` array wearing the totals' name, and every nap breakdown
    in the app rendered blank whatever the strap had recorded. The typed minute columns
    were on the row the whole time and simply were not selected.

    Both halves ship now, from the same two helpers ``_session_nights`` uses, because a
    second shaping of one thing is how the two drift apart (standards §Duplication). A
    nap the strap staged only in summary keeps an empty ``stage_timeline`` — an honest
    empty, not a structural one.
    """
    cur.execute(
        "SELECT start_ts, end_ts, (start_ts AT TIME ZONE %s)::date, "
        "  EXTRACT(EPOCH FROM (end_ts - start_ts))::int / 60, "
        "  TO_CHAR((start_ts + (end_ts - start_ts)/2) AT TIME ZONE %s, 'HH24:MI'), "
        "  stages, light_min, deep_min, rem_min, wake_min "
        "FROM sleep_session WHERE user_id = %s AND kind='nap' "
        # `start_ts` is timestamptz: comparing it to a DATE would make Postgres cast
        # that date at the SESSION's timezone (UTC), reintroducing the very bug this
        # anchor fixes. So the owner's window-start date is turned into an absolute
        # instant IN THEIR ZONE — `::timestamp` makes it their local midnight, and
        # `AT TIME ZONE %s` binds that wall-clock time back to a real instant.
        f"  AND start_ts > (({AS_OF_DAY_SQL} - %s::int)::timestamp AT TIME ZONE %s) "
        # The closing edge, built the same way: the START of the day AFTER the reference
        # one, so a nap taken on that day is in and one taken the morning after is out.
        f"  AND start_ts < (({AS_OF_DAY_SQL} + 1)::timestamp AT TIME ZONE %s) "
        "  AND EXTRACT(EPOCH FROM (end_ts - start_ts)) / 60 >= 5 "
        "ORDER BY start_ts DESC",
        (tz, tz, user_id, as_of, days, tz, as_of, tz),
    )
    return [
        {
            "start_iso": start_ts.isoformat(),
            "end_iso": end_ts.isoformat(),
            "source": "zepp_cloud",
            "date": local_date.isoformat(),
            "duration_min": int(dur),
            "midpoint_local": mid,
            "stages": stage_totals(light, deep, rem, wake),
            "stage_timeline": stage_timeline(stages, start_ts),
        }
        for start_ts, end_ts, local_date, dur, mid, stages, light, deep, rem, wake in (
            cur.fetchall()
        )
    ]
