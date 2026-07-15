"""Today-page series + cards: the secondary metric cards, the 14-day sparklines,
and today's intraday HR / step / stress shapes. v2-native: ``derived_daily`` for
day series/cards, the raw ``sample`` table for intraday, ``weight_log`` for weight.

Sparkline GAPs (keys kept for wire-compat, empty in v2): ``sleep_score`` (v2 uses
``sleep_health_score_4dim``), ``stress`` and ``pai_total`` (not derived in v2 —
analytics/metrics.py). Documented in the WP7 report.
"""

from __future__ import annotations

from healthee.analytics.baselines import compute_baseline
from healthee.derive._common import Cur
from healthee.read.common import USER_TZ_NAME, derived_series, latest_derived, user_today
from healthee.read.meta import METRIC_META, TODAY_SECONDARY_METRICS


def secondary_cards(cur: Cur) -> list[dict]:
    """RHR / steps / calories / distance / weight cards — first candidate with data
    wins, each with its 30-day median + z-anomaly flag."""
    out: list[dict] = []
    for candidates in TODAY_SECONDARY_METRICS:
        card = _card_for(cur, candidates)
        if card:
            out.append(card)
    return out


def _card_for(cur: Cur, candidates: list[str]) -> dict | None:
    for cand in candidates:
        picked = _weight_card(cur) if cand == "weight_kg" else _derived_card(cur, cand)
        if picked:
            return picked
    return None


def _derived_card(cur: Cur, metric: str) -> dict | None:
    latest = latest_derived(cur, metric)
    if not latest:
        return None
    day, value, _flags = latest
    meta = METRIC_META[metric]
    baseline = compute_baseline(metric, window_days=30)
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


def _weight_card(cur: Cur) -> dict | None:
    """Weight is stored in ``weight_log`` (not derived_daily); no derived baseline."""
    cur.execute("SELECT kg FROM weight_log ORDER BY ts DESC LIMIT 1")
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


def sparklines(cur: Cur) -> dict[str, list[dict]]:
    """14-day daily series per Today sparkline slot (empty for v2 gaps)."""
    return {
        key: (derived_series(cur, metric, 14) if metric else [])
        for key, metric in _SPARKLINE_METRICS.items()
    }


def hr_hourly(cur: Cur) -> list[dict]:
    """Hourly avg/min/max HR for today (local) — today's heart-rate shape."""
    cur.execute(
        "SELECT date_trunc('hour', ts AT TIME ZONE %s) AS h, ROUND(AVG(value))::int, "
        "  MIN(value)::int, MAX(value)::int "
        "FROM sample WHERE metric='hr' AND value > 30 AND value < 220 "
        "  AND (ts AT TIME ZONE %s)::date = %s GROUP BY 1 ORDER BY 1",
        (USER_TZ_NAME, USER_TZ_NAME, user_today()),
    )
    return [
        {"hour_iso": h.isoformat(), "hour": h.hour, "avg": avg, "min": mn, "max": mx}
        for h, avg, mn, mx in cur.fetchall()
    ]


def step_buckets(cur: Cur) -> list[dict]:
    """Today's 15-minute step buckets (distance ≈ steps × 0.78 m stride)."""
    cur.execute(
        "SELECT (time_bucket('15 minutes', ts) AT TIME ZONE %s)::time AS local_t, "
        "  SUM(value)::int AS steps, (SUM(value) * 0.78)::int AS dis_m, "
        "  (EXTRACT(HOUR FROM time_bucket('15 minutes', ts) AT TIME ZONE %s)::int * 4 "
        "   + EXTRACT(MINUTE FROM time_bucket('15 minutes', ts) AT TIME ZONE %s)::int / 15)::int "
        "FROM sample WHERE metric='steps_per_minute' AND (ts AT TIME ZONE %s)::date = %s "
        "GROUP BY 1, 4 HAVING SUM(value) > 0 ORDER BY 1",
        (USER_TZ_NAME, USER_TZ_NAME, USER_TZ_NAME, USER_TZ_NAME, user_today()),
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


def stress_series(cur: Cur) -> list[dict]:
    """Hourly stress averages for today (local). Empty if no stress rows."""
    cur.execute(
        "SELECT date_trunc('hour', ts AT TIME ZONE %s) AS h, ROUND(AVG(value))::int, "
        "  MAX(value)::int, COUNT(*)::int "
        "FROM sample WHERE metric='stress' AND value BETWEEN 0 AND 100 "
        "  AND (ts AT TIME ZONE %s)::date = %s GROUP BY 1 ORDER BY 1",
        (USER_TZ_NAME, USER_TZ_NAME, user_today()),
    )
    return [
        {"hour_iso": h.isoformat(), "hour": h.hour, "avg": avg, "max": mx, "n": n}
        for h, avg, mx, n in cur.fetchall()
    ]
