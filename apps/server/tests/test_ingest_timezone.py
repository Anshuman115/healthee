"""The owner's timezone comes from the phone, because nothing else knew it.

`app_user.timezone` decides the owner's DAY BOUNDARY — which day a sample belongs
to, when the nightly chain runs, which dates `/api/today` accepts. It was read
everywhere and written nowhere, so every account provisioned from a Supabase
sign-in kept the column default `UTC`.

Measured on the owner's real data before this shipped: **27.9% of samples** fell in
the 00:00–05:30 local window that UTC bucketing files under the PREVIOUS day, and
`/api/today` refused their real local date as "in the future" for five and a half
hours every night.
"""

from __future__ import annotations

from uuid import UUID, uuid4

import pytest

from healthee.core.db import transaction
from healthee.db import migrate
from healthee.ingest.timezone_write import adopt_timezone

pytestmark = [pytest.mark.integration, pytest.mark.usefixtures("owner_sweep")]


def _owner(tz: str = "UTC") -> UUID:
    uid = uuid4()
    with transaction() as cur:
        cur.execute(
            "INSERT INTO app_user (id, email, timezone) VALUES (%s, NULL, %s)",
            (str(uid), tz),
        )
    return uid


def _stored(uid: UUID) -> str:
    with transaction() as cur:
        cur.execute("SELECT timezone FROM app_user WHERE id = %s", (str(uid),))
        row = cur.fetchone()
    assert row is not None
    return row[0]


def test_a_real_zone_is_adopted_and_stored(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    uid = _owner()

    with transaction() as cur:
        adopted = adopt_timezone(cur, uid, "Asia/Kolkata", "UTC")

    assert adopted == "Asia/Kolkata"
    assert _stored(uid) == "Asia/Kolkata"


def test_THE_ADOPTED_ZONE_IS_RETURNED(db: None) -> None:  # noqa: ARG001, N802
    """The return value is the point, not just the write.

    `ingest_helio` buckets the push with what this returns. Writing the new zone but
    returning the old one would leave the first push from a new zone bucketed by the
    old one — the same failure, one push later.
    """
    migrate.apply_migrations()
    uid = _owner()

    with transaction() as cur:
        assert adopt_timezone(cur, uid, "America/New_York", "UTC") == "America/New_York"


class TestWhatIsLeftAlone:
    """Three ways a push says nothing worth acting on."""

    def test_an_absent_timezone_changes_nothing(self, db: None) -> None:  # noqa: ARG001
        migrate.apply_migrations()
        uid = _owner("Asia/Kolkata")

        with transaction() as cur:
            assert adopt_timezone(cur, uid, None, "Asia/Kolkata") == "Asia/Kolkata"

        assert _stored(uid) == "Asia/Kolkata"

    def test_the_same_zone_is_not_rewritten(self, db: None) -> None:  # noqa: ARG001
        migrate.apply_migrations()
        uid = _owner("Asia/Kolkata")

        with transaction() as cur:
            adopted = adopt_timezone(cur, uid, "Asia/Kolkata", "Asia/Kolkata")

        assert adopted == "Asia/Kolkata"

    def test_whitespace_is_not_a_zone(self, db: None) -> None:  # noqa: ARG001
        migrate.apply_migrations()
        uid = _owner()

        with transaction() as cur:
            assert adopt_timezone(cur, uid, "   ", "UTC") == "UTC"

        assert _stored(uid) == "UTC"


def test_AN_UNRESOLVABLE_ZONE_IS_NEVER_STORED(db: None) -> None:  # noqa: ARG001, N802
    """⛔ The one that would break every later read.

    `timezone` is fed to `ZoneInfo` by every day-boundary calculation in the
    product. A name that does not resolve would not fail here — it would fail
    later, everywhere, on reads with nothing to do with ingest.

    The push is NOT rejected for it: a client bug about where the phone is must not
    throw away a body full of measurements that are perfectly good.
    """
    migrate.apply_migrations()
    uid = _owner("Asia/Kolkata")

    with transaction() as cur:
        for bad in ("Mars/Olympus_Mons", "not a zone", "UTC+5:30", "'; DROP TABLE app_user;--"):
            assert adopt_timezone(cur, uid, bad, "Asia/Kolkata") == "Asia/Kolkata"

    assert _stored(uid) == "Asia/Kolkata"


def test_one_owners_move_does_not_touch_another(db: None) -> None:  # noqa: ARG001
    """The multi-tenant assertion: a timezone is a property of a ROW."""
    migrate.apply_migrations()
    mover, other = _owner(), _owner()

    with transaction() as cur:
        adopt_timezone(cur, mover, "Australia/Sydney", "UTC")

    assert _stored(mover) == "Australia/Sydney"
    assert _stored(other) == "UTC"
