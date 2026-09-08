"""Biological-age estimate (Gompertz hazard → years) — v2-native reads.

A DOCUMENTED exception to the no-composite rule: admissible only because the
conversion is published actuarial math, every input hazard ratio is
meta-analytic, and it is framed as a motivational estimate with a per-term
breakdown. See [[biological_age_estimate]].

The Gompertz coefficients and hazard-ratio math are ported verbatim from legacy
``biological_age.py``. The seam fix is every read: the latest VO₂max and the 14-night
average TST (from the ``sleep_health_score_4dim`` flags) both come from ``derived_daily``
instead of the ``metric_sample`` view filtered on ``source='derived'``.

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

The rule is stated once over all terms rather than per-term — a per-term policy is the
fork that produces a second definition (CLAUDE.md), and "which terms are important enough"
is the question that produced the uncited ``IDEAL["sri"]``. It covers both ways an input
can be absent, stale and never derived, because "the composite silently assumes the
reference" is the same defect either way.

## Sleep regularity is NOT a term, and never silently (2026-08-01, #86)

Between 2026-07-31 and this change the definition had a THIRD term: SRI, log-interpolated
through Cribb 2023's hazard anchors (41 → 1.53, 75 → 0.90). Those anchors are on Cribb's
SRI scale — a pipeline whose UK Biobank median is 60 — and ours is not
(``tests/derive/test_sri_scale.py``). Re-anchoring was the obvious repair and it is the
one we refused, on primary-source evidence:

- **Czeisler et al. 2026** (*Sleep* 49(4):zsaf299, PMID 41001850) scored >70 000 UK
  Biobank adults with BOTH standard SRI calculators: the scores *"differed markedly"*, and
  on all-cause mortality *"the method of calculation alone meaningfully changed results
  and interpretations."* Its editorial (*Sleep* 49(4):zsaf289) gives the size — *"only
  two-fifths of participants were classified into the same … quintile"*, a 1.19-fold
  hazard under one calculator against no significant association under the other.
- So an SRI→mortality hazard belongs to the SCORING PIPELINE, not the index. Ours is a
  third pipeline (strap hypnogram, night-only by design), never run against any cohort.
- Windred 2024's quintile hazards sit on a scale close to ours, but quintile MEMBERSHIP is
  precisely what Czeisler measured as non-transportable, and it publishes no per-point
  hazard.

Unlike ml/kg/min and hours, an SRI point has no physical unit to carry a dose-response
across pipelines. So the honest number of years regularity contributes here is *none we
can compute*, and the estimate is now defined over fitness and sleep duration only.

That absence is published, not silent: ``excluded`` is a permanent key of the payload
naming the term and why. It is deliberately NOT ``withheld`` — withheld means "you could
have this, here is what to do", and no owner action brings this one back.
[[biological_age_estimate]], [[sleep_regularity_index]].

## Both surviving terms had the same defect, one degree milder (2026-08-01, #97)

#86 removed a term whose ANCHOR did not transport. An audit of the two that remained
found both anchored on something other than what they are compared against. **Sleep
duration** applied Yin 2017's curve, measured on *questionnaire* hours, to a
*device-measured* average; it is now converted first, through a gap Lauderdale 2008
measured (``analytics/reference_scales.py``) — worth roughly half a year of penalty a
short sleeper never earned. **Fitness** compared the VO₂max estimate to a "population
median" that cited nothing; **#101 sourced it**, every cell at once from one published
row, FRIEND's treadmill 50th percentile.

The difference from #86 is the reason both survived: their anchors were
wrong-but-bounded (≈0.5 y and ≈2 y respectively, inside the note's own "±a few years is
noise"), and the SIGN of each term is robust to the whole plausible range of anchors. The
SRI term's sign was not — it credited 36 days and penalised 35 of the same owner's 71. A
bounded bias that is disclosed is a different object from a coin flip presented as a
measurement.

**But #97's stated DIRECTION for the fitness term was wrong, and only the whole table
showed it.** Four cells were checkable in an abstract, three read low, and the caveat told
owners the term flattered them; against the full row ten of twelve were HIGH — it
penalised nearly everyone, worst by ~2.4 y. A partial check is a sample, and a sample's
sign need not hold. Hence "the whole row from one paper", not "the cells we could see".

``caveats`` is where that disclosure lives: a permanent payload key, one entry per term
that is *computed but known to lean*, naming which way. It is a third state, and the
three are not interchangeable — ``withheld`` = you can fix this, ``excluded`` = nobody
can, ``caveats`` = we are telling you this anyway, and here is its tilt.

## The fitness term's INPUT, not its anchor (2026-08-02, #108)

#97/#101 fixed where the fitness hazard is measured FROM. The number on our side of that
comparison was itself part-invented: Jurca's fifth input is a self-reported activity
category, and we synthesised it from step cadence, which cannot tell deliberate exercise
from getting around. A self-described non-exerciser read 26.4 against a chronological 32.
The input is now asked (``derive/srpa.py``), the estimate withheld until answered, and
what the answer costs — 0.6-2.3 y a category — ships as a third ``caveats`` entry.

## The fitness term's INSTRUMENT (2026-08-02, #117)

#108 left this term reading ``vo2max_estimate``, which was Jurca and only Jurca. So on a
real owner it returned ``null`` — SR-PA unanswered, model withheld — on a fortnight when
two MEASURED VO₂max values sat in ``vo2max_submax``, unread by anything. The metric is now
tiered at the source (``derive/vo2max_tier.py``): graded GPS fit, then the %HRR reserve
inversion, then Jurca. Nothing about the hazard maths changes — 0.85 per MET against
FRIEND's median is the same claim whoever measured the MET — but two things do:

* the term's ``method`` says which instrument produced its input, because a fitness
  number that came from a run last week and a questionnaire this week is not the same
  measurement twice ([[hr_reserve_vo2max]] Directive 4); and
* the fitness ``caveats`` entry SWAPS with it. The self-reported-activity footing (#108)
  is a true statement about the Jurca model and a false one about a measured run, so
  shipping it regardless would have told an owner their measured fitness rested on a
  question they never answered. ``analytics/biological_age_terms.py`` owns that mapping.
"""

