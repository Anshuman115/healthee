"""Runtime proof that a "last N days" window anchors to the OWNER's local today.

6.3b made every timezone *conversion* per-user (`AT TIME ZONE %s`), but left the
window *anchors* as SQL `current_date` — which resolves in the DATABASE SESSION's
timezone (UTC), not the owner's. Every owner's window was therefore pinned to the
database's date, and two owners on opposite sides of the world got the SAME anchor.
6.4a replaced every anchor with `core.tenancy.USER_TODAY_SQL`; this suite is what
holds that closed.

Why two owners 25 hours apart: `Pacific/Kiritimati` (UTC+14) and `Pacific/Midway`
(UTC-11) are 25 h apart, so their local dates differ by exactly one day at EVERY
instant — there is no hour of the day at which this suite degenerates into
comparing an owner against themselves. That is the property that makes it a real
mutation trap: under `current_date` both owners resolve to the same anchor, so
whichever owner's local date differs from the database's reads the wrong window,
and at least one of them always does. `test_the_two_zones_never_share_a_date`
pins the premise, so a future tz-database change can't quietly defang the suite.

Each owner's rows are seeded RELATIVE TO THEIR OWN local today and at values only
they could have, so a wrong anchor surfaces as a missing/extra boundary day rather
than a row-count wobble.

Auto-skips without a reachable TimescaleDB (same policy as the other integration
tests).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import date, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

import pytest

from healthee.core.db import admin_connection, tenant_transaction, transaction
from healthee.core.tenancy import user_today
from healthee.db import migrate
from healthee.read.common import derived_series, derived_series_many
from healthee.read.history import history
from healthee.read.sleep_page import sleep_page

pytestmark = pytest.mark.integration

# UTC+14 and UTC-11 — 25 h apart, so their local dates ALWAYS differ by one day.
FAR_EAST_TZ = "Pacific/Kiritimati"
FAR_WEST_TZ = "Pacific/Midway"

_EAST_USER = UUID("44444444-4444-4444-4444-444444444444")
_WEST_USER = UUID("55555555-5555-5555-5555-555555555555")

# Per-owner marker values — a leak or a mis-anchor reads as the wrong number.
_EAST_STEPS, _WEST_STEPS = 7000.0, 13000.0

# The window every test asks for. `day > (owner_today - _WINDOW)`, so the day at
# exactly `owner_today - _WINDOW` is the EXCLUDED boundary and the day after it is
# the first INCLUDED one — the pair that pins the anchor to a single day.
_WINDOW = 3

_OWNERS = ((_EAST_USER, FAR_EAST_TZ, _EAST_STEPS), (_WEST_USER, FAR_WEST_TZ, _WEST_STEPS))


def _expected_days(tz: str) -> list[date]:
    """The days `derived_series(days=_WINDOW)` must return for an owner in ``tz``."""
    today = user_today(tz)
    return [today - timedelta(days=i) for i in range(_WINDOW - 1, -1, -1)]


def _seeded_days(tz: str) -> list[date]:
    """Seeded window: the excluded boundary day plus every day that must come back."""
    return [user_today(tz) - timedelta(days=_WINDOW), *_expected_days(tz)]


def _seed_owner(cur, user_id: UUID, tz: str, steps: float) -> None:
    """One owner's rows, dated in THEIR local calendar, spanning the boundary."""
    for day in _seeded_days(tz):
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
            "VALUES (%s, %s, 'steps_total', %s, '{}'::jsonb) "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
            (user_id, day, steps),
        )
    _seed_naps(cur, user_id, tz)


def _local_midnight(tz: str, day: date) -> datetime:
    """The absolute instant at which ``day`` begins on the owner's wall clock."""
    return datetime(day.year, day.month, day.day, tzinfo=ZoneInfo(tz))


def _seed_naps(cur, user_id: UUID, tz: str) -> None:
    """Two naps straddling the owner's local window-start midnight by 30 minutes.

    `sleep_page`'s nap read compares a **timestamptz** against the window start, so
    the boundary has to be an absolute instant in the owner's zone. Half an hour
    either side of it is far tighter than any timezone offset, so an anchor that
    resolves in the wrong zone puts both naps on the same side.
    """
    boundary = _local_midnight(tz, user_today(tz) - timedelta(days=_WINDOW))
    for offset_min, tag in ((-30, "before"), (+30, "after")):
        start = boundary + timedelta(minutes=offset_min)
        cur.execute(
            "INSERT INTO sleep_session "
            "  (user_id, start_ts, end_ts, kind, light_min, deep_min, rem_min, wake_min, score) "
            "VALUES (%s, %s, %s, 'nap', 20, 0, 0, 0, %s) "
            "ON CONFLICT (user_id, start_ts) DO NOTHING",
            (user_id, start, start + timedelta(minutes=20), 1 if tag == "after" else 0),
        )


