"""Seeded-DB tests for the engine's reads: sources, timezone bucketing, baselines,
streak protection, and owner isolation.

Auto-skips without a reachable TimescaleDB (the suite-wide policy).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta
from uuid import UUID

import pytest
from tests.challenges import _seed

from healthee.challenges.series import metric_series, protected_days, recent_value
from healthee.core.db import admin_connection, tenant_transaction, transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate

pytestmark = pytest.mark.integration

IST = "Asia/Kolkata"  # +05:30, no DST
NEW_YORK = "America/New_York"  # −04:00 in March 2026 (EDT)
UTC_TZ = "UTC"

_START = date(2026, 3, 1)
_TODAY = date(2026, 3, 7)


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


# ── sources ──────────────────────────────────────────────────────────────────


def test_derived_metric_series_is_windowed_by_since(clean_db: None) -> None:  # noqa: ARG001
    """Days before ``since`` never reach the engine — the window is the query's job."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur,
            _seed.OWNER,
            "steps_total",
            {date(2026, 2, 25): 1111.0, date(2026, 3, 1): 8000.0, date(2026, 3, 2): 9000.0},
        )
        series = metric_series(cur, _seed.OWNER, SENTINEL_TZ, "steps_total", _START)
    assert series == {date(2026, 3, 1): 8000.0, date(2026, 3, 2): 9000.0}


def test_sleep_duration_reads_the_flag_the_derive_layer_writes(clean_db: None) -> None:  # noqa: ARG001
    """`tst_min` has no `derived_daily` row of its own — only the score row's flags."""
    nights = {date(2026, 3, 1): 402.0, date(2026, 3, 2): 388.0}
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_sleep(cur, _seed.OWNER, nights)
        series = metric_series(cur, _seed.OWNER, SENTINEL_TZ, "tst_min", _START)
    assert series == nights


def test_workouts_shorter_than_ten_minutes_do_not_count(clean_db: None) -> None:  # noqa: ARG001
    """Sub-10-minute bouts are auto-detected movement noise (legacy `_MIN_WORKOUT_S`).

    600 s is the inclusive boundary: a bout of exactly ten minutes is a workout.
    """
    day = datetime(2026, 3, 3, 6, 0, tzinfo=UTC)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_workout(cur, _seed.OWNER, day, 599)
        _seed.seed_workout(cur, _seed.OWNER, day + timedelta(hours=2), 600)
        _seed.seed_workout(cur, _seed.OWNER, day + timedelta(hours=4), 3600)
        series = metric_series(cur, _seed.OWNER, UTC_TZ, "workouts_week", _START)
    assert series == {date(2026, 3, 3): 2.0}


# ── the self-logged cap sources (#61) ────────────────────────────────────────


def test_a_logged_quantity_is_summed_per_local_day(clean_db: None) -> None:  # noqa: ARG001
    """Three coffees on one day is one number: 95 + 63 + 95 = 253 mg."""
    entries = [
        (datetime(2026, 3, 2, 8, 0, tzinfo=UTC), 95.0, "mg"),
        (datetime(2026, 3, 2, 11, 0, tzinfo=UTC), 63.0, "mg"),
        (datetime(2026, 3, 2, 15, 0, tzinfo=UTC), 95.0, "mg"),
    ]
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(cur, _seed.OWNER, "caffeine", entries)
        series = metric_series(
            cur, _seed.OWNER, UTC_TZ, "caffeine_mg", _START, until=date(2026, 3, 3)
        )
    assert series == {_START: 0.0, date(2026, 3, 2): 253.0, date(2026, 3, 3): 0.0}


def test_a_day_with_no_entry_is_a_zero_not_a_gap(clean_db: None) -> None:  # noqa: ARG001
    """The owner is the sensor: "nothing logged" IS the reading, not missing data.

    Absent days must be present as 0 or a cap challenge is unscoreable for the one
    owner who kept it perfectly — they log nothing, so there is nothing to score.
    This is the same reading `analytics/cutoffs.py` takes (a night with no substance
    event is a control night, not a discarded one).
    """
    with tenant_transaction(_seed.OWNER) as cur:
        series = metric_series(
            cur, _seed.OWNER, UTC_TZ, "alcohol_units", _START, until=date(2026, 3, 3)
        )
    assert series == {_START: 0.0, date(2026, 3, 2): 0.0, date(2026, 3, 3): 0.0}


