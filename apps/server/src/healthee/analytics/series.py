"""v2-native series loaders — the read side of the seam fix.

Legacy analytics read the v1 compat VIEWs (``metric_sample``, ``session``) and
filtered on ``source='zepp_cloud'`` and v1 metric names — both empty on v2 data.
These loaders read the v2 tables directly:

  * daily metrics  → ``derived_daily`` (one row per (day, metric); no source
    column, no dedup needed — the derive layer already writes one canonical row).
  * flag-derived   → the JSON ``flags`` of another ``derived_daily`` metric
    (``moderate``/``vigorous`` inside ``mvpa_min``).
  * event days     → ``manual_entry`` directly (unchanged from legacy, which
    already read this v2-native table).

Anchoring is on the user's local (``tz``) date, matching how ``derive`` stamps
``derived_daily.day``.
"""

from __future__ import annotations

from datetime import date
from typing import LiteralString, cast
from uuid import UUID

from psycopg import Cursor
from psycopg.rows import TupleRow

from healthee.analytics.metrics import FLAG_DERIVED_METRICS, metric_filter

# Minimum trimmed-timed-event duration (seconds) that still counts as an event:
# an accidental start+stop (e.g. a 6-second "fast") must not become an event-day.
# Verbatim from legacy _event_days. Instantaneous events (no end_ts) always count.
_MIN_TIMED_EVENT_S = 60

Cur = Cursor[TupleRow]


def daily_series(cur: Cur, user_id: UUID, metric: str) -> dict[date, float]:
    """All daily values for one owner's metric from ``derived_daily``, sentinel-filtered.

    Flag-derived synthetic metrics (moderate_min/vigorous_min) transparently read
    from their owning metric's flags. One value per local day — no source
    preference/dedup because ``derived_daily`` is already canonical (seam fix).
    """
    if metric in FLAG_DERIVED_METRICS:
        return _flag_series(cur, user_id, metric)
    flt = metric_filter(metric)  # constant from METRIC_FILTERS — safe to interpolate
    query = cast(
        LiteralString,
        f"SELECT day, value FROM derived_daily WHERE user_id = %s AND metric=%s AND {flt}",
    )
    cur.execute(query, (user_id, metric))
    return {row[0]: float(row[1]) for row in cur.fetchall()}


def _flag_series(cur: Cur, user_id: UUID, metric: str) -> dict[date, float]:
    """Read a numeric value out of another metric's ``flags`` JSON, one per day."""
    owner, key = FLAG_DERIVED_METRICS[metric]
    cur.execute(
        "SELECT day, (flags->>%s)::float FROM derived_daily "
        "WHERE user_id = %s AND metric=%s AND flags ? %s",
        (key, user_id, owner, key),
    )
    return {row[0]: float(row[1]) for row in cur.fetchall() if row[1] is not None}


def event_days(cur: Cur, user_id: UUID, tz: str, kind: str) -> set[date]:
    """Local dates on which a ``manual_entry`` of the given kind occurred.

    Trivially-short timed events (< 60 s span) are ignored so an accidental
    start+stop cannot count as an event-day; instantaneous events (no ``end_ts``)
    always count. Verbatim from legacy ``_event_days``.
    """
    cur.execute(
        """
        SELECT DISTINCT (ts AT TIME ZONE %s)::date
        FROM manual_entry
        WHERE user_id = %s AND kind = %s
          AND (end_ts IS NULL OR EXTRACT(EPOCH FROM (end_ts - ts)) >= %s)
        """,
        (tz, user_id, kind, _MIN_TIMED_EVENT_S),
    )
    return {r[0] for r in cur.fetchall()}
