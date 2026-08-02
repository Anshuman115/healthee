"""Golden known-value test: both estimators on ONE real recorded session (#114).

``tests/fixtures/gps_track_2026_06_15.json`` is the owner's real 2026-06-15 outdoor
session out of the prod dump — 370 GPS fixes, 18 strap HR samples, 18 minutes, an
18-minute walk containing a ~3.5-minute run. **Longitude is shifted by a constant for
privacy**; haversine depends only on the longitude DIFFERENCE, so every distance, speed
and grade in it is bit-identical to the original recording. The SRTM elevations are
baked in, so the fixture needs no network and no DEM cache.

This is the anchor the whole of #114 is measured against, and it pins three things at
once:

* the graded fit still returns **39.6** — the one real fitness measurement this owner
  has, and the number #108's withdrawal of the Jurca estimate was corroborated against;
* the reserve inversion returns **40.9** on the SAME session, i.e. the two independent
  instruments agree within 1.3 mL/kg/min;
* the walking part of that same session, scored on its own, does NOT agree — which is
  the finding, not a wart.
"""

from __future__ import annotations

import json
from collections.abc import Callable
from pathlib import Path

import pytest

from healthee.derive.gps import make_hr_interpolator
from healthee.derive.vo2max_reserve import (
    MIN_SPEED_MS,
    WITHHOLD_WALKING_ONLY,
    reserve_vo2max,
    vo2max_from_reserve,
)
from healthee.derive.vo2max_submax import steady_windows, vo2max_from_track

_FIXTURE = Path(__file__).parent.parent / "fixtures" / "gps_track_2026_06_15.json"

# What the graded GPS method measured on this session — the reference every other
# estimate in #114 is compared to. Reported in docs/CADENCE_VO2MAX_FEASIBILITY.md §1.1.
GRADED_VO2MAX = 39.6
# What the reserve inversion returns on the same session's running windows.
RESERVE_VO2MAX = 40.9
# The highest VO2 he SUSTAINED in a steady window here. A VO2max cannot be below a value
# the person held submaximally, so this is a hard floor derived from his own data with
# no model in between — it is what refutes every walking-derived estimate.
SUSTAINED_VO2_FLOOR = 38.9


@pytest.fixture(scope="module")
def track() -> dict:
    return json.loads(_FIXTURE.read_text())


@pytest.fixture(scope="module")
def points(track: dict) -> list[tuple[float, float, float, float | None]]:
    return [
        (float(t), float(la), float(ln), None if e is None else float(e))
        for t, la, ln, e in track["points"]
    ]


@pytest.fixture(scope="module")
def hr_at(track: dict) -> Callable[[float], float | None]:
    return make_hr_interpolator(
        [float(t) for t, _ in track["hr_samples"]],
        [float(v) for _, v in track["hr_samples"]],
    )


def test_graded_fit_known_value(points, hr_at, track) -> None:
    """The shipped graded method on real data: 39.6 mL/kg/min, r²=0.66, 31 windows."""
    result, status = vo2max_from_track(points, hr_at, track["hrmax_tanaka"])
    assert status == "ok"
    assert result is not None
    assert result.vo2max == GRADED_VO2MAX
    assert result.n_windows == 31
    assert result.r2 == 0.66
    assert result.hr_range == 43.0


def test_reserve_inversion_known_value(points, hr_at, track) -> None:
    """The reserve inversion on the same session: 40.9 from 7 running windows."""
    result, status = vo2max_from_reserve(
        steady_windows(points, hr_at), track["hr_rest_7d_median"], track["hrmax_tanaka"]
    )
    assert status == "ok"
    assert result is not None
    assert result.vo2max == RESERVE_VO2MAX
    assert result.n_windows == 7


def test_the_two_instruments_agree_on_this_session(points, hr_at, track) -> None:
    """Within 1.3 mL/kg/min — well inside Jurca's 5.075 SEE, and the reason the reserve
    method is admitted at all. If a change makes these diverge, the change is wrong."""
    graded, _ = vo2max_from_track(points, hr_at, track["hrmax_tanaka"])
    reserve, _ = vo2max_from_reserve(
        steady_windows(points, hr_at), track["hr_rest_7d_median"], track["hrmax_tanaka"]
    )
    assert graded is not None and reserve is not None
    assert abs(reserve.vo2max - graded.vo2max) < 2.0


def test_sustained_vo2_floors_the_answer(points, hr_at) -> None:
    """He held 38.9 mL/kg/min in a steady window. Both instruments must land above it.

    This is the model-free check: no estimator may report a VO2max below an oxygen
    uptake the person demonstrably sustained submaximally.
    """
    wins = steady_windows(points, hr_at)
    assert wins is not None
    assert max(w.vo2 for w in wins) == pytest.approx(SUSTAINED_VO2_FLOOR, abs=0.05)
    assert GRADED_VO2MAX > SUSTAINED_VO2_FLOOR
    assert RESERVE_VO2MAX > SUSTAINED_VO2_FLOOR


def test_the_walking_half_of_this_session_is_refused(points, hr_at, track) -> None:
    """Strip the running windows out and the same session yields nothing.

    The walking windows here are real, steady, and sit at 55-87% of heart-rate reserve —
    inside the range the equivalence was validated over. They still invert to roughly
    half the session's true value, which is why the gate is on modality and the answer
    is a refusal rather than a wider error bar.
    """
    wins = steady_windows(points, hr_at)
    assert wins is not None
    walking = [w for w in wins if w.speed_ms < MIN_SPEED_MS]
    assert len(walking) >= 20  # a real walk, not a rounding artefact

    result, reason = vo2max_from_reserve(walking, track["hr_rest_7d_median"], track["hrmax_tanaka"])
    assert result is None
    assert reason == WITHHOLD_WALKING_ONLY

    # ...and this is the number the refusal prevented.
    ungated = [
        v
        for w in walking
        if (v := reserve_vo2max(w, track["hr_rest_7d_median"], track["hrmax_tanaka"])) is not None
    ]
    ungated.sort()
    assert ungated[len(ungated) // 2] < 25.0  # median ~18.7, against a true ~40
