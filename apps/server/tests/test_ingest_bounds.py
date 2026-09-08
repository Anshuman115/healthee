"""What the ingest boundary REFUSES — `AUTH_AUDIT.md` D1–D3.

`tests/test_ingest_models.py` had five tests and none of them was a bounds test, which
is how `SampleIn.value` came to accept NaN, Infinity and 1e308 while `read/gps_request
.py`, one directory over, bounded a phone-supplied route to the millimetre.

## Why every assertion here is a REFUSAL and not a sanitisation

A rejected upload is retried by the device. A sanitised one is stored, and once stored
nobody can tell it from a measurement. A NaN reaching `sample.value` propagates into
every mean, baseline, TRIMP and VO2max window over that day — each becomes NaN — and
serialises back out as invalid JSON, with nothing in the row saying it was never real.

## The accepting tests are not padding

Half of this file asserts what still gets THROUGH. A bound that refuses real data is a
worse defect than the one it fixes: it silently stops an owner's strap from syncing, and
it looks like a network problem. So the realistic push body is asserted to pass, and
each bound is asserted to accept a value close to but inside it.
"""

from __future__ import annotations

import json
import math

import pytest
from pydantic import ValidationError

from healthee.core.bounds import MAX_MAGNITUDE, MAX_WEIGHT_KG, MIN_WEIGHT_KG
from healthee.ingest.models import HelioPayload, SampleIn, SleepIn

# A normal, recent instant — every bounded field below is built around it.
_NOW_MS = 1_780_000_000_000  # 2026-06-08, comfortably inside the plausible window
_MINUTE_MS = 60_000


def _sample(**over: object) -> dict:
    return {"metric": "hr", "ts": _NOW_MS, "value": 61.0, **over}


# ── D1: the value is a number, or the push is refused ────────────────────────


@pytest.mark.parametrize("literal", ["NaN", "Infinity", "-Infinity"])
def test_a_non_numeric_value_is_refused(literal: str) -> None:
    """Python's `json` parses these bare literals out of a body, and pydantic v2's
    `allow_inf_nan` DEFAULTS to True — so all three used to be stored verbatim."""
    body = json.loads(f'{{"samples": [{{"metric": "hr", "ts": {_NOW_MS}, "value": {literal}}}]}}')
    assert math.isnan(body["samples"][0]["value"]) or math.isinf(body["samples"][0]["value"]), (
        "the premise: json really does hand us this value"
    )
    with pytest.raises(ValidationError):
        HelioPayload.model_validate(body)


def test_a_value_beyond_every_measurable_magnitude_is_refused() -> None:
    """1e308 is finite, so `allow_inf_nan=False` alone would let it through — and one
    such row dominates every mean it enters."""
    with pytest.raises(ValidationError):
        SampleIn.model_validate(_sample(value=1e308))


def test_a_real_reading_is_still_accepted() -> None:
    assert SampleIn.model_validate(_sample(value=61.0)).value == 61.0
    assert SampleIn.model_validate(_sample(value=-3.5)).value == -3.5
    assert SampleIn.model_validate(_sample(value=MAX_MAGNITUDE)).value == MAX_MAGNITUDE


def test_an_unknown_metric_name_is_still_not_refused() -> None:
    """The deliberate asymmetry, pinned so a bounds sweep cannot quietly reverse it.

    An unknown NAME is forward compatibility — a newer app may be ahead of this server,
    and the upsert coerce-drops and counts it (`samples_rejected`). An unknown VALUE is
    not ahead of anything.
    """
    payload = HelioPayload.model_validate({"samples": [_sample(metric="made_up")]})
    assert payload.samples[0].metric == "made_up"


# ── D2: the instant resolves to a plausible moment ───────────────────────────


def test_an_out_of_range_epoch_is_a_422_and_not_a_500() -> None:
    """`datetime.fromtimestamp` raises OverflowError/OSError on these — out of an ingest
    handler with no handler for it, i.e. a 500 blaming the server for a client's
    number."""
    for ts in (10**18, -(10**18), 10**15):
        with pytest.raises(ValidationError):
            SampleIn.model_validate(_sample(ts=ts))


def test_an_instant_centuries_from_now_is_refused() -> None:
    """In range for `datetime`, and a `sample` row every window then has to cope with."""
    with pytest.raises(ValidationError):
        SampleIn.model_validate(_sample(ts=99_999_999_999_999))


def test_an_instant_before_the_ms_seconds_flip_is_refused() -> None:
    """Below that point a millisecond value is small enough to be read as seconds, so
    the instant cannot be parsed unambiguously — and guessing is what storing it does."""
    with pytest.raises(ValidationError):
        SampleIn.model_validate(_sample(ts=900_000_000_000))  # 1998, as ms


