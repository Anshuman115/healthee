"""Non-exercise VO2max estimate (Jurca 2005) for one local day.

Profile (age, sex, BMI) + a 7-day median resting HR + a 7-day MVPA->activity
score feed the Jurca regression; the result also anchors the energy model. Ported
verbatim from legacy v2. Knowledge: ``non_exercise_vo2max`` (Jurca 2005 + HUNT3),
``vo2max_fitness_mortality``.
"""

from __future__ import annotations

from datetime import date, timedelta

from healthee.derive._common import Cur, _age, _load_profile, _scalar, _upsert_daily
from healthee.derive.mvpa import _mvpa_to_pa_score

_VO2MAX_FLOOR = 20.0  # floor keeps EE sane on sparse data
_JURCA_SEE_ML_KG_MIN = 5.6  # standard error of estimate (reported in flags)


def _vo2max_jurca(age: int, sex: str, bmi: float, rhr: float, pa_score: int = 3) -> float:
    """Jurca 2005 non-exercise VO2max (ml/kg/min), floored at 20.

    `pa_score` is the 0-7 physical-activity score (defaults to 3 until the MVPA
    chain feeds it). [[non_exercise_vo2max]].
    """
    if sex == "male":
        v = 56.363 + 1.921 * pa_score - 0.381 * age - 0.754 * bmi - 0.084 * rhr
    else:
        v = 50.513 + 1.589 * pa_score - 0.289 * age - 0.552 * bmi - 0.085 * rhr
    return max(v, _VO2MAX_FLOOR)


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
    cur.execute(
        "SELECT COALESCE(SUM(value),0) FROM derived_daily WHERE metric='mvpa_min' "
        "AND day<=%s AND day>%s",
        (day, day - timedelta(days=7)),
    )
    pa = _mvpa_to_pa_score(_scalar(cur))
    vo2 = _vo2max_jurca(age, prof["sex"], bmi, rhr_med, pa)
    _upsert_daily(
        cur,
        day,
        "vo2max_estimate",
        vo2,
        {
            "rhr_med": round(rhr_med, 1),
            "pa_score": pa,
            "bmi": round(bmi, 1),
            "age_years": age,
            "sex": prof["sex"],
            "see_ml_kg_min": _JURCA_SEE_ML_KG_MIN,
        },
    )
    return {"vo2max_estimate": round(vo2, 1)}
