"""#127 — a calorie figure says which weight it rests on, and when that weight is old.

``derive/energy.py`` never asked ``freshness.weight_is_stale``, so ``total_calories``,
``active_calories`` and ``basal_calories`` could all rest on a mass measured months ago
and carry no marker of it anywhere. ``derive/vo2max.py`` and ``read/today_series.py``
already held that rule for the same input — this was the third consumer, missed.

The answer here is a CAVEAT, not the withhold ``vo2max.py`` takes, and these tests pin the
arithmetic that decided it as well as the behaviour. The argument is in
``energy.py``'s module docstring; its load-bearing claim is that a wrong mass can move a
calorie by at most ``10·Δkg / BMR`` — about 0.6% per kilogram — against the ±15-20%
individual error the estimate already advertises. If the BMR arithmetic or the Mifflin
weight coefficient ever moves, ``test_the_bound_that_chose_caveat_over_withhold`` fails
and the decision gets re-argued rather than silently inherited.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.derive._common import _day_bounds_utc, _load_profile
from healthee.derive.energy import (
    AWAKE_SEDENTARY_MET,
    MIFFLIN_KCAL_PER_KG_DAY,
    derive_calories,
    weight_tilt_pct_per_kg,
)
from healthee.derive.freshness import WEIGHT_MAX_AGE_DAYS, WEIGHT_STALE
from healthee.read.fitness import activity_metric
from healthee.read.today_series import secondary_cards

_DAY = date(2026, 3, 8)
_HEIGHT_CM = 175.0
_DOB = date(1990, 1, 1)
_KG = 72.0
_STRIDE_M = 0.414 * _HEIGHT_CM / 100.0

# Mifflin-St Jeor, hand-computed for this owner on `_DAY` (male, 36 y on 2026-03-08):
#     10*72.0 + 6.25*175.0 - 5*36 + 5  =  720 + 1093.75 - 180 + 5  =  1638.75
# The same 1638.75 the legacy parity fixture carries for `basal_calories`, so this is a
# known value in the strongest sense available here: two independent implementations.
_BMR = 1638.75

# With no samples, no sleep session and no workout, EVERY minute of the day is
# awake-with-no-steps-nearby, so `_minute_met` returns AWAKE_SEDENTARY_MET for all 1440 of
# them and the day integrates to exactly `1.3 * BMR`. Asia/Kolkata has no DST, so 2026-03-08
# is 1440 minutes long (`_day_minutes`) and the multiplier is exact rather than approximate.
_TOTAL = AWAKE_SEDENTARY_MET * _BMR  # 2130.375
_ACTIVE = _TOTAL - _BMR  # 491.625
_CALORIE_METRICS = ("total_calories", "active_calories", "basal_calories")


# ── the arithmetic that chose caveat over withhold (pure, no DB) ─────────────


def test_the_bound_that_chose_caveat_over_withhold() -> None:
    """One kilogram of stale mass is ~0.6% of a calorie; the model's own error is ±15%.

    ``total = k·BMR + workout_cal`` and ``active = (k−1)·BMR + workout_cal``, with neither
    ``k`` (the MET integral) nor the device-measured workout term seeing the weight. So
    ``10·Δkg / BMR`` is an UPPER bound on the relative error for all three metrics at once,
    attained exactly at ``basal_calories``.

    The drift it would take to reach the ±15% this estimate already advertises is ~25 kg —
    a figure no evidence in the corpus attaches to any elapsed interval. That is why the
    number is served with a caveat rather than refused, and this test is the tripwire: if
    the coefficient or the BMR arithmetic moves, the argument has to be made again.
    """
    assert MIFFLIN_KCAL_PER_KG_DAY == 10.0
    assert weight_tilt_pct_per_kg(_BMR) == pytest.approx(0.6102, abs=1e-4)

    # Bhutani et al. 2017 measured 0.26 ± 1.2 kg of two-week free-living drift. Even at
    # four times its SD — 4.8 kg, a mass change no fortnight in that cohort produced —
    # the tilt is under 3%, an order below the error the number already carries.
    assert weight_tilt_pct_per_kg(_BMR) * 4.8 < 3.0
    kg_to_reach_the_models_own_error = 15.0 / weight_tilt_pct_per_kg(_BMR)
    assert kg_to_reach_the_models_own_error == pytest.approx(24.58, abs=0.01)


def test_the_bound_is_relative_so_it_holds_across_body_sizes() -> None:
    """A larger owner has a larger BMR, so the same kilogram is a SMALLER share of it.

    Worth pinning because the bound is quoted as a percentage in the caveat sentence: it is
    not a constant, and the direction matters — the people whose absolute BMR error is
    biggest are the people for whom it is proportionally smallest.
    """
    assert weight_tilt_pct_per_kg(2000.0) < weight_tilt_pct_per_kg(1200.0)
    assert weight_tilt_pct_per_kg(2000.0) == pytest.approx(0.5)


# ── the seeded day ───────────────────────────────────────────────────────────


def _seed(cur, weight_day: date) -> None:
    for table in ("derived_daily", "sample", "sleep_session", "workout", "weight_log", "profile"):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names
    cur.execute(
        "INSERT INTO profile (user_id, height_cm, sex, dob, srpa) VALUES (%s, %s, 'male', %s, 0)",
        (SENTINEL_USER_ID, _HEIGHT_CM, _DOB),
    )
    cur.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, %s, %s)",
        (SENTINEL_USER_ID, datetime.combine(weight_day, time(6), tzinfo=UTC), _KG),
    )


def _derive(cur, weight_day: date) -> dict:
    _seed(cur, weight_day)
    prof = _load_profile(cur, SENTINEL_USER_ID, SENTINEL_TZ, _DAY)
    assert prof is not None
    start_utc, end_utc = _day_bounds_utc(_DAY, SENTINEL_TZ)
    return derive_calories(cur, SENTINEL_USER_ID, _DAY, prof, start_utc, end_utc, _STRIDE_M)


def _stored(cur) -> dict[str, tuple[float, dict]]:
    cur.execute(
        "SELECT metric, value, flags FROM derived_daily WHERE user_id = %s AND metric = ANY(%s)",
        (SENTINEL_USER_ID, list(_CALORIE_METRICS)),
    )
    return {m: (float(v), f or {}) for m, v, f in cur.fetchall()}


# ── known values: the numbers themselves, and that staleness does not move them ──


@pytest.mark.integration
@pytest.mark.usefixtures("db")
def test_a_fresh_weight_derives_the_hand_computed_calories_with_no_caveat() -> None:
    """The common path, pinned to hand arithmetic, at the last day inside the horizon.

    A weight exactly ``WEIGHT_MAX_AGE_DAYS`` old is still current (the boundary is
    inclusive, matching how the evidence is quoted), so this is the fresh case at its
    tightest.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        out = _derive(cur, _DAY - timedelta(days=WEIGHT_MAX_AGE_DAYS))
        stored = _stored(cur)

    assert out == {
        "total_calories": round(_TOTAL),
        "active_calories": round(_ACTIVE),
        "basal_calories": round(_BMR),
    }
    assert stored["basal_calories"][0] == pytest.approx(_BMR)
    assert stored["total_calories"][0] == pytest.approx(_TOTAL)
    assert stored["active_calories"][0] == pytest.approx(_ACTIVE)
    for metric in _CALORIE_METRICS:
        flags = stored[metric][1]
        assert flags["caveats"] == [], metric
        # The provenance ships even when there is nothing to disclose: Coach Directive 6
        # ([[weight_bmi_body_composition]]) asks for the weight's date whenever a number
        # is justified by it, not only once it has gone stale.
        assert flags["weight_kg"] == _KG, metric
        assert flags["weight_age_days"] == WEIGHT_MAX_AGE_DAYS, metric
        assert flags["weight_as_of"] == (_DAY - timedelta(days=WEIGHT_MAX_AGE_DAYS)).isoformat()


