"""Shared read-layer primitives: the user timezone, daily-series helpers, and the
sport-code names. One definition, reused by every read service (standards
§Duplication).
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, datetime
from typing import LiteralString, cast
from zoneinfo import ZoneInfo

from healthee.analytics.baselines import Baseline, compute_baselines
from healthee.analytics.metrics import metric_filter
from healthee.derive._common import Cur

# Single-tenant timezone name, passed as a %s parameter to ``AT TIME ZONE`` so
# every day-bucketing query stays parameterized (never string-interpolated). Same
# constant the derive layer anchors daily metrics to (derive/_common USER_TZ).
USER_TZ_NAME = "Asia/Kolkata"
USER_TZ = ZoneInfo(USER_TZ_NAME)


def user_today() -> date:
    """Today's date in the user's timezone."""
    return datetime.now(tz=USER_TZ).date()


def derived_series(cur: Cur, metric: str, days: int) -> list[dict]:
    """Last ``days`` days of a ``derived_daily`` metric, oldest first, sentinel-
    filtered. Replaces the legacy ``_series_for_metric`` (which read the
    ``metric_sample`` view). The filter fragment is a hardcoded constant from the
    metric registry — safe to interpolate (standards §2)."""
    flt = metric_filter(metric)  # constant from METRIC_FILTERS — safe to interpolate
    cur.execute(
        cast(
            LiteralString,
            "SELECT day, value FROM derived_daily "
            f"WHERE metric = %s AND {flt} AND day > (current_date - %s::int) ORDER BY day",
        ),
        (metric, days),
    )
    return [{"date": r[0].isoformat(), "value": float(r[1])} for r in cur.fetchall()]


def latest_derived(cur: Cur, metric: str) -> tuple[date, float, dict] | None:
    """Most recent ``derived_daily`` row for a metric as (day, value, flags)."""
    cur.execute(
        "SELECT day, value, flags FROM derived_daily WHERE metric=%s ORDER BY day DESC LIMIT 1",
        (metric,),
    )
    row = cur.fetchone()
    if not row:
        return None
    return row[0], float(row[1]), (row[2] or {})


def latest_derived_many(cur: Cur, metrics: Sequence[str]) -> dict[str, tuple[date, float, dict]]:
    """Most recent ``derived_daily`` row for each metric in ONE ``DISTINCT ON`` query.

    Same shape and semantics as calling :func:`latest_derived` per metric (latest
    row wins, no sentinel filter), but collapses the N-metric fan-out to a single
    statement — the ``/api/today`` aggregator's latest-value loader. Metrics with no
    rows are simply absent from the result (mirroring ``latest_derived`` → None)."""
    out: dict[str, tuple[date, float, dict]] = {}
    wanted = list(dict.fromkeys(metrics))
    if not wanted:
        return out
    cur.execute(
        "SELECT DISTINCT ON (metric) metric, day, value, flags FROM derived_daily "
        "WHERE metric = ANY(%s) ORDER BY metric, day DESC",
        (wanted,),
    )
    for metric, day, value, flags in cur.fetchall():
        out[metric] = (day, float(value), (flags or {}))
    return out


def derived_series_many(cur: Cur, metrics: Sequence[str], days: int) -> dict[str, list[dict]]:
    """Last ``days`` days of several ``derived_daily`` metrics in ONE query.

    Batched form of :func:`derived_series` (same per-metric sentinel filter, same
    window, oldest-first) so the Today sparklines load in a single statement
    instead of one query per slot. Every requested metric gets a key (empty list
    when it has no rows)."""
    out: dict[str, list[dict]] = {m: [] for m in dict.fromkeys(metrics)}
    if not out:
        return out
    wanted = list(out)
    # Per-metric sentinel filter OR'd — each fragment is a METRIC_FILTERS constant.
    where = " OR ".join(f"(metric = %s AND {metric_filter(m)})" for m in wanted)
    cur.execute(
        cast(
            LiteralString,
            "SELECT metric, day, value FROM derived_daily "
            "WHERE day > (current_date - %s::int) AND (" + where + ") "
            "ORDER BY metric, day",
        ),
        (days, *wanted),
    )
    for metric, day, value in cur.fetchall():
        out[metric].append({"date": day.isoformat(), "value": float(value)})
    return out


@dataclass(frozen=True)
class TodayReads:
    """Per-request preloaded reads for the Today aggregator, so the per-metric card
    and recovery-signal payloads look values up instead of each issuing their own
    ``latest_derived`` + ``compute_baseline`` fan-out. ``None`` is never stored —
    an absent metric simply isn't a key."""

    latest: dict[str, tuple[date, float, dict]]
    baselines: dict[str, Baseline]


def build_today_reads(
    cur: Cur, latest_metrics: Sequence[str], baseline_metrics: Sequence[str]
) -> TodayReads:
    """Preload the Today latest-values (1 query) + 30-day baselines (1 query)."""
    return TodayReads(
        latest=latest_derived_many(cur, latest_metrics),
        baselines=compute_baselines(list(baseline_metrics), window_days=30),
    )


# Device sport codes (Zepp/Amazfit Huami) → display name. Ported verbatim from
# legacy ``_SPORT_NAMES``. Code 44 = the auto-detected generic "Activity" bout;
# unknown codes fall back to "Activity" (Zepp's generic label), not "Workout".
_SPORT_NAMES: dict[int, str] = {
    1: "Outdoor run", 2: "Walking", 3: "Outdoor cycling", 4: "Treadmill",
    6: "Indoor cycling", 7: "Open-water swim", 8: "Pool swim", 9: "Elliptical",
    10: "Climbing", 12: "Hiking", 14: "Strength", 15: "Rowing", 16: "Yoga",
    21: "HIIT", 22: "Core training", 23: "Stretching", 24: "Cardio",
    44: "Activity", 50: "Jump rope", 52: "Boxing", 60: "Free training",
    1000: "Outdoor run", 1001: "Walking",
}  # fmt: skip


def sport_name(code: int | None) -> str:
    """Display name for a device sport code (legacy ``_sport_name``)."""
    return _SPORT_NAMES.get(code, "Activity") if code is not None else "Activity"
