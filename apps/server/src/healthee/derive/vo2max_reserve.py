"""VO2max by inverting %HRR = %VO2R — the slope-free estimator, and what it will not do.

``vo2max_submax.vo2max_from_track`` is a graded-exercise method: it needs the workload to
RISE so heart rate follows, fits VO2 against HR, and extrapolates the line to HRmax. On
this owner's eight recorded tracks it produced a number once. The failures were not
short of heart-rate range — the 147-minute walk spanned 70 bpm — they were short of
WORKLOAD range, and no threshold rescues a regression whose x-axis does not move.

This module needs no slope. Swain & Leutholtz's equivalence says the fraction of heart-
rate reserve equals the fraction of oxygen-uptake reserve, so EVERY steady window is an
independent estimate on its own::

    %HRR   = (HR - HRrest) / (HRmax - HRrest)
    %VO2R  = (VO2 - VO2rest) / (VO2max - VO2rest)
    =>  VO2max = VO2rest + (VO2 - VO2rest) / %HRR

Aggregate the windows with a median and you have a VO2max from a flat session.

## What it actually does, measured on the eight real tracks (#114)

**It does not rescue walking, and the reason is not the one we expected.** Scored against
this owner's own data:

======================  ==================  =========================================
window kind             median estimate     against the graded method's 39.6 on 06-15
======================  ==================  =========================================
running (n=26)          40.9 / 41.7         agrees within 1.3-2.1 ml/kg/min
walking (n=355)          9.4 - 23.2         low by 17-30 ml/kg/min
======================  ==================  =========================================

Three measurements say the walking numbers are wrong, not merely uncertain:

1. **Matched-%HRR falsification.** The identity's whole content is that %HRR fixes the
   answer. At 75-85% HRR his walking windows return 10.6 and his running windows return
   42.3 — a factor of 4.0 at IDENTICAL cardiovascular strain. Whatever %HRR is measuring
   during his walks, it is not oxygen uptake.
2. **His own data floors him above them.** He SUSTAINED 38.9 ml/kg/min for half-minute
   windows at 169 bpm (06-15) and 38.8 at 177 bpm (06-18). A VO2max cannot be below a
   VO2 the person held submaximally, so every walking-derived 9-23 is refuted without
   reference to any model.
3. **Back-solved, walking demands an impossible cost.** For his walking HR to be
   consistent with a VO2max near 40, his walks would have to cost 20.0-28.2 ml/kg/min
   (5.7-8.1 METs). ACSM + Minetti put them at 7.7-13.5. The gap is x1.6-3.7 and no grade
   correction reaches it — the error is on the HR side, not the workload side.

The mechanism follows from the arithmetic: a walk costs ~13 ml/kg/min, about a quarter of
his reserve, so the METABOLIC part of his walking heart rate is small. The non-metabolic
part — heat, hydration, posture, arousal, cardiac drift — is not, and at 30-odd bpm it is
LARGER than the signal. Running triples the metabolic demand and the same non-metabolic
offset stops mattering. The equivalence is not being broken by low intensity (his walking
windows sit at 45-70% HRR, squarely inside any range it was validated over); it is being
broken by free living.

The published record says the same thing in its own units. Ferri Marini 2021 (n = 737,
the largest test, and the only large one that did NOT anchor its regressions at rest)
finds %HRR sits **6.3 to 8.0 percentage points ABOVE %VO2R at every intensity**, with an
inter-individual SD of 7.5-11.3 points that is **widest at the low-intensity end**.
Dividing by an inflated %HRR under-states VO2max, so this estimator is systematically
CONSERVATIVE — about 2.5-3 ml/kg/min low at running intensity by that table. We do not
correct for it: the same authors report that grouping by sex, age, body fat, resting HR
or VO2max explains under 4% of the variance in the individual slopes, so a population
correction would buy a second-order fix at the price of a fitted constant. The direction
and size are stated instead, here and in the payload. Note the arithmetic: that published
bias accounts for roughly 3 of the 17-30 ml/kg/min this method loses on walking. The rest
is not the equivalence's published error — it is free living.

**So the honest scope is: this estimator does not work on ordinary walks and is not
offered for them.** It is gated to the running domain, where it was checked against an
independent instrument and agreed. What it adds there is real but bounded — it needs no
load range, so it scores 2026-06-18 (which the graded method rejects at r2=0.39) and it
turns a 3.5-minute run interval into an estimate. Coverage on the eight tracks goes from
1 to 2. It does not go to 8, and nothing in this module pretends otherwise.

## The traps, each measured rather than assumed

* **Dividing by a small %HRR** amplifies every error by 1/%HRR, and :data:`MIN_HRR`
  guards it. It is not what broke walking. Across all 381 of his steady windows the
  floor excludes exactly ONE (his minimum %HRR is 0.349), and that one is a walking
  window already refused on modality; his running windows never drop below 0.644, and
  his walking sessions are wrong from windows sitting at 45-70% of reserve. The trap is
  real in the algebra and reporting it as the cause would have been a tidy wrong answer.
* **HRrest choice** sits in both numerator and denominator, so it looked like the
  dominant term. Measured, it is the smallest: moving HRrest by +/-5 bpm moves a session
  median by under 1 ml/kg/min (and by 3.5 at +15 bpm), against the 17-30 the walking
  failure needs explaining.
* **Cardiac drift** is severe where the signal is weak and absent where it is strong.
  Across the 147-minute walk the estimate decayed 28.1 -> 8.8 as HR rose 127 -> 151 at
  constant pace. Across 06-18's running windows, spanning 9.7 to 43.3 minutes, it did
  not decay at all (46.8 -> 44.8). The running gate therefore already excludes every
  session where drift bit, which is why there is no separate drift threshold to tune.

Knowledge: [[hr_reserve_vo2max]]. Pure and dependency-free — no DB, no I/O.
"""

