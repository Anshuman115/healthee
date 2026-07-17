"""Runtime proof that a baseline's 30-day window ends on the OWNER's today.

The sibling of `tests/db/test_day_window_anchoring.py`. That suite pins the SQL
anchors 6.4a replaced (`current_date` -> `USER_TODAY_SQL`); this one pins the
PYTHON anchors the same sweep missed, because they are not SQL and a grep for
`current_date` cannot see them: `baselines.compute_baselines_cur` ended its window
at `date.today()` — the SERVER PROCESS's date (container TZ=UTC), which is nobody's
local day.

Why the whole existing suite stayed green over that bug — the lesson this file
exists to encode: every baseline fixture seeded its days relative to `date.today()`
and asserted against `date.today()`, so the fixture shared the code's assumption and
the test could not fail. The tests below seed relative to `user_today(tz)` — the
owner's day — which is the only anchor that makes the assertion independent of the
code under test.

Auto-skips without a reachable TimescaleDB (same policy as the other integration
tests).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

import pytest

from healthee.analytics.baselines import compute_baseline
from healthee.core.db import admin_connection, tenant_transaction, transaction
from healthee.core.tenancy import user_today
from healthee.db import migrate
from healthee.insights import coach_tools

pytestmark = pytest.mark.integration

# UTC+14 and UTC-11 — 25 h apart, so their local dates ALWAYS differ by one day.
# Whatever the server's own date is, it CANNOT equal both owners' today, so a
# server-anchored window is always wrong for at least one of them. That is what
# makes this suite a real trap rather than a coin flip on the hour it runs at:
# these two are the pair that does the CATCHING.
FAR_EAST_TZ = "Pacific/Kiritimati"
FAR_WEST_TZ = "Pacific/Midway"

_EAST_USER = UUID("88888888-8888-8888-8888-888888888888")
_WEST_USER = UUID("99999999-9999-9999-9999-999999999999")

# The rest of the offset space, so the anchor is pinned across the shapes real
# owners actually have and not only at the extremes: UTC (the degenerate case that
# hides the bug entirely — it is the SERVER's zone, so a broken anchor looks
# perfect), IST (a HALF-HOUR offset, +05:30 — the shape that breaks any code
# assuming whole-hour zones), and New York (NEGATIVE, and the only one here that
# observes DST). Each is a separate owner with its own seeded days, so a fix that
# only worked for whole-hour or only for positive offsets fails here.
_UTC_USER = UUID("88888888-8888-8888-8888-0000000000aa")
_IST_USER = UUID("88888888-8888-8888-8888-0000000000bb")
_NYC_USER = UUID("88888888-8888-8888-8888-0000000000cc")

_OWNERS = (
    (_EAST_USER, FAR_EAST_TZ),
    (_WEST_USER, FAR_WEST_TZ),
    (_UTC_USER, "UTC"),
    (_IST_USER, "Asia/Kolkata"),
    (_NYC_USER, "America/New_York"),
)
_ALL_USERS = tuple(user_id for user_id, _ in _OWNERS)

_WINDOW = 30

# Three DISTINCT marker values, so each boundary is independently observable:
# `min` proves the far edge is excluded and `max` proves today is included. They
# must not share a value — an earlier draft of this file gave the beyond-the-edge
# day the same value as today, and a slipped anchor then swallowed that day and
# refilled both `n` and `max` with it, so the test passed under the very bug it
# was written to catch. Distinct values are what make the trap real.
# EVERY value must satisfy `rhr_daily`'s sentinel filter (`value > 30 AND value
# < 120`, metrics.METRIC_FILTERS) or the row is dropped before the window is even
# applied — a marker outside that range makes the assertion green for the wrong
# reason (an earlier draft used 10.0 and 30.0, and 30.0 fails `> 30` by exactly one
# boundary, so the "excluded" assertions were proving the FILTER worked, not the
# anchor). These four are distinct, in range, and each pins one edge.
_FAR_RHR = 35.0  # at today-31: outside even `query_metric`'s inclusive cutoff
_BEYOND_RHR = 40.0  # at today-30: OUTSIDE a 30-day baseline window
_QUIET_RHR = 50.0  # at today-29 .. today-1
_TODAY_RHR = 90.0  # at today: INSIDE the window


def _seed_owner(cur, user_id: UUID, tz: str) -> None:
    """30 days of rhr ending on THIS owner's local today — never the server's."""
    today = user_today(tz)
    for i in range(1, _WINDOW):
        _insert(cur, user_id, today - timedelta(days=i), _QUIET_RHR)
    _insert(cur, user_id, today, _TODAY_RHR)
    # One day BEYOND the far edge, at its own value: an anchor that slips a day
    # backwards swallows it, which shows up in `min`. Nothing is seeded after today
    # on purpose — `derive` anchors a daily row on the owner's local wake date, so a
    # day in the owner's future is not a state real data can reach, and seeding one
    # would test a scenario the system cannot produce.
    _insert(cur, user_id, today - timedelta(days=_WINDOW), _BEYOND_RHR)
    # One day further still. `query_metric` windows on `day >= today - days`, so
    # today-30 is its legitimate oldest day and today-31 is the first day a
    # backwards-slipped cutoff reaches. Without a marker HERE, a slipped cutoff
    # selects exactly the same rows and the test cannot see it — which is how the
    # first draft of `test_query_metric_*` below passed under the bug it targets.
    _insert(cur, user_id, today - timedelta(days=_WINDOW + 1), _FAR_RHR)


def _insert(cur, user_id: UUID, day: date, value: float) -> None:
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
        "VALUES (%s, %s, 'rhr_daily', %s, '{}'::jsonb) "
        "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
        (user_id, day, value),
    )


@pytest.fixture
def two_zones(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    """Two owners 25 h apart, each seeded around their OWN local today."""
    migrate.apply_migrations()
    with transaction() as cur:
        for user_id, tz in _OWNERS:
            cur.execute(
                "INSERT INTO app_user (id, email, timezone) VALUES (%s, %s, %s) "
                "ON CONFLICT (id) DO UPDATE SET timezone = EXCLUDED.timezone",
                (user_id, f"baseline-{user_id.hex[:8]}@example.test", tz),
            )
    for user_id, tz in _OWNERS:
        with tenant_transaction(user_id) as cur:
            _seed_owner(cur, user_id, tz)
    yield
    # The ADMIN: this cleanup spans every seeded owner (same category as `seed.reset`).
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM derived_daily WHERE user_id = ANY(%s)", (list(_ALL_USERS),))
        cur.execute("DELETE FROM app_user WHERE id = ANY(%s)", (list(_ALL_USERS),))


def test_the_two_zones_never_share_a_date() -> None:
    """The premise: 25 h apart ⇒ their local dates differ at every instant.

    Without this, both owners could resolve to the server's date and the tests
    below would pass under the bug — the "green either way" class that let the
    `date.today()` anchors survive 6.4a unnoticed.
    """
    gap = user_today(FAR_EAST_TZ) - user_today(FAR_WEST_TZ)
    assert gap >= timedelta(days=1), f"the two zones share a local date ({gap}) — premise broken"


@pytest.mark.parametrize(("user_id", "tz"), _OWNERS)
def test_baseline_window_ends_on_the_owners_today(two_zones: None, user_id: UUID, tz: str) -> None:  # noqa: ARG001
    """The owner's CURRENT day is inside their own trailing-30d baseline.

    Under a `date.today()` anchor the far-east owner's today falls one day past the
    window (n=29, median 50.0 — today's rhr of 90 silently dropped), and the
    far-west owner's window ends on their TOMORROW, dropping their oldest day.
    """
    baseline = compute_baseline(user_id, tz, "rhr_daily", window_days=_WINDOW)

    assert baseline.n == _WINDOW, (
        f"{tz}: baseline covers {baseline.n} days, not {_WINDOW} — the window is "
        f"anchored to the server's date ({date.today()}), not the owner's "
        f"({user_today(tz)})"
    )
    assert baseline.max == _TODAY_RHR, f"{tz}: today's value is outside the owner's own window"
    assert baseline.min == _QUIET_RHR, (
        f"{tz}: the window reaches a day past its far edge — it swallowed the "
        f"{_BEYOND_RHR} marker at {user_today(tz) - timedelta(days=_WINDOW)}"
    )
    assert baseline.median == _QUIET_RHR


@pytest.mark.parametrize(("user_id", "tz"), _OWNERS)
def test_baseline_excludes_the_day_before_the_window(
    two_zones: None,  # noqa: ARG001
    user_id: UUID,
    tz: str,
) -> None:
    """The far boundary is the owner's day too — a slipped anchor swallows a day.

    `window_days=2` makes the window exactly [today-1, today], so the seeded quiet
    day at today-2 must NOT appear. An anchor off by one day admits it.
    """
    baseline = compute_baseline(user_id, tz, "rhr_daily", window_days=2)

    assert baseline.n == 2, f"{tz}: 2-day window covers {baseline.n} days"
    assert baseline.max == _TODAY_RHR, f"{tz}: the owner's today is missing from a 2-day window"


@pytest.mark.parametrize(("user_id", "tz"), _OWNERS)
def test_query_metric_windows_on_the_owners_today(
    two_zones: None,  # noqa: ARG001
    user_id: UUID,
    tz: str,
) -> None:
    """The coach's `query_metric` shares the anchor — its cutoff was server-dated.

    Asserted on `min`, not on `latest`: `query_metric` bounds its window only from
    BELOW (`day >= cutoff`), so `latest` is the newest row either way and an
    assertion on it passes under the bug. `min` sits on the moving edge, so it is
    the only thing that can see the cutoff slip — a day of a far-east owner's data
    that the coach must not average in.
    """
    out = coach_tools.query_metric(user_id, tz, "rhr_daily", days=_WINDOW, stat="min")

    assert out["min"] == _BEYOND_RHR, (
        f"{tz}: the coach's {_WINDOW}-day window reaches back past its cutoff "
        f"({user_today(tz) - timedelta(days=_WINDOW)}) and pulled in the "
        f"{_FAR_RHR} marker — its window is anchored to the server's date "
        f"({date.today()}), not the owner's ({user_today(tz)})"
    )


def test_zone_offsets_are_what_this_suite_assumes() -> None:
    """Pin the offset space from `zoneinfo` — never assume a tz-database value.

    Kiribati jumped the date line on 1995-01-01 (skipping 1994-12-31 entirely), and
    a prior agent's test silently asserted a NEGATIVE offset for Kiritimati on the
    strength of a remembered +14:00. Offsets are data, not knowledge: this reads
    what `zoneinfo` says NOW, so a tz-database change fails loudly here rather than
    quietly defanging the suite above.
    """
    now = datetime.now(UTC)
    offsets = {tz: now.astimezone(ZoneInfo(tz)).utcoffset() for _, tz in _OWNERS}

    assert offsets[FAR_EAST_TZ] - offsets[FAR_WEST_TZ] >= timedelta(hours=24), (
        f"the date-line pair is no longer >= 24 h apart: {offsets}"
    )
    assert offsets["UTC"] == timedelta(0)
    # The half-hour offset is the whole point of including IST — assert the :30.
    ist = offsets["Asia/Kolkata"]
    assert ist == timedelta(hours=5, minutes=30), f"Asia/Kolkata is {ist}, not +05:30"
    assert ist % timedelta(hours=1) != timedelta(0), "IST is meant to be a half-hour zone"
    # New York is the negative, DST-observing owner; its offset moves, so assert the
    # RANGE the tz database actually allows rather than a season-specific value.
    assert offsets["America/New_York"] in (timedelta(hours=-5), timedelta(hours=-4))
