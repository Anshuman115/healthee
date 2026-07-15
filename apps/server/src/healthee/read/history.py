"""Metric history (``/api/history``) and stored profile (``/api/profile``).

Both v2-native. ``history`` serves a daily series from ``derived_daily``; ``profile``
reads ``profile`` + the latest ``weight_log`` row.

Naming seam: ``history`` reads ``derived_daily`` by the metric name as given. The
installed app maps its history requests onto v2 metric names as part of the Phase-2
mobile rebuild; a v1-only name returns an empty series rather than an error.
"""

from __future__ import annotations

from datetime import UTC, datetime

from healthee.derive._common import Cur


def history(cur: Cur, metric: str, days: int = 90) -> dict:
    """Daily series for a metric over a bounded range (metric-history screen)."""
    days = max(1, min(int(days), 1825))
    cur.execute(
        "SELECT day, value FROM derived_daily WHERE metric=%s AND day > (current_date - %s::int) "
        "ORDER BY day",
        (metric, days),
    )
    series = [{"day": d.isoformat(), "value": round(float(v), 2)} for d, v in cur.fetchall()]
    return {"metric": metric, "series": series}


def profile(cur: Cur) -> dict:
    """Stored profile (name / height / sex / dob-epoch-ms / latest weight)."""
    cur.execute("SELECT name, height_cm, sex, dob FROM profile WHERE id=1")
    r = cur.fetchone()
    cur.execute("SELECT kg FROM weight_log ORDER BY ts DESC LIMIT 1")
    w = cur.fetchone()
    if not r:
        return {}
    name, height_cm, sex, dob = r
    dob_ms = (
        int(datetime(dob.year, dob.month, dob.day, tzinfo=UTC).timestamp() * 1000) if dob else None
    )
    return {
        "name": name,
        "height_cm": float(height_cm) if height_cm is not None else None,
        "sex": sex,
        "dob": dob_ms,
        "weight_kg": float(w[0]) if w else None,
    }