from __future__ import annotations

from dataclasses import dataclass

from healthee.derive.robust import median
from healthee.derive.vo2max_submax import (
    RUN_SPEED_MS,
    VO2MAX_HI,
    VO2MAX_LO,
    SteadyWindow,
)

# ── Constants ────────────────────────────────────────────────────────────────

# Resting oxygen uptake, the VO2rest term of %VO2R. 3.5 ml/kg/min is the metabolic
# equivalent convention this codebase already spends in `derive/vo2max.py`
# (`_METS_TO_ML_KG_MIN`) and it is what Swain & Leutholtz's own %VO2R arithmetic assumes.
#
# It is also known to be HIGH: Byrne 2005 measured 2.6 ml/kg/min as the mean resting
# metabolic rate of 642 adults, so 1 MET over-states most people's rest by ~25%. We keep
# 3.5 anyway, deliberately — the ACSM speed->VO2 equations on the other side of this
# arithmetic are themselves built on a 3.5 resting term, and swapping one without the
# other would mix two definitions of rest inside a single subtraction. The size of the
# choice is small and bounded: at a running window (VO2 ~37, %HRR ~0.87) moving VO2rest
# from 3.5 to 2.6 moves the estimate by ~0.1 ml/kg/min, three orders below the walking
# bias this module exists to refuse. [[hr_reserve_vo2max]].
VO2_REST_ML_KG_MIN = 3.5

# The validated %HRR range, TAKEN FROM THE LITERATURE rather than chosen.
#
# Lounana et al. 2007 is the one paper that states a range in so many words: "Predicted
# %VO2R values were equivalent to %HRR in the 35-95%HRR range." Outside it nobody has
# published an equivalence, so outside it we do not compute one — the same posture
# `derive/vo2max.py` takes toward Jurca's validated 40-100 bpm resting HR.
#
# The floor is corroborated by what the founding papers actually measured. Swain 1998's
# treadmill protocol was the BRUCE protocol, whose first exercise stage (1.7 mph at a 10%
# grade) is ~4.6-4.7 METs — roughly 31-37% of reserve for a young adult. Everything below
# that in those regressions is a single RESTING anchor point, and Ferri Marini 2021 shows
# in as many words that including rest "could induce the slope and intercept to tend to 1
# and 0" — i.e. the part of the line nearest the origin is the part the data least
# support.
#
# An independent check from our own error budget agrees on the order of magnitude and is
# slightly STRICTER. Monte-Carlo over the equivalence's published scatter (below), an
# HRmax SD of 10 bpm [Robergs & Landwehr 2002, NOT Tanaka — #112] and this owner's HRrest
# spread, as the 1 SD of a six-window session median:
#
#     %VO2R   0.30   0.40   0.50   0.60   0.70   0.80   0.90
#     1 SD    8.26   5.57   4.25   3.65   3.43   3.23   3.18   ml/kg/min
#
# That crosses Jurca's 5.075 SEE (`derive/vo2max.py`) at about 0.42, so between 0.35 and
# ~0.43 this estimate is INSIDE the published range and no more precise than the
# non-exercise model it would displace. We keep the published bound in the code and put
# the precision caveat in the note, because a threshold invented to beat a rival model is
# the kind of number this repo has had to withdraw before.
MIN_HRR = 0.35
MAX_HRR = 0.95

