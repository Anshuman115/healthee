"""The tiered ``vo2max_estimate`` on the wire: the DB writer, the payload, the bio-age.

The precedence and the no-blending guarantee are pure and live in
``test_vo2max_tier.py``; this file drives the same rules through a seeded database and out
to every surface that carries the number, because [[hr_reserve_vo2max]] Directive 4 is two
requirements and only one of them is about which value wins — the other is "state which
one produced the value".
"""

from __future__ import annotations

import json
from datetime import date, timedelta

import pytest
from tests.derive.test_vo2max_tier import GRADED_VALUE, JURCA_VALUE, RESERVE_VALUE

from healthee.analytics.biological_age import compute_biological_age
from healthee.analytics.biological_age_terms import (
    VO2MAX_MEASURED_FROM_RESERVE,
    VO2MAX_MEASURED_FROM_SESSION,
)
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.derive.orchestrator import derive_day
from healthee.derive.srpa import SRPA_SELF_REPORTED, WITHHOLD_SRPA_NOT_REPORTED
from healthee.derive.vo2max import METHOD_JURCA
from healthee.derive.vo2max_reserve import METHOD_RESERVE
from healthee.derive.vo2max_submax import METHOD_GRADED
from healthee.derive.vo2max_tier import derive_vo2max_estimate, withhold_reason_for_day
from healthee.read.vo2max import vo2max_payload

# ── end to end, against a seeded DB ──────────────────────────────────────────

# median 56, MAD 4 — inside every Jurca gate, so the fallback tier can derive.
_CALM_WEEK = [50.0, 52.0, 54.0, 56.0, 58.0, 60.0, 62.0]


def _reset(cur) -> None:
    for table in ("derived_daily", "weight_log", "profile", "gps_point", "gps_track", "sample"):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names


def _owner(cur, srpa: int | None = 0) -> None:
    cur.execute(
        "INSERT INTO profile (user_id, height_cm, sex, dob, srpa) "
        "VALUES (%s, 175, 'male', '1994-01-01', %s)",
        (SENTINEL_USER_ID, srpa),
    )
    cur.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, now() - interval '1 day', 77)",
        (SENTINEL_USER_ID,),
    )


def _rhr_week(cur, day: date) -> None:
    for k, value in enumerate(_CALM_WEEK):
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value) VALUES (%s,%s,'rhr_daily',%s) "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
            (SENTINEL_USER_ID, day - timedelta(days=len(_CALM_WEEK) - 1 - k), value),
        )


def _submax(cur, day: date, value: float, method: str, hrr: float | None = None) -> None:
    """One stored session record — the instruments' own output, golden-tested elsewhere."""
    flags = {"method": method}
    if hrr is not None:
        flags["hrr_median"] = hrr  # type: ignore[assignment]
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
        "VALUES (%s,%s,'vo2max_submax',%s,%s::jsonb) "
        "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
        (SENTINEL_USER_ID, day, value, json.dumps(flags)),
    )


def _stored(cur) -> tuple[float, dict] | None:
    cur.execute(
        "SELECT value, flags FROM derived_daily WHERE user_id=%s AND metric='vo2max_estimate'",
        (SENTINEL_USER_ID,),
    )
    row = cur.fetchone()
    return (float(row[0]), row[1] or {}) if row else None


