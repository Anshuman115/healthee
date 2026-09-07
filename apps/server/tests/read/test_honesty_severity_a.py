"""The severity-A findings of ``docs/BACKEND_AUDIT.md``, one property per defect.

Each test asserts the PROPERTY the defect violated, not the shape of the fix. A shape
assertion passes as soon as a key exists, which is how a key that always says the same
thing survives a suite — and every one of these shipped past a green suite once already.

The paired mutations live in ``tests/read/mutations.sh``: each finding below has one that
puts the defect back and must go red here.

A1  a row carrying no SEE ships NO error bar. Absent means absent — the read layer used
    to default it to 5.6, the exact constant #108 deleted for being unsourced.
A2  an unrecorded sex is not "male", and is not SPENT on the age/sex median.
A7  ``baseline_30d`` covers thirty days, refuses under a floor, and ships its count.
A8  a recovery signal does not publish a direction from two days of history.
A9  a past workout is scored against ITS OWN day's resting heart rate.
A10 the session HR profile is one element per MINUTE, so TRIMP and zone minutes mean
    what they are called.
A11 ``/api/history``'s plain series closes at the owner's today.
A13 a missing intensity breakdown is not zero moderate and zero vigorous minutes.

A5, A6 and A12 are the sleep chain and live in ``test_honesty_severity_a_sleep.py``;
A13's uncounted-workout half is a derive-layer concern and lives with the calorie tests
(``tests/derive/test_calorie_weight_staleness.py``).
"""

from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta

import pytest
from tests.read._severity_a_seed import (
    OWN_DAY_HRMAX,
    OWN_DAY_RHR,
    TODAY_HRMAX,
    TODAY_RHR,
    ZONE,
    daily,
    reset,
)

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.read.fitness import cardio_load_payload, mvpa_payload
from healthee.read.history import history_series
from healthee.read.mvpa_week import mvpa_week
from healthee.read.recovery import recovery_signals
from healthee.read.vo2max import vo2max_payload
from healthee.read.workout import workout_detail

pytestmark = pytest.mark.integration

# ── A1 / A2. the vo2max payload does not invent an error bar or a sex ────────


@pytest.mark.usefixtures("db")
def test_a_row_with_no_recorded_error_ships_no_error_bar() -> None:
    """No `see_ml_kg_min` flag, no band on the wire.

    The default was `5.6` — the unsourced constant `derive/vo2max.py` records deleting in
    #108 — so EVERY row carried a band whether or not one had been computed, and
    `see_source` sat null beside it. Swapping the default for the correct 5.075 would have
    been the same defect in better taste; the point is that absent means absent.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        daily(cur, today, "vo2max_estimate", 43.0, {"age_years": 35, "sex": "male"})
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert payload["estimate"] == 43.0
    assert payload["see_ml_kg_min"] is None
    assert payload["see_source"] is None


@pytest.mark.usefixtures("db")
def test_a_recorded_error_still_ships_with_its_instrument() -> None:
    """The other half of A1: removing the default must not remove the figure."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        daily(
            cur,
            today,
            "vo2max_estimate",
            43.0,
            {"age_years": 35, "sex": "male", "see_ml_kg_min": 2.95, "see_source": "Carrier 2023"},
        )
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert payload["see_ml_kg_min"] == 2.95
    assert payload["see_source"] == "Carrier 2023"


@pytest.mark.usefixtures("db")
def test_an_unrecorded_sex_is_not_male_and_is_not_spent_on_the_median() -> None:
    """`sex` defaulted to "male" and was SHIPPED and SPENT.

    Spent is the serious half: `median_for_age` and `delta_from_median` were computed
    against the male reference distribution for an owner whose sex nobody recorded, and
    the app draws both. Line 160's `age or 0` is safe only because the median is fenced on
    a truthy age; the fence is the refusal, so it now guards both inputs.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        daily(cur, today, "vo2max_estimate", 43.0, {"age_years": 35})
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert payload["sex"] is None
    assert payload["median_for_age"] is None
    assert payload["delta_from_median"] is None


@pytest.mark.usefixtures("db")
def test_a_recorded_sex_still_earns_its_reference_median() -> None:
    """The fence must not become a refusal for owners who DID answer."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        daily(cur, today, "vo2max_estimate", 43.0, {"age_years": 35, "sex": "female"})
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert payload["sex"] == "female"
    assert payload["median_for_age"] is not None
    assert payload["delta_from_median"] is not None