def test_a_device_metric_keeps_its_gaps(clean_db: None) -> None:  # noqa: ARG001
    """The mirror image: `derived_daily` absence means the strap had nothing to say.

    Zero-filling a device metric would score a day with no data as a day of doing
    nothing — the opposite error, and the reason the zero-fill is per-source.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "steps_total", {date(2026, 3, 2): 8000.0})
        series = metric_series(
            cur, _seed.OWNER, UTC_TZ, "steps_total", _START, until=date(2026, 3, 3)
        )
    assert series == {date(2026, 3, 2): 8000.0}


def test_entries_in_another_unit_are_not_converted(clean_db: None) -> None:  # noqa: ARG001
    """ "2 cups" is not 2 mg, and this reader will not pretend it knows the factor.

    A NULL unit IS counted: the client's own default is the canonical one and the
    legacy CLI omitted it, so treating NULL as foreign would drop real intake.
    """
    entries = [
        (datetime(2026, 3, 2, 8, 0, tzinfo=UTC), 95.0, "mg"),
        (datetime(2026, 3, 2, 9, 0, tzinfo=UTC), 60.0, None),
        (datetime(2026, 3, 2, 10, 0, tzinfo=UTC), 2.0, "cups"),
    ]
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(cur, _seed.OWNER, "caffeine", entries)
        series = metric_series(
            cur, _seed.OWNER, UTC_TZ, "caffeine_mg", _START, until=_START + timedelta(days=1)
        )
    assert series[date(2026, 3, 2)] == 155.0


def test_logged_entries_bucket_in_the_owners_zone(clean_db: None) -> None:  # noqa: ARG001
    """22:30 New York on 03-10 is 08:00 IST on 03-11 — the drink belongs to one day.

    Same calendar-date-vs-instant class that shipped two live wrong numbers here.
    """
    entries = [(_AFTER_UTC_MIDNIGHT, 2.0, "units")]
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(cur, _seed.OWNER, "alcohol", entries)
        ist = metric_series(
            cur, _seed.OWNER, IST, "alcohol_units", date(2026, 3, 10), until=date(2026, 3, 11)
        )
        new_york = metric_series(
            cur, _seed.OWNER, NEW_YORK, "alcohol_units", date(2026, 3, 10), until=date(2026, 3, 11)
        )
    assert ist == {date(2026, 3, 10): 0.0, date(2026, 3, 11): 2.0}
    assert new_york == {date(2026, 3, 10): 2.0, date(2026, 3, 11): 0.0}


def test_a_cap_baseline_counts_the_dry_days(clean_db: None) -> None:  # noqa: ARG001
    """Two drinking days in seven ⇒ a weekly baseline of 6 units, not a 3-unit average.

    Without the zero-fill the baseline would be the mean over drinking days only,
    which overstates the owner's habit and would set the cap far too high.
    """
    entries = [
        (datetime(2026, 3, 1, 20, 0, tzinfo=UTC), 2.0, "units"),
        (datetime(2026, 3, 5, 20, 0, tzinfo=UTC), 4.0, "units"),
    ]
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(cur, _seed.OWNER, "alcohol", entries)
        weekly = recent_value(cur, _seed.OWNER, UTC_TZ, "alcohol_units", "weekly", date(2026, 3, 8))
        daily = recent_value(cur, _seed.OWNER, UTC_TZ, "alcohol_units", "daily", date(2026, 3, 8))
    assert weekly == 6.0
    assert daily == round(6 / 7, 1)


# ── timezone bucketing ───────────────────────────────────────────────────────

# Two instants either side of a local midnight. Their local dates:
#   2026-03-10 18:45 UTC → UTC 03-10 · IST 03-11 00:15 · New York 03-10 14:45
#   2026-03-11 02:30 UTC → UTC 03-11 · IST 03-11 08:00 · New York 03-10 22:30
# so the same two workouts bucket differently in all three zones — which is the
# whole point: a hardcoded zone (legacy inlined 'Asia/Kolkata') gets two of them
# wrong, and dropping the conversion gets one wrong.
_BEFORE_IST_MIDNIGHT = datetime(2026, 3, 10, 18, 45, tzinfo=UTC)
_AFTER_UTC_MIDNIGHT = datetime(2026, 3, 11, 2, 30, tzinfo=UTC)


@pytest.mark.parametrize(
    ("tz", "expected"),
    [
        (UTC_TZ, {date(2026, 3, 10): 1.0, date(2026, 3, 11): 1.0}),
        (IST, {date(2026, 3, 11): 2.0}),
        (NEW_YORK, {date(2026, 3, 10): 2.0}),
    ],
)
def test_workout_days_bucket_in_the_owners_zone(
    clean_db: None,  # noqa: ARG001
    tz: str,
    expected: dict[date, float],
) -> None:
    """A boundary instant lands on the right LOCAL day for a +, − and zero offset."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_workout(cur, _seed.OWNER, _BEFORE_IST_MIDNIGHT, 1800)
        _seed.seed_workout(cur, _seed.OWNER, _AFTER_UTC_MIDNIGHT, 1800)
        series = metric_series(cur, _seed.OWNER, tz, "workouts_week", date(2026, 3, 1))
    assert series == expected