from __future__ import annotations

import math
from datetime import date
from uuid import UUID

from psycopg import Cursor
from psycopg.rows import TupleRow

from healthee.analytics.biological_age_terms import (
    EXCLUDED_TERMS,
    FITNESS_TERM,
    REQUIRED_TERMS_MESSAGE,
    SLEEP_DURATION_MESSAGES,
    SLEEP_DURATION_TERM,
    Absent,
    absent,
    caveat_terms,
)
from healthee.analytics.reference_scales import (
    self_reported_equivalent_h,
    vo2max_median_for,
)
from healthee.core.tenancy import AS_OF_DAY_SQL, reference_day
from healthee.derive.freshness import NO_NIGHTS_IN_WINDOW
from healthee.derive.vo2max import METHOD_JURCA, WITHHOLD_MESSAGES
from healthee.derive.vo2max_tier import estimate_unavailable_reason

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

Cur = Cursor[TupleRow]


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


def compute_biological_age(
    cur: Cur, user_id: UUID, tz: str, day: date | None = None
) -> dict | None:
    """Gompertz hazard→years over one combined fitness term (VO₂max) + sleep duration.
    Returns chronological/biological age + signed per-term year contributions
    (+ = older, − = younger), or None without a profile/inputs.

    **The composite ``docs/AS_OF_DAY.md`` warns about by name.** It takes a "latest"
    VO₂max, a 14-night sleep average, and a freshness horizon — three chances to leak the
    future into ``day``, and all three are closed HERE rather than in the callers, because
    a term that resolved its own anchor is a term that can disagree with the composite it
    feeds. As of ``day``: the estimate is the newest with ``day <= day``, the 14 nights
    are the fortnight ENDING on it, the chronological age is the owner's age on it, and
    the horizon is measured from it. A VO₂max three days old on 29 July was fresh on 29
    July and saying so is correct; one first measured in August must never reach a June
    answer.

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
    as_of = reference_day(day, tz)
    chrono = as_of.year - dob.year - ((as_of.month, as_of.day) < (dob.month, dob.day))

    contribs: list[dict] = []

    def add(
        term: str, hr: float, value=None, unit=None, target=None, compared_as=None, method=None
    ) -> float:
        """``compared_as`` is the value the hazard curve was actually read at when that
        is not ``value`` (the sleep term's questionnaire equivalent, #97); null elsewhere,
        so the shape never varies by term. ``method`` is the INSTRUMENT behind the term's
        own input (#117) — non-null only for fitness, where the same VO₂max can arrive
        from a recorded run or from a questionnaire and the owner is owed the difference.
        """
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
                "method": method,
            }
        )
        return d

    dage, missing_terms, fitness_method = 0.0, [], None
    for delta, missing, method in (
        _fitness_term(cur, user_id, tz, as_of, chrono, sex, add),
        _sleep_duration_term(cur, user_id, as_of, add),
    ):
        dage += delta
        fitness_method = method or fitness_method
        if missing is not None:
            missing_terms.append(missing)

    if not contribs:
        return None
    return _estimate(chrono, dage, contribs, missing_terms, fitness_method)


def _estimate(
    chrono: int,
    dage: float,
    contribs: list[dict],
    absent: list[Absent],
    fitness_method: str | None,
) -> dict:
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
        # docstring — the three absence/uncertainty keys are not interchangeable. The
        # fitness entry moves with the INSTRUMENT behind its VO₂max (#117): the
        # self-reported-activity footing is a fact about the Jurca model and a falsehood
        # about a number measured from a run.
        "caveats": caveat_terms(fitness_method),
        "disclaimer": (
            "Motivational estimate from population data — not a clinical or diagnostic age."
        ),
        "research_notes": ["biological_age_estimate"],
    }


def _fitness_term(
    cur: Cur, user_id: UUID, tz: str, as_of: date, chrono: int, sex: str, add
) -> tuple[float, Absent | None, str | None]:
    """VO₂max vs age/sex median — the one combined cardio term (0.85 per 3.5 ml).

    Returns ``(delta_years, None, method)`` when ``as_of`` has an estimate, else
    ``(0.0, absent, None)``. The freshness rule is
    ``derive.vo2max_tier.estimate_unavailable_reason`` — the same one the VO₂max card
    applies — so the two surfaces of ``/api/today`` cannot disagree about whether this
    owner has a fitness number right now.

    Since #117 that estimate is TIERED, and this function does not re-decide the tier: it
    reads the day's canonical row and carries the instrument's name outward. Before the
    tiering this term returned ``null`` for a real owner while two measured VO₂max values
    from the same fortnight sat unread in ``vo2max_submax`` — refusing a number over an
    input we were holding a better version of.
    """
    # `day <= %s` is the fitness half of the future leak: without it a June answer would
    # read the newest estimate the owner has ever had, find it dated August, and — since
    # the gate below only asks whether that row IS the reference day's — refuse for the
    # wrong reason while a June row sat underneath it.
    cur.execute(
        "SELECT day, value, flags FROM derived_daily "
        "WHERE user_id = %s AND metric='vo2max_estimate' AND day <= %s ORDER BY day DESC LIMIT 1",
        (user_id, as_of),
    )
    vr = cur.fetchone()
    reason = estimate_unavailable_reason(cur, user_id, tz, as_of, vr[0] if vr else None)
    if vr is None or reason is not None:
        return 0.0, absent(FITNESS_TERM, reason, WITHHOLD_MESSAGES), None
    # Rows written before #117 carry no ``method`` and are all Jurca.
    method = str((vr[2] or {}).get("method") or METHOD_JURCA)
    ref = vo2max_median_for(chrono, sex)
    delta = add(
        FITNESS_TERM,
        0.85 ** ((float(vr[1]) - ref) / 3.5),
        value=round(float(vr[1]), 1),
        unit="ml/kg/min VO₂max",
        target=round(ref),
        method=method,
    )
    return delta, None, method


def _sleep_duration_term(
    cur: Cur, user_id: UUID, as_of: date, add
) -> tuple[float, Absent | None, str | None]:
    """The 14-night average TST ENDING at ``as_of``, U-shaped about Yin 2017's 7 h nadir.

    The window is anchored to the day being answered for, so this term cannot go STALE —
    only empty. Empty is still the ``HR = 1.0`` assertion ("you average 7 h/night"), so it
    withholds the composite exactly as a stale term does: one rule, three terms.

    Both ends of the fortnight now move with the reference day. The closing end is the one
    that was implicit and is now stated: a window that ran to the wall clock would average
    a past day's fortnight together with every night since, so "your last 14 nights" on 29
    July would silently mean "the 14 nights before today".

    The strap's average is read at its QUESTIONNAIRE equivalent, because Yin's exposure is
    self-reported and self-report runs long (#97, ``analytics/reference_scales.py``)."""
    cur.execute(
        "SELECT avg((flags->>'tst_min')::float) FROM derived_daily "
        "WHERE user_id = %s AND metric='sleep_health_score_4dim' AND flags ? 'tst_min' "
        f"AND day >= ({AS_OF_DAY_SQL} - 14) AND day <= {AS_OF_DAY_SQL}",
        (user_id, as_of, as_of),
    )
    sr = cur.fetchone()
    if not sr or not sr[0]:
        return (
            0.0,
            absent(SLEEP_DURATION_TERM, NO_NIGHTS_IN_WINDOW, SLEEP_DURATION_MESSAGES),
            None,
        )
    measured_h = float(sr[0]) / 60.0
    # The curve is read at the questionnaire equivalent, never at the raw device hours.
    h = self_reported_equivalent_h(measured_h)
    # The label now says what the maths does (#88 found it saying "7–9" while charging
    # 1.13× at 8 h and 1.28× at 9 h — telling the owner 9 h was on target while pricing
    # it as risk). ``SLEEP_HAZARD_NADIR_H`` is Yin's dose-response turning point, NOT a
    # recommended band: the recommendation stays NSF 2015's 7–9 h, cited by the sleep
    # surfaces. Two different quantities, one definition each — which is the canonical-
    # metric rule satisfied, not a third number added.
    return (
        add(
            SLEEP_DURATION_TERM,
            (SHORT_SLEEP_HR_PER_H ** (SLEEP_HAZARD_NADIR_H - h))
            if h < SLEEP_HAZARD_NADIR_H
            else (LONG_SLEEP_HR_PER_H ** (h - SLEEP_HAZARD_NADIR_H)),
            value=round(measured_h, 1),
            unit="h/night",
            target=SLEEP_HAZARD_NADIR_H,
            compared_as=round(h, 1),
        ),
        None,
        None,
    )
