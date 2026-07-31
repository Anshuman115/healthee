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
from datetime import UTC, date, datetime
from uuid import UUID

from psycopg.types.json import Jsonb

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

# `finding` joins the list because WP-C3c's lever ranking reads it: a personal
# pattern left behind by one test would silently promote a metric in the next.
#
# `program` joins it for a sharper version of the same reason (WP-C4): the one-active-
# ladder cap is a COUNT, so a program left behind by one test refuses the next test's
# adopt with `program_active` — which is exactly how it was found, and is the kind of
# leak that looks like a code bug for as long as it takes to check the reset list.
_TABLES = ("derived_daily", "workout", "manual_entry", "finding", "illness_flag", "program")

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


# Every column `ledger._store` writes, so a seeded outcome can be the shape the coach
# actually reads (WP-C5) rather than a subset that happens to satisfy the lever rules.
# The two NOT NULL columns default to what the schema defaults them to, so a caller who
# does not care about the honesty fields gets exactly the row this helper used to write.
_OUTCOME_COLUMNS = (
    "metric",
    "category",
    "difficulty",
    "cadence",
    "target",
    "baseline",
    "final",
    "improvement_pct",
    "improved",
    "adherence",
    "days_active",
    "status",
    "confounds",
    "co_occurring",
    "data_confidence",
    "ended_at",
)


def seed_outcome(cur, user_id: UUID, challenge_id: int, **overrides) -> None:
    """One frozen ``challenge_outcome`` row — the history the ledger readers read back."""
    row: dict = {
        "metric": "steps_total",
        "category": "activity",
        "difficulty": "standard",
        "cadence": "daily",
        "target": 8000.0,
        "baseline": 6000.0,
        "final": None,
        "improvement_pct": None,
        "improved": None,
        "adherence": None,
        "days_active": None,
        "status": "met",
        "confounds": {},
        "co_occurring": None,
        "data_confidence": "ok",
        "ended_at": datetime(2026, 7, 1, 6, 0, tzinfo=UTC),
    } | overrides
    columns = ", ".join(_OUTCOME_COLUMNS)  # a module constant of names, never input
    placeholders = ", ".join(["%s"] * len(_OUTCOME_COLUMNS))
    cur.execute(
        f"INSERT INTO challenge_outcome (user_id, challenge_id, {columns}) "  # noqa: S608
        f"VALUES (%s, %s, {placeholders})",
        (user_id, challenge_id, *(_jsonb(row[column]) for column in _OUTCOME_COLUMNS)),
    )


def _jsonb(value):
    """JSONB columns need the adapter; everything else passes through untouched."""
    return Jsonb(value) if isinstance(value, dict) else value


def seed_illness(cur, user_id: UUID, day: date, severity: str = "moderate") -> None:
    """One active ``illness_flag`` — the hard override [[recovery_readiness]] D7 names."""
    cur.execute(
        "INSERT INTO illness_flag (user_id, date, severity, rr_delta_bpm, sustained, "
        "  research_note_ids) VALUES (%s, %s, %s, 2.5, TRUE, %s) "
        "ON CONFLICT (user_id, date) DO UPDATE SET severity = EXCLUDED.severity",
        (user_id, day, severity, ["respiratory_rate_normal"]),
    )


def seed_finding(cur, user_id: UUID, **overrides) -> None:
    """One FDR-significant ``finding`` row — an owner's OWN measured evidence.

    Defaults to a personal-cutoff on caffeine, the shape CHALLENGES.md §5.1 names as the
    thing no competitor can copy ("cut caffeine after 16:00 — on your data that is worth
    ~40 min of sleep").

    The hour is 16 and not 15 because 15 is an hour the finder cannot produce: the search
    runs over ``analytics.cutoffs.CUTOFF_HOURS`` (12, 14, 16, 18, 20, 22), so a fixture at
    15 was a shape no owner could ever actually have. That was invisible while nothing
    read the hour; it stopped being invisible when the registry grew a metric per hour
    (``challenges.windowed``) and a fixture at 15 would have exercised a window that does
    not exist.
    """
    row = {
        "kind": "personal_cutoff",
        "description": "Caffeine after 16:00 Asia/Kolkata -> tst_min median 198.0 vs 238.0",
        "metric_a": "caffeine_after_16",
        "metric_b": "tst_min",
        "event_kind": "caffeine",
        "lag_days": 0,
        "effect_size": -0.62,
        "effect_metric": "mann_whitney_rb",
        "p_value": 0.004,
        "q_value": 0.03,
        "n_samples": 28,
        "research_note_ids": ["caffeine_sleep"],
    } | overrides
    cur.execute(
        "INSERT INTO finding (user_id, kind, description, metric_a, metric_b, event_kind, "
        "  lag_days, effect_size, effect_metric, p_value, q_value, n_samples, significant, "
        "  research_note_ids, details) "
        "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,TRUE,%s,'{}'::jsonb)",
        (
            user_id,
            row["kind"],
            row["description"],
            row["metric_a"],
            row["metric_b"],
            row["event_kind"],
            row["lag_days"],
            row["effect_size"],
            row["effect_metric"],
            row["p_value"],
            row["q_value"],
            row["n_samples"],
            row["research_note_ids"],
        ),
    )


def days(start: date, count: int) -> list[date]:
    """``count`` consecutive dates beginning at ``start``."""
    return [date.fromordinal(start.toordinal() + i) for i in range(count)]
