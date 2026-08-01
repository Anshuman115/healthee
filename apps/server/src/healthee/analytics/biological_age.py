"""Biological-age estimate (Gompertz hazard → years) — v2-native reads.

A DOCUMENTED exception to the no-composite rule: admissible only because the
conversion is published actuarial math, every input hazard ratio is
meta-analytic, and it is framed as a motivational estimate with a per-term
breakdown. See [[biological_age_estimate]].

The Gompertz coefficients, VO₂max medians, and hazard-ratio math are ported
verbatim from legacy ``biological_age.py``. The seam fix is every read: the
latest VO₂max and the 14-night average TST (from the ``sleep_health_score_4dim``
flags) both come from ``derived_daily`` instead of the ``metric_sample`` view
filtered on ``source='derived'``.

## EVERY term is required, because a missing term is a claim (2026-07-31)

Each ``_*_term`` read "the newest row" of its input, which is not the same claim as
"today's value". ``derive/vo2max.py`` WITHHOLDS the Jurca estimate — writes no row — on a
day its inputs cannot carry it. So one ``/api/today`` payload could say "we cannot tell
you your VO₂max today" in the fitness card and, three keys away, spend a 40-day-old
VO₂max as a current term of a headline number.

The fix is NOT a label. The composite is ``chrono + Σ ΔAge_i``, so a term that is simply
left out is not an omission — it is the assertion ``HR_term = 1.0``, i.e. *this person
sits exactly on the reference for that lever*. That is a claim about them, and silently
making it moves the number by years on a day when nothing about the person changed. A
composite that shifts because a term vanished is a different composite, not a partial one.

**So every term of the definition is required**, and the rule is the note's own Stage-1
coach directive: "hold the number back ... until the VO₂max estimate and ≥14 nights of
sleep exist". Without a current input for any term — withheld, never derived, or no
recorded nights in the window — ``biological_age`` and ``delta_years`` are ``null``,
``data_confidence`` is ``insufficient_data`` (the outcome ledger's vocabulary, as in
``read/vo2max.py``), and ``withheld.terms`` names EVERY absent term with its reason and
what it would take. The terms that ARE current still ship in ``contributions``: each one is
a standalone hazard→years fact from the note's table, and deleting them would withhold
things we genuinely know.

The rule is stated once over all terms rather than per-term — a per-term policy is exactly
the fork that produces a second definition (CLAUDE.md), and "which terms are important
enough" is the question that produced the uncited ``IDEAL["sri"]``. It also covers both
ways an input can be absent — stale and never derived — because "the composite silently
assumes the reference" is the same defect either way.

## Sleep regularity is NOT a term, and never silently (2026-08-01, #86)

Between 2026-07-31 and this change the definition had a THIRD term: SRI, log-interpolated
through Cribb 2023's hazard anchors (41 → 1.53, 75 → 0.90). Those anchors are on Cribb's
SRI scale — a pipeline whose UK Biobank median is 60 — and ours is not
(``tests/derive/test_sri_scale.py``). Re-anchoring was the obvious repair and it is the
one we refused, on primary-source evidence:

- **Czeisler et al. 2026** (*Sleep* 49(4):zsaf299, PMID 41001850) scored >70 000 UK
  Biobank adults with BOTH standard SRI calculators and reports that the scores
  *"differed markedly, both in absolute and relative values"*, and that applied to
  prospective models including all-cause mortality *"the method of calculation alone
  meaningfully changed results and interpretations."* Its editorial (Cedernaes et al.,
  *Sleep* 49(4):zsaf289) gives the size: *"only two-fifths of participants were classified
  into the same sleep regularity index quintile"*, and under one calculator the most
  irregular sleepers had *"a 1.19-fold higher adjusted hazard of death"* while *"no
  significant association was observed when the same data were analyzed using GGIR."*
- So an SRI→mortality hazard is a property of the SCORING PIPELINE, not of the index. Ours
  is a third pipeline again (strap hypnogram, global Phillips, night-only by documented
  design) and has never been run against any outcome cohort.
- Windred 2024 does publish quintile hazards on a scale close to ours, but they are
  quintile MEMBERSHIP contrasts, and quintile membership is precisely the quantity
  Czeisler measured as non-transportable. It publishes no continuous per-point hazard.

Unlike ml/kg/min and hours, an SRI point has no physical unit to carry a dose-response
across pipelines. So the honest number of years regularity contributes here is *none we
can compute*, and the estimate is now defined over fitness and sleep duration only.

That absence is published, not silent: ``excluded`` is a permanent key of the payload
naming the term and why. It is deliberately NOT ``withheld`` — withheld means "you could
have this, here is what to do", and no owner action brings this one back.
[[biological_age_estimate]], [[sleep_regularity_index]].

## Both surviving terms had the same defect, one degree milder (2026-08-01, #97)

#86 removed a term whose ANCHOR did not transport. An audit of the two that remained
found both anchored on something other than what they are compared against:

- **Sleep duration** applied Yin 2017's curve, measured on *questionnaire* hours, to a
  *device-measured* nightly average. Fixed: the average is converted to its
  questionnaire equivalent first, through a gap Lauderdale 2008 measured
  (``analytics/reference_scales.py``). For a short sleeper this was worth roughly half
  a year of penalty that was never earned.
- **Fitness** compared the VO₂max estimate to a "population median" that cited nothing.
  #97 left it standing rather than guess at a replacement and published its footing
  instead. **#101 sourced it** — every cell replaced at once from one published row,
  FRIEND's treadmill 50th percentile (``analytics/reference_scales.py``).

The difference from #86 is the reason both survived: their anchors were
wrong-but-bounded (≈0.5 y and ≈2 y respectively, inside the note's own "±a few years is
noise"), and the SIGN of each term is robust to the whole plausible range of anchors. The
SRI term's sign was not — it credited 36 days and penalised 35 of the same owner's 71. A
bounded bias that is disclosed is a different object from a coin flip presented as a
measurement.

**But #97's stated DIRECTION for the fitness term was wrong, and only reading the whole
table showed it.** Four cells were checkable in an abstract, three read low, and the
caveat told owners the term flattered them. Against the full published row, ten of the
twelve old cells were HIGH — the term penalised nearly everyone, worst by ~2.4 y. A
partial check is a sample, and a sample's sign does not have to hold. This is why the
repair was "the whole row from one paper" and not "correct the cells we could see".

``caveats`` is where that disclosure lives: a permanent payload key, one entry per term
that is *computed but known to lean*, naming which way. It is a third state, and the
three are not interchangeable — ``withheld`` = you can fix this, ``excluded`` = nobody
can, ``caveats`` = we are telling you this anyway, and here is its tilt.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date
from uuid import UUID

from psycopg import Cursor
from psycopg.rows import TupleRow

from healthee.analytics.reference_scales import (
    ANCHOR_CAVEATS,
    SLEEP_DURATION_SELF_REPORT_SCALE,
    VO2MAX_REFERENCE_CLINICAL_COHORT,
    self_reported_equivalent_h,
    vo2max_median_for,
)
from healthee.core.tenancy import USER_TODAY_SQL, user_today
from healthee.derive.freshness import NO_NIGHTS_IN_WINDOW, NOT_DERIVED_YET
from healthee.derive.vo2max import WITHHOLD_MESSAGES, estimate_unavailable_reason

# UK Biobank mortality-rate doubling time, both sexes — Libert 2025, eLife 13:RP92092
# (PMID 40497443) [biological_age_estimate]. Classical Gompertz is ~8 y; the difference
# is ~4% of ΔAge (11.1 vs 11.55 years per ln unit of hazard).
GOMPERTZ_MRDT_YEARS = 7.7
TERM_CAP_YEARS = 10.0  # no single noisy input can move age more than ±10 y

# Yin 2017's all-cause-mortality dose-response (JAHA 6(9):e005947) [biological_age_estimate].
# The nadir is a single point, not a band — see ``_sleep_duration_term``. Both slopes are
# per hour of SELF-REPORTED sleep, which is why the term converts before it applies them.
SLEEP_HAZARD_NADIR_H = 7.0
SHORT_SLEEP_HR_PER_H = 1.06  # per hour below the nadir
LONG_SLEEP_HR_PER_H = 1.13  # per hour above it

# The terms of [[biological_age_estimate]]'s table. The composite is defined over all of
# them, so it cannot be computed without all of them — see the module docstring.
FITNESS_TERM = "fitness"
SLEEP_DURATION_TERM = "sleep duration"

# Not a term — the lever this estimate deliberately does not price, stated in the payload
# so "biological age" cannot quietly change meaning between releases (#86). The reason id
# says WHOSE fault the absence is: not the owner's data, the literature's units.
REGULARITY_TERM = "regularity"
SRI_HAZARD_NOT_TRANSPORTABLE = "sri_hazard_not_transportable"
EXCLUDED_TERMS = [
    {
        "term": REGULARITY_TERM,
        "reason": SRI_HAZARD_NOT_TRANSPORTABLE,
        "message": (
            "Sleep regularity is not one of the levers behind this number. Scored on the "
            "same 70,000 people, the two standard Sleep Regularity Index calculators put "
            "only two in five into the same fifth of the population, and one found a "
            "mortality association where the other found none — so the published "
            "risk-per-SRI-point belongs to the software, not to the index. Yours is "
            "measured a third way again. You still get your regularity score and its "
            "one-hour-band target on the sleep page; what we cannot honestly do is "
            "convert it into years."
        ),
    }
]

# The third state (#97): a term that IS priced, and leans. Permanent and owner-independent
# like ``excluded`` — these are properties of the definition, not of anyone's data — but
# unlike ``excluded`` the term is still in the number, so the honest thing is to say which
# way it tilts. ``direction`` is machine-readable because "does this flatter me?" is the
# one question this product exists to answer without being asked.
# The footing statements themselves live with the anchors they describe, in
# ``reference_scales``; this module owns only which term each one attaches to.
CAVEAT_TERMS = [
    {"term": FITNESS_TERM, **ANCHOR_CAVEATS[VO2MAX_REFERENCE_CLINICAL_COHORT]},
    {"term": SLEEP_DURATION_TERM, **ANCHOR_CAVEATS[SLEEP_DURATION_SELF_REPORT_SCALE]},
]

# Why the whole estimate goes with any absent term, in the second person. The per-term
# reason and its "here is what we'd need" message are the INPUT metric's own, reused
# verbatim from ``derive/vo2max.WITHHOLD_MESSAGES``, so two surfaces cannot explain the
# same absence differently.
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
    """Gompertz hazard→years over one combined fitness term (VO₂max) + sleep duration.
    Returns chronological/biological age + signed per-term year contributions
    (+ = older, − = younger), or None without a profile/inputs.

    The composite is withheld — ``biological_age``/``delta_years`` null, with a
    ``withheld`` block naming every absent term — when any term has no CURRENT input,
    because every term is required (module docstring).

    Sleep regularity is NOT among the terms and never reaches this function: there is no
    transportable SRI→hazard conversion for our scoring pipeline (module docstring, #86).
    The payload says so in ``excluded`` rather than leaving the reader to notice."""
    cur.execute("SELECT dob, sex FROM profile WHERE user_id = %s", (user_id,))
    p = cur.fetchone()
    if not p or not p[0]:
        return None
    dob, sex = p[0], (p[1] or "male")
    today = user_today(tz)
    chrono = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))

    contribs: list[dict] = []

    def add(term: str, hr: float, value=None, unit=None, target=None, compared_as=None) -> float:
        """``compared_as`` is the value the hazard curve was actually read at, when that
        is not ``value`` — the sleep term's questionnaire equivalent (#97). Present and
        null on terms where the two are the same, so the shape never varies by term."""
        d = hazard_delta_years(hr)
        contribs.append(
            {
                "term": term,
                "delta_years": round(d, 1),
                "hr": round(hr, 3),
                "value": value,
                "unit": unit,
                "target": target,
                "compared_as": compared_as,
            }
        )
        return d

    dage, absent = 0.0, []
    for delta, missing in (
        _fitness_term(cur, user_id, tz, today, chrono, sex, add),
        _sleep_duration_term(cur, user_id, tz, add),
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
        # Permanent, owner-independent, and NOT part of `withheld`: an excluded term is a
        # limit of the evidence, not a gap in this owner's data, so it must not read as
        # something syncing more would fix. A list because a second exclusion later must
        # not change the shape of the payload.
        "excluded": EXCLUDED_TERMS,
        # Permanent too, and the third state: priced, but leaning. See the module
        # docstring — the three absence/uncertainty keys are not interchangeable.
        "caveats": CAVEAT_TERMS,
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
    """Recent 14-night average TST, U-shaped about Yin 2017's 7 h nadir.

    The window is already anchored to the owner's today, so this term cannot go STALE —
    only empty. Empty is still the ``HR = 1.0`` assertion ("you average 7 h/night"), so it
    withholds the composite exactly as a stale term does: one rule, three terms.

    The strap's average is read at its QUESTIONNAIRE equivalent, because Yin's exposure is
    self-reported and self-report runs long (#97, ``analytics/reference_scales.py``)."""
    cur.execute(
        "SELECT avg((flags->>'tst_min')::float) FROM derived_daily "
        "WHERE user_id = %s AND metric='sleep_health_score_4dim' AND flags ? 'tst_min' "
        f"AND day >= ({USER_TODAY_SQL} - 14)",
        (user_id, tz),
    )
    sr = cur.fetchone()
    if not sr or not sr[0]:
        return 0.0, _absent(SLEEP_DURATION_TERM, NO_NIGHTS_IN_WINDOW, SLEEP_DURATION_MESSAGES)
    measured_h = float(sr[0]) / 60.0
    # The curve is read at the questionnaire equivalent, never at the raw device hours.
    h = self_reported_equivalent_h(measured_h)
    # The label now says what the maths does (#88 found it saying "7–9" while charging
    # 1.13× at 8 h and 1.28× at 9 h — telling the owner 9 h was on target while pricing
    # it as risk). ``SLEEP_HAZARD_NADIR_H`` is Yin's dose-response turning point, NOT a
    # recommended band: the recommendation stays NSF 2015's 7–9 h, cited by the sleep
    # surfaces. Two different quantities, one definition each — which is the canonical-
    # metric rule satisfied, not a third number added.
    return add(
        SLEEP_DURATION_TERM,
        (SHORT_SLEEP_HR_PER_H ** (SLEEP_HAZARD_NADIR_H - h))
        if h < SLEEP_HAZARD_NADIR_H
        else (LONG_SLEEP_HR_PER_H ** (h - SLEEP_HAZARD_NADIR_H)),
        value=round(measured_h, 1),
        unit="h/night",
        target=SLEEP_HAZARD_NADIR_H,
        compared_as=round(h, 1),
    ), None
