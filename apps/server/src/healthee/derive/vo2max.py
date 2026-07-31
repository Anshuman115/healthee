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

# Not a withhold the note names — the day simply has not been derived yet (nothing has
# been synced for it). It shares the vocabulary because the USER-VISIBLE state is the
# same one the note asks for ("Insufficient data": there is no number for today), and
# because a payload that names every other absence and shrugs at this one would be the
# same silence in a different place.
NOT_DERIVED_YET = "not_derived_yet"

# What each absence would take to fix, in the second person. The note asks for exactly
# one user-facing STATE ("Insufficient data"); these are the actionable half of it, and
# they are why the reason is surfaced at all — "no number" tells an owner nothing,
# "your resting HR swung too much this week" tells them what the system is waiting on.
WITHHOLD_MESSAGES = {
    WITHHOLD_NO_PROFILE: (
        "We need your height, sex and date of birth, plus at least one logged weight, "
        "before this estimate can be computed."
    ),
    WITHHOLD_FEW_RHR_DAYS: (
        "Fewer than 3 nights of resting heart rate in the last week — wear the strap "
        "overnight for a few more nights and this comes back."
    ),
    WITHHOLD_RHR_OUT_OF_RANGE: (
        "Your 7-day resting-HR median is outside the 40-100 bpm range this model was "
        "validated on, so any number here would be a guess."
    ),
    WITHHOLD_RHR_TOO_NOISY: (
        "Your resting heart rate moved too much this week for the estimate to mean "
        "anything (7-day spread above 8 bpm). A few steadier nights will restore it."
    ),
    NOT_DERIVED_YET: "Today's estimate has not been computed yet — sync the strap.",
}

# ── Directive 5: flag out-of-range inputs (ADDITIVE — never a withhold) ──────
#
# [[non_exercise_vo2max]], Coach Directive 5 (confidence: moderate):
#   "Flag decoupling confounders (beta-blockers, atropine, out-of-range inputs)
#    when known."
# and Safety bounds, which names the ranges:
#   "Out-of-range inputs make it unreliable: the model was validated for ages
#    20-70, BMI 16-45, RHR 40-100; outside those bounds error grows and the
#    estimate should be flagged or withheld."
#
# The note offers BOTH branches ("flagged or withheld") and we take a different one
# per input, deliberately:
#
#   RHR    -> WITHHELD (`WITHHOLD_RHR_OUT_OF_RANGE` above). RHR is the input the
#             note singles out three separate times as untrustworthy-when-noisy,
#             it is the only one that moves day to day, and an out-of-range median
#             usually means the measurement is wrong rather than the person unusual.
#             So no stored row can ever carry an out-of-range RHR, and it needs no
#             flag here.
#   AGE/BMI -> FLAGGED. Both are stable facts about a person, not measurement
#             noise. Withholding on them would silently delete this metric for
#             every owner under 20, over 70, or outside BMI 16-45 — people whose
#             own TREND (which the note calls the trustworthy signal, over the
#             level) is exactly as worth tracking. "Not enough data" beats a guess;
#             "we deleted your metric because you are 72" is neither.
#
# The estimate is NOT modified by these flags — the honesty contract's answer to a
# model used outside its validated range is to say so, not to bend the number.
_AGE_VALID_LO_YEARS, _AGE_VALID_HI_YEARS = 20, 70
_BMI_VALID_LO, _BMI_VALID_HI = 16.0, 45.0

_OUT_OF_RANGE_MESSAGE = (
    "Jurca 2005 was validated on {label} {low}-{high}; at {value} the model is outside "
    "the range it was tested on, so the real error is wider than the {see} ml/kg/min "
    "this estimate advertises."
)


