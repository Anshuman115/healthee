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

from healthee.analytics.metrics import V2_DAILY_METRICS, metric_filter
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur
from healthee.derive.robust import robust_sd as _robust_sd

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
        """MAD scaled to a normal-equivalent standard deviation.

        UNFLOORED on purpose: this baseline serves every metric in
        ``V2_DAILY_METRICS``, whose units range from bpm to minutes to kcal, so no
        single floor could be meaningful across them. The degenerate MAD=0 case is
        guarded downstream in :meth:`z_score` instead.
        """
        if self.mad is None:
            return None
        return _robust_sd(self.mad)

    def z_score(self, value: float) -> float | None:
        """Robust z-score of ``value`` vs this baseline, or None if undefined."""
        if self.median is None or self.robust_sd is None or self.robust_sd == 0:
            return None
        return (value - self.median) / self.robust_sd


def compute_baseline_cur(
    cur: Cur,
    user_id: UUID,
    tz: str,
    metric: str,
    window_days: int = 30,
    end_date: date | None = None,
) -> Baseline:
    """:func:`compute_baseline` on the CALLER's cursor — the read path's form."""
    return compute_baselines_cur(cur, user_id, tz, (metric,), window_days, end_date)[metric]


def compute_baseline(
    user_id: UUID, tz: str, metric: str, window_days: int = 30, end_date: date | None = None
) -> Baseline:
    """Median/MAD/quartile baseline for one owner's metric over the trailing window.

    Thin single-metric wrapper over :func:`compute_baselines` — ONE implementation
    of the baseline maths, so the single- and batched-metric paths cannot diverge
    (standards §"one canonical definition").

    Opens its own connection: for callers with no cursor (jobs, anomalies, insight
    context). A read service already holding one must use :func:`compute_baseline_cur`.
    """
    return compute_baselines(user_id, tz, (metric,), window_days, end_date)[metric]


def compute_baselines_cur(
    cur: Cur,
    user_id: UUID,
    tz: str,
    metrics: Sequence[str],
    window_days: int = 30,
    end_date: date | None = None,
) -> dict[str, Baseline]:
    """Robust baselines for many metrics in ONE grouped query, on the CALLER's cursor.

    Numerically identical to the per-metric path: the SAME ``percentile_cont``
    aggregates, grouped ``BY metric``, each metric gated by its own
    ``METRIC_FILTERS`` sentinel (the ONE canonical constant, never re-typed). A
    metric with no valid rows in the window comes back as an ``n=0`` empty
    baseline, exactly as the per-metric path returned.

    Takes the cursor because the ``/api/today`` aggregator calls this while already
    holding a pooled connection — see :func:`compute_baselines` for why borrowing a
    second one there was a self-deadlock rather than a mere inefficiency.
    """
    wanted = list(dict.fromkeys(metrics))  # de-dup, preserve order
    result = {m: _empty_baseline(m, window_days) for m in wanted}
    if not wanted:
        return result
    # The OWNER's today (`user_today`), never `date.today()` — that is the SERVER
    # process's date (container TZ=UTC), which is nobody's local day. It is the
    # Python twin of the `current_date` anchors 6.4a removed from SQL, and it was
    # missed because it is not SQL: an owner at UTC+14 had their current day fall
    # outside their own 30-day window (n=29, median computed over the wrong days),
    # while an owner at UTC-05 got a window ending on their TOMORROW that dropped
    # their oldest day — and flipped mid-evening, with no new data. That baseline
    # feeds `z_score` → anomalies → recovery score → the LLM context, so a wrong
    # anchor here ships a confidently wrong number (`core.tenancy.USER_TODAY_SQL`).
    end_date = end_date or user_today(tz)
    start_date = end_date - timedelta(days=window_days - 1)
    cur.execute(_baselines_sql(wanted), (user_id, start_date, end_date, *wanted))
    for row in cur.fetchall():
        result[row[0]] = _row_to_baseline(row, window_days)
    return result


def compute_baselines(
    user_id: UUID,
    tz: str,
    metrics: Sequence[str],
    window_days: int = 30,
    end_date: date | None = None,
) -> dict[str, Baseline]:
    """:func:`compute_baselines_cur` on its own connection — for callers with no cursor.

    **Never call this from a read service that already holds a cursor.** Doing so
    borrows a second pooled connection while the first is held, so ~`_POOL_MAX_SIZE`
    concurrent requests deadlock the pool against itself (standards §1: "no per-item
    connections — the pool is the only way in"). Pass the cursor to
    :func:`compute_baselines_cur` instead.
    """
    with tenant_transaction(user_id) as cur:
        return compute_baselines_cur(cur, user_id, tz, metrics, window_days, end_date)


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
    tz: str,
    metrics: tuple[str, ...] = DEFAULT_DAILY_METRICS,
    window_days: int = 30,
    end_date: date | None = None,
) -> list[Baseline]:
    """Baselines for every metric in ``metrics`` over the trailing window."""
    return [compute_baseline(user_id, tz, m, window_days, end_date) for m in metrics]


def latest_value(user_id: UUID, metric: str) -> tuple[date, float] | None:
    """(day, value) of the most recent valid ``derived_daily`` row for one owner's metric."""
    flt = metric_filter(metric)  # constant from METRIC_FILTERS — safe to interpolate
    with tenant_transaction(user_id) as cur:
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
