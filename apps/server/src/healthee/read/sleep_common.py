"""Shared sleep read-helpers: stage-code names, score cutoffs/notes, the
main-session-per-wake-date selection, the stage timeline, and the derived
per-night pivot. v2-native: reads ``sleep_session`` (typed stage-minute columns +
the ``stages`` hypnogram JSONB) and ``derived_daily`` — never the v1 ``session``
view or a ``source=`` filter.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import LiteralString, cast
from uuid import UUID

from healthee.core.tenancy import AS_OF_DAY_SQL
from healthee.derive._common import Cur

# Hypnogram stage-type codes → name (ZeppOS 0x48 blob; derive uses 7=awake).
STAGE_NAME = {4: "light", 5: "deep", 7: "awake", 8: "rem"}

# 4-dim score cutoffs + the sleep research notes — identical across sleep reads.
SLEEP_CUTOFFS = {
    "duration_hours": [7.0, 9.0],
    "efficiency_min": 0.85,
    "timing_hour_band": [2, 4],
    "sri_min": 70.0,
}
SLEEP_RESEARCH_NOTES = [
    "sleep_score_implementation_plan",
    "sleep_health_score_multidim",
    "sleep_duration_mortality",
    "sleep_regularity_index",
]

# derived_daily metric → the per-night payload field it fills (0/1 point rows).
_POINT_METRICS = {
    "sleep_dim_duration": "point_duration",
    "sleep_dim_efficiency": "point_efficiency",
    "sleep_dim_timing": "point_timing",
    "sleep_dim_regularity": "point_regularity",
}
_FLAG_FIELDS = ("tst_min", "tib_min", "efficiency_pct", "midpoint_local", "session_source")


def stage_timeline(stages: list | None, start_ts: datetime) -> list[dict]:
    """Stage segments relative to the session start (v2 ``[[startMs, endMs, type]]``
    hypnogram → the frontend's {stage, duration_min, start/end offset} shape)."""
    start_ms = int(start_ts.timestamp() * 1000)
    out: list[dict] = []
    for st in stages or []:
        if len(st) < 3:
            continue
        s_start, s_end, code = st[0], st[1], st[2]
        out.append(
            {
                "stage": STAGE_NAME.get(code, f"unknown:{code}"),
                "duration_min": (s_end - s_start) / 60000,
                "start_offset_min": (s_start - start_ms) / 60000,
                "end_offset_min": (s_end - start_ms) / 60000,
            }
        )
    return out


def stage_totals(light: int | None, deep: int | None, rem: int | None, wake: int | None) -> dict:
    """Per-stage total minutes (typed sleep_session columns)."""
    return {"light": light or 0, "deep": deep or 0, "rem": rem or 0, "awake": wake or 0}


def main_sessions(cur: Cur, user_id: UUID, tz: str, days: int, on_or_before: date) -> list[tuple]:
    """One main sleep session per local wake-date over the window ENDING at
    ``on_or_before``, newest first. The main sleep is the LONGEST session of the
    wake-date (keeps a short daytime session from ever being picked as the night)."""
    # The local wake-date is computed ONCE in a subquery: with server-side binding
    # each `AT TIME ZONE %s` is a DISTINCT parameter, so repeating the expression
    # would make DISTINCT ON and ORDER BY non-matching expressions (a hard error)
    # even though the bound values are equal.
    cur.execute(
        "SELECT DISTINCT ON (local_date) local_date, "
        "  start_ts, end_ts, light_min, deep_min, rem_min, wake_min, score, stages "
        "FROM ("
        "  SELECT (end_ts AT TIME ZONE %s)::date AS local_date, start_ts, end_ts, "
        "    light_min, deep_min, rem_min, wake_min, score, stages "
        "  FROM sleep_session WHERE user_id = %s AND kind='main'"
        ") s "
        f"WHERE local_date > ({AS_OF_DAY_SQL} - %s::int) AND local_date <= {AS_OF_DAY_SQL} "
        "ORDER BY local_date, (end_ts - start_ts) DESC",
        (tz, user_id, on_or_before, days, on_or_before),
    )
    return cur.fetchall()


def derived_night_pivot(
    cur: Cur,
    user_id: UUID,
    days: int,
    metrics: tuple[str, ...],
    on_or_before: date,
) -> dict[str, dict]:
    """Pivot the derived per-night rows (score, dims, SRI, HRV, RHR) into
    {date_iso: {field: value}} for the requested metric set, over the window
    ENDING at ``on_or_before``."""
    # `placeholders` is only "%s, %s, …" (count of the metrics tuple) — never
    # caller data — so interpolating it into the IN-list is injection-safe.
    placeholders = ", ".join(["%s"] * len(metrics))
    cur.execute(
        cast(
            LiteralString,
            "SELECT day, metric, value, flags FROM derived_daily "
            f"WHERE user_id = %s AND metric IN ({placeholders}) "
            f"AND day > ({AS_OF_DAY_SQL} - %s::int) AND day <= {AS_OF_DAY_SQL}",
        ),
        (user_id, *metrics, on_or_before, days, on_or_before),
    )
    out: dict[str, dict] = {}
    for day, metric, value, flags in cur.fetchall():
        row = out.setdefault(day.isoformat(), _blank_derived())
        _apply_derived(row, metric, float(value), flags or {})
    return out


def _blank_derived() -> dict:
    return {
        "score": None,
        "point_duration": None,
        "point_efficiency": None,
        "point_timing": None,
        "point_regularity": None,
        "sri": None,
        "hrv_sleep_avg": None,
        "rhr": None,
        "tst_min": None,
        "tib_min": None,
        "efficiency_pct": None,
        "midpoint_local": None,
        "session_source": None,
    }


def _apply_derived(row: dict, metric: str, value: float, flags: dict) -> None:
    """Fold one derived row into the per-night dict (metric → field + flag ride-along)."""
    if metric == "sleep_health_score_4dim":
        row["score"] = int(value)
    elif metric in _POINT_METRICS:
        row[_POINT_METRICS[metric]] = int(value)
    elif metric == "sleep_regularity_index":
        row["sri"] = round(value, 1)
    elif metric == "hrv_sleep_avg":
        row["hrv_sleep_avg"] = round(value, 1)
    elif metric == "rhr_daily":
        row["rhr"] = round(value, 1)
    for k in _FLAG_FIELDS:
        if row.get(k) is None and flags.get(k) is not None:
            row[k] = flags.get(k)
    if row.get("sri") is None and flags.get("sri") is not None:
        row["sri"] = round(float(flags["sri"]), 1)
