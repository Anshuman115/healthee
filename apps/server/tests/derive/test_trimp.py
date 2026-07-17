"""Known-value tests for the ONE canonical Banister TRIMP (``derive/trimp``).

Every expected number here is hand-derived from the formula as PUBLISHED in the
knowledge note (``load_currency.md`` "How we compute it", marked VERIFIED against
Banister 1991; full derivation in ``training_stress_score``)::

    ΔHR   = (HR_ex − HR_rest) / (HR_max − HR_rest)   # Karvonen reserve fraction, 0–1
    y     = 0.64 · e^(1.92 · ΔHR)   (men)
            0.86 · e^(1.67 · ΔHR)   (women)
    TRIMP = Σ_minutes ( 1 min · ΔHR · y )

They are NOT recorded from a run. A "known-value" test whose values came out of the
implementation only proves the implementation equals itself; the arithmetic for each
is shown so a reviewer can check it against the note with a calculator.

The fixture reserve is deliberately round: rhr=60, hrmax=190 → reserve = 130 bpm, so
every ΔHR below is exact.
"""

from __future__ import annotations

import math

import pytest

from healthee.derive.trimp import (
    TRIMP_WEIGHTS,
    hr_reserve_fraction,
    trimp_minute,
    trimp_total,
)
from healthee.read.workout import _session_trimp

_RHR = 60.0
_HRMAX = 190.0  # reserve = 130 bpm

# Hand-derived expected values. Arithmetic shown; e^x values from the note's formula.
#
#   ΔHR = 0.0  (hr=60, at rest):    0.0 · 0.64 · e^0      = 0.0
#   ΔHR = 0.5  (hr=125 = 60+65):    0.5 · 0.64 · e^0.96
#                                   = 0.32 · 2.611696473  = 0.835742871
#   ΔHR = 1.0  (hr=190, at HRmax):  1.0 · 0.64 · e^1.92
#                                   = 0.64 · 6.820958469  = 4.365413420
_MALE_AT_HALF_RESERVE = 0.8357428714953977
_MALE_AT_FULL_RESERVE = 4.36541342034608

#   women, a=0.86 b=1.67:
#   ΔHR = 0.5  (hr=125):            0.5 · 0.86 · e^0.835
#                                   = 0.43 · 2.304814048  = 0.991070041
#   ΔHR = 1.0  (hr=190):            1.0 · 0.86 · e^1.67
#                                   = 0.86 · 5.312167797  = 4.568464306
_FEMALE_AT_HALF_RESERVE = 0.9910700407634154
_FEMALE_AT_FULL_RESERVE = 4.568464305575803


def test_coefficients_match_the_note() -> None:
    """The lactate weighting (a, b) pairs, verbatim from the note's formula block."""
    assert TRIMP_WEIGHTS == {"male": (0.64, 1.92), "female": (0.86, 1.67)}


def test_reserve_fraction_is_karvonen() -> None:
    # (125 − 60) / (190 − 60) = 65/130 = 0.5 exactly.
    assert hr_reserve_fraction(125.0, _RHR, _HRMAX) == 0.5


def test_minute_at_rest_is_zero_load() -> None:
    # ΔHR = 0 → the whole term is 0 (the ΔHR factor, not the exponential, zeroes it).
    assert trimp_minute(_RHR, _RHR, _HRMAX, "male") == 0.0


def test_minute_at_half_reserve_male() -> None:
    assert trimp_minute(125.0, _RHR, _HRMAX, "male") == pytest.approx(_MALE_AT_HALF_RESERVE)


def test_minute_at_full_reserve_male() -> None:
    assert trimp_minute(_HRMAX, _RHR, _HRMAX, "male") == pytest.approx(_MALE_AT_FULL_RESERVE)


def test_minute_at_half_reserve_female() -> None:
    assert trimp_minute(125.0, _RHR, _HRMAX, "female") == pytest.approx(_FEMALE_AT_HALF_RESERVE)


def test_minute_at_full_reserve_female() -> None:
    assert trimp_minute(_HRMAX, _RHR, _HRMAX, "female") == pytest.approx(_FEMALE_AT_FULL_RESERVE)


