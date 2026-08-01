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

Since #86 the note's table has TWO rows, not three — sleep regularity was removed
rather than re-anchored, because the published SRI→mortality hazards belong to the
scoring pipeline that produced them (Czeisler et al. 2026, *Sleep* 49(4):zsaf299:
scored on the same >70 000 adults, two standard SRI calculators agreed on the
quintile for only two in five, and "the method of calculation alone meaningfully
changed results and interpretations" for all-cause mortality). The stub cursor below
therefore RAISES on an SRI read, and the payload's ``excluded`` block is pinned here
too: a composite that quietly loses a term is a different composite wearing the same
key name. See ``tests/derive/test_sri_scale.py`` for our scale, measured.
"""

from __future__ import annotations

from datetime import UTC, date, datetime
from typing import Any
from uuid import UUID

import pytest

from healthee.analytics.biological_age import (
    SRI_HAZARD_NOT_TRANSPORTABLE,
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


class _StubCursor:
    """Minimal ``Cursor``-shaped stub: answers each of the module's three reads by
    matching on the SQL it issues. A query the stub does not recognise raises — see
    the SRI branch; a silent "no row" there would collapse the estimate to ``None``
    and could be mistaken for an ordinary empty-owner case.

    The VO₂max row carries the owner's TODAY as its day, because a term is only spent
    when its newest row IS today's (the freshness gate). Every other stub day would
    send the module down the withheld path and there would be no composite to check
    the arithmetic of — which is exactly what ``test_biological_age_freshness``
    exercises, against a real database and the real gate rather than this stub.
    Today's row also short-circuits the gate before it can issue its own query, which
    is why the stub never has to answer one.
    """

    def __init__(self, dob: date, vo2max_day: date) -> None:
        self._dob = dob
        self._vo2max_day = vo2max_day
        self._row: tuple | None = None

    def execute(self, sql: str, params: Any = None) -> None:  # noqa: ARG002
        if "sleep_regularity_index" in sql:
            # #86: regularity is not a term of this estimate and the module must not read
            # SRI at all. Asserting on the ABSENCE of a query is the only assertion that
            # a re-added `_regularity_term` cannot satisfy — an expected-value check would
            # simply be updated by whoever re-added it.
            raise AssertionError(
                "compute_biological_age read sleep_regularity_index — the regularity term "
                "was removed in #86 because no SRI→hazard conversion transports across "
                "scoring pipelines (Czeisler 2026). See the module docstring."
            )
        if "FROM profile" in sql:
            self._row = (self._dob, "male")
        elif "vo2max_estimate" in sql:
            self._row = (self._vo2max_day, _VO2MAX)
        elif "sleep_health_score_4dim" in sql:
            self._row = (_TST_MIN,)
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

    # And there is no third term. Until #86 the note's table had a regularity row
    # log-interpolating Cribb 2023's SRI anchors; it was removed, not re-anchored.
    assert set(contribs) == {"fitness", "sleep duration"}


def test_composed_biological_age_is_chronological_plus_delta() -> None:
    """The sum and its sign — the assertion that catches `chrono − ΔAge`."""
    # ΔAge_total = −1.8054 + 0.6473 = −1.1581  → delta_years −1.2
    # bio_age    = 40 − 1.1581 = 38.8419       → 38.8
    result = _stub_result()
    assert result["delta_years"] == pytest.approx(-1.2)
    assert result["biological_age"] == pytest.approx(38.8)
    # Net hazard is below the reference here, so the estimate must read YOUNGER.
    assert result["biological_age"] < result["chronological_age"]
    # A composite that IS computed says so, in the ledger's vocabulary.
    assert result["data_confidence"] == "ok"
    assert result["withheld"] is None


# ── The term that is not there ──────────────────────────────────────────────
# Removing a term from a composite silently would make "biological age" mean two
# different things in two releases while the key name stayed identical. #86 requires
# the estimate to state what it no longer prices, so these pin the statement itself.


def test_the_excluded_regularity_term_is_named_in_every_estimate() -> None:
    """Not a caveat in a doc — a key of the payload, present on a fully-computed number."""
    result = _stub_result()
    assert result["data_confidence"] == "ok"  # nothing is withheld; this is a good day
    excluded = {e["term"]: e for e in result["excluded"]}
    assert set(excluded) == {"regularity"}
    assert excluded["regularity"]["reason"] == SRI_HAZARD_NOT_TRANSPORTABLE


def test_an_excluded_term_is_not_a_withheld_one() -> None:
    """The two absences send an owner to different places, so they may not share a key.

    ``withheld`` means "sync/wear the strap and this comes back". No owner action brings
    regularity back — it is the literature that has no transportable number
    (Czeisler et al. 2026, *Sleep* 49(4):zsaf299). Folding it into ``withheld`` would
    promise a fix that does not exist, and would also make the composite null forever.
    """
    result = _stub_result()
    assert result["withheld"] is None
    assert result["biological_age"] is not None
    # The message must tell the owner where regularity DOES still live, so the exclusion
    # does not read as "we stopped measuring it".
    assert "sleep page" in result["excluded"][0]["message"]


def test_composed_returns_none_without_a_profile() -> None:
    class _NoProfile(_StubCursor):
        def fetchone(self) -> tuple | None:
            return None

    cur = _NoProfile(date(1990, 1, 1), vo2max_day=date(1990, 1, 1))
    assert compute_biological_age(cur, _USER_ID, "UTC") is None  # type: ignore[arg-type]
