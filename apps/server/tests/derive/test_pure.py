"""Known-value unit tests for the pure (no-DB) science helpers.

These need no database. Expected values are hand-computed from the published
formulas or captured from the legacy self-test, and are documented inline so a
future edit that changes the math fails loudly (standards §1: science code is
sacred — every published method carries a known-value test).
"""

from __future__ import annotations

import math
import random

import pytest

from healthee.derive.dem import _tile_name
from healthee.derive.mvpa import _weekly_mvpa_to_srpa
from healthee.derive.sleep_score import _sleep_efficiency
from healthee.derive.vo2max import _vo2max_jurca
from healthee.derive.vo2max_submax import SubmaxResult, _vo2_speed_grade, vo2max_from_track

# ── Jurca 2005 non-exercise VO2max ───────────────────────────────────────────
# CRF_METs = 18.07 + 2.77*sex - 0.10*age - 0.17*bmi - 0.03*rhr + srpa; VO2 = CRF*3.5.
# Jurca et al. 2005, Am J Prev Med 29(3):185-193 [[non_exercise_vo2max]].


def test_vo2max_jurca_male_known_value() -> None:
    # A median 40yo male: (18.07 + 2.77 - 0.10*40 - 0.17*24 - 0.03*55) * 3.5
    # = 11.11 * 3.5 = 38.885 ml/kg/min — a plausible value near the ~38 population
    # median for that age/sex. The OLD (biased-low) equation returned ~24 here.
    assert _vo2max_jurca(40, "male", 24.0, 55, 0) == pytest.approx(38.885, abs=0.5)
    assert _vo2max_jurca(40, "male", 24.0, 55, 0) > 30.0  # never the old ~24 bug


def test_vo2max_jurca_female_known_value() -> None:
    # Female drops the +2.77 sex term: (18.07 - 4.0 - 4.08 - 1.65) * 3.5
    # = 8.34 * 3.5 = 29.19 ml/kg/min.
    assert _vo2max_jurca(40, "female", 24.0, 55, 0) == pytest.approx(29.19, abs=1e-2)


def test_vo2max_jurca_floors_at_20() -> None:
    # A very unfit profile drives the regression below 20; the floor holds.
    assert _vo2max_jurca(80, "male", 40.0, 100, 0) == 20.0


# ── Sleep efficiency is asleep/(asleep+awake) — never > 100% (C2) ────────────


def test_sleep_efficiency_perfect_night_is_100() -> None:
    # 23:00-07:00, stages 300+90+90 = 480 min asleep, 0 awake -> exactly 100%.
    eff = _sleep_efficiency(480, 0)
    assert round(eff * 100, 1) == 100.0


def test_sleep_efficiency_never_exceeds_100_on_overshoot() -> None:
    # Pathological input where staged minutes overshoot the wall-clock span: the
    # legacy TST/TIB form reported >100%; the timeline form is clamped to <= 100.
    for tst, wake in [(500, 0), (490, 20), (600, 50)]:
        assert round(_sleep_efficiency(tst, wake) * 100, 1) <= 100.0


# ── ACSM x Minetti VO2 from speed + grade ────────────────────────────────────


def test_vo2_speed_grade_level_running() -> None:
    # 3 m/s (>=2 -> running): level = 3.5 + 0.2*(180) = 39.5; grade 0 -> ratio 1.
    assert _vo2_speed_grade(3.0, 0.0) == pytest.approx(39.5)


def test_vo2_speed_grade_level_walking() -> None:
    # 1 m/s (<2 -> walking): level = 3.5 + 0.1*(60) = 9.5; grade 0 -> ratio 1.
    assert _vo2_speed_grade(1.0, 0.0) == pytest.approx(9.5)


def test_vo2_speed_grade_uphill_costs_more_than_downhill() -> None:
    up = _vo2_speed_grade(1.4, 0.10)
    down = _vo2_speed_grade(1.4, -0.10)
    level = _vo2_speed_grade(1.4, 0.0)
    assert up > level > down  # Minetti U-shape: uphill dearer, gentle downhill cheaper


