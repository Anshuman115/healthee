"""Seeding helpers for the challenges engine's integration tests.

Every value the engine reads comes from three v2 tables — ``derived_daily``
(metric rows), ``derived_daily.flags`` (total sleep time rides on the
``sleep_health_score_4dim`` row) and ``workout`` — so these helpers write exactly
those three shapes and nothing else.

Dates are FIXED, never "N days ago", and every function that consumes them takes
an explicit ``today``. A suite anchored to the wall clock cannot fail the way a
timezone bug actually fails: the expected value drifts with the bug.

Not a pytest module (underscore-prefixed); imported by the test modules.
"""

from __future__ import annotations

import json
from collections.abc import Sequence
from datetime import date, datetime
from uuid import UUID

from healthee.core.db import admin_connection
from healthee.core.tenancy import SENTINEL_USER_ID

# Owner A is the sentinel (seeded by migration 0003); owner B is a second real
# tenant, created by the isolation fixture.
OWNER = SENTINEL_USER_ID
OTHER_OWNER = UUID("77777777-7777-7777-7777-777777777777")

# The metric row total sleep time rides on — NOT a metric row of its own
# (`analytics.metrics.V2_DAILY_METRICS` has no `tst_min`).
SLEEP_ROW_METRIC = "sleep_health_score_4dim"

_TABLES = ("derived_daily", "workout", "manual_entry")


def reset() -> None:
    """Empty the tables the engine reads, across every owner.

    ``TRUNCATE`` on the ADMIN connection: it is deliberately not granted to the app
    role, and a reset must clear EVERY owner's rows — which an RLS-scoped
    connection cannot even see (6.5b-2).
    """
    with admin_connection() as conn, conn.cursor() as cur:
        for table in _TABLES:
            cur.execute(f"TRUNCATE {table}")  # noqa: S608 — module constant, never input


def seed_metric(cur, user_id: UUID, metric: str, values: dict[date, float]) -> None:
    """One ``derived_daily`` row per day for a canonical daily metric."""
    for day, value in values.items():
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
            "VALUES (%s, %s, %s, %s, '{}'::jsonb) "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
            (user_id, day, metric, float(value)),
        )


def seed_sleep(cur, user_id: UUID, nights: dict[date, float]) -> None:
    """Total sleep time per local WAKE date, in the flag the derive layer writes it to."""
    for day, tst_min in nights.items():
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
            "VALUES (%s, %s, %s, 3, %s::jsonb) "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET flags = EXCLUDED.flags",
            (user_id, day, SLEEP_ROW_METRIC, json.dumps({"tst_min": tst_min})),
        )


def seed_workout(cur, user_id: UUID, start_ts: datetime, duration_s: int) -> None:
    """One ``workout`` row at an absolute instant (the local day is the engine's job)."""
    cur.execute(
        "INSERT INTO workout (user_id, start_ts, sport, duration_s) VALUES (%s, %s, 0, %s) "
        "ON CONFLICT (user_id, start_ts) DO UPDATE SET duration_s = EXCLUDED.duration_s",
        (user_id, start_ts, duration_s),
    )


def seed_manual(
    cur, user_id: UUID, kind: str, entries: Sequence[tuple[datetime, float, str | None]]
) -> None:
    """``manual_entry`` rows at absolute instants — (ts, amount, unit) each.

    ``unit`` is passed through verbatim, including ``None``, because which units the
    cap reader accepts is exactly what the tests need to pin.
    """
    for ts, amount, unit in entries:
        cur.execute(
            "INSERT INTO manual_entry (user_id, kind, ts, amount, unit) VALUES (%s,%s,%s,%s,%s)",
            (user_id, kind, ts, amount, unit),
        )


def days(start: date, count: int) -> list[date]:
    """``count`` consecutive dates beginning at ``start``."""
    return [date.fromordinal(start.toordinal() + i) for i in range(count)]
