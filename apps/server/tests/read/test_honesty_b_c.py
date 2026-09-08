"""The severity-B and severity-C findings of ``docs/BACKEND_AUDIT.md``, one per defect.

Each test asserts the PROPERTY the defect violated, not the shape of the fix — a shape
assertion passes as soon as a key exists, which is how a key that always says the same
thing survives a suite. The paired mutations live in ``tests/read/mutations.sh`` and each
one puts a defect back and must go red here.

B2  ``median_for_age`` is null when there is none, never a constant, and the projection
    that depends on it is withheld rather than computed from a stand-in.
B3  the projection ships its bound, its gap fraction and D5's "never a promise" caveat,
    so it reads as a range rather than a forecast.
B4  a 15-minute step bucket carries steps and nothing else — no population-stride
    distance, no hardcoded zero calories.
C2  a night's total sleep time and a nap's time in bed have DIFFERENT names.
C3  ``/api/sleep`` carries the server's own sleep need and debt, so no client has to
    invent one.
C5  a daily card names the instrument that produced it, and says when a counter was read
    mid-day.
C6  the calorie card carries the MET-model/device split and a note id.
D-c the sleep signal says which of its two limbs produced its verdict.
D-d the workout pace says it is measured over elapsed time.

C1 is already closed by the severity-A sleep work (``_stub_night`` sends ``stages: None``)
and is asserted there. C4, C7 and C8 are derive-layer concerns and live in
``tests/derive/test_sleep_need_inputs.py`` and ``tests/derive/test_unworn_day.py``.
"""

from __future__ import annotations

from datetime import UTC, datetime, time, timedelta

import pytest
from tests.read._severity_a_seed import ZONE, daily, night, reset

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.derive.activity import derive_daily_activity
from healthee.derive.freshness import COUNTER_MID_DAY, NO_AGE_MEDIAN
from healthee.read.fitness_plan import fitness_plan_payload, projected_gain
from healthee.read.recovery_signals import recovery_signals
from healthee.read.sleep_page import sleep_page
from healthee.read.today_series import secondary_cards, step_buckets
from healthee.read.workout import workout_detail

pytestmark = pytest.mark.integration

# The Jurca inputs a VO2max row needs before `read/vo2max.py` will report an estimate.
_VO2MAX_FLAGS = {"age_years": 35, "sex": "male", "see_ml_kg_min": 5.075, "see_source": "jurca"}


# ── B2 / B3. the VO2max-raising plan ─────────────────────────────────────────


@pytest.mark.usefixtures("db")
def test_the_plan_withholds_its_projection_when_there_is_no_age_median() -> None:
    """No age or sex on the row → no median, no gap, no projection — and no ``41``.

    ``read/vo2max.py`` returns ``median_for_age: None`` on purpose (#A2). The plan used to
    coalesce that considered null to a bare ``41`` and ship it back out under the SAME key
    name, so one response said null in one block and 41.0 in another. A1's lesson is that
    the fix for a fabricated constant is not a better constant.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        daily(cur, today, "vo2max_estimate", 38.0, {"see_ml_kg_min": 5.075})  # no age, no sex
        plan = fitness_plan_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert plan is not None, "the weekly Rx does not depend on a median and must still ship"
    assert plan["median_for_age"] is None
    assert plan["gain"] is None
    assert plan["projected_12wk"] is None
    assert plan["withheld"] is not None
    assert plan["withheld"]["reason"] == NO_AGE_MEDIAN
    assert plan["plan"]["zone2_target_min"] == 90
    # Nothing anywhere in the payload is the old stand-in, under any key.
    assert 41 not in [plan["median_for_age"], plan["projected_12wk"], plan["gain"]]


@pytest.mark.usefixtures("db")
def test_the_projection_ships_its_bound_and_refuses_to_promise() -> None:
    """The floor, the cap, the gap fraction and D5's caveat travel WITH the number.

    [[vo2max]] licenses ``clamp(0.4 × gap, 2, 5)`` only "as an estimate of typical
    response, never a promise", shown "if you follow the plan". The payload shipped the
    number bare: no caveat, no band, no provenance for the bound. A reader could not tell
    a bounded typical response from a forecast.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        daily(cur, today, "vo2max_estimate", 30.0, _VO2MAX_FLAGS)
        plan = fitness_plan_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert plan is not None
    assert plan["gain_floor"] == 2.0
    assert plan["gain_cap"] == 5.0
    assert plan["gain_gap_fraction"] == 0.4
    assert plan["weeks"] == 12
    assert plan["withheld"] is None
    assert [c["reason"] for c in plan["caveats"]] == ["typical_response_not_a_promise"]
    assert "not a promise" in plan["caveats"][0]["message"]
    assert plan["caveats"][0]["note_id"] == "vo2max"
    # The projection IS the current estimate plus the bounded gain, not a second number.
    assert plan["projected_12wk"] == round(plan["current"] + plan["gain"], 1)


