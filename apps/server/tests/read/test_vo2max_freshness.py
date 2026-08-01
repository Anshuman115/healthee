"""A withheld VO2max day must READ as withheld, never as an older day's estimate.

``derive/vo2max.py`` writes NO row when the note's gate says the inputs cannot carry
an estimate. ``vo2max_payload`` read the last 95 days and took ``rows[-1]``, so on a
withheld day it shipped an older day's number as the hero value — dated, but
confident-looking, and the whole point of the gate is to say "we don't have enough to
tell you today". These tests pin the three properties that fix depends on:

1. **A current estimate is unaffected.** The common path must not change.
2. **A withheld today reads as withheld** — ``estimate`` and ``as_of_date`` both null,
   ``data_confidence == "insufficient_data"``, and the reason names what we'd need.
   The stale value survives only inside ``withheld``, where nothing can mistake it for
   today's.
3. **It cannot resurrect.** A row anywhere else in the 95-day window does not make
   today's estimate exist.

Plus the invariant the design rests on: the read layer's recomputed gate
(``withhold_reason_for_day``) agrees with the writer (``derive_vo2max``) on every
gated state. That equivalence is why the reason needs no schema — and if a future gate
lands in one and not the other, this is what fails.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.derive.freshness import NOT_DERIVED_YET, PROFILE_INCOMPLETE
from healthee.derive.vo2max import (
    WITHHOLD_FEW_RHR_DAYS,
    WITHHOLD_MESSAGES,
    WITHHOLD_RHR_TOO_NOISY,
    derive_vo2max,
    withhold_reason_for_day,
)
from healthee.read.vo2max import vo2max_payload

# median 56, MAD 4 -> inside every gate, so these seven days DERIVE.
_CALM = [50.0, 52.0, 54.0, 56.0, 58.0, 60.0, 62.0]
# median 56; |x - 56| = [16,12,9,0,9,12,16] -> sorted [0,9,9,12,12,16,16] -> MAD 12,
# above the note's 8 bpm ceiling, so this week is WITHHELD. SEVEN days on purpose: the
# gate reads a 7-day window, so a shorter noisy run would leave calm days in it and the
# median/MAD would be of the mixture, not of what the test claims to have seeded.
_NOISY = [40.0, 44.0, 47.0, 56.0, 65.0, 68.0, 72.0]


def _reset(cur) -> None:
    for table in ("derived_daily", "weight_log", "profile"):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names


def _profile(cur) -> None:
    cur.execute(
        "INSERT INTO profile (user_id, height_cm, sex, dob) VALUES (%s, 175, 'male', '1990-01-01')",
        (SENTINEL_USER_ID,),
    )
    cur.execute(
        # Yesterday: a weight older than `freshness.WEIGHT_MAX_AGE_DAYS` is its own
        # withhold reason (#85), which is not the gate these tests are about.
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, now() - interval '1 day', 72)",
        (SENTINEL_USER_ID,),
    )


def _rhr(cur, day: date, values: list[float]) -> None:
    """Seed one ``rhr_daily`` row per day of the week ENDING on ``day``."""
    for k, value in enumerate(values):
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value) VALUES (%s, %s, %s, %s) "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
            (SENTINEL_USER_ID, day - timedelta(days=len(values) - 1 - k), "rhr_daily", value),
        )


def _estimate_on(cur, day: date, values: list[float]) -> None:
    """Run the real derivation for ``day`` over ``values`` — no hand-written rows.

    A weight logged the day before ``day`` goes in too, because since #85 the estimate
    is withheld when the weight behind its BMI is far from the day being derived — and
    an owner who has an estimate for a day 40 days back is, by construction, an owner
    who had weighed themselves around then.
    """
    cur.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, %s, 72) "
        "ON CONFLICT (user_id, ts) DO NOTHING",
        (SENTINEL_USER_ID, datetime.combine(day - timedelta(days=1), time(6), tzinfo=UTC)),
    )
    _rhr(cur, day, values)
    derive_vo2max(cur, SENTINEL_USER_ID, SENTINEL_TZ, day)


@pytest.mark.usefixtures("db")
def test_a_current_estimate_is_reported_normally() -> None:
    """The unaffected path: today derived -> a number, "ok", and no withheld block."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _profile(cur)
        _estimate_on(cur, today, _CALM)
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload is not None
    assert payload["estimate"] is not None
    assert payload["as_of_date"] == today.isoformat()
    assert payload["data_confidence"] == "ok"
    assert payload["withheld"] is None
    assert payload["delta_from_median"] is not None


