"""Shared plumbing for the derive package.

Small helpers every derivation reuses: the `derived_daily` upsert, sleep-window
statistics, the local-day <-> UTC bounds, profile/weight loading, and the score
clamp. Ported verbatim from the legacy v2 derive module — only the data plumbing
(the DB pool lives in ``healthee.core.db``) and the type hints are new; the SQL,
rounding, and math are identical.

``USER_TZ`` is a single-tenant constant (the legacy product is one user): all
daily metrics anchor on the user's local wake date. A multi-user rebuild would
lift this to per-profile config — out of scope for this verbatim port.
"""

from __future__ import annotations

import json
from datetime import UTC, date, datetime
from typing import LiteralString, cast
from zoneinfo import ZoneInfo

from psycopg import Cursor
from psycopg.rows import TupleRow

# Anchor daily metrics to the user's timezone (wake date) — same as legacy v1/v2.
USER_TZ = ZoneInfo("Asia/Kolkata")

# A cursor over plain tuple rows — the row shape every derivation reads.
Cur = Cursor[TupleRow]

# Aggregate functions allowed in `_window_stat`'s SQL. The stat name is
# interpolated into the query, so it MUST come from this hardcoded allowlist and
# never from caller-controlled data (standards §2: no untrusted SQL f-strings).
_ALLOWED_STATS = frozenset({"AVG", "MIN", "MAX", "SUM"})


def _json(payload: dict) -> str:
    """Serialize a flags dict for a jsonb column."""
    return json.dumps(payload)


def _upsert_daily(
    cur: Cur, day: date, metric: str, value: float, flags: dict | None = None
) -> None:
    """Insert-or-update one materialized daily metric row (value rounded to 4dp)."""
    cur.execute(
        """
        INSERT INTO derived_daily (day, metric, value, flags)
        VALUES (%s, %s, %s, %s::jsonb)
        ON CONFLICT (day, metric) DO UPDATE
          SET value = EXCLUDED.value, flags = EXCLUDED.flags
        """,
        (day, metric, round(float(value), 4), _json(flags or {})),
    )


def _window_stat(
    cur: Cur,
    metric: str,
    start_ts: datetime,
    end_ts: datetime,
    lo: float,
    hi: float,
    stat: str = "AVG",
) -> float | None:
    """Aggregate one metric over the [start, end) window, bounded to [lo, hi]."""
    if stat not in _ALLOWED_STATS:  # guard the interpolated aggregate name
        raise ValueError(f"unsupported stat {stat!r}")
    # `stat` is interpolated but validated against the hardcoded allowlist above,
    # so this is a constant literal to the DB — cast tells the type checker so.
    query = cast(
        LiteralString,
        f"SELECT {stat}(value)::float FROM sample "
        "WHERE metric=%s AND value BETWEEN %s AND %s AND ts >= %s AND ts < %s",
    )
    cur.execute(query, (metric, lo, hi, start_ts, end_ts))
    row = cur.fetchone()
    return float(row[0]) if row and row[0] is not None else None


def _wake_date(end_ts: datetime) -> date:
    """Daily metrics anchor on the local wake (session end) date."""
    return end_ts.astimezone(USER_TZ).date()


def _day_bounds_utc(day: date) -> tuple[datetime, datetime]:
    """UTC [start, end] instants bracketing one local (USER_TZ) calendar day."""
    start = datetime(day.year, day.month, day.day, 0, 0, 0, tzinfo=USER_TZ)
    return start.astimezone(UTC), (start.replace(hour=23, minute=59, second=59)).astimezone(UTC)


def _age(dob: date, on: date) -> int:
    """Whole years old on the given date."""
    years = on.year - dob.year
    if (on.month, on.day) < (dob.month, dob.day):
        years -= 1
    return years


def _load_profile(cur: Cur, day: date | None = None) -> dict | None:
    """Profile + weight as-of `day` (weight is a time-series, read at that date).

    Weight uses the most recent `weight_log` entry logged on or before `day`, so
    updating today's weight never retroactively rewrites past days; days before
    the first entry fall back to the earliest logged weight. With `day=None` the
    latest weight is used. Returns None if the profile or any weight is missing.
    """
    cur.execute("SELECT height_cm, sex, dob FROM profile WHERE id=1")
    prof = cur.fetchone()
    if not prof or prof[0] is None or prof[1] is None or prof[2] is None:
        return None
    weight = _weight_as_of(cur, day)
    if not weight:
        return None
    return {
        "height_cm": float(prof[0]),
        "sex": prof[1],
        "dob": prof[2],
        "weight_kg": float(weight[0]),
    }


def _weight_as_of(cur: Cur, day: date | None) -> tuple | None:
    """Most-recent weight_log row on/before `day` (earliest if none), or latest."""
    if day is not None:
        cur.execute(
            "SELECT kg FROM weight_log WHERE (ts AT TIME ZONE 'Asia/Kolkata')::date <= %s "
            "ORDER BY ts DESC LIMIT 1",
            (day,),
        )
        weight = cur.fetchone()
        if not weight:
            cur.execute("SELECT kg FROM weight_log ORDER BY ts ASC LIMIT 1")
            weight = cur.fetchone()
        return weight
    cur.execute("SELECT kg FROM weight_log ORDER BY ts DESC LIMIT 1")
    return cur.fetchone()


def _clamp100(x: float) -> float:
    """Clamp a sub-score to [0, 100]."""
    return max(0.0, min(100.0, x))


def _scalar(cur: Cur) -> float:
    """Read one guaranteed-present numeric aggregate result (a COALESCE'd SUM/…).

    Aggregate queries always return exactly one row; the None branch is defensive
    (a loud error, never a silent 0) so a plumbing bug can't masquerade as data.
    """
    row = cur.fetchone()
    if row is None:
        raise RuntimeError("expected one aggregate row, got none")
    return float(row[0])


__all__ = [
    "USER_TZ",
    "Cur",
    "_age",
    "_clamp100",
    "_day_bounds_utc",
    "_json",
    "_load_profile",
    "_scalar",
    "_upsert_daily",
    "_wake_date",
    "_window_stat",
]
