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

Since #97 the sleep term's ANCHOR is pinned as well. Yin 2017's curve is a function of
QUESTIONNAIRE hours, so the strap's average is converted first, through the gap
Lauderdale et al. 2008 measured. Those expected numbers are the paper's own published
points, not this repo's arithmetic — see ``analytics/reference_scales.py``.
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
)
from healthee.analytics.reference_scales import (
    SLEEP_DURATION_SELF_REPORT_SCALE,
    VO2MAX_REFERENCE_CLINICAL_COHORT,
    self_report_over_report_h,
    self_reported_equivalent_h,
    vo2max_median_for,
)

# ── The fitness anchor: FRIEND's published 50th-percentile row (#101) ────────
# Kaminsky LA, Arena R, Myers J, et al. (2022), "Updated Reference Standards for
# Cardiorespiratory Fitness Measured with Cardiopulmonary Exercise Testing: Data from
# the FRIEND registry", Mayo Clin Proc 97(2):285–293, PMID 34809986 — TABLE 3, treadmill,
# directly measured VO₂peak, inclusion criterion RER ≥ 1.0, the 50th-percentile row
# (16,278 treadmill CPETs, 34 US labs). Every literal below is one cell of that row as
# printed in the paper, transcribed here independently of the implementation's dict so
# that a typo in either one fails the build.
_FRIEND_2022_TREADMILL_P50_MEN = {20: 46.5, 30: 39.7, 40: 35.3, 50: 29.2, 60: 24.6, 70: 20.6}
_FRIEND_2022_TREADMILL_P50_WOMEN = {20: 36.6, 30: 28.3, 40: 25.7, 50: 22.9, 60: 19.6, 70: 17.2}


@pytest.mark.parametrize("decade,published", sorted(_FRIEND_2022_TREADMILL_P50_MEN.items()))
def test_vo2max_median_table_men_is_friends_published_row(decade: int, published: float) -> None:
    # Read at the decade's midpoint so the bucketing is exercised too, not just the dict.
    assert vo2max_median_for(decade + 5, "male") == published


@pytest.mark.parametrize("decade,published", sorted(_FRIEND_2022_TREADMILL_P50_WOMEN.items()))
def test_vo2max_median_table_women_is_friends_published_row(decade: int, published: float) -> None:
    assert vo2max_median_for(decade + 5, "female") == published


def test_vo2max_median_clamps_to_the_rows_published_ends() -> None:
    """Outside 20–89 there is no published cell, so the nearest one is reused.

    The upper clamp moved from 70 to 80 with the source: FRIEND 2022 prints an 80–89
    bucket (17.6 men / 15.4 women) that the 2015 edition did not, and clamping an
    85-year-old to the 70s reference would compare them against a decade they are not in.
    """
    assert vo2max_median_for(18, "male") == 46.5  # below the row → the 20s cell
    assert vo2max_median_for(85, "male") == 17.6  # the published 80s cell, not the 70s one
    assert vo2max_median_for(85, "female") == 15.4
    assert vo2max_median_for(99, "male") == 17.6  # above the row → the 80s cell


def test_the_replaced_table_penalised_where_it_was_never_checked() -> None:
    """#101's finding, kept executable: #97 had the sign right for a sample, not the row.

    The uncited table this replaced was M 44/41/38/33/28/24 · F 36/33/30/26/22/19. #97
    could only check the four cells the 2015 abstract prints, found three of them LOW, and
    told owners the fitness term FLATTERED them. Against the full published row, ten of
    the twelve cells were HIGH — a reference set too fit makes an owner look worse, so the
    old table penalised nearly everyone. This asserts the two cells that mattered most:
    the worst penalty (women 30–39, 33.0 against a published 28.3) and the one genuine
    flattery #97 did see (men 20–29, 44.0 against a published 46.5). If a future edition
    of the source moves either cell across the old value, the note's account of which way
    this term used to lean has to be rewritten rather than quietly outlived.
    """
    assert vo2max_median_for(35, "female") < 33.0  # was 4.7 ml/kg/min ≈ 2.4 y too harsh
    assert vo2max_median_for(25, "male") > 44.0  # was 2.5 ml/kg/min ≈ 1.3 y too kind