# ── Jurca 0-4 SRPA category from weekly MVPA-EQUIVALENT minutes ──────────────
# Bands: 0:<10  1:10-19  2:20-59  3:60-179  4:>=180 (min/wk) [[non_exercise_vo2max]].


@pytest.mark.parametrize(
    ("weekly_equiv", "expected"),
    [
        (0, 0),
        (5, 0),
        (10, 1),
        (19, 1),
        (20, 2),
        (30, 2),
        (59, 2),
        (60, 3),
        (179, 3),
        (180, 4),
        (210, 4),
    ],
)
def test_weekly_mvpa_to_srpa_boundaries(weekly_equiv: float, expected: int) -> None:
    assert _weekly_mvpa_to_srpa(weekly_equiv) == expected


def test_weekly_mvpa_equivalent_doubles_vigorous() -> None:
    # WHO rule: 10 moderate + 10 vigorous -> 10 + 2*10 = 30 equivalent min (not 20),
    # which lands in SRPA band 2 (20-59). [[cadence_intensity]]
    moderate, vigorous = 10, 10
    weekly_equiv = moderate + 2 * vigorous
    assert weekly_equiv == 30
    assert _weekly_mvpa_to_srpa(weekly_equiv) == 2


# ── SRTM tile naming ─────────────────────────────────────────────────────────


def test_tile_name_northern_eastern() -> None:
    assert _tile_name(28.6139, 77.2090) == "N28E077"  # Delhi


def test_tile_name_southern_western() -> None:
    assert _tile_name(-1.5, -0.5) == "S02W001"  # floor(-1.5)=-2, floor(-0.5)=-1


# ── Submaximal VO2max — legacy self-test track (captured expected numbers) ───


def _synthetic_track() -> tuple[
    list[tuple[float, float, float, float | None]], dict[int, float], float
]:
    """The legacy __main__ self-test: a 24-min progressive flat run, true VO2max ~50.

    Reproduced byte-for-byte (random.seed(1), same call order, same _vo2_speed_grade)
    so the fit is deterministic and equals the legacy result captured below.
    """
    random.seed(1)
    hrmax = 208 - 0.7 * 30  # 187
    hrrest_vo2, true_vo2max = 3.5, 50.0
    slope = (true_vo2max - hrrest_vo2) / (hrmax - 60)
    intercept = hrrest_vo2 - slope * 60
    pts: list[tuple[float, float, float, float | None]] = []
    hr_series: dict[int, float] = {}
    t = 1_700_000_000.0
    lat, lng = 28.6139, 77.2090
    for stage_speed in (3.0, 3.4, 3.8):  # three 8-min steady stages
        vo2 = _vo2_speed_grade(stage_speed, 0.0)
        hr = (vo2 - intercept) / slope + random.uniform(-2, 2)
        for _ in range(8 * 60):
            lng += stage_speed / (111_320 * math.cos(math.radians(lat)))
            ele = 100.0 + random.uniform(-2, 2)
            pts.append((t, lat, lng, ele))
            hr_series[round(t)] = hr + random.uniform(-1.5, 1.5)
            t += 1.0
    return pts, hr_series, hrmax


def test_submaximal_vo2max_matches_legacy_self_test() -> None:
    pts, hr_series, hrmax = _synthetic_track()
    res, status = vo2max_from_track(pts, lambda ts: hr_series.get(round(ts)), hrmax)
    assert status == "ok"
    # Captured from the LEGACY healthee.v2.vo2max_submax on this exact track:
    assert res == SubmaxResult(
        vo2max=49.3,
        n_windows=42,
        hr_range=30.0,
        r2=0.95,
        slope=0.329,
        intercept=-12.3,
        speed_kmh_mean=12.4,
    )
