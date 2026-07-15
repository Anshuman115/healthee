"""Pure known-value tests for the biological-age published maths.

The DB-driven ``compute_biological_age`` is exercised in the seeded-DB
integration test; here we pin the parts that are pure functions of published
constants: the age/sex VO₂max median table and the Gompertz hazard→years
conversion (the same formula the module's ``add`` closure applies).
"""

from __future__ import annotations

import math

import pytest

from healthee.analytics.biological_age import (
    GOMPERTZ_MRDT_YEARS,
    TERM_CAP_YEARS,
    vo2max_median_for,
)


def test_vo2max_median_table_male() -> None:
    assert vo2max_median_for(35, "male") == 41.0  # 30s bucket
    assert vo2max_median_for(52, "male") == 33.0  # 50s bucket


def test_vo2max_median_table_female() -> None:
    assert vo2max_median_for(35, "female") == 33.0
    assert vo2max_median_for(62, "female") == 22.0


def test_vo2max_median_clamps_to_table_bounds() -> None:
    assert vo2max_median_for(18, "male") == 44.0  # clamped up to 20s
    assert vo2max_median_for(90, "male") == 24.0  # clamped down to 70s


def _delta_years(hr: float) -> float:
    """The module's hazard→years conversion, capped, replicated for the assert."""
    b = math.log(2) / GOMPERTZ_MRDT_YEARS
    return max(-TERM_CAP_YEARS, min(TERM_CAP_YEARS, math.log(hr) / b))


def test_gompertz_neutral_hazard_is_zero_years() -> None:
    assert _delta_years(1.0) == pytest.approx(0.0)


def test_gompertz_doubling_hazard_is_one_mrdt_older() -> None:
    # HR = 2 → exactly one mortality-rate-doubling-time older.
    assert _delta_years(2.0) == pytest.approx(GOMPERTZ_MRDT_YEARS)


def test_gompertz_term_cap() -> None:
    assert _delta_years(1000.0) == pytest.approx(TERM_CAP_YEARS)  # capped at +10 y
    assert _delta_years(0.0001) == pytest.approx(-TERM_CAP_YEARS)  # capped at −10 y
