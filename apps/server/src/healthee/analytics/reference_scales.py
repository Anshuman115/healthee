"""The ANCHORS the biological-age hazard ratios are applied at, and their footing.

A hazard ratio is two things: a **slope** (how much risk moves per unit of exposure)
and an **anchor** (the point on the exposure axis where the slope is measured from,
and the instrument that axis was measured with). [[biological_age_estimate]]'s table
sources every slope to a meta-analysis. Until #97 nothing sourced the anchors, and
that is where both surviving terms were wrong:

- **Fitness** compares our VO₂max estimate to a population median held in a constant
  table that appears in no note and cites no paper (``_VO2MAX_MEDIAN_*`` below).
- **Sleep duration** applied Yin 2017's curve — whose exposure is a *questionnaire* —
  directly to a *device-measured* nightly average, i.e. at the wrong point on its own
  x-axis (``self_reported_equivalent_h`` below).

This is the lesson of #86 generalised. The regularity term was removed because an SRI
point is defined by the software that scored it and so has no transportable anchor at
all. These two are not that: ml/kg/min and hours are physical units, so an anchor
*exists* and can be stated, checked, corrected, or — for the VO₂max median — admitted
to be unsourced. Keeping them in one file is deliberate: "which anchor came from
where" is the question that has now produced three bugs, and it should be answerable
by reading one screen.

Nothing here is a slope. Slopes live with the term that uses them, in
``analytics/biological_age.py``.
"""

from __future__ import annotations

# ── Fitness anchor: population-median VO₂max ────────────────────────────────
#
# ⚠ UNCITED. These numbers appear in no research note and no paper we can find. Their
# whole provenance is a comment in the legacy repo's ``api/app.py``, dropped in the
# port to this one: "Approximate population-median VO2max by age band, sex-stratified
# (ACSM Guidelines 11th ed., ~50th percentile)." That claim does not survive checking.
# ACSM's 11th-edition percentiles reproduce the FRIEND registry, and FRIEND's published
# 50th percentiles (Kaminsky et al. 2015, Mayo Clin Proc 90(11):1515–23, PMID 26455884
# — 7,783 maximal treadmill CPETs, abstract verified 2026-08-01) are:
#
#     men 20–29   48.0   vs 44.0 here   (4.0 LOW)
#     women 20–29 37.6   vs 36.0 here   (1.6 LOW)
#     men 70–79   24.4   vs 24.0 here   (0.4 low)
#     women 70–79 18.3   vs 19.0 here   (0.7 high)
#
# Three of the four cells we can check against a primary source read LOW, and a low
# reference makes the owner look fitter than the population — the term FLATTERS. At the
# worst cell that is 4.0/3.5 = 1.14 MET, i.e. 2.1 years of biological age. FRIEND's
# middle decades are not in the abstract and we would not paste a number we have not
# read, so the table is left as it is and its footing is published to the owner instead
# (``biological_age.CAVEAT_TERMS``) rather than quietly corrected to a guess.
#
# Note also that FRIEND is a self-selected clinical-referral cohort, not a population
# sample, so even a perfect match to it would not make "population median" true.
# Replacing this table needs a real source, and that is issue-sized work, not a patch.
VO2MAX_REFERENCE_UNCITED = "vo2max_reference_median_uncited"

_VO2MAX_MEDIAN_MALE = {20: 44.0, 30: 41.0, 40: 38.0, 50: 33.0, 60: 28.0, 70: 24.0}
_VO2MAX_MEDIAN_FEMALE = {20: 36.0, 30: 33.0, 40: 30.0, 50: 26.0, 60: 22.0, 70: 19.0}