def test_the_since_bound_is_also_the_owners_local_date(clean_db: None) -> None:  # noqa: ARG001
    """`since = 2026-03-11` keeps both workouts in IST and drops both in New York.

    In IST both instants are 03-11; in New York both are 03-10. A `since` compared
    against UTC days instead of local ones would keep exactly one of them.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_workout(cur, _seed.OWNER, _BEFORE_IST_MIDNIGHT, 1800)
        _seed.seed_workout(cur, _seed.OWNER, _AFTER_UTC_MIDNIGHT, 1800)
        ist = metric_series(cur, _seed.OWNER, IST, "workouts_week", date(2026, 3, 11))
        new_york = metric_series(cur, _seed.OWNER, NEW_YORK, "workouts_week", date(2026, 3, 11))
    assert ist == {date(2026, 3, 11): 2.0}
    assert new_york == {}


# ── the baseline ─────────────────────────────────────────────────────────────


def test_level_baseline_is_the_trailing_average_before_the_reference_day(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Seven days of 3000/4000 alternating before 03-08 → mean 3428.6 → 3428.6.

    Values: 3000, 4000, 3000, 4000, 3000, 4000, 3000 = 24000 / 7 = 3428.571… The
    day 03-08 ITSELF is excluded — a baseline frozen at adopt must not include the
    challenge's own first day.
    """
    values = {date(2026, 3, 1) + timedelta(days=i): 3000.0 + (i % 2) * 1000 for i in range(7)}
    values[date(2026, 3, 8)] = 99999.0  # the reference day — must not count
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "steps_total", values)
        baseline = recent_value(
            cur, _seed.OWNER, SENTINEL_TZ, "steps_total", "daily", date(2026, 3, 8)
        )
    assert baseline == 3428.6


def test_additive_baseline_is_the_trailing_sum(clean_db: None) -> None:  # noqa: ARG001
    """A weekly target is a total, so its baseline must be a total: 7 × 20 = 140 min."""
    values = {date(2026, 3, 1) + timedelta(days=i): 20.0 for i in range(7)}
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "mvpa_min", values)
        baseline = recent_value(
            cur, _seed.OWNER, SENTINEL_TZ, "mvpa_min", "weekly", date(2026, 3, 8)
        )
    assert baseline == 140.0


def test_no_data_is_none_not_zero(clean_db: None) -> None:  # noqa: ARG001
    """ "We don't know" must be distinguishable from "they did nothing"."""
    with tenant_transaction(_seed.OWNER) as cur:
        assert (
            recent_value(cur, _seed.OWNER, SENTINEL_TZ, "steps_total", "daily", date(2026, 3, 8))
            is None
        )


# ── streak protection (relative to self) ─────────────────────────────────────

# A 210-minute night. For a normal sleeper (median 420) that is 50 % of their norm
# and protected; for a chronic short sleeper (median 220) it is 95 % of theirs — a
# perfectly ordinary night — and NOT protected. Same absolute number, opposite
# verdict: that IS the relative-to-self property this test exists for.
_SHARED_NIGHT_MIN = 210.0


def _seed_nights(cur, median_minutes: float, rough: dict[date, float]) -> None:
    """Thirty nights ending on ``_TODAY`` at ``median_minutes``, plus the rough ones."""
    nights = {_TODAY - timedelta(days=i): median_minutes for i in range(30)}
    nights.update(rough)
    _seed.seed_sleep(cur, _seed.OWNER, nights)


