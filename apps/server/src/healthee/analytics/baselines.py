"""Robust personal baselines per daily metric — v2-native.

Median + MAD (median absolute deviation) so outliers don't poison the baseline;
each metric carries a sentinel filter (RHR=0 means "not measured", not a real
zero). The statistics are ported verbatim from legacy ``baselines.py``; the read
is the seam fix — values come from ``derived_daily`` (one canonical row per
(day, metric)) instead of the ``metric_sample`` v1 view with its
``source='zepp_cloud'`` filter and v1 metric names.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from typing import LiteralString, cast

from healthee.analytics.metrics import MAD_TO_SD, V2_DAILY_METRICS, metric_filter
from healthee.core.db import transaction

# Metrics baselined by default: the canonical v2 daily set (metrics.py).
DEFAULT_DAILY_METRICS: tuple[str, ...] = V2_DAILY_METRICS


@dataclass
class Baseline:
    """A metric's robust central tendency + spread over a trailing window."""

    metric: str
    window_days: int
    n: int
    median: float | None
    mad: float | None
    p25: float | None
    p75: float | None
    min: float | None
    max: float | None

    @property
    def robust_sd(self) -> float | None:
        """MAD scaled to a normal-equivalent standard deviation."""
        if self.mad is None:
            return None
        return self.mad * MAD_TO_SD

    def z_score(self, value: float) -> float | None:
        """Robust z-score of ``value`` vs this baseline, or None if undefined."""
        if self.median is None or self.robust_sd is None or self.robust_sd == 0:
            return None
        return (value - self.median) / self.robust_sd


def compute_baseline(metric: str, window_days: int = 30, end_date: date | None = None) -> Baseline:
    """Median/MAD/quartile baseline for a metric over the trailing window."""
    end_date = end_date or date.today()
    start_date = end_date - timedelta(days=window_days - 1)
    flt = metric_filter(metric)  # constant from METRIC_FILTERS — safe to interpolate
    with transaction() as cur:
        summary_sql = cast(
            LiteralString,
            """
            SELECT COUNT(*),
              percentile_cont(0.5)  WITHIN GROUP (ORDER BY value),
              percentile_cont(0.25) WITHIN GROUP (ORDER BY value),
              percentile_cont(0.75) WITHIN GROUP (ORDER BY value),
              MIN(value), MAX(value)
            FROM derived_daily
            WHERE metric = %s AND day BETWEEN %s AND %s AND """
            + flt,
        )
        cur.execute(summary_sql, (metric, start_date, end_date))
        row = cur.fetchone()
        n, median, p25, p75, mn, mx = row if row else (0, None, None, None, None, None)
        mad = (
            _compute_mad(cur, metric, flt, median, start_date, end_date)
            if n and median is not None
            else None
        )
    return Baseline(
        metric=metric,
        window_days=window_days,
        n=int(n or 0),
        median=float(median) if median is not None else None,
        mad=float(mad) if mad is not None else None,
        p25=float(p25) if p25 is not None else None,
        p75=float(p75) if p75 is not None else None,
        min=float(mn) if mn is not None else None,
        max=float(mx) if mx is not None else None,
    )


def _compute_mad(
    cur, metric: str, flt: str, median: float, start_date: date, end_date: date
) -> float | None:
    """Median absolute deviation about ``median`` over the same filtered window."""
    mad_sql = cast(
        LiteralString,
        """
        SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY abs_dev)
        FROM (
          SELECT abs(value - %s::float8) AS abs_dev
          FROM derived_daily
          WHERE metric = %s AND day BETWEEN %s AND %s AND """
        + flt
        + ") t",
    )
    cur.execute(mad_sql, (float(median), metric, start_date, end_date))
    row = cur.fetchone()
    return row[0] if row else None


def compute_all(
    metrics: tuple[str, ...] = DEFAULT_DAILY_METRICS,
    window_days: int = 30,
    end_date: date | None = None,
) -> list[Baseline]:
    """Baselines for every metric in ``metrics`` over the trailing window."""
    return [compute_baseline(m, window_days, end_date) for m in metrics]


def latest_value(metric: str) -> tuple[date, float] | None:
    """(day, value) of the most recent valid ``derived_daily`` row for a metric."""
    flt = metric_filter(metric)  # constant from METRIC_FILTERS — safe to interpolate
    with transaction() as cur:
        query = cast(
            LiteralString,
            f"SELECT day, value FROM derived_daily WHERE metric = %s AND {flt} "
            "ORDER BY day DESC LIMIT 1",
        )
        cur.execute(query, (metric,))
        row = cur.fetchone()
        if not row:
            return None
        return row[0], float(row[1])
