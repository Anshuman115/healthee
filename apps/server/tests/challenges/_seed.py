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

from healthee.challenges import store
from healthee.core.db import admin_connection, transaction
from healthee.core.tenancy import SENTINEL_USER_ID

# Owner A is the sentinel (seeded by migration 0003); owner B is a second real
# tenant, created by the isolation fixture.
OWNER = SENTINEL_USER_ID
OTHER_OWNER = UUID("77777777-7777-7777-7777-777777777777")

# The metric row total sleep time rides on — NOT a metric row of its own
# (`analytics.metrics.V2_DAILY_METRICS` has no `tst_min`).
SLEEP_ROW_METRIC = "sleep_health_score_4dim"

_TABLES = ("derived_daily", "workout", "manual_entry")

# `challenge` is truncated separately with CASCADE: `challenge_outcome` references
# it, and TRUNCATE refuses a referenced table without CASCADE. Taking the ledger
# with it is exactly right for a reset — an outcome without its challenge is orphan
# history nothing can explain.
_CASCADING_TABLES = ("challenge",)


def reset() -> None:
    """Empty the tables the engine reads and writes, across every owner.

    ``TRUNCATE`` on the ADMIN connection: it is deliberately not granted to the app
    role, and a reset must clear EVERY owner's rows — which an RLS-scoped
    connection cannot even see (6.5b-2).
    """
    with admin_connection() as conn, conn.cursor() as cur:
        for table in _TABLES:
            cur.execute(f"TRUNCATE {table}")  # noqa: S608 — module constant, never input
        for table in _CASCADING_TABLES:
            cur.execute(f"TRUNCATE {table} CASCADE")  # noqa: S608 — module constant


def ensure_owner_b() -> None:
    """Create the second tenant, so isolation can be PROVED rather than assumed.

    `app_user` carries no RLS policy by design (MULTI_USER.md §3.3) — the app must
    resolve who you are before it has an owner to scope to — so this runs on the
    ordinary pool rather than the admin.
    """
    with transaction() as cur:
        cur.execute(
            "INSERT INTO app_user (id, email, timezone) VALUES (%s, %s, %s) "
            "ON CONFLICT (id) DO NOTHING",
            (OTHER_OWNER, "challenges-owner-b@example.test", "Asia/Kolkata"),
        )


def remove_owner_b() -> None:
    """Delete owner B; the FK cascade takes every row they own with them."""
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM app_user WHERE id = %s", (OTHER_OWNER,))


def seed_challenge(cur, user_id: UUID, **overrides) -> int:
    """One ``suggested`` challenge owned by ``user_id``; returns its id.

    Defaults to the shape the rest of the suite uses (7-day daily step target) so a
    test only states the field it is actually about.
    """
    row = {
        "title": "Walk more",
        "why": "because",
        "category": "activity",
        "metric": "steps_total",
        "comparator": ">=",
        "target_value": 8000.0,
        "cadence": "daily",
        "window_days": 7,
        "status": "suggested",
    } | overrides
    cur.execute(
        "INSERT INTO challenge (user_id, title, why, category, metric, comparator, "
        "  target_value, cadence, window_days, status, adopted_at, baseline_value) "
        "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id",
        (
            user_id,
            row["title"],
            row["why"],
            row["category"],
            row["metric"],
            row["comparator"],
            row["target_value"],
            row["cadence"],
            row["window_days"],
            row["status"],
            row.get("adopted_at"),
            row.get("baseline_value"),
        ),
    )
    row = cur.fetchone()
    assert row is not None, "INSERT ... RETURNING id gave no row"
    return int(row[0])


def stored(cur, user_id: UUID, challenge_id: int) -> dict:
    """``store.fetch`` for an id the test KNOWS exists — asserts rather than returns None.

    A missing row here is a broken test setup, and it must say so instead of failing
    later on an attribute of ``None``.
    """
    challenge = store.fetch(cur, user_id, challenge_id)
    assert challenge is not None, f"challenge {challenge_id} is not visible to {user_id}"
    return challenge


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
