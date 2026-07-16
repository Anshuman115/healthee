"""Shared plumbing for the derive package.

Small helpers every derivation reuses: the `derived_daily` upsert, sleep-window
statistics, the local-day <-> UTC bounds, profile/weight loading, and the score
clamp. Ported verbatim from the legacy v2 derive module — only the data plumbing
(the DB pool lives in ``healthee.core.db``) and the type hints are new; the SQL,
rounding, and math are identical.

All daily metrics anchor on the user's local wake date. The timezone is threaded
in as an IANA name (``tz: str``) rather than read from a module constant: 6.3b
removed the single-tenant ``USER_TZ``, and 6.4 sources the value from the
authenticated user's ``app_user.timezone``. SQL binds it to ``AT TIME ZONE %s``;
Python datetime math builds a local ``ZoneInfo(tz)``.
"""

from __future__ import annotations

import json
from datetime import UTC, date, datetime
from typing import LiteralString, cast
from uuid import UUID
from zoneinfo import ZoneInfo

from psycopg import Cursor
from psycopg.rows import TupleRow

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
    cur: Cur, user_id: UUID, day: date, metric: str, value: float, flags: dict | None = None
) -> None:
    """Insert-or-update one materialized daily metric row (value rounded to 4dp).

    `user_id` is the row's owner and part of the key (0004 folded it into the PK),
    so the conflict target is (user_id, day, metric): two users' same-day rows no
    longer collide. It has no default on purpose — a derivation that silently wrote
    under the wrong owner is exactly the class of bug the explicit thread prevents.
    """
    cur.execute(
        """
        INSERT INTO derived_daily (user_id, day, metric, value, flags)
        VALUES (%s, %s, %s, %s, %s::jsonb)
        ON CONFLICT (user_id, day, metric) DO UPDATE
          SET value = EXCLUDED.value, flags = EXCLUDED.flags
        """,
        (user_id, day, metric, round(float(value), 4), _json(flags or {})),
    )


def _window_stat(
    cur: Cur,
    user_id: UUID,
    metric: str,
    start_ts: datetime,
    end_ts: datetime,
    lo: float,
    hi: float,
    stat: str = "AVG",
) -> float | None:
    """Aggregate one owner's metric over the [start, end) window, bounded to [lo, hi]."""
    if stat not in _ALLOWED_STATS:  # guard the interpolated aggregate name
        raise ValueError(f"unsupported stat {stat!r}")
    # `stat` is interpolated but validated against the hardcoded allowlist above,
    # so this is a constant literal to the DB — cast tells the type checker so.
    query = cast(
        LiteralString,
        f"SELECT {stat}(value)::float FROM sample "
        "WHERE user_id = %s AND metric=%s AND value BETWEEN %s AND %s AND ts >= %s AND ts < %s",
    )
    cur.execute(query, (user_id, metric, lo, hi, start_ts, end_ts))
    row = cur.fetchone()
    return float(row[0]) if row and row[0] is not None else None


def _wake_date(end_ts: datetime, tz: str) -> date:
    """Daily metrics anchor on the local wake (session end) date."""
    return end_ts.astimezone(ZoneInfo(tz)).date()


def _day_bounds_utc(day: date, tz: str) -> tuple[datetime, datetime]:
    """UTC [start, end] instants bracketing one local (``tz``) calendar day."""
    start = datetime(day.year, day.month, day.day, 0, 0, 0, tzinfo=ZoneInfo(tz))
    return start.astimezone(UTC), (start.replace(hour=23, minute=59, second=59)).astimezone(UTC)


def _age(dob: date, on: date) -> int:
    """Whole years old on the given date."""
    years = on.year - dob.year
    if (on.month, on.day) < (dob.month, dob.day):
        years -= 1
    return years


def _load_profile(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> dict | None:
    """Profile + weight as-of `day` (weight is a time-series, read at that date).

    Weight uses the most recent `weight_log` entry logged on or before `day`, so
    updating today's weight never retroactively rewrites past days; days before
    the first entry fall back to the earliest logged weight. With `day=None` the
    latest weight is used. Returns None if the profile or any weight is missing.

    `profile` keeps its `id = 1` predicate alongside the owner filter — the re-key
    to a `user_id` PK is 6.3c.
    """
    cur.execute("SELECT height_cm, sex, dob FROM profile WHERE id=1 AND user_id = %s", (user_id,))
    prof = cur.fetchone()
    if not prof or prof[0] is None or prof[1] is None or prof[2] is None:
        return None
    weight = _weight_as_of(cur, user_id, tz, day)
    if not weight:
        return None
    return {
        "height_cm": float(prof[0]),
        "sex": prof[1],
        "dob": prof[2],
        "weight_kg": float(weight[0]),
    }


def _weight_as_of(cur: Cur, user_id: UUID, tz: str, day: date | None) -> tuple | None:
    """Most-recent weight_log row on/before `day` (earliest if none), or latest."""
    if day is not None:
        cur.execute(
            "SELECT kg FROM weight_log WHERE user_id = %s "
            "AND (ts AT TIME ZONE %s)::date <= %s ORDER BY ts DESC LIMIT 1",
            (user_id, tz, day),
        )
        weight = cur.fetchone()
        if not weight:
            cur.execute(
                "SELECT kg FROM weight_log WHERE user_id = %s ORDER BY ts ASC LIMIT 1",
                (user_id,),
            )
            weight = cur.fetchone()
        return weight
    cur.execute("SELECT kg FROM weight_log WHERE user_id = %s ORDER BY ts DESC LIMIT 1", (user_id,))
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