# ── A7. the thirty-day baseline is thirty days, floored, and counted ─────────


@pytest.mark.usefixtures("db")
def test_the_load_baseline_is_withheld_under_its_floor_and_says_how_short() -> None:
    """It had no minimum: with two rows the "30-day baseline" was one day's value.

    The app draws `load / baseline_30d` as a ratio, which is why an absent floor is not a
    cosmetic problem — today's load was expressed as a multiple of a single day.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        for back in range(3):
            daily(cur, today - timedelta(days=back), "cardio_load", 50.0)
        payload = cardio_load_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert payload["load"] == 50.0
    assert payload["baseline_30d"] is None
    assert payload["baseline_30d_n"] == 2
    assert payload["baseline_30d_min_n"] == 5


@pytest.mark.usefixtures("db")
def test_the_load_baseline_window_is_thirty_days_not_thirty_six() -> None:
    """The window read `as_of - 35`. Two keys say thirty; the window said thirty-six.

    A day 30 back is INSIDE a 30-day window ending today and a day 31 back is not, so a
    row planted at day 31 with an unmistakable value must not move the mean.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        for back in range(30):
            daily(cur, today - timedelta(days=back), "cardio_load", 50.0)
        daily(cur, today - timedelta(days=31), "cardio_load", 5000.0)
        payload = cardio_load_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert payload["baseline_30d"] == 50.0
    assert payload["baseline_30d_n"] == 29
    assert len(payload["trend_30d"]) == 30


# ── A8. no verdict from two mornings ─────────────────────────────────────────