# ── The sleep anchor: questionnaire hours vs device hours (#97) ──────────────
# Every expected value below is a number Lauderdale et al. 2008 (Epidemiology 19(6):
# 838–45, PMID 18854708) published, not one this codebase computed.


def test_self_report_gap_matches_lauderdales_published_anchors() -> None:
    # "persons sleeping 5 hours over-reported their sleep duration by 1.2 hours, and
    # those sleeping 7 hours over-reported by 0.4 hours"; and the cohort means,
    # "average measured sleep was 6 hours, whereas the average from subjective reports
    # was 6.8 hours" — three independent points on one line.
    assert self_report_over_report_h(5.0) == pytest.approx(1.2)
    assert self_report_over_report_h(6.0) == pytest.approx(0.8)
    assert self_report_over_report_h(7.0) == pytest.approx(0.4)
    assert self_reported_equivalent_h(6.0) == pytest.approx(6.8)


def test_self_report_gap_does_not_extrapolate_past_the_published_anchors() -> None:
    """Held flat below 5 h (Lauderdale's shortest anchor) and floored at 0 from 8 h up.

    Both clamps are conservative on purpose: growing the gap below 5 h would invent an
    ever-larger credit for the shortest sleepers, and letting the line go negative past
    8 h would invent a discount on the long-sleep tail. Neither was measured."""
    assert self_report_over_report_h(4.0) == pytest.approx(1.2)  # not 1.6
    assert self_report_over_report_h(3.0) == pytest.approx(1.2)  # not 2.0
    assert self_report_over_report_h(8.0) == pytest.approx(0.0)  # the line's own zero
    assert self_report_over_report_h(9.5) == pytest.approx(0.0)  # not −0.6
    assert self_reported_equivalent_h(9.5) == pytest.approx(9.5)


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
# Deliberately exactly one MET above FRIEND's published 40–49 male median (35.3 + 3.5),
# so the fitness hazard is 0.85 ** 1.0 and the expected years below stay hand-derivable
# from the note's table rather than from a calculator. Before #101 the same intent was
# expressed as 41.5, one MET above the uncited table's 38.0.
_VO2MAX = 38.8  # ml/kg/min
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
    # vs the age/sex reference VO₂max. Reference at 40 y male = 35.3, FRIEND 2022's
    # published treadmill 50th percentile for 40–49 (#101; it was an uncited 38.0).
    #   METs above reference = (38.8 − 35.3)/3.5 = 1.0  →  HR = 0.85^1.0 = 0.85
    #   ΔAge = ln(0.85)·7.7/ln(2) = −0.1625189·7.7/0.6931472 = −1.8054  → −1.8
    assert contribs["fitness"]["hr"] == pytest.approx(0.85)
    assert contribs["fitness"]["delta_years"] == pytest.approx(-1.8)

    # Sleep duration — 1.06 per hour BELOW the 7 h nadir (Yin 2017), read at the
    # QUESTIONNAIRE equivalent of the strap's average (#97). The fixture's 6.0 h is
    # Lauderdale's own cohort mean, so its equivalent is that paper's published mean
    # report, 6.8 h — no arithmetic of ours in the anchor at all.
    #   6.0 h measured → 6.8 h reported → HR = 1.06^(7 − 6.8) = 1.06^0.2 = 1.01172
    #   ΔAge = 0.2·ln(1.06)·7.7/ln(2) = 0.2·0.0582689·11.1088 = +0.1295  → +0.1
    # Before #97 this read 1.06^(7 − 6.0) = 1.06 → +0.6: half a year charged for the
    # difference between a strap and a questionnaire.
    assert contribs["sleep duration"]["compared_as"] == pytest.approx(6.8)
    assert contribs["sleep duration"]["hr"] == pytest.approx(1.012)
    assert contribs["sleep duration"]["delta_years"] == pytest.approx(0.1)
    # The label says what the maths does. It was "7–9" while 9 h was charged 1.28×
    # (#88); it is now Yin's single-point nadir. The 7–9 BAND is a different claim
    # (NSF 2015's recommendation) and stays on the sleep surfaces that make it.
    assert contribs["sleep duration"]["target"] == 7.0
    assert contribs["sleep duration"]["value"] == pytest.approx(6.0)  # what we measured

    # And there is no third term. Until #86 the note's table had a regularity row
    # log-interpolating Cribb 2023's SRI anchors; it was removed, not re-anchored.
    assert set(contribs) == {"fitness", "sleep duration"}