def out_of_range_inputs(age_years: float | None, bmi: float | None) -> list[dict]:
    """Jurca inputs outside the model's VALIDATED range, as additive flags.

    Pure and total. Never changes or withholds the estimate — Directive 5 asks for a
    flag, and the ranges come from the note's Safety bounds section. An ABSENT input
    produces no flag: "we cannot tell" is a different state from "out of range", and
    a missing profile input already withholds upstream in :func:`derive_vo2max`.
    Boundaries are INCLUSIVE, matching how the note writes them ("ages 20-70").
    [[non_exercise_vo2max]].
    """
    lo_age, hi_age = _AGE_VALID_LO_YEARS, _AGE_VALID_HI_YEARS
    flags: list[dict] = []
    if age_years is not None and not (lo_age <= age_years <= hi_age):
        flags.append(_flag("age_years", "ages", age_years, lo_age, hi_age))
    if bmi is not None and not (_BMI_VALID_LO <= bmi <= _BMI_VALID_HI):
        flags.append(_flag("bmi", "BMI", round(bmi, 1), _BMI_VALID_LO, _BMI_VALID_HI))
    return flags


def _flag(name: str, label: str, value: float, low: float, high: float) -> dict:
    """One out-of-range input, machine-readable and self-explaining."""
    return {
        "input": name,
        "value": value,
        "validated_low": low,
        "validated_high": high,
        "message": _OUT_OF_RANGE_MESSAGE.format(
            label=label, low=low, high=high, value=value, see=_JURCA_SEE_ML_KG_MIN
        ),
    }


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


def rhr_week(cur: Cur, user_id: UUID, day: date) -> list[float]:
    """The 7-day resting-HR window ``day``'s estimate is built from (``day`` included)."""
    cur.execute(
        "SELECT value FROM derived_daily "
        "WHERE user_id = %s AND metric='rhr_daily' AND day<=%s AND day>%s",
        (user_id, day, day - timedelta(days=7)),
    )
    return [float(r[0]) for r in cur.fetchall()]


def withhold_reason_for_day(cur: Cur, user_id: UUID, tz: str, day: date) -> str | None:
    """Why ``day`` has no estimate, or None when its inputs CAN carry one.

    The same two checks :func:`derive_vo2max` makes, in the same order, over the same
    window — but without writing anything. The read layer calls this so it can say
    *why* a day has no number instead of quietly showing an older day's, which is the
    "here's what we'd need" posture the product promises. Keeping the reason
    recomputable is what lets us do that with NO new schema and no backfill: the
    withhold decision is a pure function of inputs that are still in the database.

    The equivalence with the writer is not an assumption — ``test_vo2max_freshness``
    pins ``derive_vo2max(...) is None`` iff this returns a reason, across every gated
    state, so a gate added to one and not the other fails the build.
    [[non_exercise_vo2max]].
    """
    if not _load_profile(cur, user_id, tz, day):
        return WITHHOLD_NO_PROFILE
    return vo2max_withhold_reason(rhr_week(cur, user_id, day))


def estimate_unavailable_reason(
    cur: Cur, user_id: UUID, tz: str, today: date, last_day: date | None
) -> str | None:
    """Why this owner has no estimate FOR TODAY, or ``None`` when ``last_day`` IS today.

    The FRESHNESS half of the gate, in one place. :func:`withhold_reason_for_day` answers
    "could today carry an estimate"; this answers the question a *consumer* actually has,
    which is "is the newest stored row today's". They are different questions and the
    second is the one that was getting skipped: a row is not evidence about today merely
    because it is the newest row, so an estimate is reported only when the newest row is
    the owner's today. ``last_day is None`` (no row at all) is the same answer as a stale
    one — there is no estimate for today either way.

    Extracted because there are now TWO consumers and the rule must not fork: the VO2max
    payload (``read/vo2max.py``) and the biological-age fitness term
    (``analytics/biological_age.py``), where a stale estimate is laundered into a headline
    composite. [[non_exercise_vo2max]], [[biological_age_estimate]].
    """
    if last_day == today:
        return None
    return withhold_reason_for_day(cur, user_id, tz, today) or NOT_DERIVED_YET


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
    rhrs = rhr_week(cur, user_id, day)
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