def test_a_normal_sleeper_is_protected_after_a_rough_night(clean_db: None) -> None:  # noqa: ARG001
    """Median 420 ⇒ threshold 252; a 210-minute night is well under it."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_nights(cur, 420.0, {date(2026, 3, 5): _SHARED_NIGHT_MIN})
        protected = protected_days(cur, _seed.OWNER, SENTINEL_TZ, _START, _TODAY)
    assert protected == {date(2026, 3, 5)}


def test_a_chronic_short_sleeper_is_not_protected_every_day(clean_db: None) -> None:  # noqa: ARG001
    """Median 220 ⇒ threshold 132. The SAME 210-minute night is normal for them.

    An absolute threshold would protect this user every single day and make their
    streak meaningless — for exactly the person this product was built for.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_nights(cur, 220.0, {date(2026, 3, 5): _SHARED_NIGHT_MIN})
        protected = protected_days(cur, _seed.OWNER, SENTINEL_TZ, _START, _TODAY)
    assert protected == set()


def test_a_chronic_short_sleeper_is_still_protected_after_a_truly_bad_night(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Median 220 ⇒ threshold 132: 120 minutes is genuinely rough even for them."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_nights(cur, 220.0, {date(2026, 3, 4): 120.0})
        protected = protected_days(cur, _seed.OWNER, SENTINEL_TZ, _START, _TODAY)
    assert protected == {date(2026, 3, 4)}


def test_days_before_the_challenge_started_are_not_returned(clean_db: None) -> None:  # noqa: ARG001
    """Protection applies to the challenge's own window, not the user's whole history."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_nights(cur, 420.0, {date(2026, 2, 20): 100.0, date(2026, 3, 5): 100.0})
        protected = protected_days(cur, _seed.OWNER, SENTINEL_TZ, _START, _TODAY)
    assert protected == {date(2026, 3, 5)}


def test_too_few_nights_means_no_protection_at_all(clean_db: None) -> None:  # noqa: ARG001
    """Four nights is not a norm; inventing a median from it would inflate streaks."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_sleep(
            cur,
            _seed.OWNER,
            {_TODAY - timedelta(days=i): (60.0 if i == 0 else 420.0) for i in range(4)},
        )
        protected = protected_days(cur, _seed.OWNER, SENTINEL_TZ, _START, _TODAY)
    assert protected == set()


# ── owner isolation ──────────────────────────────────────────────────────────


@pytest.fixture
def two_owners(clean_db: None) -> Iterator[None]:  # noqa: ARG001
    """Both owners get rows on the SAME days, at values only they could have."""
    with transaction() as cur:
        cur.execute(
            "INSERT INTO app_user (id, email, timezone) VALUES (%s, %s, %s) "
            "ON CONFLICT (id) DO NOTHING",
            (_seed.OTHER_OWNER, "challenges-owner-b@example.test", SENTINEL_TZ),
        )
    for owner, steps in ((SENTINEL_USER_ID, 4000.0), (_seed.OTHER_OWNER, 19000.0)):
        with tenant_transaction(owner) as cur:
            _seed.seed_metric(cur, owner, "steps_total", {_START: steps})
            _seed.seed_workout(cur, owner, _AFTER_UTC_MIDNIGHT, 1800)
    yield
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM app_user WHERE id = %s", (_seed.OTHER_OWNER,))


@pytest.mark.parametrize(
    ("owner", "steps"), [(SENTINEL_USER_ID, 4000.0), (_seed.OTHER_OWNER, 19000.0)]
)
def test_series_never_pools_across_owners(
    two_owners: None,  # noqa: ARG001
    owner: UUID,
    steps: float,
) -> None:
    """Each owner reads their own number, and their own single workout — never both.

    Both owners hold rows on the same days at the same instants, so only ``user_id``
    can tell them apart: a leak surfaces as a wrong NUMBER (23000 steps, two
    workouts), which is the silent-wrongness shape, not a row-count wobble.
    """
    with tenant_transaction(owner) as cur:
        series = metric_series(cur, owner, SENTINEL_TZ, "steps_total", _START)
        workouts = metric_series(cur, owner, UTC_TZ, "workouts_week", date(2026, 3, 1))
    assert series == {_START: steps}
    assert workouts == {date(2026, 3, 11): 1.0}, "the other owner's workout leaked in"