@pytest.mark.usefixtures("db")
def test_a_withheld_today_does_not_ship_yesterdays_number_as_todays() -> None:
    """THE bug. Yesterday derived, today's week is too noisy to derive.

    Before the fix this returned yesterday's 51.x as ``estimate`` with yesterday's
    ``as_of_date`` — a current-looking hero number on a day the system had decided it
    could not tell the owner anything.
    """
    today = user_today(SENTINEL_TZ)
    yesterday = today - timedelta(days=1)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _profile(cur)
        _estimate_on(cur, yesterday, _CALM)
        _rhr(cur, today, _NOISY)  # today's window is now noisy -> the gate withholds
        assert derive_vo2max(cur, SENTINEL_USER_ID, SENTINEL_TZ, today) is None
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload is not None
    assert payload["estimate"] is None
    assert payload["as_of_date"] is None
    assert payload["data_confidence"] == "insufficient_data"
    assert payload["delta_from_median"] is None
    withheld = payload["withheld"]
    assert withheld["reason"] == WITHHOLD_RHR_TOO_NOISY
    assert withheld["message"] == WITHHOLD_MESSAGES[WITHHOLD_RHR_TOO_NOISY]
    assert withheld["age_days"] == 1
    # The stale number is not deleted — it is moved somewhere it cannot be read as now.
    assert withheld["last_as_of_date"] == yesterday.isoformat()
    assert withheld["last_estimate"] is not None
    assert payload["trend_90d"], "the trend is still shown — the note calls it the signal"


@pytest.mark.usefixtures("db")
def test_a_row_deep_in_the_window_cannot_resurrect_as_a_fresh_number() -> None:
    """40 days old is still not today. ``age_days`` says exactly how not-today it is."""
    today = user_today(SENTINEL_TZ)
    old = today - timedelta(days=40)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _profile(cur)
        _estimate_on(cur, old, _CALM)
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload is not None
    assert payload["estimate"] is None
    assert payload["data_confidence"] == "insufficient_data"
    assert payload["withheld"]["age_days"] == 40


@pytest.mark.usefixtures("db")
def test_an_unsynced_today_says_so_rather_than_inventing_a_withhold() -> None:
    """No data at all for today is NOT the gate refusing — and must not claim to be.

    The RHR window here is calm; the derivation simply has not run for today because
    nothing has been synced. The reason distinguishes that from a noisy week, which is
    the difference between "wait for tonight's sync" and "your RHR is unstable".
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _profile(cur)
        _estimate_on(cur, today - timedelta(days=2), _CALM)
        _rhr(cur, today, _CALM)  # today's inputs are fine; nobody ran the derivation
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload is not None
    assert payload["withheld"]["reason"] == NOT_DERIVED_YET
    assert payload["withheld"]["message"] == WITHHOLD_MESSAGES[NOT_DERIVED_YET]


@pytest.mark.usefixtures("db")
def test_the_submax_comparison_is_withheld_with_the_jurca_estimate() -> None:
    """``vs_jurca`` is a claim about two numbers we hold TODAY. Null when one is gone."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _profile(cur)
        _estimate_on(cur, today - timedelta(days=3), _CALM)
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value) VALUES (%s, %s, %s, %s)",
            (SENTINEL_USER_ID, today, "vo2max_submax", 43.0),
        )
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload is not None
    assert payload["submax"]["latest"] == 43.0  # the submax method still has a number
    assert payload["submax"]["vs_jurca"] is None  # but nothing to compare it against


@pytest.mark.usefixtures("db")
def test_no_history_at_all_is_still_no_payload() -> None:
    """An owner with nothing gets None, unchanged — there is no card to caveat."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        assert vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ) is None


# ── the invariant that lets the reason be recomputed instead of stored ───────


@pytest.mark.usefixtures("db")
@pytest.mark.parametrize(
    ("has_profile", "rhrs", "expected"),
    [
        (True, _CALM, None),
        (True, _NOISY, WITHHOLD_RHR_TOO_NOISY),
        (True, [], WITHHOLD_FEW_RHR_DAYS),
        (True, [56.0, 56.0], WITHHOLD_FEW_RHR_DAYS),
        # 3 and 4 days are the THIN-BUT-SUFFICIENT band, and they are here because a
        # first version of this matrix skipped them: with only 0, 2 and 7-day cases,
        # a writer-only `len(rhrs) < 5` gate satisfied every row and the invariant
        # passed while the two gates genuinely disagreed. Mutation-tested.
        (True, [56.0] * 3, None),
        (True, [56.0] * 4, None),
        (False, _CALM, PROFILE_INCOMPLETE),
    ],
)
def test_the_read_gate_and_the_write_gate_agree(
    has_profile: bool, rhrs: list[float], expected: str | None
) -> None:
    """``derive_vo2max`` writes nothing exactly when ``withhold_reason_for_day`` names
    a reason — and it is the SAME reason.

    The payload's honesty rests on this: it recomputes the reason rather than reading a
    stored one, so the two gates diverging would let the payload explain a withhold
    that did not happen (or stay silent about one that did).
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        if has_profile:
            _profile(cur)
        _rhr(cur, today, rhrs)
        read_reason = withhold_reason_for_day(cur, SENTINEL_USER_ID, SENTINEL_TZ, today)
        wrote = derive_vo2max(cur, SENTINEL_USER_ID, SENTINEL_TZ, today) is not None
    assert read_reason == expected
    assert wrote is (read_reason is None)


def test_every_reason_has_a_message() -> None:
    """A reason with no message would surface as a bare machine string to a person."""
    for reason in (
        PROFILE_INCOMPLETE,
        WITHHOLD_FEW_RHR_DAYS,
        WITHHOLD_RHR_TOO_NOISY,
        NOT_DERIVED_YET,
    ):
        assert WITHHOLD_MESSAGES[reason].strip()
