"""A stale sleep number must READ as stale — regularity, debt, and "last night".

Three payload fields presented a stored row as the owner's current state after dropping
its date:

* ``/api/sleep/consistency`` — ``sri``, the only field in a window-framed payload with no
  date of its own, though an SRI *is* a 7-day window.
* ``/api/today``'s ``sleep_debt`` — ``debt_min``, a cumulative claim over the 14 nights
  ending on its own day, in a payload that carried no date key at all.
* the same block's ``last_tst_min`` / ``performance_pct`` — a field named "last night"
  and a percentage named "performance", both computed from the newest sleep-score row
  whatever night that was.

Each test seeds a stale state and asserts the current-looking field is GONE, not merely
annotated — a date in a field the UI may not render does not undo a confident
current-looking number (``read/vo2max.py``). The fresh case is asserted alongside every
one of them, so none of these can pass by making the number disappear.
"""

from __future__ import annotations

import json
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.derive.freshness import (
    NO_NIGHTS_IN_WINDOW,
    NOT_DERIVED_YET,
    PROFILE_INCOMPLETE,
)
from healthee.derive.sleep_score import (
    SLEEP_DEBT_MESSAGES,
    SRI_MESSAGES,
    SRI_WINDOW_TOO_SHORT,
    derive_sleep_debt,
    sleep_debt_withhold_reason_for_day,
)
from healthee.read.health_metrics import sleep_debt_payload
from healthee.read.sleep_extras import sleep_consistency

pytestmark = pytest.mark.integration

_ZONE = ZoneInfo(SENTINEL_TZ)
_TST_MIN = 380.0
_NEED_MIN = 480.0
_DEBT_MIN = 120.0


def _reset(cur) -> None:
    for table in ("derived_daily", "sleep_session", "weight_log", "profile"):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names


def _profile(cur, today: date) -> None:
    cur.execute(
        "INSERT INTO profile (user_id, height_cm, sex, dob) VALUES (%s, 175, 'male', %s)",
        (SENTINEL_USER_ID, date(today.year - 35, 1, 1)),
    )
    cur.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, now() - interval '1 day', 72)",
        (SENTINEL_USER_ID,),
    )


def _dd(cur, day: date, metric: str, value: float, flags: dict | None = None) -> None:
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
        "VALUES (%s,%s,%s,%s,%s::jsonb) ON CONFLICT (user_id, day, metric) DO UPDATE "
        "SET value = EXCLUDED.value, flags = EXCLUDED.flags",
        (SENTINEL_USER_ID, day, metric, value, json.dumps(flags or {})),
    )


def _nights(cur, last_wake: date, n: int) -> None:
    """``n`` consecutive main-sleep nights ending on ``last_wake``, sessions + score rows."""
    for k in range(n):
        wake = last_wake - timedelta(days=k)
        start = datetime.combine(wake - timedelta(days=1), time(23, 0), tzinfo=_ZONE)
        end = datetime.combine(wake, time(6, 30), tzinfo=_ZONE)
        stages = [[int(start.timestamp() * 1000), int(end.timestamp() * 1000), 4]]
        cur.execute(
            "INSERT INTO sleep_session (user_id, start_ts, end_ts, kind, rem_min, light_min, "
            "deep_min, wake_min, stages) VALUES (%s,%s,%s,'main',90,200,90,20,%s) "
            "ON CONFLICT (user_id, start_ts) DO NOTHING",
            (SENTINEL_USER_ID, start.astimezone(UTC), end.astimezone(UTC), json.dumps(stages)),
        )
        _dd(cur, wake, "sleep_health_score_4dim", 2.0, {"tst_min": _TST_MIN})


# ── /api/sleep/consistency — the SRI (also the coach's sleep_consistency tool) ─


