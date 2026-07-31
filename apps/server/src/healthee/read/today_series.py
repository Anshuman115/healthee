"""Today-page series + cards: the secondary metric cards, the 14-day sparklines,
and today's intraday HR / step / stress shapes. v2-native: ``derived_daily`` for
day series/cards, the raw ``sample`` table for intraday, ``weight_log`` for weight.

Sparkline GAPs (keys kept for wire-compat, empty in v2): ``sleep_score`` (v2 uses
``sleep_health_score_4dim``), ``stress`` and ``pai_total`` (not derived in v2 —
analytics/metrics.py). Documented in the WP7 report.
"""

from __future__ import annotations

from uuid import UUID

from healthee.analytics.baselines import compute_baseline_cur
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur, _day_bounds_utc
from healthee.derive.hr_validity import HR_VALID_BOUNDS, HR_VALID_SQL
from healthee.read.common import TodayReads, derived_series_many, latest_derived
from healthee.read.meta import METRIC_META, TODAY_SECONDARY_METRICS

# Why every intraday query below carries `_day_bounds_utc`'s half-open `ts` range
# ALONGSIDE its `(ts AT TIME ZONE %s)::date = %s` filter: `sample` is a hypertable
# partitioned on `ts`, and a query with no `ts` predicate gets NO chunk exclusion —
# the tz-date expression is a Filter, never an Index Cond, so answering "today" opened
# every chunk of all history. Measured on a 1-year, 1.37 M-row table: 7,914 buffers /
# 53 chunks before, 17 buffers / 1 chunk after, and the old form was O(all history) —
# degrading forever against a p95 < 100 ms budget.
#
# The date filter STAYS. The range is implied by it, so it prunes chunks without
# changing a single row — that redundancy is the correctness argument, not an
# oversight, and `tests/read/test_day_window.py` proves the two agree instant for
# instant against Postgres' own `AT TIME ZONE`, DST transitions included.


def secondary_cards(
    cur: Cur, user_id: UUID, tz: str, reads: TodayReads | None = None
) -> list[dict]:
    """RHR / steps / calories / distance / weight cards — first candidate with data
    wins, each with its 30-day median + z-anomaly flag. ``reads`` (when supplied by
    the Today aggregator) serves latest-values + baselines from a single preloaded
    batch instead of a per-card query fan-out."""
    out: list[dict] = []
    for candidates in TODAY_SECONDARY_METRICS:
        card = _card_for(cur, user_id, tz, candidates, reads)
        if card:
            out.append(card)
    return out


def _card_for(
    cur: Cur, user_id: UUID, tz: str, candidates: list[str], reads: TodayReads | None
) -> dict | None:
    for cand in candidates:
        picked = (
            _weight_card(cur, user_id)
            if cand == "weight_kg"
            else _derived_card(cur, user_id, tz, cand, reads)
        )
        if picked:
            return picked
    return None


def _derived_card(
    cur: Cur, user_id: UUID, tz: str, metric: str, reads: TodayReads | None
) -> dict | None:
    latest = reads.latest.get(metric) if reads else latest_derived(cur, user_id, metric)
    if not latest:
        return None
    day, value, _flags = latest
    meta = METRIC_META[metric]
    # Preloaded baseline when the aggregator supplied one; else compute on demand —
    # on THIS cursor, so a card whose metric the aggregator forgot to preload costs an
    # extra query, never an extra pooled connection.
    baseline = (reads.baselines.get(metric) if reads else None) or compute_baseline_cur(
        cur, user_id, tz, metric, window_days=30
    )
    z = baseline.z_score(value)
    return {
        "metric": metric,
        "label": meta["label"],
        "value": value,
        "unit": meta["unit"],
        "median_30d": baseline.median,
        "z": z,
        "anomalous": z is not None and abs(z) >= 2,
    }


def _weight_card(cur: Cur, user_id: UUID) -> dict | None:
    """Weight is stored in ``weight_log`` (not derived_daily); no derived baseline."""
    cur.execute("SELECT kg FROM weight_log WHERE user_id = %s ORDER BY ts DESC LIMIT 1", (user_id,))
    r = cur.fetchone()
    if not r:
        return None
    meta = METRIC_META["weight_kg"]
    return {
        "metric": "weight_kg",
        "label": meta["label"],
        "value": float(r[0]),
        "unit": meta["unit"],
        "median_30d": None,
        "z": None,
        "anomalous": False,
    }


