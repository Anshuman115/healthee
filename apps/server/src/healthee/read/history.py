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

from datetime import timedelta
from uuid import UUID

from healthee.analytics.metrics import FLAG_DERIVED_METRICS
from healthee.analytics.series import flag_series
from healthee.core.dob import date_to_dob_ms
from healthee.core.tenancy import USER_TODAY_SQL, user_today
from healthee.derive._common import Cur
from healthee.derive.body_mass import body_mass_index
from healthee.derive.freshness import weight_age_days


def history(cur: Cur, user_id: UUID, tz: str, metric: str, days: int = 90) -> dict:
    """Daily series for a metric over a bounded range (metric-history screen)."""
    days = max(1, min(int(days), 1825))
    since = user_today(tz) - timedelta(days=days - 1)
    if metric in FLAG_DERIVED_METRICS:
        owner, key = FLAG_DERIVED_METRICS[metric]
        values = flag_series(cur, user_id, owner, key, since)
        return {
            "metric": metric,
            "series": [
                {"day": day.isoformat(), "value": round(value, 2)}
                for day, value in sorted(values.items())
                if day <= user_today(tz)
            ],
        }
    if metric == "weight_kg":
        return _weight_history(cur, user_id, tz, since)
    cur.execute(
        "SELECT day, value FROM derived_daily WHERE user_id = %s AND metric=%s "
        f"AND day > ({USER_TODAY_SQL} - %s::int) ORDER BY day",
        (user_id, metric, tz, days),
    )
    series = [{"day": d.isoformat(), "value": round(float(v), 2)} for d, v in cur.fetchall()]
    return {"metric": metric, "series": series}


def _weight_history(cur: Cur, user_id: UUID, tz: str, since) -> dict:
    cur.execute(
        "SELECT DISTINCT ON (day) day, kg FROM ("
        "SELECT (ts AT TIME ZONE %s)::date AS day, ts, kg "
        "FROM weight_log WHERE user_id = %s) AS weights "
        "WHERE day >= %s AND day <= %s ORDER BY day, ts DESC",
        (tz, user_id, since, user_today(tz)),
    )
    return {
        "metric": "weight_kg",
        "series": [{"day": day.isoformat(), "value": float(kg)} for day, kg in cur.fetchall()],
    }


def profile(cur: Cur, user_id: UUID, tz: str) -> dict:
    """Stored profile (name / height / sex / dob-epoch-ms / latest weight + its date).

    `dob` goes back out as epoch ms at **owner-local midnight** (`date_to_dob_ms`),
    the exact inverse of the parse the ingest applies — this endpoint restores the
    profile after a reinstall and the app re-pushes what it gets, so an encoder
    anchored to a different zone than the decoder silently walks the date backwards
    on every sync for negative-offset owners. See `core.dob.date_to_dob_ms`.

    `weight_kg` keeps shipping undated-looking company (it is what a reinstall
    restores), and `weight_as_of` / `weight_age_days` are what make it honest: the
    identical read-modify-push loop applies to weight too, and this endpoint used to
    hand back a mass with no indication it was measured in March. `weight_kg` is a
    restore value, NOT a claim about today — the surface that has to answer "what do
    you weigh now" is the Today card, and that one withholds.
    """
    cur.execute(
        "SELECT name, height_cm, sex, dob, srpa FROM profile WHERE user_id = %s", (user_id,)
    )
    r = cur.fetchone()
    cur.execute(
        "SELECT kg, (ts AT TIME ZONE %s)::date FROM weight_log "
        "WHERE user_id = %s ORDER BY ts DESC LIMIT 1",
        (tz, user_id),
    )
    w = cur.fetchone()
    if not r:
        return {}
    name, height_cm, sex, dob, srpa = r
    dob_ms = date_to_dob_ms(dob, tz) if dob else None
    return {
        "name": name,
        "height_cm": float(height_cm) if height_cm is not None else None,
        "sex": sex,
        "dob": dob_ms,
        "dob_date": dob.isoformat() if dob else None,
        # Jurca's activity category (0-4), or null when unanswered (#108). It ships here
        # for the same reason `dob` does: this endpoint is what a reinstall restores from,
        # and an answer the owner gave once must survive wiping the app.
        "bmi": round(body_mass_index(float(w[0]), float(height_cm)), 2)
        if w and height_cm and height_cm > 0
        else None,
        "srpa": int(srpa) if srpa is not None else None,
        "weight_kg": float(w[0]) if w else None,
        "weight_as_of": w[1].isoformat() if w else None,
        "weight_age_days": weight_age_days(w[1], user_today(tz)) if w else None,
    }