@pytest.mark.usefixtures("db")
def test_a_recent_graded_session_becomes_the_estimate_and_names_itself() -> None:
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _owner(cur)
        _rhr_week(cur, today)
        _submax(cur, today - timedelta(days=2), GRADED_VALUE, METHOD_GRADED)
        out = derive_vo2max_estimate(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        stored = _stored(cur)
    assert out == {"vo2max_estimate": GRADED_VALUE}
    assert stored is not None
    value, flags = stored
    assert value == GRADED_VALUE
    assert flags["method"] == METHOD_GRADED
    assert flags["measured_as_of"] == (today - timedelta(days=2)).isoformat()
    assert flags["measured_age_days"] == 2
    # NOT the model's SEE: a measurement carried under Jurca's error figure is a mislabel.
    assert flags["see_source"].startswith("Carrier 2023")


@pytest.mark.usefixtures("db")
def test_without_a_recent_session_the_fallback_tier_writes_the_row() -> None:
    """The whole point of the fallback: a sedentary fortnight still has a number."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _owner(cur)
        _rhr_week(cur, today)
        _submax(cur, today - timedelta(days=40), GRADED_VALUE, METHOD_GRADED)
        derive_vo2max_estimate(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        stored = _stored(cur)
    assert stored is not None
    assert stored[1]["method"] == METHOD_JURCA
    assert stored[0] != GRADED_VALUE


@pytest.mark.usefixtures("db")
def test_a_withheld_fallback_falls_through_to_a_measurement_we_are_holding() -> None:
    """THE defect, as one assertion.

    Production, 2026-08-02: SR-PA unanswered, so the Jurca tier withheld and wrote
    nothing; two measured values sat in ``vo2max_submax``; ``vo2max_estimate`` was empty
    and the biological age was ``null``. We refused to produce a number while holding a
    better version of the input we were refusing for.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _owner(cur, srpa=None)  # the gate the strap cannot clear
        _rhr_week(cur, today)
        assert withhold_reason_for_day(cur, SENTINEL_USER_ID, SENTINEL_TZ, today) == (
            WITHHOLD_SRPA_NOT_REPORTED
        )
        _submax(cur, today - timedelta(days=1), GRADED_VALUE, METHOD_GRADED)
        # ...and now the same day carries a number, from the instrument that has one.
        assert withhold_reason_for_day(cur, SENTINEL_USER_ID, SENTINEL_TZ, today) is None
        derive_vo2max_estimate(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        stored = _stored(cur)
    assert stored is not None
    assert (stored[0], stored[1]["method"]) == (GRADED_VALUE, METHOD_GRADED)


@pytest.mark.usefixtures("db")
@pytest.mark.parametrize(
    ("srpa", "session"),
    [
        (0, None),
        (None, (METHOD_GRADED, GRADED_VALUE)),
        (0, (METHOD_RESERVE, RESERVE_VALUE)),
        (None, None),
    ],
)
def test_the_read_gate_and_the_write_gate_agree_across_the_tiers(
    srpa: int | None, session: tuple[str, float] | None
) -> None:
    """The payload recomputes the reason instead of storing one, so the tiered gate and
    the tiered writer must answer identically — including when one tier refuses and
    another does not. Before #117 the gate answered for Jurca alone while claiming to
    answer for the metric."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _owner(cur, srpa=srpa)
        _rhr_week(cur, today)
        if session is not None:
            _submax(cur, today, session[1], session[0], hrr=0.8)
        reason = withhold_reason_for_day(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        wrote = derive_vo2max_estimate(cur, SENTINEL_USER_ID, SENTINEL_TZ, today) is not None
    assert wrote is (reason is None)


@pytest.mark.usefixtures("db")
def test_the_reserve_tier_carries_its_own_published_precision() -> None:
    """A reserve number's ± band comes from [[hr_reserve_vo2max]]'s own Monte-Carlo table,
    read at the published point at or BELOW the session's fraction of reserve."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _owner(cur)
        _rhr_week(cur, today)
        _submax(cur, today, RESERVE_VALUE, METHOD_RESERVE, hrr=0.87)
        derive_vo2max_estimate(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        stored = _stored(cur)
    assert stored is not None
    assert stored[1]["see_ml_kg_min"] == 3.23  # the 0.80 row, not the 0.90 one
    assert stored[1]["see_source"].startswith("hr_reserve_vo2max")


# ── the instrument reaches every surface that carries the number ─────────────


@pytest.mark.usefixtures("db")
def test_the_payload_names_the_instrument_that_produced_the_number() -> None:
    """[[hr_reserve_vo2max]] D4: "state which one produced the value"."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _owner(cur)
        _rhr_week(cur, today)
        _submax(cur, today, RESERVE_VALUE, METHOD_RESERVE, hrr=0.8)
        derive_vo2max_estimate(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload is not None
    assert payload["estimate"] == RESERVE_VALUE
    assert payload["method"] == METHOD_RESERVE
    assert "run" in payload["method_caveat"]
    assert payload["n_sessions"] == 1
    assert "one session" in payload["method_caveat"]  # D6's qualifier at n = 1
    assert payload["research_notes"] == ["vo2max", "hr_reserve_vo2max"]


@pytest.mark.usefixtures("db")
def test_a_legacy_row_without_a_method_reads_as_the_model_it_came_from() -> None:
    """Every ``vo2max_estimate`` row written before #117 is Jurca — the tiered writer is
    what introduced the other two — so the default cannot mislabel history."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _owner(cur)
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
            'VALUES (%s,%s,\'vo2max_estimate\',%s,\'{"age_years": 32, "sex": "male"}\'::jsonb)',
            (SENTINEL_USER_ID, today, JURCA_VALUE),
        )
        _rhr_week(cur, today)
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload is not None
    assert payload["method"] == METHOD_JURCA
    assert payload["research_notes"] == ["vo2max", "non_exercise_vo2max"]


# ── biological age spends the tiered number, and says whose it is ────────────


def _seed_nights(cur, today: date) -> None:
    """14 nights of a 380-minute sleeper, so the sleep term is present and the composite
    can be computed at all (every term is required)."""
    for k in range(14):
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags) VALUES "
            "(%s,%s,'sleep_health_score_4dim',70,'{\"tst_min\": 380}'::jsonb) "
            "ON CONFLICT (user_id, day, metric) DO NOTHING",
            (SENTINEL_USER_ID, today - timedelta(days=k)),
        )


