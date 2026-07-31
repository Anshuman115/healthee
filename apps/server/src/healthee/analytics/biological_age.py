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

## No CURRENT fitness input ⇒ no biological age (2026-07-31)

``_fitness_term`` read ``vo2max_estimate`` as "the newest row", which is not the same
claim as "today's estimate". ``derive/vo2max.py`` WITHHOLDS the Jurca estimate — writes
no row — on a day its inputs cannot carry it, and ``read/vo2max.py`` reports that as
``insufficient_data``. So one ``/api/today`` payload could say "we cannot tell you your
VO₂max today" in the fitness card and, three keys away, spend a 40-day-old VO₂max as a
current term of a headline number.

The fix is NOT a label. The composite is ``chrono + Σ ΔAge_i``, so a term that is simply
left out is not an omission — it is the assertion ``HR_fitness = 1.0``, i.e. *this person
sits exactly on the age/sex-median VO₂max*. That is a claim about them, it is the one the
note calls **dominant** ("VO₂max is the dominant term ... AND the least certain input —
so bio_age is sensitive to it"), and silently making it would move the number by years on
a day when nothing about the person changed. A composite that shifts because a term
vanished is a different composite, not a partial one.

So the fitness term is REQUIRED, and the rule is the note's own Stage-1 coach directive:
"hold the number back ... until the VO₂max estimate ... exist[s]". Without a VO₂max for
the owner's today — withheld, or never derived — ``biological_age`` and ``delta_years``
are ``null``, ``data_confidence`` is ``insufficient_data`` (the outcome ledger's
vocabulary, as in ``read/vo2max.py``), and a ``withheld`` block names the reason and what
it would take. The terms that ARE current still ship in ``contributions``: each one is a
standalone hazard→years fact from the note's table, and deleting them would withhold
things we genuinely know.

ONE rule covers both ways the input can be absent — withheld today and never derived at
all — because "the composite silently assumes median fitness" is the same defect either
way, and two treatments of one state is how a second definition gets in (CLAUDE.md).
"""

from __future__ import annotations

import math
from datetime import date
from uuid import UUID

from psycopg import Cursor
from psycopg.rows import TupleRow

from healthee.core.tenancy import USER_TODAY_SQL, user_today
from healthee.derive.vo2max import WITHHOLD_MESSAGES, estimate_unavailable_reason

# Age/sex population-median VO₂max (ml/kg/min), 10-year buckets.
_VO2MAX_MEDIAN_MALE = {20: 44.0, 30: 41.0, 40: 38.0, 50: 33.0, 60: 28.0, 70: 24.0}
_VO2MAX_MEDIAN_FEMALE = {20: 36.0, 30: 33.0, 40: 30.0, 50: 26.0, 60: 22.0, 70: 19.0}

GOMPERTZ_MRDT_YEARS = 7.7  # UK Biobank mortality-rate doubling time
TERM_CAP_YEARS = 10.0  # no single noisy input can move age more than ±10 y

# The term the composite cannot be computed without — see the module docstring.
FITNESS_TERM = "fitness"

# Why the whole estimate goes with the fitness term, in the second person. The reason
# itself (and its "here is what we'd need" message) is VO₂max's, reused verbatim from
# ``derive/vo2max.WITHHOLD_MESSAGES`` so the two surfaces cannot explain the same
# absence differently.
FITNESS_REQUIRED_MESSAGE = (
    "Fitness is the largest term in this estimate, so without today's VO₂max there is no "
    "biological age to report. The terms below are still current."
)

Cur = Cursor[TupleRow]


def vo2max_median_for(age: int, sex: str) -> float:
    """Population-median VO₂max for the age bucket (clamped to 20–70)."""
    table = _VO2MAX_MEDIAN_FEMALE if sex == "female" else _VO2MAX_MEDIAN_MALE
    return table[max(20, min(70, (age // 10) * 10))]


def hazard_delta_years(hr: float) -> float:
    """Gompertz hazard→years: ΔAge = ln(HR) / b, where b = ln(2) / MRDT.

    The published actuarial conversion behind the estimate — a fixed proportional
    change in all-cause-mortality hazard maps to a fixed number of years, so a
    meta-analytic hazard ratio becomes an age shift. Capped at ±TERM_CAP_YEARS so
    one noisy input (VO₂max above all) cannot produce an alarming age.
    See [[biological_age_estimate]] ("Finding", "Effect size / sanity checks").
    """
    b = math.log(2) / GOMPERTZ_MRDT_YEARS
    return max(-TERM_CAP_YEARS, min(TERM_CAP_YEARS, math.log(hr) / b))


def compute_biological_age(cur: Cur, user_id: UUID, tz: str) -> dict | None:
    """Gompertz hazard→years over one combined fitness term (VO₂max) + sleep
    duration + SRI. Returns chronological/biological age + signed per-term year
    contributions (+ = older, − = younger), or None without a profile/inputs.

    The composite is withheld — ``biological_age``/``delta_years`` null, with a
    ``withheld`` block — when the owner has no VO₂max estimate for TODAY, because the
    fitness term is required (module docstring)."""
    cur.execute("SELECT dob, sex FROM profile WHERE user_id = %s", (user_id,))
    p = cur.fetchone()
    if not p or not p[0]:
        return None
    dob, sex = p[0], (p[1] or "male")
    today = user_today(tz)
    chrono = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))

    contribs: list[dict] = []

    def add(term: str, hr: float, value=None, unit=None, target=None) -> float:
        d = hazard_delta_years(hr)
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

    dage, no_fitness = _fitness_term(cur, user_id, tz, today, chrono, sex, add)
    dage += _sleep_duration_term(cur, user_id, tz, add)
    dage += _regularity_term(cur, user_id, add)

    if not contribs:
        return None
    return _estimate(chrono, dage, contribs, no_fitness)


def _estimate(chrono: int, dage: float, contribs: list[dict], no_fitness: str | None) -> dict:
    """The payload — the composite only when every required term is current.

    ``no_fitness`` is a VO₂max withhold reason (``derive/vo2max.py``'s vocabulary); when
    it is set the number is not computed at all rather than computed and flagged, because
    a flagged wrong number is still a wrong number the UI can render as the hero."""
    withheld = no_fitness is not None
    return {
        "chronological_age": chrono,
        "biological_age": None if withheld else round(chrono + dage, 1),
        "delta_years": None if withheld else round(dage, 1),
        "data_confidence": "insufficient_data" if withheld else "ok",
        "withheld": None
        if no_fitness is None
        else {
            "term": FITNESS_TERM,
            "reason": no_fitness,
            "message": WITHHOLD_MESSAGES[no_fitness],
            "consequence": FITNESS_REQUIRED_MESSAGE,
        },
        "contributions": contribs,
        "disclaimer": (
            "Motivational estimate from population data — not a clinical or diagnostic age."
        ),
        "research_notes": ["biological_age_estimate"],
    }


def _fitness_term(
    cur: Cur, user_id: UUID, tz: str, today: date, chrono: int, sex: str, add
) -> tuple[float, str | None]:
    """VO₂max vs age/sex median — the one combined cardio term (0.85 per 3.5 ml).

    Returns ``(delta_years, None)`` when TODAY has an estimate, else ``(0.0, reason)``.
    The freshness rule is ``derive.vo2max.estimate_unavailable_reason`` — the same one
    the VO₂max card applies — so the two surfaces of ``/api/today`` cannot disagree about
    whether this owner has a fitness number right now."""
    cur.execute(
        "SELECT day, value FROM derived_daily WHERE user_id = %s AND metric='vo2max_estimate' "
        "ORDER BY day DESC LIMIT 1",
        (user_id,),
    )
    vr = cur.fetchone()
    reason = estimate_unavailable_reason(cur, user_id, tz, today, vr[0] if vr else None)
    if vr is None or reason is not None:
        return 0.0, reason
    ref = vo2max_median_for(chrono, sex)
    delta = add(
        FITNESS_TERM,
        0.85 ** ((float(vr[1]) - ref) / 3.5),
        value=round(float(vr[1]), 1),
        unit="ml/kg/min VO₂max",
        target=round(ref),
    )
    return delta, None


def _sleep_duration_term(cur: Cur, user_id: UUID, tz: str, add) -> float:
    """Recent 14-night average TST, U-shaped about a 7 h reference."""
    cur.execute(
        "SELECT avg((flags->>'tst_min')::float) FROM derived_daily "
        "WHERE user_id = %s AND metric='sleep_health_score_4dim' AND flags ? 'tst_min' "
        f"AND day >= ({USER_TODAY_SQL} - 14)",
        (user_id, tz),
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


def _regularity_term(cur: Cur, user_id: UUID, add) -> float:
    """SRI — log-linear through Cribb 2023 anchors (41 → 1.53, 75 → 0.90)."""
    cur.execute(
        "SELECT value FROM derived_daily WHERE user_id = %s AND metric='sleep_regularity_index' "
        "ORDER BY day DESC LIMIT 1",
        (user_id,),
    )
    qr = cur.fetchone()
    if not qr:
        return 0.0
    ln_hr = max(math.log(0.90), min(math.log(1.53), 0.425 - 0.0156 * (float(qr[0]) - 41)))
    return add("regularity", math.exp(ln_hr), value=round(float(qr[0])), unit="SRI", target="≥75")
