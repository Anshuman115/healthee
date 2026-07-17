"""Non-exercise VO2max estimate (Jurca 2005) for one local day.

Profile (age, sex, BMI) + a 7-day median resting HR + a 7-day self-reported
physical-activity category (SRPA 0-4, mapped from weekly MVPA-equivalent minutes)
feed the Jurca regression; the result also anchors the energy model. Knowledge:
[[non_exercise_vo2max]] (Jurca 2005: CRF in METs, x3.5 -> ml/kg/min),
[[cadence_intensity]] (weekly MVPA-equivalent = moderate + 2*vigorous),
[[vo2max]].
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import date, timedelta
from uuid import UUID

from healthee.core.logging import get_logger
from healthee.derive._common import Cur, _age, _load_profile, _scalar, _upsert_daily
from healthee.derive.mvpa import _weekly_mvpa_to_srpa
from healthee.derive.robust import median, median_abs_deviation

log = get_logger(__name__)

_VO2MAX_FLOOR = 20.0  # floor keeps EE sane on sparse data
_JURCA_SEE_ML_KG_MIN = 5.6  # standard error of estimate (reported in flags)
_METS_TO_ML_KG_MIN = 3.5  # 1 MET = 3.5 ml O2 / kg / min

# ── The withhold gate, verbatim from [[non_exercise_vo2max]] ─────────────────
#
# The note is explicit in three places that this estimate is WITHHELD, not merely
# caveated, when its inputs can't carry it:
#
#   "Skip if any input is missing — never write a wrong value. Also skip (show
#    'Insufficient data') if the 7-day RHR MAD > 8 bpm or weight_kg is missing,
#    since a noisy RHR or absent mass makes the estimate untrustworthy."
#   Coach Directive 3 (confidence: high) — "Skip the derivation (show 'Insufficient
#    data') when any input is missing, RHR 7-day MAD > 8 bpm, or weight is absent —
#    never write a wrong value."
#   Honesty policy — "withhold when inputs are missing/out-of-range or RHR is too noisy."
#
# Why it matters beyond this metric: RHR is a Jurca input at -0.03 METs/bpm, so a week
# of illness, poor sensor contact or travel yields a median the model cannot see is
# untrustworthy — and VO2max is the DOMINANT term in [[biological_age_estimate]], so
# the noise launders straight into the age number.
_RHR_MAD_MAX_BPM = 8.0  # withhold ABOVE this; MAD == 8.0 still derives
_RHR_VALID_LO_BPM, _RHR_VALID_HI_BPM = 40.0, 100.0  # Jurca's validated RHR range
_RHR_MIN_DAYS = 3  # fewer than 3 of 7 days is not a week

# Machine-readable withhold reasons. "Insufficient data" is what the UI shows for all
# of them (the note asks for exactly one user-facing state), but they are distinct in
# the log so an operator can tell a noisy week from an empty one.
WITHHOLD_NO_PROFILE = "profile_or_weight_missing"
WITHHOLD_FEW_RHR_DAYS = "insufficient_rhr_days"
WITHHOLD_RHR_OUT_OF_RANGE = "rhr_median_outside_validated_range"
WITHHOLD_RHR_TOO_NOISY = "rhr_7d_mad_above_8_bpm"


def vo2max_withhold_reason(rhrs: Sequence[float]) -> str | None:
    """Why the Jurca estimate must be withheld for this 7-day RHR window, else None.

    Pure and total — the whole gate in one place so it can be tested without a DB.
    Order matters only for which reason is reported; any hit withholds.
    [[non_exercise_vo2max]].
    """
    if len(rhrs) < _RHR_MIN_DAYS:
        return WITHHOLD_FEW_RHR_DAYS
    if not (_RHR_VALID_LO_BPM <= median(rhrs) <= _RHR_VALID_HI_BPM):
        return WITHHOLD_RHR_OUT_OF_RANGE
    # Raw MAD in bpm — the note quotes the threshold in MAD, NOT in a normal-equivalent
    # sigma, so this must not be scaled by MAD_TO_SD.
    if median_abs_deviation(rhrs) > _RHR_MAD_MAX_BPM:
        return WITHHOLD_RHR_TOO_NOISY
    return None


def _vo2max_jurca(age: int, sex: str, bmi: float, rhr: float, srpa: int = 0) -> float:
    """Jurca 2005 non-exercise cardiorespiratory fitness -> VO2max (ml/kg/min).

    ONE equation for both sexes — sex is a term, not a sex-stratified model:
        CRF_METs = 18.07 + 2.77*sex - 0.10*age - 0.17*bmi - 0.03*rhr + srpa
    with sex = 1 (male) / 0 (female) and `srpa` the 0-4 self-reported physical-
    activity category. VO2max = CRF_METs * 3.5, floored at 20.

    Jurca et al. 2005, Am J Prev Med 29(3):185-193; CRF in METs, x3.5 ->
    ml/kg/min. [[non_exercise_vo2max]].
    """
    sex_term = 1.0 if sex == "male" else 0.0
    crf_mets = 18.07 + 2.77 * sex_term - 0.10 * age - 0.17 * bmi - 0.03 * rhr + srpa
    return max(crf_mets * _METS_TO_ML_KG_MIN, _VO2MAX_FLOOR)


def _withheld(user_id: UUID, day: date, reason: str) -> None:
    """Log a withheld estimate and return None (the "no number" the note asks for).

    Withholding is a real outcome, not a non-event: the note treats "the inputs are
    too noisy to trust" as a decision the system MADE. Logging it keeps that decision
    observable — an operator can tell a noisy week from an empty one by `reason`,
    which is the standards §1 requirement that "no data" and a failed/withheld
    computation stay distinguishable to the caller.
    """
    log.info(
        "vo2max_estimate withheld", extra={"user_id": str(user_id), "day": str(day), "why": reason}
    )
    return None


def derive_vo2max(cur: Cur, user_id: UUID, tz: str, day: date) -> dict | None:
    """Non-exercise VO2max: profile + 7-day median rhr_daily + 7-day MVPA score.

    None when the estimate is WITHHELD — either because an input is missing (no
    profile, no logged weight, fewer than 3 resting-HR days) or because the inputs
    are present but untrustworthy (RHR median outside Jurca's validated 40-100 bpm,
    or a 7-day RHR MAD above 8 bpm). Nothing is written in either case: the note's
    rule is "never write a wrong value", and the reason is logged so a withheld week
    is not silent. [[non_exercise_vo2max]].
    """
    prof = _load_profile(cur, user_id, tz, day)
    if not prof:
        # `_load_profile` already returns None when height/sex/dob or ANY logged
        # weight is absent, so the note's "weight_kg is missing" case is withheld
        # here — the BMI division below can never see a missing mass.
        return _withheld(user_id, day, WITHHOLD_NO_PROFILE)
    age = _age(prof["dob"], day)
    bmi = prof["weight_kg"] / ((prof["height_cm"] / 100) ** 2)
    cur.execute(
        "SELECT value FROM derived_daily "
        "WHERE user_id = %s AND metric='rhr_daily' AND day<=%s AND day>%s",
        (user_id, day, day - timedelta(days=7)),
    )
    rhrs = sorted(float(r[0]) for r in cur.fetchall())
    if reason := vo2max_withhold_reason(rhrs):
        return _withheld(user_id, day, reason)
    rhr_med = median(rhrs)
    # Weekly MVPA-EQUIVALENT applies the WHO rule (1 vigorous min = 2 moderate),
    # so we sum moderate + 2*vigorous from the daily mvpa_min flags — the stored
    # mvpa_min value itself stays raw (moderate + vigorous). [[cadence_intensity]]
    cur.execute(
        "SELECT COALESCE("
        "SUM((flags->>'moderate')::float + 2 * (flags->>'vigorous')::float), 0) "
        "FROM derived_daily WHERE user_id = %s AND metric='mvpa_min' AND day<=%s AND day>%s",
        (user_id, day, day - timedelta(days=7)),
    )
    srpa = _weekly_mvpa_to_srpa(_scalar(cur))
    vo2 = _vo2max_jurca(age, prof["sex"], bmi, rhr_med, srpa)
    _upsert_daily(
        cur,
        user_id,
        day,
        "vo2max_estimate",
        vo2,
        {
            "rhr_med": round(rhr_med, 1),
            "srpa": srpa,
            "bmi": round(bmi, 1),
            "age_years": age,
            "sex": prof["sex"],
            "see_ml_kg_min": _JURCA_SEE_ML_KG_MIN,
        },
    )
    return {"vo2max_estimate": round(vo2, 1)}