@pytest.mark.usefixtures("db")
def test_biological_age_uses_the_tiered_value_and_names_its_instrument() -> None:
    """The live consequence of the defect: bio-age returned ``null`` while two measured
    VO₂max values sat unread. It now computes, and its fitness term says what measured it.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _owner(cur, srpa=None)  # Jurca withheld, exactly as on production
        _rhr_week(cur, today)
        _seed_nights(cur, today)
        _submax(cur, today - timedelta(days=3), GRADED_VALUE, METHOD_GRADED)
        derive_vo2max_estimate(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert result is not None
    assert result["biological_age"] is not None, "a measured input must not read as absent"
    assert result["withheld"] is None
    fitness = next(c for c in result["contributions"] if c["term"] == "fitness")
    assert fitness["value"] == GRADED_VALUE
    assert fitness["method"] == METHOD_GRADED


@pytest.mark.usefixtures("db")
@pytest.mark.parametrize(
    ("method", "expected_reason"),
    [
        (METHOD_GRADED, VO2MAX_MEASURED_FROM_SESSION),
        (METHOD_RESERVE, VO2MAX_MEASURED_FROM_RESERVE),
        (METHOD_JURCA, SRPA_SELF_REPORTED),
    ],
)
def test_the_fitness_caveat_swaps_with_the_instrument(method: str, expected_reason: str) -> None:
    """The self-reported-activity footing is TRUE about the Jurca model and FALSE about a
    number measured from a run. Shipping it regardless would tell an owner their measured
    fitness rested on a question they never answered — so the entry swaps rather than
    accumulates, and there is always exactly one of it."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _owner(cur)
        _rhr_week(cur, today)
        _seed_nights(cur, today)
        if method != METHOD_JURCA:
            _submax(cur, today, GRADED_VALUE, method, hrr=0.8)
        derive_vo2max_estimate(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert result is not None
    fitness_caveats = [c["reason"] for c in result["caveats"] if c["term"] == "fitness"]
    assert expected_reason in fitness_caveats
    assert len(fitness_caveats) == 2, "the anchor caveat plus exactly one instrument"


# ── ordering: the estimate READS what the track scoring writes ───────────────


@pytest.mark.usefixtures("db")
def test_derive_day_scores_the_days_tracks_before_it_reads_them() -> None:
    """``derive_day``'s order is the contract (#117). Reversed, a session recorded today
    would not reach today's own estimate until the next push — #107's shape, smaller.

    Driven through the whole pass rather than by inspecting the source, so a future
    reordering fails here rather than in review.
    """
    from tests.derive._gps_seed import insert_hr, insert_track, synthetic_run

    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _owner(cur)
        _rhr_week(cur, today)
        cur.execute(
            "SELECT extract(epoch FROM (%s::date + time '09:00') AT TIME ZONE %s)",
            (today, SENTINEL_TZ),
        )
        row = cur.fetchone()
        assert row is not None
        points, hr_rows = synthetic_run(float(row[0]))
        insert_track(cur, SENTINEL_USER_ID, points)
        insert_hr(cur, SENTINEL_USER_ID, hr_rows)
        derive_day(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        stored = _stored(cur)
        cur.execute(
            "SELECT value FROM derived_daily WHERE user_id=%s AND metric='vo2max_submax'",
            (SENTINEL_USER_ID,),
        )
        session_row = cur.fetchone()
    assert session_row is not None, "the day's track was scored"
    assert stored is not None
    assert stored[1]["method"] == METHOD_GRADED
    assert stored[0] == float(session_row[0]), "the same pass spent what it just measured"