# Windows must be at running speed. This is the ACSM equation switch that
# `vo2max_submax._vo2_speed_grade` already uses, reused rather than re-picked.
#
# ## Why walking is excluded — three independent reasons, only one of them ours
#
# 1. **The walking-specific literature is damning.** Solheim 2014 walked 28 adults at 3
#    mph targeting 50% reserve and measured %VO2R 46.9 +/- 2.0 against %HRR 55.3 +/- 5.4,
#    with a correlation of r = 0.31 (p = 0.105) — against r = 0.990 in Swain's treadmill
#    GXT. Warner 2022's meta-regression on walking puts %HRR at 3 METs at 33% with a 95%
#    CI of 18-57%. A mapping with a 39-point confidence interval cannot carry a division.
# 2. **Prolonged constant-load exercise breaks it, and a walk is exactly that.** Cunha
#    2011 found the GXT-derived relationship "did not apply to prolonged treadmill
#    running" (mean difference 8%); Ferri Marini 2022 found %HRR and %VO2R
#    indistinguishable over 15-minute steady states but %HRR higher by 6.7 points over
#    45-minute ones (p = 0.009). This owner's walks run 22 to 147 minutes.
# 3. **Measured on his own tracks it is wrong, not merely uncertain** — see the module
#    docstring: a factor of 4.0 against running windows at matched %HRR, and values his
#    own sustained VO2 refutes outright.
#
# The threshold itself is the ACSM walking/running equation boundary, already in this
# codebase; what is new is the refusal to compute below it. Note what is NOT claimed:
# that the equivalence fails because his walking intensity is low. It is not low — his
# walking windows sit at 45-70% HRR, inside MIN_HRR..MAX_HRR. It fails because at walking
# workloads the metabolic share of his heart rate is small enough that the non-metabolic
# share (heat, hydration, posture, drift) dominates it.
MIN_SPEED_MS = RUN_SPEED_MS

# At least this many admissible windows before a median means anything. Matches
# `vo2max_submax.MIN_WINDOWS` — the same question ("is this enough of a session to
# speak for") deserves the same answer in both estimators.
MIN_RESERVE_WINDOWS = 6

# HRmax must sit meaningfully above HRrest or the reserve span is not a span.
_MIN_RESERVE_SPAN_BPM = 40.0

# ── Withhold reasons (the `derive/freshness.py` vocabulary shape) ────────────
#
# One id per state, each with the second-person sentence that says what would restore
# the number. `walking_only` is the one this task exists to produce: it is the honest
# answer to "why is there no fitness number from my hour-long walk", and it has to say
# that no amount of MORE walking will change it.

WITHHOLD_NO_STEADY_WINDOWS = "no_steady_windows"
WITHHOLD_WALKING_ONLY = "walking_intensity_only"
WITHHOLD_FEW_RESERVE_WINDOWS = "too_few_reserve_windows"
WITHHOLD_HRR_TOO_LOW = "heart_rate_reserve_fraction_too_low"
WITHHOLD_NO_RESTING_HR = "no_resting_hr"
WITHHOLD_IMPLAUSIBLE = "implausible_reserve_estimate"

RESERVE_WITHHOLD_MESSAGES = {
    WITHHOLD_NO_STEADY_WINDOWS: (
        "Nothing in this session held a steady enough pace to read effort from. Stop-"
        "start walking with crossings and pauses can't be turned into a fitness number."
    ),
    WITHHOLD_WALKING_ONLY: (
        "This session was walking, and walking can't measure your VO₂max. At walking "
        "pace your heart rate is driven as much by heat, hydration and how long you've "
        "been out as by how hard you're working, so the number it gives is wrong rather "
        "than uncertain — on your own walks this method reads about half your real "
        "fitness. It needs a stretch of running, not a longer or brisker walk."
    ),
    WITHHOLD_FEW_RESERVE_WINDOWS: (
        f"There were fewer than {MIN_RESERVE_WINDOWS} steady half-minutes of running in "
        "this session — not enough to take a reliable middle from. A few unbroken "
        "minutes at a running pace is all this needs."
    ),
    WITHHOLD_HRR_TOO_LOW: (
        "Your heart rate stayed outside the band this calculation was validated over "
        f"({MIN_HRR:.0%}-{MAX_HRR:.0%} of the way from resting to maximum). Too close to "
        "resting and dividing by a small number multiplies every error in it; too close "
        "to maximum and nobody has published what the relationship does."
    ),
    WITHHOLD_NO_RESTING_HR: (
        "This needs your resting heart rate, and there aren't enough recent nights of "
        "it. Wear the strap overnight for a few nights and this comes back."
    ),
    WITHHOLD_IMPLAUSIBLE: (
        "The result fell outside the range of humanly plausible VO₂max values, so we "
        "won't report it. Something in this session's pace, heart rate or elevation is "
        "not what it appears to be."
    ),
}


