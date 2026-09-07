"""Directive 5 of ``non_exercise_vo2max.md``: out-of-range inputs are FLAGGED.

The note asks for this twice, and gives the ranges once:

    Coach Directive 5 (confidence: moderate) — "Flag decoupling confounders
    (beta-blockers, atropine, out-of-range inputs) when known."

    Safety bounds — "Out-of-range inputs make it unreliable: the model was
    validated for ages 20-70, BMI 16-45, RHR 40-100; outside those bounds error
    grows and the estimate should be flagged or withheld."

    Honesty & uncertainty — "Out-of-range inputs (ages, BMI, RHR outside the
    validated ranges) grow the error."

RHR already takes the note's *withhold* branch (``test_vo2max_withhold.py``); age
and BMI take the *flag* branch, and until now took neither — a 78-year-old's
estimate shipped looking exactly as solid as a 40-year-old's.

Every boundary below is the note's number, asserted from both sides. The flags are
ADDITIVE: the estimate must be byte-identical with and without them.
"""

from __future__ import annotations

from datetime import date, timedelta

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.derive.vo2max import (
    _AGE_VALID_HI_YEARS,
    _AGE_VALID_LO_YEARS,
    _BMI_VALID_HI,
    _BMI_VALID_LO,
    _vo2max_jurca,
    derive_vo2max,
    out_of_range_inputs,
)
from healthee.read.vo2max import vo2max_payload

_CALM_WEEK = [50.0, 52.0, 54.0, 56.0, 58.0, 60.0, 62.0]  # median 56, MAD 4 -> derives


def test_the_ranges_are_the_notes_numbers() -> None:
    """20-70 years and BMI 16-45, exactly as the Safety bounds section writes them."""
    assert (_AGE_VALID_LO_YEARS, _AGE_VALID_HI_YEARS) == (20, 70)
    assert (_BMI_VALID_LO, _BMI_VALID_HI) == (16.0, 45.0)


@pytest.mark.parametrize("age", [20, 45, 70])
def test_an_in_range_age_is_not_flagged(age: int) -> None:
    """The bounds are INCLUSIVE — the note says "ages 20-70", not "between"."""
    assert out_of_range_inputs(age, 24.0) == []


@pytest.mark.parametrize("age", [19, 71, 8, 95])
def test_an_out_of_range_age_is_flagged(age: int) -> None:
    flags = out_of_range_inputs(age, 24.0)
    assert [f["input"] for f in flags] == ["age_years"]
    assert flags[0]["value"] == age
    assert (flags[0]["validated_low"], flags[0]["validated_high"]) == (20, 70)
    assert "20-70" in flags[0]["message"]


@pytest.mark.parametrize("bmi", [16.0, 24.0, 45.0])
def test_an_in_range_bmi_is_not_flagged(bmi: float) -> None:
    assert out_of_range_inputs(40, bmi) == []


@pytest.mark.parametrize("bmi", [15.9, 45.1, 12.0, 60.0])
def test_an_out_of_range_bmi_is_flagged(bmi: float) -> None:
    flags = out_of_range_inputs(40, bmi)
    assert [f["input"] for f in flags] == ["bmi"]
    assert flags[0]["value"] == round(bmi, 1)
    assert (flags[0]["validated_low"], flags[0]["validated_high"]) == (16.0, 45.0)
    assert "16.0-45.0" in flags[0]["message"]


def test_both_inputs_out_of_range_flag_independently() -> None:
    """Two flags, not one summary — the owner is told which input, not just "bad"."""
    assert [f["input"] for f in out_of_range_inputs(75, 48.0)] == ["age_years", "bmi"]


def test_an_absent_input_is_not_an_out_of_range_input() -> None:
    """ "We cannot tell" is a different state from "outside the validated range".

    A missing profile input already withholds the whole estimate upstream, so this
    branch only guards a row whose flags predate a field — it must not invent a
    range violation from a null.
    """
    assert out_of_range_inputs(None, None) == []
    assert out_of_range_inputs(None, 24.0) == []
    assert out_of_range_inputs(40, None) == []


