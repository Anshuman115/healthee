"""Biological-age estimate (Gompertz hazard → years) — v2-native reads.

A DOCUMENTED exception to the no-composite rule: admissible only because the
conversion is published actuarial math, every input hazard ratio is
meta-analytic, and it is framed as a motivational estimate with a per-term
breakdown. See [[biological_age_estimate]].

The Gompertz coefficients, VO₂max medians, and hazard-ratio math are ported
verbatim from legacy ``biological_age.py``. The seam fix is every read: the
latest VO₂max, the 14-night average TST (from the ``sleep_health_score_4dim``
flags), and the latest SRI all come from ``derived_daily`` instead of the
``metric_sample`` view filtered on ``source='derived'``.
"""

from __future__ import annotations

import math
from datetime import datetime
from zoneinfo import ZoneInfo

from psycopg import Cursor
from psycopg.rows import TupleRow

USER_TZ = ZoneInfo("Asia/Kolkata")

# Age/sex population-median VO₂max (ml/kg/min), 10-year buckets.
_VO2MAX_MEDIAN_MALE = {20: 44.0, 30: 41.0, 40: 38.0, 50: 33.0, 60: 28.0, 70: 24.0}
_VO2MAX_MEDIAN_FEMALE = {20: 36.0, 30: 33.0, 40: 30.0, 50: 26.0, 60: 22.0, 70: 19.0}

GOMPERTZ_MRDT_YEARS = 7.7  # UK Biobank mortality-rate doubling time
TERM_CAP_YEARS = 10.0  # no single noisy input can move age more than ±10 y

Cur = Cursor[TupleRow]


def vo2max_median_for(age: int, sex: str) -> float:
    """Population-median VO₂max for the age bucket (clamped to 20–70)."""
    table = _VO2MAX_MEDIAN_FEMALE if sex == "female" else _VO2MAX_MEDIAN_MALE
    return table[max(20, min(70, (age // 10) * 10))]


def compute_biological_age(cur: Cur) -> dict | None:
    """Gompertz hazard→years over one combined fitness term (VO₂max) + sleep
    duration + SRI. Returns chronological/biological age + signed per-term year
    contributions (+ = older, − = younger), or None without a profile/inputs."""
    cur.execute("SELECT dob, sex FROM profile WHERE id=1")
    p = cur.fetchone()
    if not p or not p[0]:
        return None
    dob, sex = p[0], (p[1] or "male")
    today = datetime.now(tz=USER_TZ).date()
    chrono = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))

    b = math.log(2) / GOMPERTZ_MRDT_YEARS
    contribs: list[dict] = []

    def add(term: str, hr: float, value=None, unit=None, target=None) -> float:
        d = max(-TERM_CAP_YEARS, min(TERM_CAP_YEARS, math.log(hr) / b))
        contribs.append(
            {
                "term": term,
                "delta_years": round(d, 1),
                "hr": round(hr, 3),
                "value": value,
                "unit": unit,
                "target": target,
            }
        )
        return d

    dage = _fitness_term(cur, chrono, sex, add)
    dage += _sleep_duration_term(cur, add)
    dage += _regularity_term(cur, add)

    if not contribs:
        return None
    return {
        "chronological_age": chrono,
        "biological_age": round(chrono + dage, 1),
        "delta_years": round(dage, 1),
        "contributions": contribs,
        "disclaimer": (
            "Motivational estimate from population data — not a clinical or diagnostic age."
        ),
        "research_notes": ["biological_age_estimate"],
    }


def _fitness_term(cur: Cur, chrono: int, sex: str, add) -> float:
    """VO₂max vs age/sex median — the one combined cardio term (0.85 per 3.5 ml)."""
    cur.execute(
        "SELECT value FROM derived_daily WHERE metric='vo2max_estimate' ORDER BY day DESC LIMIT 1"
    )
    vr = cur.fetchone()
    if not vr:
        return 0.0
    ref = vo2max_median_for(chrono, sex)
    if not ref:
        return 0.0
    return add(
        "fitness",
        0.85 ** ((float(vr[0]) - ref) / 3.5),
        value=round(float(vr[0]), 1),
        unit="ml/kg/min VO₂max",
        target=round(ref),
    )


def _sleep_duration_term(cur: Cur, add) -> float:
    """Recent 14-night average TST, U-shaped about a 7 h reference."""
    cur.execute(
        "SELECT avg((flags->>'tst_min')::float) FROM derived_daily "
        "WHERE metric='sleep_health_score_4dim' AND flags ? 'tst_min' "
        "AND day >= (current_date - 14)"
    )
    sr = cur.fetchone()
    if not sr or not sr[0]:
        return 0.0
    h = float(sr[0]) / 60.0
    return add(
        "sleep duration",
        (1.06 ** (7 - h)) if h < 7 else (1.13 ** (h - 7)),
        value=round(h, 1),
        unit="h/night",
        target="7–9",
    )


def _regularity_term(cur: Cur, add) -> float:
    """SRI — log-linear through Cribb 2023 anchors (41 → 1.53, 75 → 0.90)."""
    cur.execute(
        "SELECT value FROM derived_daily WHERE metric='sleep_regularity_index' "
        "ORDER BY day DESC LIMIT 1"
    )
    qr = cur.fetchone()
    if not qr:
        return 0.0
    ln_hr = max(math.log(0.90), min(math.log(1.53), 0.425 - 0.0156 * (float(qr[0]) - 41)))
    return add("regularity", math.exp(ln_hr), value=round(float(qr[0])), unit="SRI", target="≥75")
