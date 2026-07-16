"""Integration tests for the Phase 6.2 tenant column (0003_tenant_column).

Proves the migration is correct AND strictly additive: every data table gains a
NOT NULL `user_id`, existing/legacy-shaped writes (omitting user_id) still work and
backfill to the sentinel owner via the column DEFAULT, the FK rejects unknown
owners, and the (user_id, …) secondary indexes exist. Auto-skips without a
reachable TimescaleDB (same policy as the other integration tests).
"""

from __future__ import annotations

import psycopg
import pytest

from healthee.core.db import transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration

# The sentinel legacy owner all pre-auth single-tenant data belongs to (0003).
_SENTINEL = "00000000-0000-0000-0000-000000000000"

# The 16 data tables that gained a tenant column in 6.2.
_TENANT_TABLES = (
    "sample",
    "sleep_session",
    "workout",
    "derived_daily",
    "weight_log",
    "kv",
    "manual_entry",
    "illness_flag",
    "recommendation",
    "finding",
    "challenge",
    "program",
    "challenge_outcome",
    "gps_track",
    "gps_point",
    "profile",
)


def test_sentinel_owner_exists_with_kolkata_tz(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    with transaction() as cur:
        cur.execute("SELECT timezone FROM app_user WHERE id = %s", (_SENTINEL,))
        row = cur.fetchone()
    assert row is not None, "sentinel app_user row is missing"
    # Must match the single-tenant USER_TZ so 6.3 day boundaries don't shift.
    assert row[0] == "Asia/Kolkata"


@pytest.mark.parametrize("table", _TENANT_TABLES)
def test_table_has_not_null_user_id(db: None, table: str) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    with transaction() as cur:
        cur.execute(
            "SELECT is_nullable FROM information_schema.columns "
            "WHERE table_name = %s AND column_name = 'user_id'",
            (table,),
        )
        row = cur.fetchone()
    assert row is not None, f"{table} is missing the user_id column"
    assert row[0] == "NO", f"{table}.user_id must be NOT NULL"


def test_legacy_shaped_derived_daily_write_backfills_to_sentinel(
    db: None,  # noqa: ARG001
) -> None:
    """A write using the OLD column list (no user_id) still works and defaults to
    the sentinel — proving 6.2 keeps existing writers non-breaking."""
    with transaction() as cur:
        cur.execute(
            "INSERT INTO derived_daily (day, metric, value) "
            "VALUES ('2999-01-01', '_tenant_test', 1.0) "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value"
        )
    with transaction() as cur:
        cur.execute(
            "SELECT user_id FROM derived_daily WHERE day = '2999-01-01' AND metric = '_tenant_test'"
        )
        row = cur.fetchone()
        cur.execute(
            "DELETE FROM derived_daily WHERE day = '2999-01-01' AND metric = '_tenant_test'"
        )
    assert row is not None
    assert str(row[0]) == _SENTINEL


def test_legacy_shaped_kv_write_backfills_to_sentinel(db: None) -> None:  # noqa: ARG001
    with transaction() as cur:
        cur.execute(
            "INSERT INTO kv (key, value) VALUES ('_tenant_test_key', 'v') "
            "ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value"
        )
    with transaction() as cur:
        cur.execute("SELECT user_id FROM kv WHERE key = '_tenant_test_key'")
        row = cur.fetchone()
        cur.execute("DELETE FROM kv WHERE key = '_tenant_test_key'")
    assert row is not None
    assert str(row[0]) == _SENTINEL


@pytest.mark.parametrize(
    ("table", "index"),
    [
        ("sample", "sample_user_idx"),
        ("derived_daily", "derived_daily_user_idx"),
        ("finding", "finding_user_idx"),
        ("profile", "profile_user_idx"),
    ],
)
def test_user_index_exists(db: None, table: str, index: str) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    with transaction() as cur:
        cur.execute(
            "SELECT 1 FROM pg_indexes WHERE tablename = %s AND indexname = %s",
            (table, index),
        )
        assert cur.fetchone() is not None, f"missing index {index} on {table}"


def test_fk_rejects_unknown_owner(db: None) -> None:  # noqa: ARG001
    """A user_id that is not a real app_user id is rejected by the FK."""
    migrate.apply_migrations()
    with pytest.raises(psycopg.errors.ForeignKeyViolation), transaction() as cur:
        cur.execute(
            "INSERT INTO kv (key, value, user_id) "
            "VALUES ('_tenant_fk_test', 'v', '11111111-1111-1111-1111-111111111111')"
        )


def test_profile_is_keyed_by_owner(db: None) -> None:  # noqa: ARG001
    """0005 replaced profile's `id=1` single-row CHECK with a `user_id` PK.

    The invariant it guarded ("at most one profile row") is now stated PER OWNER
    instead of globally: a second insert for the SAME owner conflicts, while a
    different owner is free to hold their own row (asserted in
    `test_profile_rekey.py`). This is the same rule, correctly scoped — the old
    version made a second owner's profile impossible.
    """
    migrate.apply_migrations()
    with transaction() as cur:
        cur.execute(
            "INSERT INTO profile (user_id, name) VALUES (%s, '_dup_test') "
            "ON CONFLICT (user_id) DO UPDATE SET name = EXCLUDED.name",
            (_SENTINEL,),
        )
    with pytest.raises(psycopg.errors.UniqueViolation), transaction() as cur:
        cur.execute("INSERT INTO profile (user_id, name) VALUES (%s, '_dup_2')", (_SENTINEL,))
    with transaction() as cur:
        cur.execute("DELETE FROM profile WHERE user_id = %s AND name = '_dup_test'", (_SENTINEL,))