# Legacy sparkline slots → the v2 metric that backs each. ``None`` = a v2 GAP
# (key kept for wire-compat, empty series). See the module docstring.
_SPARKLINE_METRICS: dict[str, str | None] = {
    "rhr_daily": "rhr_daily",
    "sleep_score": None,
    "sleep_health_score_4dim": "sleep_health_score_4dim",
    "sleep_regularity_index": "sleep_regularity_index",
    "hrv_sleep_avg": "hrv_sleep_avg",
    "stress": None,
    "pai_total": None,
    "total_calories": "total_calories",
    "respiratory_rate_sleep": "respiratory_rate_sleep",
    "spo2_overnight": "spo2_overnight",
    "spo2_overnight_min": "spo2_overnight_min",
}


def sparklines(cur: Cur, user_id: UUID, tz: str) -> dict[str, list[dict]]:
    """14-day daily series per Today sparkline slot (empty for v2 gaps).

    All backed slots load in ONE batched query (``derived_series_many``) rather
    than a query per slot; the v2-gap slots (metric ``None``) stay empty."""
    backed = {key: m for key, m in _SPARKLINE_METRICS.items() if m}
    series = derived_series_many(cur, user_id, tz, list(backed.values()), 14)
    return {
        key: (series.get(metric, []) if metric else [])
        for key, metric in _SPARKLINE_METRICS.items()
    }


def hr_hourly(cur: Cur, user_id: UUID, tz: str) -> list[dict]:
    """Hourly avg/min/max HR for today (local) — today's heart-rate shape.

    Bounded by ``derive.hr_validity``, the one plausibility predicate every HR
    reader shares.
    """
    day = user_today(tz)
    ts_from, ts_to = _day_bounds_utc(day, tz)  # chunk pruning + the date filter; see above
    cur.execute(
        "SELECT date_trunc('hour', ts AT TIME ZONE %s) AS h, ROUND(AVG(value))::int, "
        "  MIN(value)::int, MAX(value)::int "
        f"FROM sample WHERE user_id = %s AND metric='hr' AND {HR_VALID_SQL} "
        "  AND ts >= %s AND ts < %s "
        "  AND (ts AT TIME ZONE %s)::date = %s GROUP BY 1 ORDER BY 1",
        (tz, user_id, *HR_VALID_BOUNDS, ts_from, ts_to, tz, day),
    )
    return [
        {"hour_iso": h.isoformat(), "hour": h.hour, "avg": avg, "min": mn, "max": mx}
        for h, avg, mn, mx in cur.fetchall()
    ]


def step_buckets(cur: Cur, user_id: UUID, tz: str) -> list[dict]:
    """Today's 15-minute step buckets (distance ≈ steps × 0.78 m stride)."""
    day = user_today(tz)
    ts_from, ts_to = _day_bounds_utc(day, tz)  # chunk pruning + the date filter; see above
    cur.execute(
        "SELECT (time_bucket('15 minutes', ts) AT TIME ZONE %s)::time AS local_t, "
        "  SUM(value)::int AS steps, (SUM(value) * 0.78)::int AS dis_m, "
        "  (EXTRACT(HOUR FROM time_bucket('15 minutes', ts) AT TIME ZONE %s)::int * 4 "
        "   + EXTRACT(MINUTE FROM time_bucket('15 minutes', ts) AT TIME ZONE %s)::int / 15)::int "
        "FROM sample WHERE user_id = %s AND metric='steps_per_minute' "
        "AND ts >= %s AND ts < %s "
        "AND (ts AT TIME ZONE %s)::date = %s "
        "GROUP BY 1, 4 HAVING SUM(value) > 0 ORDER BY 1",
        (tz, tz, tz, user_id, ts_from, ts_to, tz, day),
    )
    return [
        {
            "time": local_t.isoformat(timespec="minutes"),
            "bucket": bucket,
            "steps": steps,
            "distance_m": dis_m,
            "calories": 0,
        }
        for local_t, steps, dis_m, bucket in cur.fetchall()
    ]


def stress_series(cur: Cur, user_id: UUID, tz: str) -> list[dict]:
    """Hourly stress averages for today (local). Empty if no stress rows."""
    day = user_today(tz)
    ts_from, ts_to = _day_bounds_utc(day, tz)  # chunk pruning + the date filter; see above
    cur.execute(
        "SELECT date_trunc('hour', ts AT TIME ZONE %s) AS h, ROUND(AVG(value))::int, "
        "  MAX(value)::int, COUNT(*)::int "
        "FROM sample WHERE user_id = %s AND metric='stress' AND value BETWEEN 0 AND 100 "
        "  AND ts >= %s AND ts < %s "
        "  AND (ts AT TIME ZONE %s)::date = %s GROUP BY 1 ORDER BY 1",
        (tz, user_id, ts_from, ts_to, tz, day),
    )
    return [
        {"hour_iso": h.isoformat(), "hour": h.hour, "avg": avg, "max": mx, "n": n}
        for h, avg, mx, n in cur.fetchall()
    ]
