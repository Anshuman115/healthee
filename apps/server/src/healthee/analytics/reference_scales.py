"""The ANCHORS the biological-age hazard ratios are applied at, and their footing.

A hazard ratio is two things: a **slope** (how much risk moves per unit of exposure)
and an **anchor** (the point on the exposure axis where the slope is measured from,
and the instrument that axis was measured with). [[biological_age_estimate]]'s table
sources every slope to a meta-analysis. Until #97 nothing sourced the anchors, and
that is where both surviving terms were wrong:

- **Fitness** compared our VO₂max estimate to a "population median" held in a constant
  table that appeared in no note and cited no paper. Sourced in #101 to one published
  row — FRIEND's treadmill 50th percentile (``_FRIEND_TREADMILL_MEDIAN_*`` below) —
  which also reversed #97's reading of which way the old table leaned.
- **Sleep duration** applied Yin 2017's curve — whose exposure is a *questionnaire* —
  directly to a *device-measured* nightly average, i.e. at the wrong point on its own
  x-axis (``self_reported_equivalent_h`` below).

This is the lesson of #86 generalised. The regularity term was removed because an SRI
point is defined by the software that scored it and so has no transportable anchor at
all. These two are not that: ml/kg/min and hours are physical units, so an anchor
*exists* and can be stated, checked and corrected. Keeping them in one file is
deliberate: "which anchor came from where" is the question that has now produced three
bugs, and it should be answerable by reading one screen.

Nothing here is a slope. Slopes live with the term that uses them, in
``analytics/biological_age.py``.
"""

from __future__ import annotations

# ── Fitness anchor: the FRIEND treadmill 50th percentile ────────────────────
#
# ONE SOURCE, EVERY CELL. Kaminsky LA, Arena R, Myers J, Peterman JE, Bonikowske AR,
# Harber MP, Medina Inojosa JR, Lavie CJ, Squires RW (2022), "Updated Reference Standards
# for Cardiorespiratory Fitness Measured with Cardiopulmonary Exercise Testing: Data from
# the Fitness Registry and the Importance of Exercise National Database (FRIEND)", Mayo
# Clin Proc 97(2):285–293, PMID 34809986 — **Table 3, treadmill block, the 50th-percentile
# row**, directly measured VO₂peak in mLO₂·kg⁻¹·min⁻¹, inclusion criterion RER ≥ 1.0.
# 16,278 treadmill CPETs from 34 US laboratories (men n = 9,564, women n = 6,714), tested
# 1968-01-01 → 2021-03-31. Table read in full 2026-08-01; the 80–89 bucket is in the same
# row, which is why the clamp now reaches 80 instead of stopping at 70.
#
# Why the whole row and not a patch: the table this replaced was invented cell by cell,
# and a table half from FRIEND and half from anywhere else would be a new version of the
# same defect — two scales inside one comparison. Nothing here comes from a secondary
# reproduction, from the 2015 edition, or from ACSM.
#
# WHAT WAS HERE BEFORE, and why it had to go. The old constants (M 44/41/38/33/28/24,
# F 36/33/30/26/22/19) cited nothing; their whole provenance was a comment in the legacy
# repo's ``api/app.py``, dropped in the port to this one — "Approximate population-median
# VO2max by age band, sex-stratified (ACSM Guidelines 11th ed., ~50th percentile)", whose
# very next sentence said "Used only for a 'above/below average for your age and sex'
# badge — not for precision claims". It was promoted to driving the dominant term of a
# number expressed in years and its own caveat was left behind.
#
# #97 could only check four cells (the two the 2015 abstract prints) and concluded the
# table read LOW, i.e. that the term FLATTERED, by up to ~2.1 y. **Reading all twelve
# cells against the current standard reverses that for most of the table**:
#
#     old − FRIEND 2022    20s     30s     40s     50s     60s     70s
#     men                 −2.5    +1.3    +2.7    +3.8    +3.4    +3.4
#     women               −0.6    +4.7    +4.3    +3.1    +2.4    +1.8
#
# Ten of twelve cells were HIGH — a reference set too fit makes the owner look worse, so
# the old table PENALISED almost everywhere, worst at women 30–39 (4.7 ml/kg/min =
# 1.34 MET ≈ 2.4 years charged and never earned). Only the two 20-something cells
# flattered. The four-cell check was not wrong about its four cells; it was a sample, and
# the sample's sign did not hold. That is the reason this constant needed a whole row from
# one paper rather than a correction.
#
# WHY THE 2022 EDITION AND NOT THE 2015 ONE. Same authors, same registry, same modality,
# same effort criterion (the 2015 paper's own abstract reads "maximal (respiratory
# exchange ratio, ≥1.0) treadmill tests"), so Table 3 here is the like-for-like successor
# to the table #97 compared against. Its abstract states the update is "1.5–4.6
# mLO₂·kg⁻¹·min⁻¹ lower compared with the previous 2015 standards" and that this
# "improve[s] the representativeness of the US population". Both editions were read in
# full and the deltas between their 50th-percentile rows reproduce the 2022 paper's own
# published ranges exactly — men 1.5–3.8, women 0.4–1.9 — which is the cross-check that
# neither table was mis-transcribed here. Using the superseded edition when its authors
# have published the replacement would be choosing the number, not the source.
#
# WHAT IS STILL NOT TRUE OF THIS TABLE, and why the caveat survives the fix:
#
#  1. **It is not a population median, and no amount of matching it makes it one.** FRIEND
#     is people who came to a laboratory for a CPET. The paper's own limitations: "the
#     individual referral for the tests varied (clinical assessment as part of a
#     comprehensive physical exam, fitness assessment, and participants in research
#     studies)", and "the term 'apparently healthy' may not be appropriate for the entire
#     study population as some had diseases (eg, diabetes and obesity)".
#  2. **The direction of that selection is not measured for the US.** Where FRIEND was
#     compared with a whole-population CPET sample measured the same way, it ran LOWER at
#     every decade: the 2015 paper's Table 4 puts FRIEND men at 47.6 vs 54.4 (Loe et al.
#     2013, n = 3,816 Norwegians) at 20–29 and 25.8 vs 35.3 at 70–79, women 37.6 vs 43.0
#     and 18.3 vs 28.3. That paper's own conclusion is that reference values are "region
#     and country specific", so this bounds nothing for a US owner — it only shows the
#     choice of reference COHORT moves this term by more than the correction above did.
#  3. **Our side of the comparison is an estimate, not a measurement.** Jurca 2005 was
#     validated against measured maximal-treadmill VO₂max, so the unit transports (unlike
#     an SRI point — see [[biological_age_estimate]] on #86), but it carries SEE ≈ 5.6
#     ml/kg/min ≈ 2.9 years of ΔAge, which is larger than every anchor effect on this
#     screen. [[non_exercise_vo2max]].
VO2MAX_REFERENCE_CLINICAL_COHORT = "vo2max_reference_clinical_cohort"

