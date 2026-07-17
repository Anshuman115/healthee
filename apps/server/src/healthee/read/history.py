"""Metric history (``/api/history``) and stored profile (``/api/profile``).

Both v2-native. ``history`` serves a daily series from ``derived_daily``; ``profile``
reads ``profile`` + the latest ``weight_log`` row.

Naming seam: ``history`` reads ``derived_daily`` by the metric name as given. The
v2 app sends canonical v2 metric names (``analytics.metrics.KNOWN_METRICS``); the
router rejects any other name with 422 upstream
(``api.validation.require_known_metric``) — an unknown metric must not read as an
empty result. Retired v1 names (e.g. ``hrv_sleep_avg_ms``) are not accepted: the
canonical name is ``hrv_sleep_avg``.
"""

from __future__ import annotations

from uuid import UUID

from healthee.core.dob import date_to_dob_ms
from healthee.core.tenancy import USER_TODAY_SQL
from healthee.derive._common import Cur


def history(cur: Cur, user_id: UUID, tz: str, metric: str, days: int = 90) -> dict:
    """Daily series for a metric over a bounded range (metric-history screen)."""
    days = max(1, min(int(days), 1825))
    cur.execute(
        "SELECT day, value FROM derived_daily WHERE user_id = %s AND metric=%s "
        f"AND day > ({USER_TODAY_SQL} - %s::int) ORDER BY day",
        (user_id, metric, tz, days),
    )
    series = [{"day": d.isoformat(), "value": round(float(v), 2)} for d, v in cur.fetchall()]
    return {"metric": metric, "series": series}


def profile(cur: Cur, user_id: UUID, tz: str) -> dict:
    """Stored profile (name / height / sex / dob-epoch-ms / latest weight).

    `dob` goes back out as epoch ms at **owner-local midnight** (`date_to_dob_ms`),
    the exact inverse of the parse the ingest applies — this endpoint restores the
    profile after a reinstall and the app re-pushes what it gets, so an encoder
    anchored to a different zone than the decoder silently walks the date backwards
    on every sync for negative-offset owners. See `core.dob.date_to_dob_ms`.
    """
    cur.execute("SELECT name, height_cm, sex, dob FROM profile WHERE user_id = %s", (user_id,))
    r = cur.fetchone()
    cur.execute("SELECT kg FROM weight_log WHERE user_id = %s ORDER BY ts DESC LIMIT 1", (user_id,))
    w = cur.fetchone()
    if not r:
        return {}
    name, height_cm, sex, dob = r
    dob_ms = date_to_dob_ms(dob, tz) if dob else None
    return {
        "name": name,
        "height_cm": float(height_cm) if height_cm is not None else None,
        "sex": sex,
        "dob": dob_ms,
        "weight_kg": float(w[0]) if w else None,
    }
