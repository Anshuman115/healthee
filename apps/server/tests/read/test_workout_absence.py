"""B6 — the workout payload names why each derived figure it lacks is missing.

``/api/activity/workout`` was the one payload in this API with no honesty envelope: a
bare nullable for every derived metric, and a key simply absent when its inputs were.
The app reconstructed the reasons for itself
(``apps/mobile/lib/data/workouts/workout_readings.dart``), which is the wrong place
twice over — the preconditions are the server's, and the client can only see the ones
that happen to reach the wire. The session TRIMP is the standing proof: it needs a
resting heart rate and the owner's sex, and neither is in that payload.

Split out of ``test_wire_thinness.py`` at the 400-line gate. It was the right seam
anyway: the other section-B items are each one field on one payload, while this is a
whole vocabulary with a gate per figure (standards §1 — a file has one reason to change).

The load-bearing property is not that reasons EXIST but that they agree with the
producer: every session below is put through ``read/workout.py::_metrics`` itself, and
the absence map is checked against what that function really produced. A test that named
the produced set by hand could only prove the gates agree with the test.
"""

from __future__ import annotations

from datetime import UTC, datetime, time
from zoneinfo import ZoneInfo

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.read.workout import _metrics, _zone_minutes, workout_detail
from healthee.read.workout_absence import (
    DRIFT_MIN_SAMPLES,
    NO_HR_SAMPLES,
    NO_HRMAX,
    NO_STRAP_CALORIES,
    UNEXPLAINED,
    WorkoutInputs,
    workout_absences,
)

pytestmark = pytest.mark.integration

_ZONE = ZoneInfo(SENTINEL_TZ)

_FULL_SESSION = {
    "avg_hr": 135,
    "max_hr": 168,
    "distance_m": 4200.0,
    "duration_min": 30,
    "calories": 250,
    "hrmax": 185.0,
    "rhr": 55.0,
    "sex": "male",
    "hrs": [130 + (n % 20) for n in range(30)],
}


def _session(**over) -> tuple[WorkoutInputs, set[str]]:
    """One session's inputs AND the keys ``_metrics`` really produces from them."""
    s = {**_FULL_SESSION, **over}
    zones = _zone_minutes(s["hrs"], s["hrmax"])
    metrics = _metrics(
        s["avg_hr"],
        s["max_hr"],
        s["distance_m"],
        s["duration_min"],
        s["calories"],
        s["hrmax"],
        s["rhr"],
        s["sex"],
        s["hrs"],
        zones,
    )
    inputs = WorkoutInputs(
        avg_hr=s["avg_hr"],
        max_hr=s["max_hr"],
        distance_m=s["distance_m"],
        duration_min=s["duration_min"],
        calories=s["calories"],
        hrmax=s["hrmax"],
        rhr=s["rhr"],
        sex=s["sex"],
        hr_sample_count=len(s["hrs"]),
        zoned_minutes=sum(zones),
    )
    produced = set(metrics) | ({"zones"} if s["hrmax"] and s["hrs"] else set())
    return inputs, produced


def _absences(**over) -> dict[str, dict]:
    inputs, produced = _session(**over)
    return workout_absences(inputs, produced)


def test_a_complete_session_withholds_nothing() -> None:
    """Otherwise every later test could pass by explaining absences that are not there."""
    assert _absences() == {}


def test_each_absence_names_the_input_that_was_actually_missing() -> None:
    """The whole point of moving this to the server: it can see which one it was.

    The client could only name all four TRIMP inputs, because the resting heart rate and
    the owner's sex are not on that payload at all.
    """
    absences = _absences(rhr=None)
    assert absences["trimp"]["reason"] == "resting_hr_unavailable"
    assert "resting heart rate" in absences["trimp"]["message"]

    assert _absences(sex=None)["trimp"]["reason"] == "profile_sex_missing"
    assert _absences(hrmax=None)["trimp"]["reason"] == NO_HRMAX
    assert _absences(hrs=[])["trimp"]["reason"] == NO_HR_SAMPLES


def test_a_short_session_is_told_apart_from_one_with_no_samples_at_all() -> None:
    """Two different states, two ids — "too few" and "none" are not the same answer."""
    few = _absences(hrs=[130] * (DRIFT_MIN_SAMPLES - 1))
    assert few["hr_drift_bpm"]["reason"] == "too_few_heart_rate_samples"
    assert _absences(hrs=[])["hr_drift_bpm"]["reason"] == NO_HR_SAMPLES


def test_no_absence_is_ever_left_unexplained_by_a_real_gate() -> None:
    """The fallback exists so a forgotten gate is admitted, not so it can be used.

    Every input stripped one at a time, and no combination reaches the shared
    "we cannot say why" id — which is what makes that id a tripwire rather than a shrug.
    Each strip is also asserted to REMOVE something, so a strip that stopped mattering
    fails here instead of quietly testing the complete session over again.
    """
    strips = (
        {"avg_hr": None},
        {"max_hr": None},
        {"distance_m": None},
        {"distance_m": 10.0},
        {"duration_min": None},
        {"calories": None},
        {"hrmax": None},
        {"rhr": None},
        {"sex": None},
        {"hrs": []},
        {"hrs": [80] * 30},  # every minute below 50% HRmax: no zone, so no dominant one
        {"hrmax": 40.0},  # below the resting HR: the range TRIMP measures across is unusable
    )
    for strip in strips:
        absences = _absences(**strip)
        assert absences, f"{strip} removed nothing"
        for name, block in absences.items():
            assert block["reason"] != UNEXPLAINED, f"{strip} → {name}"
            assert block["message"], f"{strip} → {name}"


@pytest.mark.usefixtures("db")
def test_a_real_session_with_no_heart_rate_explains_every_figure_it_lacks() -> None:
    """End to end: the envelope reaches the payload, and it describes THAT payload.

    A key present in ``metrics`` is never explained away, and a key absent from it always
    carries a sentence.
    """
    today = user_today(SENTINEL_TZ)
    start = datetime.combine(today, time(7, 0), tzinfo=_ZONE).astimezone(UTC)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        for table in ("derived_daily", "workout", "sample", "profile"):
            cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names
        cur.execute(
            "INSERT INTO workout (user_id,start_ts,sport,duration_s,calories,distance_m) "
            "VALUES (%s,%s,1,1800,NULL,NULL)",
            (SENTINEL_USER_ID, start),
        )
        detail = workout_detail(cur, SENTINEL_USER_ID, SENTINEL_TZ, start.isoformat())

    withheld = detail["metrics_withheld"]
    assert set(withheld) & set(detail["metrics"]) == set()
    assert withheld["cal_per_min"]["reason"] == NO_STRAP_CALORIES
    assert withheld["pace_min_per_km"]["reason"] == "no_recorded_distance"
    assert withheld["trimp"]["reason"] == NO_HR_SAMPLES
    assert all(block["message"] for block in withheld.values())
    assert all(block["reason"] != UNEXPLAINED for block in withheld.values())

    # `zones` is five zeroes on this payload and it is NOT a measurement: there
    # was no HRmax to cut them against. All-zero IS a reading on a session that
    # had one — "no minute reached 50%" is a fact about an easy hour — so only
    # the server can tell the two apart, and an unexplained zero list would
    # render as the easy session this owner did not have.
    assert detail["zones"] == [0, 0, 0, 0, 0]
    assert detail["hrmax"] is None
    assert withheld["zones"]["reason"] == NO_HRMAX