def vo2max_median_for(age: int, sex: str) -> float:
    """Population-median VO₂max for the age bucket (clamped to 20–70).

    ⚠ The table is UNCITED and reads low against FRIEND — see the block above. Callers
    that show this number to an owner must carry the caveat with it."""
    table = _VO2MAX_MEDIAN_FEMALE if sex == "female" else _VO2MAX_MEDIAN_MALE
    return table[max(20, min(70, (age // 10) * 10))]


# ── Sleep-duration anchor: questionnaire hours vs device hours ──────────────
#
# Yin et al. 2017 (JAHA 6(9):e005947) is the source of the 1.06/1.13-per-hour slopes and
# of the 7 h nadir. Its exposure is self-report: "Sleep duration was measured by
# self-report questionnaires in 48 studies and by interview in 19 studies", and its own
# limitations open "nearly all studies relied on sleep duration that was self-reported
# by questionnaire or interview". Our input is a strap hypnogram. Applying the curve to
# device hours reads it at the wrong place on its own x-axis, and the error is not small
# at the short end, which is where a short sleeper lives.
#
# The gap was MEASURED, and it is dose-dependent rather than a constant. Lauderdale
# et al. 2008 (Epidemiology 19(6):838–45, PMID 18854708 — CARDIA Chicago, n = 669, 3
# days of wrist actigraphy plus questions about usual sleep, abstract verified
# 2026-08-01) publishes three points:
#
#     mean measured 6.0 h  ↔  mean reported 6.8 h      (+0.8)
#     measured 5 h         ↔  over-reported by 1.2 h
#     measured 7 h         ↔  over-reported by 0.4 h
#
# All three lie on one line: over-report_h = 3.2 − 0.4 × measured_h. (The paper's other
# published figure, "subjective reports increased on average by 34 minutes for each
# additional hour of measured sleep", is the same line to within a minute: slope 0.6.)
#
# Note that this REPLACES the "30–60 min" figure asserted, uncited, in
# [[sleep_duration_mortality]]'s honesty section. That range is not wrong so much as
# not applicable: it is roughly right in the middle of the curve and materially too
# small below ~5.5 h measured, which is exactly the population this product exists for.
SELF_REPORT_OVER_REPORT_INTERCEPT_H = 3.2
SELF_REPORT_OVER_REPORT_SLOPE_PER_H = 0.4
# Lauderdale's shortest published anchor is 5 h measured (+1.2 h). Below it the line is
# extrapolation, so the offset is held flat rather than grown — an errors-in-variables
# fit run off the end of its data is how a correction becomes its own wrong number.
SELF_REPORT_OVER_REPORT_MAX_H = 1.2
# At 8 h measured the line reaches zero and would turn negative (i.e. claim people
# UNDER-report long sleep). Lauderdale's cohort averaged 6.0 h and publishes no anchor
# out there, so the offset floors at zero: past 8 h we apply the curve to device hours
# unchanged and say so, rather than inventing a discount on the long-sleep tail.
SELF_REPORT_OVER_REPORT_MIN_H = 0.0

SLEEP_DURATION_SELF_REPORT_SCALE = "sleep_duration_self_report_scale"


def self_report_over_report_h(measured_h: float) -> float:
    """How many hours longer than ``measured_h`` a person typically *says* they slept.

    Lauderdale et al. 2008's measured, dose-dependent gap, clamped to the range its
    published anchors cover (see the block above). Known-value tested against all three
    of the paper's own points in ``tests/analytics/test_biological_age_math.py``."""
    raw = SELF_REPORT_OVER_REPORT_INTERCEPT_H - SELF_REPORT_OVER_REPORT_SLOPE_PER_H * measured_h
    return max(SELF_REPORT_OVER_REPORT_MIN_H, min(SELF_REPORT_OVER_REPORT_MAX_H, raw))


def self_reported_equivalent_h(measured_h: float) -> float:
    """Device-measured nightly hours → the questionnaire hours Yin 2017's curve expects.

    This is the whole of the #97 sleep fix: the curve is unchanged, the point it is read
    at is corrected. Leaving it out is not neutral — it asserts that a strap and a
    questionnaire produce the same number, which Lauderdale measured and they do not."""
    return measured_h + self_report_over_report_h(measured_h)


# ── What each anchor's footing costs the owner, in the second person ────────
#
# Keyed by reason id; ``analytics/biological_age.py`` attaches each to its term and
# publishes the result as the payload's ``caveats``. These belong here rather than there
# because they are statements ABOUT THE ANCHORS, and an anchor whose footing is described
# two files away from its numbers is how the legacy provenance comment got lost.
#
# The shape is deliberately ``excluded``'s — term, reason, message — because the reader
# should not have to learn a second one. There is no machine-readable "direction" field:
# the fitness anchor's tilt is one-directional and the message says so, but the sleep
# anchor's residual pushes short sleepers and long sleepers OPPOSITE ways, and a key that
# is right for most owners and wrong for some is worse than a sentence that is right for
# all of them.
ANCHOR_CAVEATS = {
    VO2MAX_REFERENCE_UNCITED: {
        "reason": VO2MAX_REFERENCE_UNCITED,
        "message": (
            "The fitness term measures your VO₂max estimate against a population median "
            "for your age and sex, and that median is the one number behind this estimate "
            "with no published source — it was carried over from an older version of this "
            "app. Where it can be checked against the US reference standard (FRIEND, 7,783 "
            "maximal treadmill tests), it reads low: 44 where FRIEND says 48 for men in "
            "their twenties, 36 where FRIEND says 37.6 for women. A reference set too low "
            "makes you look fitter than the population, so on that count this number is "
            "generous to you rather than harsh — by up to about 2 years."
        ),
    },
    SLEEP_DURATION_SELF_REPORT_SCALE: {
        "reason": SLEEP_DURATION_SELF_REPORT_SCALE,
        "message": (
            "Your sleep hours are translated before the risk curve is applied to them. "
            "That curve was measured on sleep people reported on questionnaires, and "
            "questionnaires run long: in the study that measured both, people who actually "
            "slept 5 hours said 6.2, and people who slept 7 said 7.4. Your strap's nightly "
            "average is converted to its questionnaire equivalent first, so you are not "
            "charged for hours you never claimed — which also means the lowest-risk point "
            "sits near 6h20 on your strap rather than at the 7 hours the studies quote. "
            "Two things are left uncorrected: wrist devices read about 17 minutes short of "
            "a sleep lab, which charges a short sleeper slightly too much and credits a "
            "long sleeper slightly too much; and above 8 hours we stop translating "
            "altogether rather than extrapolate past what was measured, which keeps the "
            "long-sleep penalty at its full size."
        ),
    },
}