@pytest.mark.integration
@pytest.mark.usefixtures("db")
def test_a_stale_weight_caveats_and_changes_no_number() -> None:
    """One day past the horizon: same three values, plus a caveat on each.

    Both halves are the point. The values must be byte-identical to the fresh case,
    because a caveat that also bent the number would be a second, undocumented model; and
    a row must exist for all three, which is exactly what ``derive/vo2max.py`` does NOT do
    in the same situation. The difference between the two modules is deliberate and
    argued (``energy.py`` module docstring), so it is asserted rather than assumed.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        out = _derive(cur, _DAY - timedelta(days=WEIGHT_MAX_AGE_DAYS + 1))
        stored = _stored(cur)

    assert out == {
        "total_calories": round(_TOTAL),
        "active_calories": round(_ACTIVE),
        "basal_calories": round(_BMR),
    }
    assert set(stored) == set(_CALORIE_METRICS)  # nothing withheld
    assert stored["basal_calories"][0] == pytest.approx(_BMR)
    for metric in _CALORIE_METRICS:
        caveats = stored[metric][1]["caveats"]
        assert len(caveats) == 1, metric
        assert caveats[0]["reason"] == WEIGHT_STALE, metric
        assert caveats[0]["age_days"] == WEIGHT_MAX_AGE_DAYS + 1, metric
        assert caveats[0]["horizon_days"] == WEIGHT_MAX_AGE_DAYS, metric
        assert caveats[0]["kcal_per_day_per_kg"] == MIFFLIN_KCAL_PER_KG_DAY, metric
        assert caveats[0]["max_percent_per_kg"] == pytest.approx(0.61, abs=1e-9), metric


@pytest.mark.integration
@pytest.mark.usefixtures("db")
def test_the_boundary_is_the_shared_weight_horizon_and_nothing_else() -> None:
    """14 days silent, 15 days caveated — the ONE weight horizon, not a calorie-specific one.

    A second constant here would mean a stale weight meant 14 days to the fitness card and
    something else to the calorie card, which is the two-definitions failure
    ``derive/freshness.py`` exists to prevent. The quantity being asked about is the same
    quantity (is this logged mass a statement about this day's body?), so the horizon is
    the same horizon; only the RESPONSE to a `no` differs.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _derive(cur, _DAY - timedelta(days=WEIGHT_MAX_AGE_DAYS))
        assert _stored(cur)["total_calories"][1]["caveats"] == []
        _derive(cur, _DAY - timedelta(days=WEIGHT_MAX_AGE_DAYS + 1))
        assert len(_stored(cur)["total_calories"][1]["caveats"]) == 1


@pytest.mark.integration
@pytest.mark.usefixtures("db")
def test_a_weight_logged_after_the_day_is_just_as_stale_here() -> None:
    """``_weight_as_of`` hands pre-first-entry days a LATER weigh-in, so the age is absolute.

    Every day before the owner's first entry falls back to the earliest logged weight. A
    signed age would report those days a negative number, read it as fresh, and exempt the
    entire pre-first-entry era from the gate — on the metric that is derived for every day
    of history, not just today's.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _derive(cur, _DAY + timedelta(days=40))
        caveats = _stored(cur)["basal_calories"][1]["caveats"]
    assert len(caveats) == 1
    assert caveats[0]["age_days"] == 40


@pytest.mark.integration
@pytest.mark.usefixtures("db")
def test_the_caveat_sentence_names_the_weight_its_date_and_the_way_out() -> None:
    """A reason id alone tells an owner nothing; the sentence is the actionable half.

    It has to join two facts that look unrelated from outside — that a calorie estimate
    runs on body mass, and that we are holding one the owner has not confirmed in weeks —
    and it has to say the tilt is small, because the whole reason we still show the number
    is that we measured the tilt and found it small.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _derive(cur, _DAY - timedelta(days=60))
        message = _stored(cur)["total_calories"][1]["caveats"][0]["message"]
    assert "72.0 kg" in message
    assert (_DAY - timedelta(days=60)).isoformat() in message
    assert "60 days" in message
    assert "10 kcal" in message
    assert "15% individual error" in message
    assert "Log a weight" in message


# ── the payload half: a caveat only the database can see is the same silence ──


@pytest.mark.integration
@pytest.mark.usefixtures("db")
def test_the_caveat_reaches_both_surfaces_that_render_a_calorie() -> None:
    """The Today card and the Activity tab both drop it, or the fix does not exist.

    This is the half that was structurally missing rather than merely unwritten: BOTH
    ``read/today_series._derived_card`` and ``read/fitness.activity_metric`` read the
    stored row's ``flags`` and then discarded them, so ``derive/energy.py`` could have
    stamped a stale-weight caveat for months and no owner would ever have seen one.

    Both reads are asked for ``_DAY``, the day the rows above were derived for. They used
    to be asked for *today* and answered anyway with a row months old — which is the
    separate defect the freshness gate on these two functions now closes, and asking the
    old question here would have this test proving the caveat reaches a card that is no
    longer allowed to carry a number.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _derive(cur, _DAY - timedelta(days=60))
        cards = {
            c["metric"]: c for c in secondary_cards(cur, SENTINEL_USER_ID, SENTINEL_TZ, day=_DAY)
        }
        tab = activity_metric(cur, SENTINEL_USER_ID, SENTINEL_TZ, ["total_calories"], day=_DAY)

    for metric in _CALORIE_METRICS:
        assert cards[metric]["value"] is not None, metric  # served, not withheld
        assert len(cards[metric]["caveats"]) == 1, metric
        assert cards[metric]["caveats"][0]["reason"] == WEIGHT_STALE, metric
    assert tab is not None
    assert tab["caveats"][0]["reason"] == WEIGHT_STALE


@pytest.mark.integration
@pytest.mark.usefixtures("db")
def test_caveats_is_a_permanent_key_even_where_there_is_nothing_to_say() -> None:
    """``[]``, never a missing key — for every metric, not only the calorie ones.

    An absent key and "we checked and there is nothing to disclose" are different claims,
    and a client that has to distinguish them by `in` will eventually get it wrong. The
    weight card is the one exception and stays one: it comes from ``_weight_card``, which
    answers with ``withheld`` because its own value IS refused past the horizon.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _derive(cur, _DAY)  # weighed on the day itself — nothing to disclose
        cards = {c["metric"]: c for c in secondary_cards(cur, SENTINEL_USER_ID, SENTINEL_TZ)}

    assert cards["basal_calories"]["caveats"] == []
    assert "caveats" not in cards["weight_kg"]
    assert cards["weight_kg"]["withheld"] is not None  # `_DAY` is long past the owner's today
