"""The Phase 6.3c profile re-key (0005) — the fix for a real cross-tenant corruption.

Before 0005, `profile` was `id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1)`: ONE row
globally, not one per owner. Two concrete bugs followed, and both are asserted dead
here rather than merely described:

  * **B could not have a profile at all** — every read is `WHERE user_id = %s`, and
    only one owner could hold the single `id = 1` row.
  * **B's profile push silently overwrote A's demographics** — `upsert_profile`
    conflicted on `(id)` and updated name/height/sex/dob WITHOUT setting `user_id`,
    so the row kept A's owner while carrying B's body. Height/sex/dob feed energy,
    distance, VO₂max and bio-age, so this corrupted A's derived health numbers with
    a stranger's body — silently, and in a way that still looks like a real number.

Auto-skips without a reachable TimescaleDB (same policy as the other integration
tests).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime
from uuid import UUID

import psycopg
import pytest

from healthee.core.db import admin_connection, tenant_transaction, transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.ingest.models import ProfileIn
from healthee.ingest.upsert import upsert_profile
from healthee.read.history import profile as read_profile

pytestmark = pytest.mark.integration

_OWNER_B = UUID("55555555-5555-5555-5555-555555555555")

# A's demographics vs B's — no value overlaps, so a clobber is unmistakable.
#
# The dobs are deliberately POST-2001: `upsert.epoch_to_utc` guesses ms-vs-seconds
# with `ts > 10**12`, so any dob before 2001-09-09 sent as epoch ms is misread (1990
# raises, 1970 silently becomes 2060). That is a real pre-existing ingest bug, but it
# is NOT what this suite is about and fixing it is its own PR — these tests must fail
# only on a tenancy regression, so they stay clear of that landmine.
_A = {"name": "OwnerA", "height_cm": 176.0, "sex": "male", "dob": date(2002, 1, 1)}
_B = {"name": "OwnerB", "height_cm": 150.0, "sex": "female", "dob": date(2005, 6, 15)}


def _dob_ms(d: date) -> int:
    """A date as the epoch-ms `ProfileIn.dob` the app sends."""
    return int(datetime(d.year, d.month, d.day, tzinfo=UTC).timestamp() * 1000)


def _profile_in(spec: dict) -> ProfileIn:
    return ProfileIn(
        name=spec["name"],
        height_cm=spec["height_cm"],
        sex=spec["sex"],
        dob=_dob_ms(spec["dob"]),
    )


@pytest.fixture
def two_profiles(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    """Owner A (sentinel) + owner B both exist; only A starts with a profile."""
    migrate.apply_migrations()
    # `app_user` is identity (no RLS policy); `profile` is tenant, so A's row is
    # written under A. The two-owner DELETE goes to the ADMIN — no single RLS-scoped
    # transaction can see across owners (same category as `seed.reset`).
    with transaction() as cur:
        cur.execute(
            "INSERT INTO app_user (id, email, timezone) VALUES (%s, %s, %s) "
            "ON CONFLICT (id) DO NOTHING",
            (_OWNER_B, "rekey-b@example.test", SENTINEL_TZ),
        )
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM profile WHERE user_id IN (%s, %s)", (SENTINEL_USER_ID, _OWNER_B))
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "INSERT INTO profile (user_id, name, height_cm, sex, dob) VALUES (%s,%s,%s,%s,%s)",
            (SENTINEL_USER_ID, _A["name"], _A["height_cm"], _A["sex"], _A["dob"]),
        )
    yield
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM profile WHERE user_id IN (%s, %s)", (SENTINEL_USER_ID, _OWNER_B))
        cur.execute("DELETE FROM app_user WHERE id = %s", (_OWNER_B,))


def test_the_id_column_is_gone(two_profiles: None) -> None:  # noqa: ARG001
    """0005 dropped `id`, and with it the `CHECK (id = 1)` single-row constraint."""
    with transaction() as cur:
        cur.execute(
            "SELECT 1 FROM information_schema.columns "
            "WHERE table_name = 'profile' AND column_name = 'id'"
        )
        assert cur.fetchone() is None, "profile.id survived the re-key"


def test_profile_primary_key_is_the_owner(two_profiles: None) -> None:  # noqa: ARG001
    """The PK must be exactly (user_id) — that is what makes the upsert tenant-safe."""
    with transaction() as cur:
        cur.execute(
            "SELECT a.attname FROM pg_index i "
            "JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey) "
            "WHERE i.indrelid = 'profile'::regclass AND i.indisprimary"
        )
        assert [row[0] for row in cur.fetchall()] == ["user_id"]


def test_each_owner_holds_their_own_profile(two_profiles: None) -> None:  # noqa: ARG001
    """B can have a profile at all — impossible while one global `id = 1` row existed."""
    with tenant_transaction(_OWNER_B) as cur:
        upsert_profile(cur, _OWNER_B, SENTINEL_TZ, _profile_in(_B))
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        a = read_profile(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    with tenant_transaction(_OWNER_B) as cur:
        b = read_profile(cur, _OWNER_B, SENTINEL_TZ)
    assert a["name"] == _A["name"]
    assert b["name"] == _B["name"]
    assert a["height_cm"] == pytest.approx(_A["height_cm"])
    assert b["height_cm"] == pytest.approx(_B["height_cm"])


def test_owner_b_upsert_cannot_clobber_owner_a(two_profiles: None) -> None:  # noqa: ARG001
    """THE regression: B's push must leave every one of A's fields untouched.

    This is the assertion that fails against the pre-0005 `ON CONFLICT (id)` upsert,
    where B's body silently became A's.
    """
    with tenant_transaction(_OWNER_B) as cur:
        upsert_profile(cur, _OWNER_B, SENTINEL_TZ, _profile_in(_B))
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "SELECT name, height_cm, sex, dob FROM profile WHERE user_id = %s",
            (SENTINEL_USER_ID,),
        )
        row = cur.fetchone()
    assert row is not None, "owner A's profile row disappeared"
    assert row[0] == _A["name"]
    assert row[1] == pytest.approx(_A["height_cm"]), "owner B's height overwrote owner A's"
    assert row[2] == _A["sex"], "owner B's sex overwrote owner A's — derived numbers corrupted"
    assert row[3] == _A["dob"], "owner B's dob overwrote owner A's — age-based science corrupted"


def test_a_second_profile_for_the_same_owner_conflicts(two_profiles: None) -> None:  # noqa: ARG001
    """The old single-row invariant, correctly scoped: one profile PER OWNER."""
    with pytest.raises(psycopg.errors.UniqueViolation), tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute("INSERT INTO profile (user_id, name) VALUES (%s, 'dup')", (SENTINEL_USER_ID,))


def test_repeated_upsert_for_one_owner_updates_in_place(two_profiles: None) -> None:  # noqa: ARG001
    """The upsert still UPDATEs its owner's row (and COALESCEs a missing name)."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        upsert_profile(
            cur,
            SENTINEL_USER_ID,
            SENTINEL_TZ,
            ProfileIn(name=None, height_cm=180.0, sex="male", dob=_dob_ms(_A["dob"])),
        )
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute("SELECT name, height_cm FROM profile WHERE user_id = %s", (SENTINEL_USER_ID,))
        row = cur.fetchone()
        cur.execute("SELECT count(*) FROM profile WHERE user_id = %s", (SENTINEL_USER_ID,))
        counted = cur.fetchone()
    assert counted is not None and counted[0] == 1, "the upsert inserted a second row"
    assert row is not None, "owner A's profile row disappeared"
    assert row[0] == _A["name"], "a name-less push must preserve the stored name (COALESCE)"
    assert row[1] == pytest.approx(180.0)
