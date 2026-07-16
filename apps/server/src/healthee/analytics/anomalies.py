"""Anomaly detection against personal baselines — v2-native.

For each daily metric, walk the most recent N days and flag values beyond a
2σ-equivalent deviation from the personal baseline (computed over the trailing
window, excluding the day being evaluated). Every anomaly carries research-note
citations so the validity caveat (e.g. wearable sleep-stage accuracy) is always
attached. Logic ported verbatim from legacy ``anomalies.py``; the daily values
come from ``derived_daily`` (seam fix) and citations from the WP4 manifest.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from typing import LiteralString, cast
from uuid import UUID

from healthee.analytics.baselines import DEFAULT_DAILY_METRICS, Baseline, compute_baseline
from healthee.analytics.metrics import metric_filter
from healthee.analytics.notes import notes_for
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import USER_TODAY_SQL


@dataclass
class Anomaly:
    """One daily value that deviates ≥ ``z_threshold`` from its personal norm."""

    when: date
    metric: str
    value: float
    baseline: Baseline
    z: float
    direction: str  # 'high' | 'low'
    research_note_ids: list[str]


def _daily_values(
    cur, user_id: UUID, tz: str, metric: str, days_back: int
) -> list[tuple[date, float]]:
    """The last ``days_back`` days of one owner's metric from ``derived_daily``, filtered.

    One canonical row per day already lives in ``derived_daily`` — no source
    preference/dedup (that was a v1 multi-source artifact). The window ends at the
    OWNER's today (``USER_TODAY_SQL``), not the database session's date.
    """
    flt = metric_filter(metric)  # constant from METRIC_FILTERS — safe to interpolate
    query = cast(
        LiteralString,
        f"SELECT day, value FROM derived_daily WHERE user_id = %s AND metric = %s AND {flt} "
        f"AND day > ({USER_TODAY_SQL} - %s::int) ORDER BY day DESC",
    )
    cur.execute(query, (user_id, metric, tz, days_back))
    return [(r[0], float(r[1])) for r in cur.fetchall()]


def detect(
    user_id: UUID,
    tz: str,
    metrics: tuple[str, ...] = DEFAULT_DAILY_METRICS,
    days_back: int = 14,
    window_days: int = 30,
    z_threshold: float = 2.0,
) -> list[Anomaly]:
    """Scan the last ``days_back`` days for anomalies vs a ``window_days`` baseline."""
    out: list[Anomaly] = []
    for metric in metrics:
        note_ids = notes_for([metric])
        with tenant_transaction(user_id) as cur:
            values = _daily_values(cur, user_id, tz, metric, days_back)
        for d, v in values:
            anomaly = _evaluate(user_id, metric, d, v, window_days, z_threshold, note_ids)
            if anomaly is not None:
                out.append(anomaly)
    out.sort(key=lambda a: (a.when, abs(a.z)), reverse=True)
    return out


def _evaluate(
    user_id: UUID,
    metric: str,
    d: date,
    v: float,
    window_days: int,
    z_threshold: float,
    note_ids: list[str],
) -> Anomaly | None:
    """Baseline (excluding day ``d``) and flag ``v`` if |z| ≥ threshold."""
    baseline = compute_baseline(user_id, metric, window_days, end_date=d - timedelta(days=1))
    z = baseline.z_score(v)
    if z is None or abs(z) < z_threshold:
        return None
    return Anomaly(
        when=d,
        metric=metric,
        value=v,
        baseline=baseline,
        z=z,
        direction="high" if z > 0 else "low",
        research_note_ids=note_ids,
    )
