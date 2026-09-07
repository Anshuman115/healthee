"""Why a workout's derived metrics are not there — the honesty envelope for one session.

``/api/activity/workout`` was the last payload in this API with no envelope at all.
``read/workout.py::_metrics`` writes a derived figure into ``metrics`` only when its
inputs existed and simply omits it otherwise, so the wire carried a bare absence: no
reason, no sentence, nothing a screen could say. The app filled that in for itself
(``apps/mobile/lib/data/workouts/workout_readings.dart``), which is the wrong place for
it twice over — the reasons are the server's own preconditions, and the client can only
see the ones that happen to be visible on the wire. The session TRIMP is the standing
proof: it needs a resting heart rate and the owner's sex, neither of which is in that
payload, so the app could only name all four inputs and hope. This module names the one
that was actually missing.

## The rule these sentences are written to

**Nothing here is a remedy.** ``derive/freshness.py``'s ``withheld_block`` carries a
second-person "do this and it comes back", and it earns that because a stale weight
really is fixed by weighing yourself. Almost none of these are: a treadmill run recorded
no distance and never will, and telling the owner to sync would be an instruction that
cannot work. So each message states the precondition that was not met, in the second
person, and stops there. A truthful absence with no action beats an action that is not
one.

**And nothing here re-derives anything.** The gates below read the same inputs
``_metrics`` branched on, in the same order, so the two cannot disagree about whether a
figure exists — the absence map is built for exactly the keys ``metrics`` did not
produce, and a gate that cannot explain one of them falls back to the shared
"no value and no reason" vocabulary rather than inventing a plausible cause.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

# The floor `read/workout.py` publishes a pace above: below it the distance is GPS noise
# rather than a route, and a pace computed from it would be arithmetic on a rounding
# error.
PACE_MIN_DISTANCE_M = 50

# Halves cannot be compared without enough minutes to halve.
DRIFT_MIN_SAMPLES = 6

# ── reason ids ───────────────────────────────────────────────────────────────
# One id per state, shared with the app's own vocabulary where the state is the same
# (`workout_readings.dart` already files absences under these names), so the client can
# stop reconstructing them without renaming what it shows.

NO_HRMAX = "hrmax_unavailable"
NO_HR_SUMMARY = "no_heart_rate_summary"
NO_DISTANCE = "no_recorded_distance"
NO_DURATION = "no_recorded_duration"
NO_STRAP_CALORIES = "no_strap_calories"
NO_HR_SAMPLES = "no_heart_rate_samples"
TOO_FEW_HR_SAMPLES = "too_few_heart_rate_samples"
NO_RESTING_HR = "resting_hr_unavailable"
NO_PROFILE_SEX = "profile_sex_missing"
HRMAX_NOT_ABOVE_RHR = "hrmax_not_above_resting_hr"
NO_MINUTE_IN_A_ZONE = "no_minute_reached_a_zone"

# The shared "we have no value and cannot say why" state. It exists so that a gate the
# code forgets to write shows up as an admitted gap rather than as a confident wrong
# reason; ``tests/read/test_workout_absence.py`` asserts it never fires in practice.
UNEXPLAINED = "unexplained_absence"

_MESSAGES: dict[str, str] = {
    NO_HRMAX: (
        "This needs an estimate of your maximum heart rate, and there was none for this "
        "session — it comes from your daily training-load row, which had not been "
        "computed."
    ),
    NO_HR_SUMMARY: "The strap sent no heart-rate summary for this session.",
    NO_DISTANCE: (
        "The strap recorded no distance for this session, or less than "
        f"{PACE_MIN_DISTANCE_M} m of it — below that the figure is GPS noise rather than "
        "a route."
    ),
    NO_DURATION: "The strap recorded no duration for this session.",
    NO_STRAP_CALORIES: "The strap recorded no calorie figure for this session.",
    NO_HR_SAMPLES: (
        "No heart-rate samples fell inside this session. A workout summary can reach the "
        "server before the minutes behind it do."
    ),
    TOO_FEW_HR_SAMPLES: (
        f"Comparing the two halves of a session needs at least {DRIFT_MIN_SAMPLES} "
        "recorded heart-rate minutes, and this one has fewer."
    ),
    NO_RESTING_HR: (
        "A session load is measured against your resting heart rate, and there was none "
        "on file for this session."
    ),
    NO_PROFILE_SEX: (
        "The session-load formula uses a sex-specific coefficient, and your profile does "
        "not record one."
    ),
    HRMAX_NOT_ABOVE_RHR: (
        "Your maximum and resting heart rates did not come out in the right order for "
        "this session, so the range the load is measured across is not usable."
    ),
    NO_MINUTE_IN_A_ZONE: (
        "No minute of this session reached 50% of your maximum heart rate, so there is "
        "no zone for one to be dominant in."
    ),
    UNEXPLAINED: (
        "There is no value for this, and we cannot say why. That is a gap on our side "
        "rather than in your data."
    ),
}


@dataclass(frozen=True)
class WorkoutInputs:
    """Everything ``read/workout.py::_metrics`` branches on, as it branched on it."""

    avg_hr: int | None
    max_hr: int | None
    distance_m: float | None
    duration_min: int | None
    calories: int | None
    hrmax: float | None
    rhr: float | None
    sex: str | None
    hr_sample_count: int
    zoned_minutes: int


def _pct_hrmax(i: WorkoutInputs) -> str | None:
    """``avg_pct_hrmax`` / ``intensity``: an average heart rate priced against HRmax."""
    if not i.avg_hr:
        return NO_HR_SUMMARY
    return None if i.hrmax else NO_HRMAX


def _max_pct_hrmax(i: WorkoutInputs) -> str | None:
    if not i.max_hr:
        return NO_HR_SUMMARY
    return None if i.hrmax else NO_HRMAX


def _pace(i: WorkoutInputs) -> str | None:
    """``pace_min_per_km`` / ``speed_kmh``: a distance worth dividing, and a duration."""
    if not (i.distance_m and i.distance_m > PACE_MIN_DISTANCE_M):
        return NO_DISTANCE
    return None if i.duration_min else NO_DURATION


def _cal_rate(i: WorkoutInputs) -> str | None:
    if not i.calories:
        return NO_STRAP_CALORIES
    return None if i.duration_min else NO_DURATION


def _trimp(i: WorkoutInputs) -> str | None:
    """The four inputs Banister needs, reported one at a time in the order checked."""
    if not i.hr_sample_count:
        return NO_HR_SAMPLES
    if not i.hrmax:
        return NO_HRMAX
    if not i.rhr:
        return NO_RESTING_HR
    if i.sex not in ("male", "female"):
        return NO_PROFILE_SEX
    return None if i.hrmax > i.rhr else HRMAX_NOT_ABOVE_RHR


def _drift(i: WorkoutInputs) -> str | None:
    if not i.hr_sample_count:
        return NO_HR_SAMPLES
    return None if i.hr_sample_count >= DRIFT_MIN_SAMPLES else TOO_FEW_HR_SAMPLES


def _dominant_zone(i: WorkoutInputs) -> str | None:
    if not i.hrmax:
        return NO_HRMAX
    if not i.hr_sample_count:
        return NO_HR_SAMPLES
    return None if i.zoned_minutes else NO_MINUTE_IN_A_ZONE


def _zones(i: WorkoutInputs) -> str | None:
    """The five zone buckets themselves: all zero without an HRmax to cut them against."""
    if not i.hrmax:
        return NO_HRMAX
    return None if i.hr_sample_count else NO_HR_SAMPLES


# Derived key → the gate that explains its absence. ``zones`` is in here although it is
# not inside ``metrics``: an all-zero zone list is a real reading about an easy session
# when an HRmax exists, and a structural blank when one does not, and only the server can
# tell those two apart.
_GATES: tuple[tuple[str, Callable[[WorkoutInputs], str | None]], ...] = (
    ("avg_pct_hrmax", _pct_hrmax),
    ("intensity", _pct_hrmax),
    ("max_pct_hrmax", _max_pct_hrmax),
    ("pace_min_per_km", _pace),
    ("speed_kmh", _pace),
    ("cal_per_min", _cal_rate),
    ("trimp", _trimp),
    ("hr_drift_bpm", _drift),
    ("dominant_zone", _dominant_zone),
    ("zones", _zones),
)


def workout_absences(inputs: WorkoutInputs, produced: set[str]) -> dict[str, dict]:
    """``{metric: {reason, message}}`` for every derived figure this session cannot carry.

    ``produced`` is the set of keys ``_metrics`` actually wrote, so this describes the
    payload rather than predicting it: a key that IS present is never explained away, and
    a key that is absent always gets a sentence — the fallback one if no gate claims it,
    because "we did not compute this" must never reach the wire as silence.
    """
    out: dict[str, dict] = {}
    for name, gate in _GATES:
        if name in produced:
            continue
        reason = gate(inputs) or UNEXPLAINED
        out[name] = {"reason": reason, "message": _MESSAGES[reason]}
    return out