def test_women_score_higher_than_men_at_the_same_low_reserve() -> None:
    """A sanity check on the sex weighting direction, straight from the coefficients.

    At ΔHR 0.5 the women's curve (0.86·e^0.835) sits above the men's (0.64·e^0.96);
    the men's steeper b overtakes it by ΔHR 1.0. If the two pairs were ever swapped,
    this ordering flips — which the raw coefficient test alone would not catch.
    """
    assert _FEMALE_AT_HALF_RESERVE > _MALE_AT_HALF_RESERVE
    assert _MALE_AT_FULL_RESERVE < _FEMALE_AT_FULL_RESERVE


def test_unknown_sex_falls_back_to_the_mens_coefficients() -> None:
    assert trimp_minute(125.0, _RHR, _HRMAX, None) == pytest.approx(_MALE_AT_HALF_RESERVE)
    assert trimp_minute(125.0, _RHR, _HRMAX, "unspecified") == pytest.approx(_MALE_AT_HALF_RESERVE)


# --- the divergence this PR exists to remove -------------------------------------


def test_reserve_fraction_above_hrmax_clamps_to_one() -> None:
    """ΔHR > 1 is not a thing: the note defines the reserve fraction as 0–1.

    HRmax is Tanaka-ESTIMATED (208 − 0.7·age), so real sessions record HR above it.
    hr=216 → (216−60)/130 = 1.2 → clamped to 1.0.
    """
    assert hr_reserve_fraction(216.0, _RHR, _HRMAX) == 1.0


def test_minute_above_hrmax_scores_the_ceiling_not_more() -> None:
    """THE regression this PR fixes. read/workout.py had no upper clamp.

    At ΔHR 1.2 the unclamped term would be 1.2 · 0.64 · e^2.304
    = 0.768 · 10.014159085 = 7.690874177 — i.e. 7.690874/4.365413 = 1.76x, ~76% MORE
    than the ceiling the formula defines, because the weighting is exponential. That
    error is an artefact of HRmax ESTIMATION, and it compounds over every such minute.
    """
    clamped = trimp_minute(216.0, _RHR, _HRMAX, "male")
    assert clamped == pytest.approx(_MALE_AT_FULL_RESERVE)

    unclamped = 1.2 * 0.64 * math.exp(1.92 * 1.2)
    assert unclamped == pytest.approx(7.690874176966173)
    assert unclamped / clamped == pytest.approx(1.7617745300183867)
    assert clamped < unclamped, "an above-HRmax minute must not out-score the ceiling"


def test_minute_below_rest_scores_zero_not_negative() -> None:
    """ΔHR < 0 clamps to 0 — an HR below rest is no load, never negative load."""
    assert hr_reserve_fraction(40.0, _RHR, _HRMAX) == 0.0
    assert trimp_minute(40.0, _RHR, _HRMAX, "male") == 0.0


# --- the accumulator ---------------------------------------------------------------


def test_total_sums_the_per_minute_terms() -> None:
    # Two minutes at ΔHR 0.5 + one at ΔHR 1.0 (men):
    #   2 · 0.835742871 + 4.365413420 = 1.671485743 + 4.365413420 = 6.036899163
    expected = 2 * _MALE_AT_HALF_RESERVE + _MALE_AT_FULL_RESERVE
    assert expected == pytest.approx(6.0368991733368755)
    assert trimp_total([125.0, 125.0, 190.0], _RHR, _HRMAX, "male") == pytest.approx(expected)


def test_total_of_no_minutes_is_zero() -> None:
    assert trimp_total([], _RHR, _HRMAX, "male") == 0.0


def test_total_clamps_every_minute_not_just_the_sum() -> None:
    """Three above-HRmax minutes score 3 × the ceiling, not 3 × the unclamped term.

    3 · 4.365413420 = 13.096240261.
    """
    assert trimp_total([216.0, 220.0, 300.0], _RHR, _HRMAX, "male") == pytest.approx(
        3 * _MALE_AT_FULL_RESERVE
    )


def test_both_layers_score_an_identical_minute_identically() -> None:
    """The point of the extraction: one athlete-minute, one load, whichever surface.

    ``derive/cardio_load`` (daily) and ``read/workout`` (session) now call the same
    function; before, an above-HRmax minute scored 76% higher on the workout screen
    than in the day's total.
    """
    hrs = [125, 190, 216]
    # 0.835742871 + 4.365413420 + 4.365413420 (clamped) = 9.566569712 → 9.6
    assert _session_trimp(hrs, _HRMAX, _RHR, "male") == pytest.approx(
        round(trimp_total([float(h) for h in hrs], _RHR, _HRMAX, "male"), 1)
    )
    assert _session_trimp(hrs, _HRMAX, _RHR, "male") == 9.6
