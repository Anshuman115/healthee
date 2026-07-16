"""Integration tests for the Phase 6.3a key fold (0004_tenant_keys).

0003 added `user_id` but left the OLD single-tenant uniqueness in place, so two
users still could not hold the same (metric, ts) / (day, metric) / (start_ts). This
suite proves 0004 actually delivers the tenancy:

  * every folded table's PK/UNIQUE now includes `user_id`;
  * writes land under the passed-in owner and re-running is idempotent via the NEW
    conflict target (upsert twice -> one row, updated value);
  * two rows that collide on the OLD key but differ by `user_id` coexist — the
    property the whole fold exists for.

Auto-skips without a reachable TimescaleDB (same policy as the other integration
tests).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime
from uuid import UUID

import pytest

from healthee.core.db import transaction
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.db import migrate

pytestmark = pytest.mark.integration

# A second owner, so a cross-tenant collision can actually be attempted. (The
# two-user SEED — and the read-path leakage tests it enables — are 6.3c; this row
# exists only to prove the key fold.)
_OTHER_USER = UUID("22222222-2222-2222-2222-222222222222")

# (table, constraint columns) as 0004 leaves them — the folded natural keys.
_FOLDED_KEYS = [
    ("sample", ["user_id", "metric", "ts"]),
    ("sleep_session", ["user_id", "start_ts"]),
    ("workout", ["user_id", "start_ts"]),
    ("derived_daily", ["user_id", "day", "metric"]),
    ("weight_log", ["user_id", "ts"]),
    ("kv", ["user_id", "key"]),
    ("illness_flag", ["user_id", "date"]),
    ("gps_point", ["user_id", "track_id", "ts"]),
    ("recommendation", ["user_id", "date", "rank"]),
    ("finding", ["user_id", "kind", "metric_a", "metric_b", "event_kind", "lag_days"]),
]

_TEST_TS = datetime(2999, 3, 1, 12, 0, tzinfo=UTC)


@pytest.fixture
def migrated(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    """Migrations applied + the second owner present; test rows cleaned up after."""
    migrate.apply_migrations()
    with transaction() as cur:
        cur.execute(
            "INSERT INTO app_user (id, email) VALUES (%s, %s) ON CONFLICT (id) DO NOTHING",
            (_OTHER_USER, "other@example.test"),
        )
    yield
    with transaction() as cur:
        cur.execute("DELETE FROM sample WHERE ts = %s", (_TEST_TS,))
        cur.execute("DELETE FROM kv WHERE key LIKE '_keyfold%'")
        cur.execute("DELETE FROM derived_daily WHERE day = '2999-03-01'")
        cur.execute("DELETE FROM app_user WHERE id = %s", (_OTHER_USER,))


def _key_columns(table: str) -> list[list[str]]:
    """The column lists of every PRIMARY KEY / UNIQUE constraint on `table`."""
    with transaction() as cur:
        cur.execute(
            """
            SELECT array_agg(att.attname::text ORDER BY key.ord)
            FROM pg_constraint con
            JOIN pg_class rel ON rel.oid = con.conrelid
            JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS key(attnum, ord) ON TRUE
            JOIN pg_attribute att ON att.attrelid = rel.oid AND att.attnum = key.attnum
            WHERE rel.relname = %s AND con.contype IN ('p', 'u')
            GROUP BY con.oid
            """,
            (table,),
        )
        return [row[0] for row in cur.fetchall()]


@pytest.mark.parametrize(("table", "columns"), _FOLDED_KEYS)
def test_natural_key_is_folded_by_user(migrated: None, table: str, columns: list[str]) -> None:  # noqa: ARG001
    """The folded key exists exactly as 0004 declares it (owner first)."""
    assert columns in _key_columns(table), (
        f"{table} has no PK/UNIQUE on {columns}; found {_key_columns(table)}"
    )


@pytest.mark.parametrize(("table", "columns"), _FOLDED_KEYS)
def test_no_key_omits_the_owner(migrated: None, table: str, columns: list[str]) -> None:  # noqa: ARG001
    """The OLD un-scoped uniqueness is GONE — the point of the fold.

    A surviving UNIQUE on the natural key WITHOUT user_id would still block a second
    tenant from holding the same row, so no key may be the old column list. (The
    surrogate PKs `recommendation.id` / `finding.id` are unrelated and stay.)
    """
    old_key = columns[1:]  # the pre-0004 key: same columns, minus the owner
    assert old_key not in _key_columns(table), f"{table} still carries the un-scoped key {old_key}"


def test_sample_upsert_is_idempotent_on_the_new_conflict_target(migrated: None) -> None:  # noqa: ARG001
    """The retargeted ON CONFLICT still dedups a re-ingest to ONE row."""
    for value in (61.0, 62.0):  # a re-push of the same point with a corrected value
        with transaction() as cur:
            cur.execute(
                "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, %s, %s) "
                "ON CONFLICT (user_id, metric, ts) DO UPDATE SET value = EXCLUDED.value",
                (SENTINEL_USER_ID, _TEST_TS, "_keyfold_hr", value),
            )
    with transaction() as cur:
        cur.execute(
            "SELECT count(*), max(value) FROM sample WHERE metric = %s AND user_id = %s",
            ("_keyfold_hr", SENTINEL_USER_ID),
        )
        row = cur.fetchone()
    assert row is not None
    assert row[0] == 1, "re-upsert must not duplicate the row"
    assert row[1] == 62.0, "re-upsert must update the value in place"


def test_two_users_can_hold_the_same_sample_key(migrated: None) -> None:  # noqa: ARG001
    """The fold's whole purpose: rows colliding on the OLD key (metric, ts) but
    differing by user_id now COEXIST instead of overwriting each other."""
    with transaction() as cur:
        for owner, value in ((SENTINEL_USER_ID, 61.0), (_OTHER_USER, 99.0)):
            cur.execute(
                "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, %s, %s) "
                "ON CONFLICT (user_id, metric, ts) DO UPDATE SET value = EXCLUDED.value",
                (owner, _TEST_TS, "_keyfold_hr", value),
            )
    with transaction() as cur:
        cur.execute(
            "SELECT user_id, value FROM sample WHERE metric = %s AND ts = %s ORDER BY value",
            ("_keyfold_hr", _TEST_TS),
        )
        rows = cur.fetchall()
    assert len(rows) == 2, "both owners' rows must persist (the old key would have collapsed them)"
    assert {(str(r[0]), r[1]) for r in rows} == {
        (str(SENTINEL_USER_ID), 61.0),
        (str(_OTHER_USER), 99.0),
    }


def test_two_users_can_hold_the_same_derived_daily_key(migrated: None) -> None:  # noqa: ARG001
    """Same property on the derive write path's key (user_id, day, metric)."""
    with transaction() as cur:
        for owner, value in ((SENTINEL_USER_ID, 8000.0), (_OTHER_USER, 12000.0)):
            cur.execute(
                "INSERT INTO derived_daily (user_id, day, metric, value) VALUES (%s, %s, %s, %s) "
                "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
                (owner, "2999-03-01", "_keyfold_steps", value),
            )
    with transaction() as cur:
        cur.execute(
            "SELECT count(*) FROM derived_daily WHERE day = '2999-03-01' AND metric = %s",
            ("_keyfold_steps",),
        )
        row = cur.fetchone()
    assert row is not None
    assert row[0] == 2


def test_two_users_can_hold_the_same_kv_key(migrated: None) -> None:  # noqa: ARG001
    """Per-user job markers / cached text: the same kv key under two owners."""
    with transaction() as cur:
        for owner, value in ((SENTINEL_USER_ID, "a"), (_OTHER_USER, "b")):
            cur.execute(
                "INSERT INTO kv (user_id, key, value) VALUES (%s, %s, %s) "
                "ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value",
                (owner, "_keyfold_marker", value),
            )
    with transaction() as cur:
        cur.execute("SELECT count(*) FROM kv WHERE key = %s", ("_keyfold_marker",))
        row = cur.fetchone()
    assert row is not None
    assert row[0] == 2