def test_the_projected_gain_is_the_corpus_formula() -> None:
    """``clamp(0.4 × gap, 2, 5)`` — known values, no database. [[vo2max]].

    Three points, one per branch: the cap (a large deficit), the linear middle, and the
    floor (an owner at or above their age median, where the headroom term is zero).
    """
    assert projected_gain(20.0, 45.0) == 5.0  # 0.4 × 25 = 10 → capped
    assert projected_gain(40.0, 48.0) == 3.2  # 0.4 × 8, inside the band
    assert projected_gain(50.0, 45.0) == 2.0  # no deficit → the floor is the whole claim


# ── B4. the step-bucket strip ────────────────────────────────────────────────


@pytest.mark.usefixtures("db")
def test_a_step_bucket_carries_steps_and_nothing_it_did_not_measure() -> None:
    """No ``distance_m`` from a population stride, no ``calories: 0``.

    ``SUM(value) * 0.78`` was a second definition of stride — the canonical one is
    ``0.414 × the owner's height`` and REFUSES without a profile — and it implied a 188 cm
    owner, so the strip could not sum to the distance card above it. ``calories`` was the
    literal zero for a quantity nobody computed.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        noon = datetime.combine(today, time(12, 0), tzinfo=ZONE).astimezone(UTC)
        for i in range(4):
            cur.execute(
                "INSERT INTO sample (user_id, ts, metric, value) "
                "VALUES (%s, %s, 'steps_per_minute', %s)",
                (SENTINEL_USER_ID, noon + timedelta(minutes=i), 30.0),
            )
        buckets = step_buckets(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert buckets, "the seeded minutes must produce a bucket"
    for bucket in buckets:
        assert set(bucket) == {"time", "bucket", "steps"}, bucket


# ── C2. one name, one quantity ───────────────────────────────────────────────


@pytest.mark.usefixtures("db")
def test_a_night_and_a_nap_do_not_share_one_name_for_two_quantities() -> None:
    """The night reports ``tst_min``; the nap reports ``tib_min`` AND ``tst_min``.

    Both used to be keyed ``duration_min`` in one ``/api/sleep`` payload — total sleep
    time on a night, wall-clock time in bed on a nap — with nothing on the wire saying
    which. The nap's own docstring claimed it was "shaped exactly like a night"; duration
    was the one field it was not.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        night(cur, today, staged=True)
        nap_start = datetime.combine(today, time(14, 0), tzinfo=ZONE).astimezone(UTC)
        cur.execute(
            "INSERT INTO sleep_session "
            "(user_id,start_ts,end_ts,kind,rem_min,light_min,deep_min,wake_min,stages) "
            "VALUES (%s,%s,%s,'nap',0,20,5,15,'[]'::jsonb)",
            (SENTINEL_USER_ID, nap_start, nap_start + timedelta(minutes=40)),
        )
        page = sleep_page(cur, SENTINEL_USER_ID, SENTINEL_TZ, days=7)

    night_row = page["nights"][0]
    assert "duration_min" not in night_row
    assert night_row["tst_min"] == 420  # light + deep + rem, wake excluded

    nap = page["naps"][0]
    assert "duration_min" not in nap
    assert nap["tib_min"] == 40  # wall clock, wake included
    assert nap["tst_min"] == 25  # light + deep + rem
    assert nap["tib_min"] > nap["tst_min"], "the two names must not be able to collapse"


# ── C3. the Sleep tab is sent the need it used to invent ─────────────────────


@pytest.mark.usefixtures("db")
def test_the_sleep_page_carries_the_servers_own_need_and_debt() -> None:
    """``/api/sleep`` sends ``sleep_debt``, from the same rows the Today page reads.

    It sent neither, so the Sleep tab measured its shortfall against a client constant of
    480 minutes flat while the Today tab reported the age-selected need — two definitions
    of one metric across two tabs of one app.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        night(cur, today, staged=True)
        daily(cur, today, "sleep_need_min", 450.0, {"basis": "NSF2015", "age": 70})
        daily(cur, today, "sleep_debt_min", 240.0, {"window_nights": 14, "nights": 9})
        page = sleep_page(cur, SENTINEL_USER_ID, SENTINEL_TZ, days=7)

    debt = page["sleep_debt"]
    assert debt is not None
    # 450, the over-65 band — NOT the 480 the client used to assume for everyone.
    assert debt["need_min"] == 450
    assert debt["debt_min"] == 240
    assert debt["window_nights"] == 14


# ── C5 / C6. the card names its instrument ───────────────────────────────────


@pytest.mark.usefixtures("db")
def test_a_daily_card_names_the_instrument_that_produced_it() -> None:
    """``provenance`` forwards what the derive layer recorded, per metric.

    ``derive/device_totals.py`` exists to choose between two step instruments and stamps
    the answer in ``flags.source``; ``derive/energy.py`` records how much of a day's
    calories came from the MET model and how much from the device's workout figure. The
    read layer discarded both, so #121's whole point stopped at the database.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        daily(
            cur,
            today,
            "steps_total",
            9000.0,
            {"source": "strap_0x16", "steps_per_minute_sum": 8100, "sample_minutes": 640},
        )
        daily(cur, today, "total_calories", 2400.0, {"bmr": 1700, "workout_cal": 310})
        cards = {c["metric"]: c for c in secondary_cards(cur, SENTINEL_USER_ID, SENTINEL_TZ)}

    steps = cards["steps_total"]
    assert steps["provenance"]["source"] == "strap_0x16"
    assert steps["provenance"]["steps_per_minute_sum"] == 8100
    assert steps["provenance"]["sample_minutes"] == 640
    assert steps["note_id"] == "steps_mortality"

    calories = cards["total_calories"]
    assert calories["provenance"]["workout_cal"] == 310
    assert calories["provenance"]["bmr"] == 1700
    # The calorie rows carried no note id at all, so the note's own ±15-20% estimate label
    # had nowhere to render.
    assert calories["note_id"] == "energy_expenditure_derivation"
    # A metric whose derivation recorded nothing about itself gets an honest empty, never
    # a null-filled shape that would read as "no workout calories" on a step card.
    assert "workout_cal" not in steps["provenance"]


