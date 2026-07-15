"""Unit tests for the /ingest/helio pydantic models.

Builds a payload in the exact shape the mobile client's `helio_api.dart` push()
sends, and asserts the model accepts it, parses `day` to a date, and rejects a
malformed sample (missing field) — while an *unknown metric* is NOT rejected here
(it is coerce-dropped in the upsert layer).
"""

from __future__ import annotations

from datetime import date

import pytest
from pydantic import ValidationError

from healthee.ingest.models import HelioPayload

# A realistic push body — mirrors helio_api.dart push() field-for-field.
_PUSH_BODY = {
    "samples": [
        {"metric": "hr", "ts": 1_718_000_000_000, "value": 61.0},
        {"metric": "steps_per_minute", "ts": 1_718_000_060_000, "value": 12.0},
        {"metric": "hrv", "ts": 1_718_000_120_000, "value": 44.0},
    ],
    "sleep": [
        {
            "start_ts": 1_717_950_000_000,
            "end_ts": 1_717_980_000_000,
            "kind": "main",
            "score": 89,
            "avg_hr": 55,
            "rem_min": 90,
            "light_min": 200,
            "deep_min": 80,
            "wake_min": 20,
            "stages": [
                [1_717_950_000_000, 1_717_953_600_000, 2],
                [1_717_953_600_000, 1_717_957_200_000, 7],
            ],
        }
    ],
    "workouts": [
        {
            "start_ts": 1_717_900_000_000,
            "sport": 1,
            "duration_s": 1800,
            "calories": 250,
            "avg_hr": 130,
            "max_hr": 155,
            "min_hr": 95,
        }
    ],
    "daily_totals": [{"day": "2026-06-16", "steps": 9264, "distance_m": 5081, "calories": 451}],
    "profile": {
        "name": "Ashish",
        "height_cm": 178.0,
        "sex": "male",
        "dob": 631_152_000_000,
        "weight_kg": 72.5,
    },
}


def test_accepts_realistic_push_body() -> None:
    payload = HelioPayload.model_validate(_PUSH_BODY)
    assert len(payload.samples) == 3
    assert payload.samples[0].metric == "hr"
    assert payload.sleep[0].kind == "main"
    assert payload.sleep[0].stages[0] == [1_717_950_000_000, 1_717_953_600_000, 2]
    assert payload.workouts[0].duration_s == 1800
    assert payload.daily_totals[0].day == date(2026, 6, 16)
    assert payload.profile is not None
    assert payload.profile.weight_kg == 72.5


def test_empty_body_is_valid() -> None:
    # A push can omit every section; all lists default empty, profile None.
    payload = HelioPayload.model_validate({})
    assert payload.samples == []
    assert payload.profile is None


def test_workout_distance_defaults_none() -> None:
    # The app omits distance_m on workouts; the column stays optional.
    payload = HelioPayload.model_validate(_PUSH_BODY)
    assert payload.workouts[0].distance_m is None


def test_malformed_sample_missing_ts_is_rejected() -> None:
    with pytest.raises(ValidationError):
        HelioPayload.model_validate({"samples": [{"metric": "hr", "value": 61.0}]})


def test_unknown_metric_is_accepted_at_model_level() -> None:
    # Whitelisting happens in the upsert (coerce-drop), not the model, so a newer
    # app adding a metric never 422s its whole push.
    payload = HelioPayload.model_validate(
        {"samples": [{"metric": "made_up", "ts": 1_718_000_000_000, "value": 1.0}]}
    )
    assert payload.samples[0].metric == "made_up"
