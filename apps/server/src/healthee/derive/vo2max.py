"""Non-exercise VO2max estimate (Jurca 2005) for one local day.

Profile (age, sex, BMI) + a 7-day median resting HR + a 7-day self-reported
physical-activity category (SRPA 0-4, mapped from weekly MVPA-equivalent minutes)
feed the Jurca regression; the result also anchors the energy model. Knowledge:
``non_exercise_vo2max`` (Jurca 2005: CRF in METs, x3.5 -> ml/kg/min),
``cadence_intensity`` (weekly MVPA-equivalent = moderate + 2*vigorous),
``vo2max_fitness_mortality``.
"""

from __future__ import annotations

from datetime import date, timedelta

from healthee.derive._common import Cur, _age, _load_profile, _scalar, _upsert_daily
from healthee.derive.mvpa import _weekly_mvpa_to_srpa

_VO2MAX_FLOOR = 20.0  # floor keeps EE sane on sparse data
_JURCA_SEE_ML_KG_MIN = 5.6  # standard error of estimate (reported in flags)
_METS_TO_ML_KG_MIN = 3.5  # 1 MET = 3.5 ml O2 / kg / min


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


def derive_vo2max(cur: Cur, day: date) -> dict | None:
    """Non-exercise VO2max: profile + 7-day median rhr_daily + 7-day MVPA score.

    None until at least 3 resting-HR days are present and the median RHR is a
    plausible 40-100 bpm. [[non_exercise_vo2max]].
    """
    prof = _load_profile(cur, day)
    if not prof:
        return None
    age = _age(prof["dob"], day)
    bmi = prof["weight_kg"] / ((prof["height_cm"] / 100) ** 2)
    cur.execute(
        "SELECT value FROM derived_daily WHERE metric='rhr_daily' AND day<=%s AND day>%s",
        (day, day - timedelta(days=7)),
    )
    rhrs = sorted(float(r[0]) for r in cur.fetchall())
    if len(rhrs) < 3:
        return None
    n = len(rhrs)
    rhr_med = rhrs[n // 2] if n % 2 else 0.5 * (rhrs[n // 2 - 1] + rhrs[n // 2])
    if not (40 <= rhr_med <= 100):
        return None
    # Weekly MVPA-EQUIVALENT applies the WHO rule (1 vigorous min = 2 moderate),
    # so we sum moderate + 2*vigorous from the daily mvpa_min flags — the stored
    # mvpa_min value itself stays raw (moderate + vigorous). [[cadence_intensity]]
    cur.execute(
        "SELECT COALESCE("
        "SUM((flags->>'moderate')::float + 2 * (flags->>'vigorous')::float), 0) "
        "FROM derived_daily WHERE metric='mvpa_min' AND day<=%s AND day>%s",
        (day, day - timedelta(days=7)),
    )
    srpa = _weekly_mvpa_to_srpa(_scalar(cur))
    vo2 = _vo2max_jurca(age, prof["sex"], bmi, rhr_med, srpa)
    _upsert_daily(
        cur,
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
