"""v2-native DB seeding helpers for the analytics integration tests.

Every row written here uses a *v2* shape — ``derived_daily`` (metric/value/flags
per local day), ``sleep_session`` (stage minutes), ``manual_entry``, ``profile``,
``weight_log`` — with the v2 metric names the derive layer emits. That is the
whole point of the seam-bug regression tests: on this data the legacy analytics
(v1 names, ``source='zepp_cloud'``, ``summary->>'tst_minutes'``) would read
nothing, while the v2-native analytics read it correctly.

Not a pytest module (underscore-prefixed); imported by the integration tests via
a sys.path insert, like the derive suite's ``_seed``.
"""

from __future__ import annotations

import json
from datetime import date, datetime, time, timedelta
from typing import LiteralString, cast
from zoneinfo import ZoneInfo

from healthee.core.db import admin_connection
from healthee.core.tenancy import SENTINEL_USER_ID

IST = ZoneInfo("Asia/Kolkata")

# Every row here belongs to the sentinel, named explicitly: `0007` dropped the
# transitional `user_id` DEFAULT, so omitting the owner now raises NotNullViolation.
_OWNER = SENTINEL_USER_ID

_CLEAN_TABLES = (
    "derived_daily",
    "sleep_session",
    "manual_entry",
    "finding",
    "weight_log",
    "illness_flag",
)


def clean(*extra_tables: str) -> None:
    """Truncate the tables the analytics read so tests don't cross-contaminate.

    Self-opening on the ADMIN connection, and no longer takes a cursor — same reason
    as `tests/contracts/seed.reset`: `TRUNCATE` is deliberately not granted to the
    app role, and a reset must clear EVERY owner's rows, which an RLS-scoped
    connection cannot see (6.5b-2). A `DELETE` here on the app pool would silently
    remove nothing and leave the next test reading stale rows.

    `extra_tables` are truncated alongside the defaults — for the callers that also
    need `kv` (the per-day LLM cache) or `recommendation` emptied.
    """
    with admin_connection() as conn, conn.cursor() as cur:
        for table in (*_CLEAN_TABLES, *extra_tables):
            # Trusted SQL — a module constant plus the caller's literal, never input.
            cur.execute(cast("LiteralString", f"TRUNCATE {table}"))
        cur.execute("DELETE FROM profile")


def seed_daily(cur, metric: str, values: dict[date, float], flags: dict | None = None) -> None:
    """Insert ``derived_daily`` rows for one metric (optionally shared flags)."""
    payload = json.dumps(flags or {})
    for day, value in values.items():
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
            "VALUES (%s, %s, %s, %s, %s::jsonb) ON CONFLICT (user_id, day, metric) DO UPDATE "
            "SET value = EXCLUDED.value, flags = EXCLUDED.flags",
            (_OWNER, day, metric, float(value), payload),
        )


def seed_daily_with_flags(cur, metric: str, rows: dict[date, tuple[float, dict]]) -> None:
    """Insert ``derived_daily`` rows carrying a per-day flags dict."""
    for day, (value, flags) in rows.items():
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
            "VALUES (%s, %s, %s, %s, %s::jsonb)",
            (_OWNER, day, metric, float(value), json.dumps(flags)),
        )


def seed_night(cur, wake_date: date, rem: int, light: int, deep: int, wake: int) -> None:
    """Insert one 'main' sleep session ending 07:00 IST on ``wake_date``.

    TST = rem+light+deep (the v2 source of truth for the cutoff finder); TIB is
    the start→end span. Onset is the previous evening at 23:00 IST.
    """
    end_ts = datetime.combine(wake_date, time(7, 0), tzinfo=IST)
    start_ts = end_ts - timedelta(hours=8)
    cur.execute(
        "INSERT INTO sleep_session "
        "(user_id, start_ts, end_ts, kind, rem_min, light_min, deep_min, wake_min)"
        " VALUES (%s, %s, %s, 'main', %s, %s, %s, %s)",
        (_OWNER, start_ts, end_ts, rem, light, deep, wake),
    )


def seed_caffeine(cur, wake_date: date, hour_ist: int = 21) -> None:
    """Log a caffeine ``manual_entry`` the evening before ``wake_date`` (no end)."""
    ts = datetime.combine(wake_date - timedelta(days=1), time(hour_ist, 0), tzinfo=IST)
    cur.execute(
        "INSERT INTO manual_entry (user_id, kind, ts, amount, unit) "
        "VALUES (%s, 'caffeine', %s, 100, 'mg')",
        (_OWNER, ts),
    )


def seed_event(cur, kind: str, day: date, hour_ist: int = 8) -> None:
    """Log a generic instantaneous ``manual_entry`` event on ``day``."""
    ts = datetime.combine(day, time(hour_ist, 0), tzinfo=IST)
    cur.execute(
        "INSERT INTO manual_entry (user_id, kind, ts) VALUES (%s, %s, %s)", (_OWNER, kind, ts)
    )


def seed_profile(cur, dob: date, sex: str = "male", height_cm: float = 175.0) -> None:
    """Set the owner's profile and one weight_log row (for BMI-based derives).

    The owner is the sentinel, named explicitly as everywhere else in this seeder;
    0005 re-keyed `profile` to that column and 0007 removed its DEFAULT.
    """
    cur.execute(
        # srpa 2 — Jurca's self-reported activity category (#108). Required, so it is
        # seeded explicitly rather than left NULL, and deliberately not the reference
        # level so the dummy coefficient is actually exercised.
        "INSERT INTO profile (user_id, height_cm, sex, dob, srpa) VALUES (%s, %s, %s, %s, 2) "
        "ON CONFLICT (user_id) DO UPDATE SET height_cm=EXCLUDED.height_cm, sex=EXCLUDED.sex, "
        "dob=EXCLUDED.dob, srpa=EXCLUDED.srpa",
        (_OWNER, height_cm, sex, dob),
    )
    cur.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, %s, %s) "
        "ON CONFLICT (user_id, ts) DO NOTHING",
        (_OWNER, datetime.now(tz=IST) - timedelta(days=1), 72.0),
    )


def recent_days(n: int, end_offset: int = 0) -> list[date]:
    """``n`` consecutive local dates ending ``end_offset`` days before today."""
    today = datetime.now(tz=IST).date() - timedelta(days=end_offset)
    return [today - timedelta(days=i) for i in range(n - 1, -1, -1)]
