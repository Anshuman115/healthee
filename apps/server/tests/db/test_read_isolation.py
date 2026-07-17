"""Runtime proof that the Phase 6.3b read scoping actually isolates owners.

The static guard (`test_tenant_read_scoping.py`) proves every tenant-table
statement MENTIONS `user_id`; it cannot prove the filter is bound to the right
value or lands in the right predicate. This suite runs the real read functions
against a DB holding TWO owners with deliberately different values and asserts
owner A's reads return A's numbers and never B's.

Two owners is the whole point: with one tenant an unscoped `SELECT` returns
exactly the correct rows, so every other test in this suite would pass against a
completely unscoped read layer. B's rows are seeded to values that would be
*impossible* for A (a wildly different RHR, twice the steps), so a leak shows up
as a wrong number and not merely a wrong row count.

Scope: a minimal local two-owner fixture over three representative tables
(`derived_daily`, `sleep_session`, `sample`). The full contract-seed two-tenant
rework and the end-to-end HTTP leakage suite are 6.3c (MULTI_USER.md §10).

Auto-skips without a reachable TimescaleDB (same policy as the other integration
tests).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta
from uuid import UUID

import pytest

from healthee.analytics.baselines import compute_baseline, latest_value
from healthee.analytics.series import daily_series
from healthee.core.db import admin_connection, tenant_transaction, transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.read.common import derived_series, latest_derived, latest_derived_many
from healthee.read.recovery import data_health_payload
from healthee.read.sleep_extras import latest_main_session

pytestmark = pytest.mark.integration

# Owner B — a second real tenant, not a placeholder.
_OTHER_USER = UUID("33333333-3333-3333-3333-333333333333")

# Values chosen so a leak is unmistakable: B's RHR is nowhere near A's, and B has
# double A's steps. An assertion on a NUMBER (not a row count) then localises the
# bug — a wrong owner's data reads as a physiologically impossible jump.
_A_RHR, _B_RHR = 55.0, 91.0
_A_STEPS, _B_STEPS = 6000.0, 12000.0

_DAYS = 10


def _days() -> list[date]:
    """A fixed recent window, anchored in the owner's tz (TZ-boundary safe)."""
    today = date(2999, 6, 15)
    return [today - timedelta(days=i) for i in range(_DAYS)]


def _seed_owner(cur, user_id: UUID, rhr: float, steps: float) -> None:
    """One owner's derived_daily + sleep_session + sample rows over the window."""
    for i, day in enumerate(_days()):
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
            "VALUES (%s, %s, 'rhr_daily', %s, '{}'::jsonb) "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
            (user_id, day, rhr + (i % 3)),
        )
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
            "VALUES (%s, %s, 'steps_total', %s, '{}'::jsonb) "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
            (user_id, day, steps),
        )
    # One main sleep session + one hr sample per owner, at the SAME instants for
    # both owners: identical keys, so only user_id can tell the rows apart.
    start = datetime(2999, 6, 15, 23, 0, tzinfo=UTC)
    cur.execute(
        "INSERT INTO sleep_session "
        "  (user_id, start_ts, end_ts, kind, light_min, deep_min, rem_min, wake_min, score) "
        "VALUES (%s, %s, %s, 'main', %s, 60, 60, 20, %s) "
        "ON CONFLICT (user_id, start_ts) DO NOTHING",
        (user_id, start, start + timedelta(hours=7), int(steps / 100), int(rhr)),
    )
    cur.execute(
        "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, 'hr', %s) "
        "ON CONFLICT (user_id, metric, ts) DO UPDATE SET value = EXCLUDED.value",
        (user_id, start, rhr),
    )