@pytest.mark.usefixtures("db")
def test_a_current_sri_is_reported_with_the_day_it_describes() -> None:
    """The unaffected path, plus the date the field never used to carry."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _nights(cur, today, 7)
        _dd(cur, today, "sleep_regularity_index", 74.0)
        payload = sleep_consistency(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload["sri"] == 74.0
    assert payload["sri_as_of_date"] == today.isoformat()
    assert payload["sri_withheld"] is None


@pytest.mark.usefixtures("db")
def test_a_90_day_old_sri_is_not_this_weeks_regularity() -> None:
    """THE bug. Every other field here is framed by the 28-night window; this one was a
    number from a week last quarter with nothing to say so."""
    today = user_today(SENTINEL_TZ)
    old = today - timedelta(days=90)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _nights(cur, today, 7)
        _dd(cur, old, "sleep_regularity_index", 41.0)
        payload = sleep_consistency(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload["sri"] is None
    assert payload["sri_as_of_date"] is None
    withheld = payload["sri_withheld"]
    assert withheld["reason"] == NOT_DERIVED_YET
    assert withheld["message"] == SRI_MESSAGES[NOT_DERIVED_YET]
    assert withheld["age_days"] == 90
    # Not deleted — moved somewhere it carries its own date and cannot read as now.
    assert withheld["last_sri"] == 41.0
    assert withheld["last_as_of_date"] == old.isoformat()
    # The rest of the payload is untouched: those fields were always dated.
    assert payload["nights"] == 7
    assert payload["median_bedtime"] == "23:00"


@pytest.mark.usefixtures("db")
def test_an_owner_who_has_never_had_an_sri_gets_the_directives_reason() -> None:
    """No SRI and a short week: the reason is Directive 4, not "sync"."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _nights(cur, today, 3)
        payload = sleep_consistency(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload["sri"] is None
    assert payload["sri_withheld"]["reason"] == SRI_WINDOW_TOO_SHORT
    assert payload["sri_withheld"]["last_as_of_date"] is None
    assert payload["sri_withheld"]["age_days"] is None


# ── /api/today — sleep debt ──────────────────────────────────────────────────


@pytest.mark.usefixtures("db")
def test_a_current_debt_is_reported_normally_and_now_carries_its_date() -> None:
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _profile(cur, today)
        _nights(cur, today, 14)
        _dd(cur, today, "sleep_need_min", _NEED_MIN)
        _dd(cur, today, "sleep_debt_min", _DEBT_MIN, {"avg_tst_min": 380, "window_nights": 14})
        payload = sleep_debt_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert payload["debt_min"] == 120
    assert payload["as_of_date"] == today.isoformat()
    assert payload["data_confidence"] == "ok"
    assert payload["withheld"] is None
    assert payload["avg_tst_min"] == 380


@pytest.mark.usefixtures("db")
def test_a_three_week_old_debt_describes_a_fortnight_that_no_longer_overlaps_today() -> None:
    """THE bug. 21 days on, the stored window and today's share no night at all, so this
    is not "the debt, slightly out of date"."""
    today = user_today(SENTINEL_TZ)
    old = today - timedelta(days=21)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _profile(cur, today)
        _dd(cur, old, "sleep_need_min", _NEED_MIN)
        _dd(cur, old, "sleep_debt_min", _DEBT_MIN, {"avg_tst_min": 380, "window_nights": 14})
        payload = sleep_debt_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert payload["debt_min"] is None
    assert payload["as_of_date"] is None
    assert payload["data_confidence"] == "insufficient_data"
    # The window's own breakdown goes with it — otherwise "avg 6.3 h/night" restores
    # exactly the current-looking stale number the withhold exists to remove.
    assert payload["avg_tst_min"] is None
    withheld = payload["withheld"]
    assert withheld["reason"] == NO_NIGHTS_IN_WINDOW
    assert withheld["message"] == SLEEP_DEBT_MESSAGES[NO_NIGHTS_IN_WINDOW]
    assert withheld["last_debt_min"] == 120
    assert withheld["age_days"] == 21
    # The NSF age-band need survives: it is a recommendation for someone of this owner's
    # age, not a measurement of them.
    assert payload["need_min"] == 480


@pytest.mark.usefixtures("db")
def test_an_undated_debt_could_not_have_been_caught_by_a_client() -> None:
    """The shape half of the fix: before this there was no date key of any kind, so no
    consumer — app, coach or reviewer — could have noticed."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _profile(cur, today)
        _nights(cur, today, 14)
        _dd(cur, today, "sleep_debt_min", _DEBT_MIN, {"window_nights": 14})
        payload = sleep_debt_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert {"as_of_date", "data_confidence", "withheld"} <= set(payload)


# ── /api/today — "last night's sleep" and Sleep Performance % ────────────────


@pytest.mark.usefixtures("db")
def test_a_week_old_night_is_not_last_night_and_carries_no_performance_pct() -> None:
    """The debt can be current while "last night" is not — an owner who took the strap
    off still has a 14-night window. So this is a SECOND freshness question, and the
    percentage is the dependent claim that goes with it."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _profile(cur, today)
        _nights(cur, today - timedelta(days=7), 7)  # nothing recorded since
        derive_sleep_debt(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)  # today's debt IS real
        payload = sleep_debt_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert payload["debt_min"] is not None, "the rolling window still reaches those nights"
    assert payload["as_of_date"] == today.isoformat()
    assert payload["last_tst_min"] is None
    assert payload["last_tst_as_of_date"] is None
    assert payload["performance_pct"] is None
    stale = payload["last_tst_withheld"]
    assert stale["reason"] == NOT_DERIVED_YET
    assert stale["age_days"] == 7
    assert stale["last_tst_min"] == 380


@pytest.mark.usefixtures("db")
def test_last_night_is_reported_when_it_really_is_last_night() -> None:
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _profile(cur, today)
        _nights(cur, today, 14)
        derive_sleep_debt(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        payload = sleep_debt_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert payload["last_tst_min"] == 380
    assert payload["last_tst_as_of_date"] == today.isoformat()
    assert payload["performance_pct"] == 79  # round(100 * 380 / 480)
    assert payload["last_tst_withheld"] is None


# ── the invariant: the debt gate recomputes what the writer decided ──────────


@pytest.mark.usefixtures("db")
@pytest.mark.parametrize(
    ("has_profile", "nights", "expected"),
    [
        (True, 14, None),
        (True, 1, None),  # one recorded night IS a window the note computes over
        (True, 0, NO_NIGHTS_IN_WINDOW),
        (False, 14, PROFILE_INCOMPLETE),
    ],
)
def test_the_debt_read_gate_and_the_write_gate_agree(
    has_profile: bool, nights: int, expected: str | None
) -> None:
    """``derive_sleep_debt`` writes nothing exactly when the gate names a reason.

    The payload recomputes the reason rather than storing one, so the two diverging would
    let it explain a withhold that never happened.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        if has_profile:
            _profile(cur, today)
        _nights(cur, today, nights)
        reason = sleep_debt_withhold_reason_for_day(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        wrote = derive_sleep_debt(cur, SENTINEL_USER_ID, SENTINEL_TZ, today) is not None

    assert reason == expected
    assert wrote is (reason is None)


def test_every_debt_reason_has_a_message() -> None:
    for reason in (PROFILE_INCOMPLETE, NO_NIGHTS_IN_WINDOW, NOT_DERIVED_YET):
        assert SLEEP_DEBT_MESSAGES[reason].strip()
