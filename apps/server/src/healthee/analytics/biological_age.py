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

## EVERY term is required, because a missing term is a claim (2026-07-31)

Each ``_*_term`` read "the newest row" of its input, which is not the same claim as
"today's value". ``derive/vo2max.py`` WITHHOLDS the Jurca estimate — writes no row — on a
day its inputs cannot carry it; ``derive/sleep_score.py`` withholds an SRI whose 7-day
window is short (Directive 4 of [[sleep_regularity_index]]: "Do not compute or report SRI
from <7 days of data"). So one ``/api/today`` payload could say "we cannot tell you your
VO₂max today" in the fitness card and, three keys away, spend a 40-day-old VO₂max as a
current term of a headline number — and could spend a 90-day-old SRI, which is a valid
statement about a week three months ago, as this week's regularity.

The fix is NOT a label. The composite is ``chrono + Σ ΔAge_i``, so a term that is simply
left out is not an omission — it is the assertion ``HR_term = 1.0``, i.e. *this person
sits exactly on the reference for that lever*. That is a claim about them, and silently
making it moves the number by years on a day when nothing about the person changed. A
composite that shifts because a term vanished is a different composite, not a partial one.

**So all three terms are required**, and the rule is the note's own Stage-1 coach
directive: "hold the number back ... until the VO₂max estimate and ≥14 nights of sleep
exist". Without a current input for any term — withheld, never derived, or no recorded
nights in the window — ``biological_age`` and ``delta_years`` are ``null``,
``data_confidence`` is ``insufficient_data`` (the outcome ledger's vocabulary, as in
``read/vo2max.py``), and ``withheld.terms`` names EVERY absent term with its reason and
what it would take. The terms that ARE current still ship in ``contributions``: each one is
a standalone hazard→years fact from the note's table, and deleting them would withhold
things we genuinely know.

**Why regularity too, and not just fitness** (the question the first pass left open).
Fitness earned "required" partly because the note calls it *dominant*, but dominance is
why the composite is SENSITIVE to it — it is not why the omission is a lie. The omission
is a lie at any size, and regularity's is not small: the Cribb anchors put its term
between −1.2 y (SRI 75) and +4.7 y (SRI 41), and dropping it asserts SRI ≈ 68, the
neutral point of that log-linear. For an irregular sleeper that silently subtracts nearly
five years. Sleep duration is required by the identical argument (its absence asserts
7 h/night), so the rule is stated once over all terms rather than per-term — a per-term
policy is exactly the fork that produces a second definition (CLAUDE.md), and "which
terms are important enough" is the question that produced the uncited ``IDEAL["sri"]``.

ONE rule also covers both ways an input can be absent — stale and never derived — because
"the composite silently assumes the reference" is the same defect either way.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date
from uuid import UUID

from psycopg import Cursor
from psycopg.rows import TupleRow

from healthee.core.tenancy import USER_TODAY_SQL, user_today
from healthee.derive.freshness import NO_NIGHTS_IN_WINDOW, NOT_DERIVED_YET
from healthee.derive.sleep_score import SRI_MESSAGES, sri_unavailable_reason
from healthee.derive.vo2max import WITHHOLD_MESSAGES, estimate_unavailable_reason

# Age/sex population-median VO₂max (ml/kg/min), 10-year buckets.
_VO2MAX_MEDIAN_MALE = {20: 44.0, 30: 41.0, 40: 38.0, 50: 33.0, 60: 28.0, 70: 24.0}
_VO2MAX_MEDIAN_FEMALE = {20: 36.0, 30: 33.0, 40: 30.0, 50: 26.0, 60: 22.0, 70: 19.0}

# UK Biobank mortality-rate doubling time, both sexes — Libert 2025, eLife 13:RP92092
# (PMID 40497443) [biological_age_estimate]. Classical Gompertz is ~8 y; the difference
# is ~4% of ΔAge (11.1 vs 11.55 years per ln unit of hazard).
GOMPERTZ_MRDT_YEARS = 7.7
TERM_CAP_YEARS = 10.0  # no single noisy input can move age more than ±10 y

# The three terms of [[biological_age_estimate]]'s table. The composite is defined over
# all of them, so it cannot be computed without all of them — see the module docstring.
FITNESS_TERM = "fitness"
SLEEP_DURATION_TERM = "sleep duration"
REGULARITY_TERM = "regularity"

# Why the whole estimate goes with any absent term, in the second person. The per-term
# reason and its "here is what we'd need" message are the INPUT metric's own, reused
# verbatim from ``derive/vo2max.WITHHOLD_MESSAGES`` / ``derive/sleep_score.SRI_MESSAGES``
# so two surfaces cannot explain the same absence differently.
REQUIRED_TERMS_MESSAGE = (
    "Biological age is your chronological age plus each term's year contribution, so a "
    "term with no current value is not left out — it would silently assert you sit exactly "
    "at the reference for that lever. There is no biological age to report without all of "
    "them. The terms below are the ones that are current."
)

# The 14-night average TST has one way to be absent: nothing recorded in the window. It
# is a WINDOWED aggregate, so it cannot go stale the way a single latest row can — the
# query is already anchored to the owner's today. It can still be MISSING, and missing is
# the same assertion (``HR = 1.0``, i.e. 7 h/night) that staleness was.
SLEEP_DURATION_MESSAGES = {
    NO_NIGHTS_IN_WINDOW: (
        "No sleep has been recorded in the last 14 nights, so there is no nightly average "
        "to work from — wear the strap overnight and this comes back."
    )
}

Cur = Cursor[TupleRow]


@dataclass(frozen=True)
class _Absent:
    """A required term the owner has no CURRENT input for, and why.

    ``reason`` is the input metric's own machine-readable id (``derive/freshness.py``'s
    shared ids plus that metric's own gates) and ``message`` is that metric's second-person
    "here is what we'd need" — never re-worded here, so the biological age and the input's
    own card explain one absence with one sentence.
    """

    term: str
    reason: str
    message: str


def _absent(term: str, reason: str | None, messages: dict[str, str]) -> _Absent:
    """One absent term. ``reason is None`` cannot happen for an absent term (the freshness
    rule always names one), so the fallback is defensive rather than a second meaning."""
    named = reason or NOT_DERIVED_YET
    return _Absent(term, named, messages[named])


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
    ``withheld`` block naming every absent term — when any term has no CURRENT input,
    because every term is required (module docstring)."""
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

    dage, absent = 0.0, []
    for delta, missing in (
        _fitness_term(cur, user_id, tz, today, chrono, sex, add),
        _sleep_duration_term(cur, user_id, tz, add),
        _regularity_term(cur, user_id, tz, today, add),
    ):
        dage += delta
        if missing is not None:
            absent.append(missing)

    if not contribs:
        return None
    return _estimate(chrono, dage, contribs, absent)


def _estimate(chrono: int, dage: float, contribs: list[dict], absent: list[_Absent]) -> dict:
    """The payload — the composite only when EVERY term is current.

    When any term is absent the number is not computed at all rather than computed and
    flagged, because a flagged wrong number is still a wrong number the UI can render as
    the hero. ``withheld.terms`` is a list because more than one term can be absent at
    once, and naming only the first would hide half the reason."""
    withheld = bool(absent)
    return {
        "chronological_age": chrono,
        "biological_age": None if withheld else round(chrono + dage, 1),
        "delta_years": None if withheld else round(dage, 1),
        "data_confidence": "insufficient_data" if withheld else "ok",
        "withheld": None
        if not absent
        else {
            "consequence": REQUIRED_TERMS_MESSAGE,
            "terms": [{"term": a.term, "reason": a.reason, "message": a.message} for a in absent],
        },
        "contributions": contribs,
        "disclaimer": (
            "Motivational estimate from population data — not a clinical or diagnostic age."
        ),
        "research_notes": ["biological_age_estimate"],
    }


def _fitness_term(
    cur: Cur, user_id: UUID, tz: str, today: date, chrono: int, sex: str, add
) -> tuple[float, _Absent | None]:
    """VO₂max vs age/sex median — the one combined cardio term (0.85 per 3.5 ml).

    Returns ``(delta_years, None)`` when TODAY has an estimate, else ``(0.0, absent)``.
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
        return 0.0, _absent(FITNESS_TERM, reason, WITHHOLD_MESSAGES)
    ref = vo2max_median_for(chrono, sex)
    delta = add(
        FITNESS_TERM,
        0.85 ** ((float(vr[1]) - ref) / 3.5),
        value=round(float(vr[1]), 1),
        unit="ml/kg/min VO₂max",
        target=round(ref),
    )
    return delta, None


def _sleep_duration_term(cur: Cur, user_id: UUID, tz: str, add) -> tuple[float, _Absent | None]:
    """Recent 14-night average TST, U-shaped about a 7 h reference.

    The window is already anchored to the owner's today, so this term cannot go STALE —
    only empty. Empty is still the ``HR = 1.0`` assertion ("you average 7 h/night"), so it
    withholds the composite exactly as a stale term does: one rule, three terms."""
    cur.execute(
        "SELECT avg((flags->>'tst_min')::float) FROM derived_daily "
        "WHERE user_id = %s AND metric='sleep_health_score_4dim' AND flags ? 'tst_min' "
        f"AND day >= ({USER_TODAY_SQL} - 14)",
        (user_id, tz),
    )
    sr = cur.fetchone()
    if not sr or not sr[0]:
        return 0.0, _absent(SLEEP_DURATION_TERM, NO_NIGHTS_IN_WINDOW, SLEEP_DURATION_MESSAGES)
    h = float(sr[0]) / 60.0
    # 🔴 THE LABEL AND THE MATH DISAGREE, found 2026-08-01 (#88) — not fixed here.
    # The hazard is a SINGLE-POINT nadir at 7 h (Yin 2017's dose-response), so 8 h is
    # penalised 1.13x and 9 h is penalised 1.28x. The card meanwhile tells the user the
    # target is "7–9", i.e. that 9 h is on target while the model is charging them a
    # third of a hazard unit for it. One of the two is wrong and choosing which is a
    # science decision, not a typo: either this term adopts the NSF 7–9 band (changing
    # every owner's biological age) or the label becomes "7" (changing what the card
    # says). Both are behaviour changes owed their own PR with known-value tests
    # (CLAUDE.md). Recorded rather than quietly patched — see the same discipline at
    # ``_regularity_term`` below. This is a third numeric definition of "optimal sleep
    # duration" in one product, which is exactly what the canonical-metric rule forbids.
    return add(
        SLEEP_DURATION_TERM,
        (1.06 ** (7 - h)) if h < 7 else (1.13 ** (h - 7)),
        value=round(h, 1),
        unit="h/night",
        target="7–9",
    ), None


def _regularity_term(
    cur: Cur, user_id: UUID, tz: str, today: date, add
) -> tuple[float, _Absent | None]:
    """SRI — log-linear through Cribb 2023 anchors (41 → 1.53, 75 → 0.90).

    🔴 KNOWN WRONG NUMBER, measured 2026-08-01 (#83c) — do not "tune" it here.
    Cribb's anchors are on Cribb's SRI scale (its cohort median is 60); OUR SRI is on
    Windred's scale (median 81.0), which ``tests/derive/test_sri_scale.py`` establishes
    by driving ``_compute_sri`` over seeded sessions and recovering Windred's own
    published quintile boundaries from Windred's own behavioural description of them.
    Interpolating one scale's anchors against the other's values leaves this term's
    ZERO at SRI 68.24 — which on our estimator is a sleeper moving bed and wake time
    ~1.9 h at EACH end every night, worse than Windred's least-regular quintile. So the
    penalty half is unreachable: every realistic owner gets an age-REDUCING
    contribution, and anyone at SRI ≥ 75 is clamped to the maximum credit. The product
    that promises never to flatter is, in this one term, flattering everybody by
    roughly 2.5–3.5 years.

    It is left as-is deliberately. Re-anchoring is a behaviour change in science code,
    which CLAUDE.md makes its own PR with known-value tests, and the honest fix needs
    our real SRI distribution measured on owner data — not a constant nudged until the
    output looks right. Full write-up, with magnitudes and what was and was not
    measured: [[biological_age_estimate]] §Caveats.

    This query did not even SELECT the day before the class fix: the newest SRI row was
    spent as the owner's current regularity however old it was, though an SRI *is* a
    7-day window and a 90-day-old one describes a week 90 days ago. The freshness rule is
    ``derive.sleep_score.sri_unavailable_reason`` — the same one ``/api/sleep/consistency``
    applies — so the regularity card and this term cannot disagree."""
    cur.execute(
        "SELECT day, value FROM derived_daily WHERE user_id = %s "
        "AND metric='sleep_regularity_index' ORDER BY day DESC LIMIT 1",
        (user_id,),
    )
    qr = cur.fetchone()
    reason = sri_unavailable_reason(cur, user_id, tz, today, qr[0] if qr else None)
    if qr is None or reason is not None:
        return 0.0, _absent(REGULARITY_TERM, reason, SRI_MESSAGES)
    sri = float(qr[1])
    ln_hr = max(math.log(0.90), min(math.log(1.53), 0.425 - 0.0156 * (sri - 41)))
    return add(REGULARITY_TERM, math.exp(ln_hr), value=round(sri), unit="SRI", target="≥75"), None