@pytest.fixture
def two_owners(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    """Sentinel owner A + a second owner B, each with distinct seeded values."""
    migrate.apply_migrations()
    # `app_user` is an identity table and carries no RLS policy (0008); each owner's
    # tenant rows then need that owner set, or the policy's WITH CHECK denies them.
    with transaction() as cur:
        cur.execute(
            "INSERT INTO app_user (id, email, timezone) VALUES (%s, %s, %s) "
            "ON CONFLICT (id) DO NOTHING",
            (_OTHER_USER, "owner-b@example.test", SENTINEL_TZ),
        )
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed_owner(cur, SENTINEL_USER_ID, _A_RHR, _A_STEPS)
    with tenant_transaction(_OTHER_USER) as cur:
        _seed_owner(cur, _OTHER_USER, _B_RHR, _B_STEPS)
    yield
    # The ADMIN: this cleanup spans BOTH owners, which no single RLS-scoped
    # transaction can see (same category as `seed.reset`).
    with admin_connection() as conn, conn.cursor() as cur:
        for table in ("sample", "sleep_session", "derived_daily"):
            cur.execute(
                f"DELETE FROM {table} WHERE user_id IN (%s, %s)",  # noqa: S608 — constant
                (SENTINEL_USER_ID, _OTHER_USER),
            )
        cur.execute("DELETE FROM app_user WHERE id = %s", (_OTHER_USER,))


def test_latest_derived_returns_only_the_asked_owner(two_owners: None) -> None:  # noqa: ARG001
    """The single-metric latest read must not see the other owner's newer row."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        a = latest_derived(cur, SENTINEL_USER_ID, "rhr_daily")
    with tenant_transaction(_OTHER_USER) as cur:
        b = latest_derived(cur, _OTHER_USER, "rhr_daily")
    assert a is not None and b is not None
    assert _A_RHR <= a[1] < _B_RHR, f"owner A read {a[1]} — that is owner B's range"
    assert b[1] >= _B_RHR


def test_latest_derived_many_is_scoped(two_owners: None) -> None:  # noqa: ARG001
    """The batched DISTINCT ON loader must partition by owner, not collapse across."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        a = latest_derived_many(cur, SENTINEL_USER_ID, ["rhr_daily", "steps_total"])
    with tenant_transaction(_OTHER_USER) as cur:
        b = latest_derived_many(cur, _OTHER_USER, ["rhr_daily", "steps_total"])
    assert a["steps_total"][1] == _A_STEPS
    assert b["steps_total"][1] == _B_STEPS


def test_derived_series_is_scoped(two_owners: None) -> None:  # noqa: ARG001
    """A series must contain the owner's OWN points only — not a merged 2×-length one."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        a = derived_series(cur, SENTINEL_USER_ID, SENTINEL_TZ, "steps_total", 400)
    assert a, "owner A must get their own series"
    values = {point["value"] for point in a}
    assert values == {_A_STEPS}, f"owner B's steps leaked into A's series: {values}"


def test_daily_series_and_baseline_are_scoped(two_owners: None) -> None:  # noqa: ARG001
    """The analytics series + baseline read A's distribution, never the pooled one.

    A pooled read would land the median between A and B — the silent-wrongness
    failure this whole phase exists to prevent, since the number still looks real.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        series = daily_series(cur, SENTINEL_USER_ID, "rhr_daily")
    assert series and all(v < _B_RHR for v in series.values())

    baseline = compute_baseline(
        SENTINEL_USER_ID, SENTINEL_TZ, "rhr_daily", window_days=90, end_date=max(_days())
    )
    assert baseline.median is not None
    assert baseline.median < _B_RHR, f"baseline median {baseline.median} is pooled across owners"


def test_latest_value_is_scoped(two_owners: None) -> None:  # noqa: ARG001
    """``analytics.latest_value`` opens its own connection — it must still scope."""
    a = latest_value(SENTINEL_USER_ID, "steps_total")
    b = latest_value(_OTHER_USER, "steps_total")
    assert a is not None and b is not None
    assert (a[1], b[1]) == (_A_STEPS, _B_STEPS)


def test_latest_main_session_is_scoped(two_owners: None) -> None:  # noqa: ARG001
    """Both owners have a session at the SAME start_ts — only user_id separates them."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        a = latest_main_session(cur, SENTINEL_USER_ID)
    with tenant_transaction(_OTHER_USER) as cur:
        b = latest_main_session(cur, _OTHER_USER)
    assert a is not None and b is not None
    assert a[6] == int(_A_RHR), "owner A got the other owner's sleep session"
    assert b[6] == int(_B_RHR)


def test_data_health_counts_only_the_owners_samples(two_owners: None) -> None:  # noqa: ARG001
    """Feed freshness is per-owner: B's sample must not make A's feed look alive."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute("DELETE FROM sample WHERE user_id = %s AND metric = 'hr'", (SENTINEL_USER_ID,))
        payload = data_health_payload(cur, SENTINEL_USER_ID)
    hr = next(item for item in payload["items"] if item["metric"] == "hr")
    assert hr["last_iso"] is None, "owner B's hr sample leaked into owner A's data-health"
    assert hr["status"] == "unavailable"