@dataclass
class ReserveResult:
    """One session's reserve-inverted VO2max plus the diagnostics that justify it."""

    vo2max: float
    n_windows: int
    hrr_median: float
    hrr_min: float
    spread: float  # inter-quartile spread of the per-window estimates, ml/kg/min
    speed_kmh_median: float


def hrr_fraction(hr: float, hr_rest: float, hr_max: float) -> float:
    """Karvonen's fraction of heart-rate reserve. [[hr_reserve_vo2max]]."""
    return (hr - hr_rest) / (hr_max - hr_rest)


def reserve_vo2max(window: SteadyWindow, hr_rest: float, hr_max: float) -> float | None:
    """One window's independent VO2max estimate, or None outside the validated %HRR range.

    The inversion of Swain & Leutholtz's equivalence, applied to a single steady window.
    No regression, no other window, no session — which is exactly why a flat effort can
    be scored at all. [[hr_reserve_vo2max]].
    """
    hrr = hrr_fraction(window.hr, hr_rest, hr_max)
    if not (MIN_HRR <= hrr <= MAX_HRR):
        return None
    return VO2_REST_ML_KG_MIN + (window.vo2 - VO2_REST_ML_KG_MIN) / hrr


def _iqr(values: list[float]) -> float:
    """Inter-quartile spread, on the same halves-of-the-sorted-list convention as
    ``derive/robust.median`` — reported so a wide session reads as wide."""
    ordered = sorted(values)
    half = len(ordered) // 2
    lower = ordered[:half]
    upper = ordered[half + 1 :] if len(ordered) % 2 else ordered[half:]
    if not lower or not upper:
        return 0.0
    return median(upper) - median(lower)


def vo2max_from_reserve(
    windows: list[SteadyWindow] | None,
    hr_rest: float | None,
    hr_max: float,
) -> tuple[ReserveResult | None, str]:
    """Median of the per-window %HRR inversions over one session's steady windows.

    ``windows`` is ``vo2max_submax.steady_windows(...)`` — ``None`` when the track could
    not be windowed at all. Returns ``(ReserveResult, "ok")`` or ``(None, reason)``,
    where the reason is one of the ``WITHHOLD_*`` ids above.

    **Fails closed.** Every gate below refuses rather than widening a caveat, because
    the failure this estimator has on walking is a BIAS of 17-30 ml/kg/min and no
    confidence label survives being that wrong. [[hr_reserve_vo2max]].
    """
    if hr_rest is None:
        return None, WITHHOLD_NO_RESTING_HR
    if not windows:
        return None, WITHHOLD_NO_STEADY_WINDOWS
    if hr_max - hr_rest < _MIN_RESERVE_SPAN_BPM:
        return None, WITHHOLD_NO_RESTING_HR
    fast = [w for w in windows if w.speed_ms >= MIN_SPEED_MS]
    if not fast:
        return None, WITHHOLD_WALKING_ONLY
    scored = [(w, v) for w in fast if (v := reserve_vo2max(w, hr_rest, hr_max)) is not None]
    if not scored:
        return None, WITHHOLD_HRR_TOO_LOW
    if len(scored) < MIN_RESERVE_WINDOWS:
        return None, WITHHOLD_FEW_RESERVE_WINDOWS
    return _result(scored, hr_rest, hr_max)


def _result(
    scored: list[tuple[SteadyWindow, float]], hr_rest: float, hr_max: float
) -> tuple[ReserveResult | None, str]:
    """Aggregate the admitted windows, or refuse an implausible middle.

    The MEDIAN, never the mean: the per-window estimates carry a long tail from single
    windows whose DEM grade or interpolated HR is momentarily wrong (one 06-13 window
    reads 42.7 against a session median of 22.1), and one such window must not move the
    answer. [[hr_reserve_vo2max]].
    """
    estimates = [v for _, v in scored]
    vo2max = median(estimates)
    if not (VO2MAX_LO <= vo2max <= VO2MAX_HI):
        return None, WITHHOLD_IMPLAUSIBLE
    hrrs = [hrr_fraction(w.hr, hr_rest, hr_max) for w, _ in scored]
    return (
        ReserveResult(
            vo2max=round(vo2max, 1),
            n_windows=len(scored),
            hrr_median=round(median(hrrs), 3),
            hrr_min=round(min(hrrs), 3),
            spread=round(_iqr(estimates), 1),
            speed_kmh_median=round(median([w.speed_ms for w, _ in scored]) * 3.6, 1),
        ),
        "ok",
    )