def test_the_flag_does_not_touch_the_estimate() -> None:
    """Additive, per the brief and the note: flag it, do not bend it.

    Two people identical but for age (70 = in range, 71 = flagged) must differ in
    their estimate ONLY by Jurca's own -0.10 METs/year age term:
        CRF(70) - CRF(71) = 0.10 METs -> 0.35 ml/kg/min.
    A flag that also clipped, floored or discounted the number would break this.
    """
    inside = _vo2max_jurca(age=70, sex="male", bmi=24.0, rhr=56.0, srpa=0)
    outside = _vo2max_jurca(age=71, sex="male", bmi=24.0, rhr=56.0, srpa=0)
    assert out_of_range_inputs(70, 24.0) == []
    assert len(out_of_range_inputs(71, 24.0)) == 1
    assert inside - outside == pytest.approx(0.35, abs=1e-9)


# ── end-to-end: the flag reaches the payload ─────────────────────────────────
#
# Anchored to the OWNER's today, not a fixed calendar date: `vo2max_payload` only
# reads the last 95 days, so a hardcoded day silently returns None as soon as the
# suite runs on a later date — the stale-fixture flake this repo has paid for before.


def _dob_for_age(today: date, years: int) -> str:
    """A 1 January birthday that makes the owner exactly ``years`` old today."""
    return f"{today.year - years:04d}-01-01"


def _seed(cur, day: date, dob: str, height_cm: int, weight_kg: float) -> None:
    for table in ("derived_daily", "weight_log", "profile"):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names
    cur.execute(
        # srpa 0 (Jurca's reference level) — the flags under test are age/BMI, and the
        # activity category must be ANSWERED or the estimate withholds first (#108).
        "INSERT INTO profile (user_id, height_cm, sex, dob, srpa) VALUES (%s, %s, 'male', %s, 0)",
        (SENTINEL_USER_ID, height_cm, dob),
    )
    cur.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, %s, %s)",
        # One day back, not 30: past `freshness.WEIGHT_MAX_AGE_DAYS` the estimate is
        # withheld outright (#85) and there would be no payload left to flag.
        (SENTINEL_USER_ID, day - timedelta(days=1), weight_kg),
    )
    for k, rhr in enumerate(_CALM_WEEK):
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value) VALUES (%s, %s, %s, %s)",
            (SENTINEL_USER_ID, day - timedelta(days=len(_CALM_WEEK) - 1 - k), "rhr_daily", rhr),
        )


@pytest.mark.usefixtures("db")
def test_an_in_range_owner_gets_no_flags_in_the_payload() -> None:
    """Age 35, 175 cm / 72 kg -> BMI 23.5. Both inputs inside Jurca's ranges."""
    day = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur, day, _dob_for_age(day, 35), 175, 72.0)
        assert derive_vo2max(cur, SENTINEL_USER_ID, SENTINEL_TZ, day) is not None
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload is not None
    assert payload["age_years"] == 35
    assert payload.get("caveats") == []


@pytest.mark.usefixtures("db")
def test_an_out_of_range_owner_is_flagged_but_still_gets_the_number() -> None:
    """Age 80, 175 cm / 150 kg -> BMI 49.0. Both inputs outside Jurca's ranges.

    The estimate is still produced and still shipped — Directive 5 flags, it does not
    withhold — but the payload now says the model is outside its validated range.
    """
    day = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur, day, _dob_for_age(day, 80), 175, 150.0)
        assert derive_vo2max(cur, SENTINEL_USER_ID, SENTINEL_TZ, day) is not None
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload is not None
    assert payload["estimate"] is not None
    # UNDER ``caveats``, which is the key the app's honesty envelope reads. Filed under a
    # key of its own the flag never became a `Caveated` reading and the estimate rendered
    # `Present` at full confidence, which is what this assertion is really guarding.
    # `.get`, not `[...]`, on purpose: a KeyError reports a missing key as an ERROR, and
    # this is a claim about the WIRE — the key being absent is the defect, so it has to
    # read as a failed assertion rather than as a broken test.
    caveats = payload.get("caveats")
    assert caveats is not None, "the out-of-range flags must ship under `caveats`"
    assert [f["input"] for f in caveats] == ["age_years", "bmi"]
    assert caveats[0]["value"] == 80
    assert caveats[1]["value"] == 49.0  # 150 / 1.75^2 = 48.98
    # `reason` + `message` are the envelope's two required fields; a block missing either
    # is dropped on the client, so the disclosure would exist and never be shown.
    for flag in caveats:
        assert isinstance(flag.get("reason"), str) and flag.get("reason")
        assert isinstance(flag.get("message"), str) and flag.get("message")