def test_seconds_and_milliseconds_are_both_still_accepted() -> None:
    """The documented tolerance, kept: the bound is on the RESOLVED instant, never on
    the raw integer, so a seconds-encoded recent timestamp is fine."""
    assert SampleIn.model_validate(_sample(ts=_NOW_MS)).ts == _NOW_MS
    assert SampleIn.model_validate(_sample(ts=_NOW_MS // 1000)).ts == _NOW_MS // 1000


# ── D3: no list is unbounded, and the hypnogram cannot amplify ───────────────


def test_the_sample_list_is_capped() -> None:
    """The client pages at 4,000 (`push_reader.kPushSampleLimit`); the cap is well above
    it, and it exists at all."""
    too_many = {"samples": [_sample() for _ in range(20_001)]}
    with pytest.raises(ValidationError):
        HelioPayload.model_validate(too_many)


def test_a_full_client_page_is_still_accepted() -> None:
    page = {"samples": [_sample(ts=_NOW_MS + i * _MINUTE_MS) for i in range(4_000)]}
    assert len(HelioPayload.model_validate(page).samples) == 4_000


def _sleep(stages: list[list[int]], span_ms: int = 8 * 3600 * 1000) -> dict:
    return {
        "start_ts": _NOW_MS,
        "end_ts": _NOW_MS + span_ms,
        "kind": "main",
        "stages": stages,
    }


def test_a_stage_spanning_years_is_refused() -> None:
    """The amplifier. `emit_sleep_minutes` runs `generate_series(start, end, '1 minute')`
    on each stage with nothing between the payload's numbers and that statement — one
    stage declaring a span of years materialised tens of millions of rows per request."""
    years = 5 * 365 * 24 * 3600 * 1000
    with pytest.raises(ValidationError):
        SleepIn.model_validate(_sleep([[_NOW_MS, _NOW_MS + years, 2]]))


def test_stages_that_together_exceed_a_day_of_minutes_are_refused() -> None:
    """The per-stage cap alone is not enough: 2,000 stages of 23 h each is the same
    attack in pieces. What is bounded is what one session can MATERIALISE."""
    hour = 3600 * 1000
    many = [[_NOW_MS + i * hour, _NOW_MS + (i + 1) * hour, 2] for i in range(30)]
    with pytest.raises(ValidationError):
        SleepIn.model_validate(_sleep(many))


def test_a_real_nights_hypnogram_is_accepted() -> None:
    """~7 h in ten segments — the shape the strap actually reports."""
    step = 42 * _MINUTE_MS
    stages = [[_NOW_MS + i * step, _NOW_MS + (i + 1) * step, 2 if i % 2 else 7] for i in range(10)]
    assert len(SleepIn.model_validate(_sleep(stages)).stages) == 10


def test_a_malformed_stage_is_a_422_naming_the_field_not_an_indexerror() -> None:
    """`stages: [[]]` used to be an `IndexError` inside `emit_sleep_minutes` → 500, and
    the inner list's arity was never validated because the type is `list[list[int]]`."""
    for bad in ([[]], [[_NOW_MS]], [[_NOW_MS, _NOW_MS + _MINUTE_MS]], [[1, 2, 3, 4]]):
        with pytest.raises(ValidationError):
            SleepIn.model_validate(_sleep(bad))


def test_the_stage_list_itself_is_capped() -> None:
    with pytest.raises(ValidationError):
        SleepIn.model_validate(_sleep([[_NOW_MS, _NOW_MS + _MINUTE_MS, 2]] * 2_001))


def test_the_sleep_workout_and_totals_lists_are_capped() -> None:
    workout = {"start_ts": _NOW_MS, "sport": 1, "duration_s": 1800}
    total = {"day": "2026-06-16", "steps": 9264}
    with pytest.raises(ValidationError):
        HelioPayload.model_validate({"sleep": [_sleep([])] * 201})
    with pytest.raises(ValidationError):
        HelioPayload.model_validate({"workouts": [workout] * 501})
    with pytest.raises(ValidationError):
        HelioPayload.model_validate({"daily_totals": [total] * 401})


# ── D4 (shared with read/logs): a weight is a body mass ──────────────────────


@pytest.mark.parametrize("kg", [0.0, MIN_WEIGHT_KG - 0.1, MAX_WEIGHT_KG + 0.1, 1e308])
def test_a_profile_weight_outside_human_range_is_refused(kg: float) -> None:
    """`weight_log.kg` is `numeric(5,2)`, so an unbounded float is a database error
    before it is anything else — and weight feeds BMI, VO2max and biological age."""
    with pytest.raises(ValidationError):
        HelioPayload.model_validate({"profile": {"weight_kg": kg}})


def test_a_real_weight_is_accepted() -> None:
    payload = HelioPayload.model_validate({"profile": {"weight_kg": 79.9}})
    assert payload.profile is not None and payload.profile.weight_kg == 79.9
