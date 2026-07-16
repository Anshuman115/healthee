"""Integration tests for the tenant column (0003_tenant_column, 0005, 0007).

Every data table carries a NOT NULL `user_id`, the FK rejects unknown owners, and
the `(user_id, …)` secondary indexes exist.

**The DEFAULT is gone (0007).** 6.2 shipped `user_id … NOT NULL DEFAULT '<sentinel>'`
as a transitional scaffold so legacy-shaped writes kept working while 6.3 threaded
the owner through; that job is done, and with multi-user live the default became a
hazard — a writer that forgot `user_id` would silently attribute one person's health
data to the sentinel. This file now pins the inverse: forgetting the owner RAISES.

Auto-skips without a reachable TimescaleDB (same policy as the other integration
tests).
"""

from __future__ import annotations

from uuid import UUID

import psycopg
import pytest

from healthee.core.db import admin_connection, tenant_transaction, transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration

# The sentinel legacy owner all pre-auth single-tenant data belongs to (0003).
_SENTINEL = "00000000-0000-0000-0000-000000000000"
_SENTINEL_UUID = UUID(_SENTINEL)

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


@pytest.mark.parametrize("table", _TENANT_TABLES)
def test_user_id_has_no_column_default(db: None, table: str) -> None:  # noqa: ARG001
    """0007: the transitional DEFAULT is gone from EVERY tenant table.

    Driven off the canonical 16-table list, so a table that keeps its default
    cannot hide behind a hand-picked sample.
    """
    migrate.apply_migrations()
    with transaction() as cur:
        cur.execute(
            "SELECT column_default FROM information_schema.columns "
            "WHERE table_name = %s AND column_name = 'user_id'",
            (table,),
        )
        row = cur.fetchone()
    assert row is not None, f"{table} is missing the user_id column"
    assert row[0] is None, f"{table}.user_id still has a DEFAULT ({row[0]}) — 0007 missed it"


def test_no_tenant_table_kept_a_default_at_all(db: None) -> None:  # noqa: ARG001
    """The same claim asked of the database rather than of our list.

    `_TENANT_TABLES` is a hand-maintained constant; this asks `information_schema`
    for any `user_id` column anywhere in `public` that still carries a default, so a
    17th tenant table added later without a `DROP DEFAULT` fails here even if nobody
    remembers to extend the list.
    """
    migrate.apply_migrations()
    with transaction() as cur:
        cur.execute(
            "SELECT table_name FROM information_schema.columns "
            "WHERE column_name = 'user_id' AND table_schema = 'public' "
            "AND column_default IS NOT NULL ORDER BY table_name"
        )
        offenders = [row[0] for row in cur.fetchall()]
    assert offenders == [], f"user_id still defaults on: {offenders}"


# The two tests that used to live here asserted the INVERSE — that a legacy-shaped
# write (no user_id) "backfills to the sentinel" — because 6.2's DEFAULT was a
# deliberate scaffold keeping legacy writers non-breaking. 0007 retired it, so the
# invariant flips: forgetting the owner must now be LOUD. Silently attributing one
# person's health data to the sentinel is exactly the silent wrongness this repo
# exists to prevent, so the tests are replaced rather than deleted — the file still
# pins the current truth about what a write without an owner does.


# These two run on the ADMIN, which is the table owner and (0008 does not FORCE) is
# not subject to the tenant policies. That is the only identity from which `NOT NULL`
# is still the FIRST thing an owner-less write meets — on the app pool `0008`'s
# WITH CHECK rejects it earlier (`user_id = NULL` is NULL, never true), which
# `test_rls.py::test_a_write_without_an_owner_is_denied_by_the_policy` pins. The
# column constraint and the policy are two independent guarantees; each is asserted
# where it actually bites, rather than letting the policy mask the column's.


def test_a_derived_daily_write_without_an_owner_raises(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    with (
        pytest.raises(psycopg.errors.NotNullViolation),
        admin_connection() as conn,
        conn.cursor() as cur,
    ):
        cur.execute(
            "INSERT INTO derived_daily (day, metric, value) "
            "VALUES ('2999-01-01', '_tenant_test', 1.0)"
        )


def test_a_kv_write_without_an_owner_raises(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    with (
        pytest.raises(psycopg.errors.NotNullViolation),
        admin_connection() as conn,
        conn.cursor() as cur,
    ):
        cur.execute("INSERT INTO kv (key, value) VALUES ('_tenant_test_key', 'v')")


def test_the_same_write_succeeds_when_it_names_the_owner(db: None) -> None:  # noqa: ARG001
    """The other half: NOT NULL is kept, but supplying the owner still works.

    Without this, the two tests above would also pass if 0007 had broken the column
    outright — "it raises" is only the right behaviour if the correct write doesn't.
    """
    migrate.apply_migrations()
    with tenant_transaction(_SENTINEL_UUID) as cur:
        cur.execute(
            "INSERT INTO kv (user_id, key, value) VALUES (%s, '_tenant_test_key', 'v') "
            "ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value",
            (_SENTINEL,),
        )
    with tenant_transaction(_SENTINEL_UUID) as cur:
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
    """A user_id that is not a real app_user id is rejected by the FK.

    Scoped TO that unknown owner on purpose: `0008`'s WITH CHECK is evaluated before
    the FK, so on an unscoped transaction this would be denied by the policy and the
    test would pass without the FK ever being consulted — green either way, proving
    nothing. Satisfying the policy first is what lets the FK be the thing under test.
    """
    migrate.apply_migrations()
    unknown = UUID("11111111-1111-1111-1111-111111111111")
    with pytest.raises(psycopg.errors.ForeignKeyViolation), tenant_transaction(unknown) as cur:
        cur.execute(
            "INSERT INTO kv (key, value, user_id) VALUES ('_tenant_fk_test', 'v', %s)",
            (unknown,),
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
    with tenant_transaction(_SENTINEL_UUID) as cur:
        cur.execute(
            "INSERT INTO profile (user_id, name) VALUES (%s, '_dup_test') "
            "ON CONFLICT (user_id) DO UPDATE SET name = EXCLUDED.name",
            (_SENTINEL,),
        )
    with (
        pytest.raises(psycopg.errors.UniqueViolation),
        tenant_transaction(_SENTINEL_UUID) as cur,
    ):
        cur.execute("INSERT INTO profile (user_id, name) VALUES (%s, '_dup_2')", (_SENTINEL,))
    with tenant_transaction(_SENTINEL_UUID) as cur:
        cur.execute("DELETE FROM profile WHERE user_id = %s AND name = '_dup_test'", (_SENTINEL,))
