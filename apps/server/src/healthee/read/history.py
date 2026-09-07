"""Metric history (``/api/history``) and stored profile (``/api/profile``).

Both v2-native. ``history`` serves a daily series from ``derived_daily``; ``profile``
reads ``profile`` + the latest ``weight_log`` row.

Naming seam: ``history`` reads ``derived_daily`` by the metric name as given. The
v2 app sends canonical v2 metric names (``analytics.metrics.KNOWN_METRICS``); the
router rejects any other name with 422 upstream
(``api.validation.require_known_metric``) — an unknown metric must not read as an
empty result. Retired v1 names (e.g. ``hrv_sleep_avg_ms``) are not accepted: the
canonical name is ``hrv_sleep_avg``.

## One definition of a series, read for one metric or for many

:func:`history_series` is that definition, and both public forms are shaped from
it — :func:`history` (one metric, the metric-detail screen) and
:func:`history_batch` (a list, the dated-history panels). The alternative was a
batch that loops over the single-metric read, which is the N+1 the standards
forbid on a read path, and a batch with its own SQL, which is two definitions of
what a day's value is. This way the number a chart draws cannot depend on which
endpoint asked for it.

**A bounded number of queries, not one per metric.** The plain
``derived_daily`` metrics are read in ONE statement (``metric = ANY``); the two
flag-carried synthetics keep going through ``analytics.series.flag_series``,
which is the one reader for a value living inside another metric's ``flags``;
and ``weight_kg`` keeps its own ``weight_log`` read. So a call naming every
metric the server serves costs four statements, not twenty-five.
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import date, timedelta
from uuid import UUID

from healthee.analytics.metrics import FLAG_DERIVED_METRICS
from healthee.analytics.series import flag_series
from healthee.core.dob import date_to_dob_ms
from healthee.core.tenancy import USER_TODAY_SQL, user_today
from healthee.derive._common import Cur
from healthee.derive.body_mass import body_mass_index
from healthee.derive.freshness import weight_age_days

# The longest window a caller may ask for, and the shortest. A chart range is
# bounded data (standards section 1, "unbounded data is windowed"); five years is
# well past the retention any client keeps and is here so a typo cannot ask for
# the whole table.
MIN_DAYS = 1
MAX_DAYS = 1825

# The one metric whose series does not come from ``derived_daily`` at all.
_WEIGHT = "weight_kg"


def bounded_days(days: int) -> int:
    """``days`` clamped into the window this endpoint will answer for."""
    return max(MIN_DAYS, min(int(days), MAX_DAYS))


def history(cur: Cur, user_id: UUID, tz: str, metric: str, days: int = 90) -> dict:
    """Daily series for a metric over a bounded range (metric-history screen)."""
    return {
        "metric": metric,
        "series": history_series(cur, user_id, tz, (metric,), days)[metric],
    }


def history_batch(cur: Cur, user_id: UUID, tz: str, metrics: Sequence[str], days: int) -> dict:
    """Daily series for several metrics in one read — the dated-history panels.

    ``days`` is echoed back because the server clamps it: a client that asked for
    3,000 days and drew a caption saying so would be captioning a window it did
    not get. Every metric asked for is a key in ``series``, empty list included,
    so "you have no readings" is a series the client can see rather than a key it
    has to notice is missing.
    """
    return {
        "days": bounded_days(days),
        "series": history_series(cur, user_id, tz, metrics, days),
    }


def history_series(
    cur: Cur, user_id: UUID, tz: str, metrics: Sequence[str], days: int
) -> dict[str, list[dict]]:
    """``{metric: [{day, value}, …]}`` — THE definition of a dated series.

    Days with no reading are absent, never zero-filled and never carried forward
    from a neighbour: a gap is a gap, and the client draws it as one.
    """
    days = bounded_days(days)
    since = user_today(tz) - timedelta(days=days - 1)
    # Seeded in the order asked for, so every requested metric has an entry even
    # when the owner has nothing for it.
    series: dict[str, list[dict]] = {metric: [] for metric in metrics}
    plain = [m for m in series if m != _WEIGHT and m not in FLAG_DERIVED_METRICS]
    if plain:
        series.update(_daily_rows(cur, user_id, tz, plain, days))
    for metric in series:
        if metric in FLAG_DERIVED_METRICS:
            series[metric] = _flag_points(cur, user_id, tz, metric, since)
    if _WEIGHT in series:
        series[_WEIGHT] = _weight_points(cur, user_id, tz, since)
    return series


def _daily_rows(
    cur: Cur, user_id: UUID, tz: str, metrics: list[str], days: int
) -> dict[str, list[dict]]:
    """One statement for every plain ``derived_daily`` metric asked for."""
    cur.execute(
        "SELECT metric, day, value FROM derived_daily WHERE user_id = %s AND metric = ANY(%s) "
        f"AND day > ({USER_TODAY_SQL} - %s::int) ORDER BY metric, day",
        (user_id, metrics, tz, days),
    )
    rows: dict[str, list[dict]] = {}
    for metric, day, value in cur.fetchall():
        rows.setdefault(metric, []).append(
            {"day": day.isoformat(), "value": round(float(value), 2)}
        )
    return rows


def _flag_points(cur: Cur, user_id: UUID, tz: str, metric: str, since: date) -> list[dict]:
    """A synthetic metric carried inside another metric's ``flags``."""
    owner, key = FLAG_DERIVED_METRICS[metric]
    values = flag_series(cur, user_id, owner, key, since)
    today = user_today(tz)
    return [
        {"day": day.isoformat(), "value": round(value, 2)}
        for day, value in sorted(values.items())
        if day <= today
    ]


def _weight_points(cur: Cur, user_id: UUID, tz: str, since: date) -> list[dict]:
    """The last weigh-in of each local day — ``weight_log``, not ``derived_daily``."""
    cur.execute(
        "SELECT DISTINCT ON (day) day, kg FROM ("
        "SELECT (ts AT TIME ZONE %s)::date AS day, ts, kg "
        "FROM weight_log WHERE user_id = %s) AS weights "
        "WHERE day >= %s AND day <= %s ORDER BY day, ts DESC",
        (tz, user_id, since, user_today(tz)),
    )
    return [{"day": day.isoformat(), "value": float(kg)} for day, kg in cur.fetchall()]


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