@pytest.mark.usefixtures("db")
def test_two_days_of_resting_heart_rate_publish_no_direction() -> None:
    """MAD over two points is the half-distance, so the z was finite and shipped.

    `_sleep_signal` in the same function has always required five days. One payload was
    running three signals under two admission rules.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        daily(cur, today, "rhr_daily", 62.0)
        daily(cur, today - timedelta(days=1), "rhr_daily", 54.0)
        payload = recovery_signals(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is None


@pytest.mark.usefixtures("db")
def test_five_days_earn_a_direction_and_it_ships_its_count() -> None:
    """The floor must admit as well as refuse, and `n` must reach the wire."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        for back, value in enumerate((62.0, 54.0, 55.0, 56.0, 54.0, 55.0)):
            daily(cur, today - timedelta(days=back), "rhr_daily", value)
        payload = recovery_signals(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    signal = next(s for s in payload["signals"] if s["name"] == "Resting HR")
    assert signal["n"] >= 5
    assert signal["direction"] in ("favorable", "unfavorable", "neutral")
    # One signal, so the sentence must not claim agreement across markers.
    assert payload["total"] == 1
    assert payload["summary"].startswith("One recovery signal")


# ── A9 / A10. the session is scored against its own day, per minute ──────────


def _seed_past_workout(cur, session_day: date, today: date) -> datetime:
    """A workout on ``session_day`` with per-second HR, and two very different reserves."""
    start = datetime.combine(session_day, time(9, 0), tzinfo=ZONE).astimezone(UTC)
    cur.execute(
        "INSERT INTO workout (user_id, start_ts, sport, duration_s, avg_hr, max_hr) "
        "VALUES (%s, %s, 1, 600, 150, 165)",
        (SENTINEL_USER_ID, start),
    )
    # Ten minutes, six samples a minute — the cadence that multiplied TRIMP by six.
    rows = [(SENTINEL_USER_ID, start + timedelta(seconds=10 * i), "hr", 150.0) for i in range(60)]
    cur.executemany("INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, %s, %s)", rows)
    daily(
        cur,
        session_day,
        "cardio_load",
        40.0,
        {"hrmax": OWN_DAY_HRMAX, "rhr": OWN_DAY_RHR},
    )
    daily(cur, today, "cardio_load", 40.0, {"hrmax": TODAY_HRMAX, "rhr": TODAY_RHR})
    # TRIMP needs a sex-specific coefficient; without one the metric withholds and the
    # per-minute assertion below would pass for the wrong reason.
    cur.execute(
        "INSERT INTO profile (user_id, sex) VALUES (%s, 'male') "
        "ON CONFLICT (user_id) DO UPDATE SET sex = 'male'",
        (SENTINEL_USER_ID,),
    )
    return start


@pytest.mark.usefixtures("db")
def test_a_past_workout_is_scored_against_its_own_days_reserve() -> None:
    """The future leak: `cardio_load_payload` defaulted to the owner's TODAY.

    `hrmax` and `rhr` are the whole Karvonen reserve, so a past session's zones,
    intensity, dominant zone and TRIMP were computed from a resting heart rate measured
    after it. `avg_pct_hrmax` is the visible tell — 150 bpm is 79% of this session's own
    190 and 100% of today's 150.
    """
    today = user_today(SENTINEL_TZ)
    session_day = today - timedelta(days=40)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        start = _seed_past_workout(cur, session_day, today)
        detail = workout_detail(cur, SENTINEL_USER_ID, SENTINEL_TZ, start.isoformat())

    assert detail["metrics"]["avg_pct_hrmax"] == round(100 * 150 / OWN_DAY_HRMAX)


@pytest.mark.usefixtures("db")
def test_the_session_hr_profile_is_one_point_per_minute() -> None:
    """`trimp_total`'s contract is "each element is taken to be one minute".

    The profile selected raw samples, so at six samples a minute the session TRIMP and
    every "zone minute" were six times what they should have been. Ten minutes of samples
    must produce ten elements, and no two of them may claim the same offset.
    """
    today = user_today(SENTINEL_TZ)
    session_day = today - timedelta(days=40)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        start = _seed_past_workout(cur, session_day, today)
        detail = workout_detail(cur, SENTINEL_USER_ID, SENTINEL_TZ, start.isoformat())

    series = detail["hr_series"]
    assert len(series) == 10
    offsets = [point["min"] for point in series]
    assert offsets == sorted(set(offsets))
    # Zone buckets are minutes, so they cannot sum past the minutes recorded.
    assert sum(detail["zones"]) <= 10


# ── A11. the plain history series closes at the owner's today ────────────────


@pytest.mark.usefixtures("db")
def test_a_future_dated_row_never_reaches_a_history_series() -> None:
    """Lower bound only, while both siblings in the same file close.

    `_flag_points` filters `day <= today` and `_weight_points` binds it in SQL. The path
    that serves every `derived_daily` metric — and therefore every dated panel on every
    screen — did not.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        daily(cur, today, "rhr_daily", 55.0)
        daily(cur, today + timedelta(days=3), "rhr_daily", 99.0)
        series = history_series(cur, SENTINEL_USER_ID, SENTINEL_TZ, ["rhr_daily"], 30)

    days = [point["day"] for point in series["rhr_daily"]]
    assert days == [today.isoformat()]


# ── A13. a missing breakdown is not a measured zero ──────────────────────────


@pytest.mark.usefixtures("db")
def test_a_day_with_no_intensity_breakdown_makes_the_weeks_split_unknown() -> None:
    """The flags were coalesced to 0 in SQL — the flag-level twin of the row-level gap.

    `mvpa_week`'s own docstring is careful that an owner with no `mvpa_min` row "has not
    been measured as still, they have not been measured". One level down, the same
    absence was filled in with a number.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        daily(cur, today, "mvpa_min", 30.0)  # no moderate/vigorous flags
        week = mvpa_week(cur, SENTINEL_USER_ID, today)
        payload = mvpa_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert week is not None
    assert week.mvpa_min == 30  # the stored total is unaffected
    assert week.moderate_min is None
    assert week.vigorous_min is None
    assert payload is not None
    assert payload["week_moderate_min"] is None
    assert payload["daily"][0]["moderate_min"] is None


@pytest.mark.usefixtures("db")
def test_a_recorded_breakdown_still_sums() -> None:
    """The absence must be about the missing flags, not about the metric."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        daily(cur, today, "mvpa_min", 30.0, {"moderate": 22, "vigorous": 4})
        week = mvpa_week(cur, SENTINEL_USER_ID, today)

    assert week is not None
    assert week.moderate_min == 22
    assert week.vigorous_min == 4