# FRIEND 2022, Table 3, treadmill, RER ≥ 1.0, 50th percentile. Keys are the decade's
# lower bound; every value is one cell of that published row.
_FRIEND_TREADMILL_MEDIAN_MALE = {
    20: 46.5,
    30: 39.7,
    40: 35.3,
    50: 29.2,
    60: 24.6,
    70: 20.6,
    80: 17.6,
}
_FRIEND_TREADMILL_MEDIAN_FEMALE = {
    20: 36.6,
    30: 28.3,
    40: 25.7,
    50: 22.9,
    60: 19.6,
    70: 17.2,
    80: 15.4,
}


def vo2max_median_for(age: int, sex: str) -> float:
    """FRIEND's 50th-percentile treadmill VO₂peak for the age decade (clamped to 20–80).

    The reference the fitness term is measured against. It is a *reference-standard*
    median, not a population one — see the block above; callers that show this number to
    an owner must carry the caveat with it."""
    table = _FRIEND_TREADMILL_MEDIAN_FEMALE if sex == "female" else _FRIEND_TREADMILL_MEDIAN_MALE
    return table[max(20, min(80, (age // 10) * 10))]


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
    VO2MAX_REFERENCE_CLINICAL_COHORT: {
        "reason": VO2MAX_REFERENCE_CLINICAL_COHORT,
        "message": (
            "The fitness term measures your VO₂max estimate against a reference for your "
            "age and sex. That reference is now the US standard — the median of 16,278 "
            "treadmill exercise tests in the FRIEND registry — replacing a table that had "
            "no published source and was charging most people up to about two years they "
            "had not earned. It is still not a median of the population: FRIEND is people "
            "who came to a laboratory for a test, and how that differs from everyone else "
            "has not been measured in the US. Where it has been compared with a "
            "whole-population sample abroad, FRIEND sat lower, which would make this "
            "comparison generous rather than harsh — but that was a different country. "
            "Either way it is the smaller uncertainty here: your own VO₂max is estimated "
            "rather than measured, and that estimate's error is worth about three years."
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