@pytest.fixture
def two_zones(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    """Two owners 25 h apart, each seeded around their OWN local window boundary."""
    migrate.apply_migrations()
    # `app_user` has no RLS policy (0008 — identity); each owner's tenant rows are
    # seeded under that owner, or the policy's WITH CHECK denies the write.
    with transaction() as cur:
        for user_id, tz, _ in _OWNERS:
            cur.execute(
                "INSERT INTO app_user (id, email, timezone) VALUES (%s, %s, %s) "
                "ON CONFLICT (id) DO UPDATE SET timezone = EXCLUDED.timezone",
                (user_id, f"owner-{tz.split('/')[1].lower()}@example.test", tz),
            )
    for user_id, tz, steps in _OWNERS:
        with tenant_transaction(user_id) as cur:
            _seed_owner(cur, user_id, tz, steps)
    yield
    # The ADMIN: this cleanup spans BOTH owners (same category as `seed.reset`).
    with admin_connection() as conn, conn.cursor() as cur:
        for table in ("sleep_session", "derived_daily"):
            cur.execute(
                f"DELETE FROM {table} WHERE user_id IN (%s, %s)",  # noqa: S608 — constant
                (_EAST_USER, _WEST_USER),
            )
        cur.execute("DELETE FROM app_user WHERE id IN (%s, %s)", (_EAST_USER, _WEST_USER))


def test_the_two_zones_never_share_a_date() -> None:
    """The suite's premise: 25 h apart ⇒ the local dates differ at every instant.

    The gap is one day for most of the UTC day and two around the hours when the
    25 h span straddles two local midnights; the load-bearing part is that it is
    NEVER zero. Without that, the tests below could silently pass by comparing an
    owner against themselves — the "green either way" class of test that let the
    `current_date` anchors survive 6.3b unnoticed.
    """
    gap = user_today(FAR_EAST_TZ) - user_today(FAR_WEST_TZ)
    assert gap >= timedelta(days=1), f"the two zones share a local date ({gap}) — premise broken"


@pytest.mark.parametrize(("user_id", "tz", "steps"), _OWNERS)
def test_derived_series_anchors_to_the_owners_today(
    two_zones: None,  # noqa: ARG001
    user_id: UUID,
    tz: str,
    steps: float,
) -> None:
    """Each owner's window runs to THEIR today — not the database's, not the other's."""
    with tenant_transaction(user_id) as cur:
        series = derived_series(cur, user_id, tz, "steps_total", _WINDOW)

    got = [date.fromisoformat(point["date"]) for point in series]
    assert got == _expected_days(tz), (
        f"{tz}: window anchored to the wrong day — expected {_expected_days(tz)}, got {got}"
    )
    assert {point["value"] for point in series} == {steps}


@pytest.mark.parametrize(("user_id", "tz", "steps"), _OWNERS)
def test_derived_series_many_anchors_to_the_owners_today(
    two_zones: None,  # noqa: ARG001
    user_id: UUID,
    tz: str,
    steps: float,  # noqa: ARG001 — the parametrised owner tuple is shared
) -> None:
    """The batched Today-sparkline loader shares the single-metric anchor."""
    with tenant_transaction(user_id) as cur:
        series = derived_series_many(cur, user_id, tz, ["steps_total"], _WINDOW)

    got = [date.fromisoformat(point["date"]) for point in series["steps_total"]]
    assert got == _expected_days(tz)


@pytest.mark.parametrize(("user_id", "tz", "steps"), _OWNERS)
def test_history_anchors_to_the_owners_today(
    two_zones: None,  # noqa: ARG001
    user_id: UUID,
    tz: str,
    steps: float,  # noqa: ARG001 — the parametrised owner tuple is shared
) -> None:
    """`/api/history`'s series gained `tz` in 6.4a — it must use it as the anchor."""
    with tenant_transaction(user_id) as cur:
        payload = history(cur, user_id, tz, "steps_total", days=_WINDOW)

    got = [date.fromisoformat(point["day"]) for point in payload["series"]]
    assert got == _expected_days(tz)


@pytest.mark.parametrize(("user_id", "tz", "steps"), _OWNERS)
def test_nap_window_boundary_is_an_instant_in_the_owners_zone(
    two_zones: None,  # noqa: ARG001
    user_id: UUID,
    tz: str,
    steps: float,  # noqa: ARG001 — the parametrised owner tuple is shared
) -> None:
    """The timestamptz-vs-date trap: the nap cutoff must be the owner's local midnight.

    Comparing `start_ts` (timestamptz) against a bare date makes Postgres cast that
    date at the SESSION timezone — the same bug wearing a different hat. Only the
    nap 30 min AFTER the owner's local boundary may come back.
    """
    with tenant_transaction(user_id) as cur:
        naps = sleep_page(cur, user_id, tz, days=_WINDOW)["naps"]

    boundary = _local_midnight(tz, user_today(tz) - timedelta(days=_WINDOW))
    starts = sorted(datetime.fromisoformat(nap["start_iso"]) for nap in naps)
    assert starts == [boundary + timedelta(minutes=30)], (
        f"{tz}: nap window boundary resolved in the wrong zone — got {starts}, "
        f"expected only the nap after {boundary}"
    )
