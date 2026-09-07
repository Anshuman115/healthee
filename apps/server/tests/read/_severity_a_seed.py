"""Seed helpers shared by the two severity-A suites.

`test_honesty_severity_a.py` (the fitness, recovery, workout and history findings) and
`test_honesty_severity_a_sleep.py` (the sleep chain) both need the same three primitives,
and the sleep helper in particular has to be able to write a session with NO stage
breakdown — the state migration `0018` made expressible and the whole point of A5. Copying
it into both files would be two chances to write the absent-stage row two ways, which is
the shape of the defect the suites exist to catch.

Not a `test_*.py` file, so it is never collected as a suite.
"""

from __future__ import annotations

import json
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID

ZONE = ZoneInfo(SENTINEL_TZ)

# Deliberately far from every default and every plausible rounding artefact, so a leak
# reads as THIS number rather than as arithmetic.
OWN_DAY_RHR = 44.0
TODAY_RHR = 71.0
OWN_DAY_HRMAX = 190.0
TODAY_HRMAX = 150.0

# One staged night's four stage minutes, in the column order `_night` writes them.
STAGED_MINUTES = (60, 240, 120, 20)  # rem, light, deep, wake
STAGED_TST_MIN = 420  # light + deep + rem; wake excluded


def reset(cur) -> None:
    """Empty every table these suites write, so one test cannot seed another."""
    for table in (
        "derived_daily",
        "sleep_session",
        "workout",
        "sample",
        "weight_log",
        "profile",
        "finding",
    ):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names


def daily(cur, day: date, metric: str, value: float, flags: dict | None = None) -> None:
    """One ``derived_daily`` row, flags included."""
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
        "VALUES (%s, %s, %s, %s, %s::jsonb) "
        "ON CONFLICT (user_id, day, metric) DO UPDATE SET "
        "value = EXCLUDED.value, flags = EXCLUDED.flags",
        (SENTINEL_USER_ID, day, metric, value, json.dumps(flags or {})),
    )


def night(cur, wake_on: date, *, staged: bool) -> datetime:
    """One main sleep session ending on ``wake_on``, with or without a stage breakdown.

    ``staged=False`` writes NULL into all four stage columns — the state the schema could
    not hold before `0018`, and the one every A5 assertion turns on. Returns the session's
    UTC start so a caller can address it.
    """
    end = datetime.combine(wake_on, time(7, 0), tzinfo=ZONE)
    start = end - timedelta(hours=7)
    minutes = STAGED_MINUTES if staged else (None, None, None, None)
    cur.execute(
        "INSERT INTO sleep_session "
        "(user_id,start_ts,end_ts,kind,rem_min,light_min,deep_min,wake_min,stages) "
        "VALUES (%s,%s,%s,'main',%s,%s,%s,%s,'[]'::jsonb) "
        "ON CONFLICT (user_id, start_ts) DO NOTHING",
        (SENTINEL_USER_ID, start.astimezone(UTC), end.astimezone(UTC), *minutes),
    )
    return start.astimezone(UTC)