@pytest.mark.usefixtures("db")
def test_a_counter_read_mid_day_says_so_on_the_card() -> None:
    """The disclosure ``device_totals.py`` argued for in a comment and never emitted.

    "A counter read at 09:00 is a statement about a partial day". The strap's accumulator
    is still the preferred instrument — the per-minute stream drops whole stretches — but
    a prefix of a day is what the number covers, and the card said nothing.
    """
    today = user_today(SENTINEL_TZ)
    read_at = datetime.combine(today, time(9, 0), tzinfo=ZONE).astimezone(UTC)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        cur.execute("DELETE FROM device_daily_total")
        cur.execute(
            "INSERT INTO device_daily_total (user_id, day, steps, source, reported_at) "
            "VALUES (%s, %s, %s, 'strap_0x16', %s)",
            (SENTINEL_USER_ID, today, 4200, read_at),
        )
        derive_daily_activity(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        cards = {c["metric"]: c for c in secondary_cards(cur, SENTINEL_USER_ID, SENTINEL_TZ)}

    steps = cards["steps_total"]
    assert steps["value"] == 4200
    assert [c["reason"] for c in steps["caveats"]] == [COUNTER_MID_DAY]
    assert steps["provenance"]["reported_at"] == read_at.isoformat()


# ── D-c. the sleep signal's two limbs ────────────────────────────────────────


@pytest.mark.usefixtures("db")
def test_the_sleep_signal_says_which_limb_produced_its_verdict() -> None:
    """A chronic short sleeper's verdict comes from the POPULATION floor, and says so.

    The signal presents itself as a comparison against "personal usual" and then decides
    from an absolute floor as well. For someone whose every night is under five hours the
    floor fires every night, so the personal z it computes and ships can never change the
    word beside it. The thresholds are cited and unchanged; what was missing is which one
    spoke.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        # Seven nights of ~4 h, flat: every one is under the 300-minute floor, and the
        # newest is right AT the personal median, so the personal limb says nothing.
        for back in range(7):
            wake = today - timedelta(days=back)
            end = datetime.combine(wake, time(6, 0), tzinfo=ZONE).astimezone(UTC)
            cur.execute(
                "INSERT INTO sleep_session "
                "(user_id,start_ts,end_ts,kind,rem_min,light_min,deep_min,wake_min,stages) "
                "VALUES (%s,%s,%s,'main',40,160,40,20,'[]'::jsonb)",
                (SENTINEL_USER_ID, end - timedelta(hours=4), end),
            )
        payload = recovery_signals(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    sleep = next(s for s in payload["signals"] if s["name"] == "Sleep duration")
    assert sleep["direction"] == "unfavorable"
    assert sleep["direction_basis"] == "population"
    assert sleep["population_floor_min"] == 300.0
    assert abs(sleep["z"]) < 1.0, "the personal limb must NOT be what decided this"


# ── D-d. the workout pace names its denominator ──────────────────────────────


@pytest.mark.usefixtures("db")
def test_the_workout_pace_says_it_is_measured_over_elapsed_time() -> None:
    """A paused session reports a slower pace than it was run at, and the wire says so."""
    day = user_today(SENTINEL_TZ) - timedelta(days=1)
    start = datetime.combine(day, time(9, 0), tzinfo=ZONE).astimezone(UTC)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        cur.execute(
            "INSERT INTO workout (user_id, start_ts, sport, duration_s, distance_m, "
            "  calories, avg_hr, max_hr, min_hr) "
            "VALUES (%s,%s,1,%s,%s,300,140,165,110)",
            (SENTINEL_USER_ID, start, 3600, 8000.0),
        )
        detail = workout_detail(cur, SENTINEL_USER_ID, SENTINEL_TZ, start.isoformat())

    metrics = detail["metrics"]
    assert metrics["pace_min_per_km"] == 7.5  # 60 min over 8 km, ELAPSED
    assert metrics["pace_basis"] == "elapsed"
