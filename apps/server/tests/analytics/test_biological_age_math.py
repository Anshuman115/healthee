"""Known-value tests for the biological-age published maths.

Every expected number below is hand-derived from the published constants in
``packages/knowledge/notes/metrics/biological_age_estimate.md`` (and the papers
it cites), NOT read back out of the implementation. The derivation is written
out in a comment above each assertion so a reviewer can re-check the arithmetic
without running the code.

Deliberately, this module does NOT import ``GOMPERTZ_MRDT_YEARS`` or
``TERM_CAP_YEARS`` and does NOT re-implement the conversion: asserting against
the constants (or against a replica of the formula) is a tautology that survives
any change to the maths. The literals 7.7 and 10.0 are the note's values.
"""

from __future__ import annotations

from datetime import UTC, date, datetime
from typing import Any
from uuid import UUID

import pytest

from healthee.analytics.biological_age import (
    compute_biological_age,
    hazard_delta_years,
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


# ── Gompertz hazard→years conversion ────────────────────────────────────────
# Note "Finding": b = ln(2)/MRDT with MRDT = 7.7 y (UK Biobank), ΔAge = ln(HR)/b.


def test_gompertz_neutral_hazard_is_zero_years() -> None:
    # ln(1) = 0 → no age shift at the reference hazard.
    assert hazard_delta_years(1.0) == pytest.approx(0.0, abs=1e-12)


def test_gompertz_doubling_hazard_is_one_mrdt_older() -> None:
    # ΔAge = ln(2)/(ln(2)/7.7) = 7.7 — one mortality-rate-doubling-time older.
    # 7.7 is the note's MRDT literal, NOT the module constant (a change to the
    # constant must fail this test).
    assert hazard_delta_years(2.0) == pytest.approx(7.7, abs=1e-9)


def test_gompertz_halved_hazard_is_one_mrdt_younger() -> None:
    # ΔAge = ln(0.5)·7.7/ln(2) = −7.7.
    assert hazard_delta_years(0.5) == pytest.approx(-7.7, abs=1e-9)


def test_gompertz_ten_percent_hazard_is_about_one_year() -> None:
    # The note's own sanity check ("Effect size"): HR_total = 1.10 → ΔAge ≈ +1.05 y
    # ("the 10% ≈ 1 year rule"), computed there with the rounded 11.1 shorthand.
    # Exactly: ln(1.10)·7.7/ln(2) = 0.0953102·7.7/0.6931472 = 1.0588.
    assert hazard_delta_years(1.10) == pytest.approx(1.0588, abs=5e-4)


def test_gompertz_term_cap_is_plus_minus_ten_years() -> None:
    # Note "Safety bounds": each term's contribution is hard-capped at ±10 y.
    # Uncapped these would be ln(1000)·7.7/ln(2) = +76.7 and −102.3.
    assert hazard_delta_years(1000.0) == pytest.approx(10.0, abs=1e-9)
    assert hazard_delta_years(0.0001) == pytest.approx(-10.0, abs=1e-9)


# ── The composed estimate ───────────────────────────────────────────────────
# The term maths alone cannot catch a sign error in `chronological + ΔAge`, nor a
# term wired to the wrong hazard. This pins `compute_biological_age`'s real output
# on fixed inputs, with every expected value derived from the note.

_CHRONO_AGE = 40
_VO2MAX = 41.5  # ml/kg/min
_TST_MIN = 360.0  # 6.0 h/night, 14-night average
_SRI = 58.0


class _StubCursor:
    """Minimal ``Cursor``-shaped stub: answers each of the module's four reads by
    matching on the SQL it issues. A query the stub does not recognise yields no
    row, which collapses the estimate to ``None`` — a loud failure, never a
    silently-passing one.

    The VO₂max row carries the owner's TODAY as its day, because the fitness term is
    only spent when the newest row IS today's (the freshness gate). Every other stub
    day would send the module down the withheld path and there would be no composite
    to check the arithmetic of — which is exactly what
    ``test_biological_age_freshness`` exercises, against a real database and the real
    gate rather than this stub.
    """

    def __init__(self, dob: date, vo2max_day: date) -> None:
        self._dob = dob
        self._vo2max_day = vo2max_day
        self._row: tuple | None = None

    def execute(self, sql: str, params: Any = None) -> None:  # noqa: ARG002
        if "FROM profile" in sql:
            self._row = (self._dob, "male")
        elif "vo2max_estimate" in sql:
            self._row = (self._vo2max_day, _VO2MAX)
        elif "sleep_health_score_4dim" in sql:
            self._row = (_TST_MIN,)
        elif "sleep_regularity_index" in sql:
            self._row = (_SRI,)
        else:  # pragma: no cover — an unrecognised read must not pass silently
            raise AssertionError(f"stub cursor got an unexpected query: {sql}")

    def fetchone(self) -> tuple | None:
        return self._row


_USER_ID = UUID(int=1)


def _stub_result() -> dict:
    """``compute_biological_age`` over the fixed inputs above, at a dob chosen so
    the chronological age is exactly 40 on any run date — Jan 1 included, since
    ``(1, 1) < (1, 1)`` is false. The tz is pinned to UTC and the dob is anchored
    to the UTC year, so the process timezone cannot move the answer."""
    today = datetime.now(UTC).date()
    cur = _StubCursor(date(today.year - _CHRONO_AGE, 1, 1), vo2max_day=today)
    result = compute_biological_age(cur, _USER_ID, "UTC")  # type: ignore[arg-type]
    assert result is not None
    return result


def test_composed_chronological_age() -> None:
    assert _stub_result()["chronological_age"] == _CHRONO_AGE


def test_composed_per_term_contributions() -> None:
    """Each term's signed year contribution, hand-derived from the note's table."""
    contribs = {c["term"]: c for c in _stub_result()["contributions"]}

    # Fitness — note "Inputs we use": HR = 0.85 per +1 MET (1 MET = 3.5 ml/kg/min)
    # vs the age/sex-median VO₂max. Median at 40 y male = 38.0 (note's ported table).
    #   METs above median = (41.5 − 38.0)/3.5 = 1.0  →  HR = 0.85^1.0 = 0.85
    #   ΔAge = ln(0.85)·7.7/ln(2) = −0.1625189·7.7/0.6931472 = −1.8054  → −1.8
    assert contribs["fitness"]["hr"] == pytest.approx(0.85)
    assert contribs["fitness"]["delta_years"] == pytest.approx(-1.8)

    # Sleep duration — note: 1.06 per hour BELOW the 7 h reference (Yin 2017).
    #   6.0 h → HR = 1.06^(7 − 6) = 1.06
    #   ΔAge = ln(1.06)·7.7/ln(2) = 0.0582689·7.7/0.6931472 = +0.6473  → +0.6
    assert contribs["sleep duration"]["hr"] == pytest.approx(1.06)
    assert contribs["sleep duration"]["delta_years"] == pytest.approx(0.6)

    # Regularity — note: log-interpolate the Cribb 2023 anchors, SRI 41 → 1.53 and
    # SRI 75 → 0.90, i.e. ln(HR) = 0.425 − 0.0156·(SRI − 41)
    #   (check: SRI 41 → e^0.425 = 1.530 ✓;  SRI 75 → e^(0.425−0.5304) = 0.900 ✓)
    #   SRI 58 → ln(HR) = 0.425 − 0.0156·17 = 0.1598  →  HR = e^0.1598 = 1.173
    #   ΔAge = 0.1598·7.7/ln(2) = 1.23046/0.6931472 = +1.7752  → +1.8
    assert contribs["regularity"]["hr"] == pytest.approx(1.173, abs=5e-4)
    assert contribs["regularity"]["delta_years"] == pytest.approx(1.8)


def test_composed_biological_age_is_chronological_plus_delta() -> None:
    """The sum and its sign — the assertion that catches `chrono − ΔAge`."""
    # ΔAge_total = −1.8054 + 0.6473 + 1.7752 = +0.6171  → delta_years +0.6
    # bio_age    = 40 + 0.6171 = 40.617                 → 40.6
    result = _stub_result()
    assert result["delta_years"] == pytest.approx(0.6)
    assert result["biological_age"] == pytest.approx(40.6)
    # Net hazard is above the reference here, so the estimate must read OLDER.
    assert result["biological_age"] > result["chronological_age"]
    # A composite that IS computed says so, in the ledger's vocabulary.
    assert result["data_confidence"] == "ok"
    assert result["withheld"] is None


def test_composed_returns_none_without_a_profile() -> None:
    class _NoProfile(_StubCursor):
        def fetchone(self) -> tuple | None:
            return None

    cur = _NoProfile(date(1990, 1, 1), vo2max_day=date(1990, 1, 1))
    assert compute_biological_age(cur, _USER_ID, "UTC") is None  # type: ignore[arg-type]