def test_composed_biological_age_is_chronological_plus_delta() -> None:
    """The sum and its sign — the assertion that catches `chrono − ΔAge`."""
    # ΔAge_total = −1.8054 + 0.1295 = −1.6759  → delta_years −1.7
    # bio_age    = 40 − 1.6759 = 38.3241       → 38.3
    result = _stub_result()
    assert result["delta_years"] == pytest.approx(-1.7)
    assert result["biological_age"] == pytest.approx(38.3)
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


# ── The terms that ARE there, and lean (#97) ────────────────────────────────


def test_every_priced_term_publishes_its_footing() -> None:
    """Both surviving terms are anchored on something imperfect, and both say so.

    This is the assertion that a future "tidy up the payload" cannot quietly pass: the
    composite exception in [[biological_age_estimate]] rests on its inputs being
    meta-analytic, and a meta-analytic SLOPE read at an unsourced ANCHOR is not the same
    claim. If a term's anchor is ever properly sourced, its caveat is deleted here on
    purpose — not by a payload key going missing."""
    result = _stub_result()
    caveats = {c["term"]: c for c in result["caveats"]}
    assert set(caveats) == {"fitness", "sleep duration"}
    assert caveats["fitness"]["reason"] == VO2MAX_REFERENCE_CLINICAL_COHORT
    assert caveats["sleep duration"]["reason"] == SLEEP_DURATION_SELF_REPORT_SCALE
    # The fitness anchor is sourced since #101, so its caveat is no longer "this cites
    # nothing" — it is the part that sourcing cannot fix. FRIEND is a laboratory-referral
    # cohort, so "median" here is a reference standard and not a population's middle, and
    # the payload has to say which one it means.
    assert "not a median of the population" in caveats["fitness"]["message"]


def test_a_caveat_is_neither_withheld_nor_excluded() -> None:
    """Three states, three keys, and the difference is what the owner should do.

    ``withheld`` = sync and it comes back · ``excluded`` = nobody can price this ·
    ``caveats`` = it IS in your number, and here is which way it leans. Collapsing any
    two of them would either promise a fix that does not exist or hide a live bias
    behind a word that reads like "missing"."""
    result = _stub_result()
    assert result["withheld"] is None  # nothing absent on this good day
    assert result["biological_age"] is not None  # and the caveated terms are priced
    caveat_terms = {c["term"] for c in result["caveats"]}
    excluded_terms = {e["term"] for e in result["excluded"]}
    assert caveat_terms.isdisjoint(excluded_terms)
    priced = {c["term"] for c in result["contributions"]}
    assert caveat_terms <= priced  # a caveat only ever describes a term that is IN


def test_composed_returns_none_without_a_profile() -> None:
    class _NoProfile(_StubCursor):
        def fetchone(self) -> tuple | None:
            return None

    cur = _NoProfile(date(1990, 1, 1), vo2max_day=date(1990, 1, 1))
    assert compute_biological_age(cur, _USER_ID, "UTC") is None  # type: ignore[arg-type]
