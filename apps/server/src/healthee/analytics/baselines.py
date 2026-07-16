"""Robust personal baselines per daily metric — v2-native.

Median + MAD (median absolute deviation) so outliers don't poison the baseline;
each metric carries a sentinel filter (RHR=0 means "not measured", not a real
zero). The statistics are ported verbatim from legacy ``baselines.py``; the read
is the seam fix — values come from ``derived_daily`` (one canonical row per
(day, metric)) instead of the ``metric_sample`` v1 view with its
``source='zepp_cloud'`` filter and v1 metric names.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Any, LiteralString, cast
from uuid import UUID

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


def compute_baseline(
    user_id: UUID, metric: str, window_days: int = 30, end_date: date | None = None
) -> Baseline:
    """Median/MAD/quartile baseline for one owner's metric over the trailing window.

    Thin single-metric wrapper over :func:`compute_baselines` — ONE implementation
    of the baseline maths, so the single- and batched-metric paths cannot diverge
    (standards §"one canonical definition").
    """
    return compute_baselines(user_id, (metric,), window_days, end_date)[metric]


def compute_baselines(
    user_id: UUID,
    metrics: Sequence[str],
    window_days: int = 30,
    end_date: date | None = None,
) -> dict[str, Baseline]:
    """Robust baselines for many metrics in ONE grouped query on ONE connection.

    The ``/api/today`` aggregator needs ~8 baselines per request; computing them
    one metric at a time meant N separate ``transaction()`` checkouts × 2 queries
    each (a pool-starvation hazard under concurrency). This collapses them to a
    single connection and a single statement.

    Numerically identical to the per-metric path: the SAME ``percentile_cont``
    aggregates, grouped ``BY metric``, each metric gated by its own
    ``METRIC_FILTERS`` sentinel (the ONE canonical constant, never re-typed). A
    metric with no valid rows in the window comes back as an ``n=0`` empty
    baseline, exactly as the per-metric path returned.
    """
    wanted = list(dict.fromkeys(metrics))  # de-dup, preserve order
    result = {m: _empty_baseline(m, window_days) for m in wanted}
    if not wanted:
        return result
    end_date = end_date or date.today()
    start_date = end_date - timedelta(days=window_days - 1)
    with transaction() as cur:
        cur.execute(_baselines_sql(wanted), (user_id, start_date, end_date, *wanted))
        rows = cur.fetchall()
    for row in rows:
        result[row[0]] = _row_to_baseline(row, window_days)
    return result


def _baselines_sql(wanted: list[str]) -> LiteralString:
    """The grouped summary + MAD statement for :func:`compute_baselines`.

    Each metric's sentinel filter is a hardcoded ``METRIC_FILTERS`` constant
    (never caller input) OR'd into the window predicate — safe to interpolate
    (standards §2); the metric names and window bounds stay parameterized (``%s``).
    """
    where = " OR ".join(f"(metric = %s AND {metric_filter(m)})" for m in wanted)
    return cast(
        LiteralString,
        "WITH win AS ("
        "  SELECT metric, value FROM derived_daily "
        "  WHERE user_id = %s AND day BETWEEN %s AND %s AND (" + where + ")"
        "), summ AS ("
        "  SELECT metric, COUNT(*) AS n, "
        "    percentile_cont(0.5)  WITHIN GROUP (ORDER BY value) AS median, "
        "    percentile_cont(0.25) WITHIN GROUP (ORDER BY value) AS p25, "
        "    percentile_cont(0.75) WITHIN GROUP (ORDER BY value) AS p75, "
        "    MIN(value) AS mn, MAX(value) AS mx "
        "  FROM win GROUP BY metric"
        ") "
        "SELECT s.metric, s.n, s.median, s.p25, s.p75, s.mn, s.mx, "
        "  percentile_cont(0.5) WITHIN GROUP (ORDER BY abs(w.value - s.median)) AS mad "
        "FROM summ s JOIN win w USING (metric) "
        "GROUP BY s.metric, s.n, s.median, s.p25, s.p75, s.mn, s.mx",
    )


def _row_to_baseline(row: tuple, window_days: int) -> Baseline:
    """Map one grouped-query row to a Baseline (``_f`` NULL-guards every stat)."""
    metric, n, median, p25, p75, mn, mx, mad = row
    return Baseline(
        metric=metric,
        window_days=window_days,
        n=int(n or 0),
        median=_f(median),
        mad=_f(mad),
        p25=_f(p25),
        p75=_f(p75),
        min=_f(mn),
        max=_f(mx),
    )


def _empty_baseline(metric: str, window_days: int) -> Baseline:
    """The ``n=0`` baseline a metric gets when it has no rows in the window."""
    return Baseline(metric, window_days, 0, None, None, None, None, None, None)


def _f(v: Any) -> float | None:
    return float(v) if v is not None else None


def compute_all(
    user_id: UUID,
    metrics: tuple[str, ...] = DEFAULT_DAILY_METRICS,
    window_days: int = 30,
    end_date: date | None = None,
) -> list[Baseline]:
    """Baselines for every metric in ``metrics`` over the trailing window."""
    return [compute_baseline(user_id, m, window_days, end_date) for m in metrics]


def latest_value(user_id: UUID, metric: str) -> tuple[date, float] | None:
    """(day, value) of the most recent valid ``derived_daily`` row for one owner's metric."""
    flt = metric_filter(metric)  # constant from METRIC_FILTERS — safe to interpolate
    with transaction() as cur:
        query = cast(
            LiteralString,
            f"SELECT day, value FROM derived_daily WHERE user_id = %s AND metric = %s AND {flt} "
            "ORDER BY day DESC LIMIT 1",
        )
        cur.execute(query, (user_id, metric))
        row = cur.fetchone()
        if not row:
            return None
        return row[0], float(row[1])
