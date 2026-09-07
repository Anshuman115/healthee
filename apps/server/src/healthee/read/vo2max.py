"""The VO2max payload — the estimate, the instrument behind it, and why there isn't one.

## The number is tiered, and this file does NOT decide the tier (#117)

``vo2max_estimate`` is one metric with three instruments in a fixed order — graded GPS
fit, then the %HRR reserve inversion, then the Jurca non-exercise model. That order is
applied once, when the day's row is written (``derive/vo2max_tier.py``), and this payload
reads the row. It never re-tiers: a read-time choice would be a second definition of the
metric, and the day's row would then mean different things depending on who asked.

What this file owes the owner is the OTHER half of [[hr_reserve_vo2max]] Directive 4 —
"state which one produced the value". ``method``, ``method_caveat``, ``see_source`` and
``research_notes`` all move with the instrument, so a number that came from a run last
week and a questionnaire this week cannot look like the same measurement twice.


Split out of ``read/fitness.py`` when the freshness gate below pushed that file past
the 400-line limit. It was the right home anyway: everything here answers "what do we
actually know about this owner's aerobic fitness TODAY", which is a different question
from load, MVPA and strength (standards §1: a file has one reason to change).

## Withheld must READ as withheld (2026-07-31)

``derive/vo2max.py`` withholds the Jurca estimate — writes NO row — when its inputs
cannot carry it: no profile or logged weight, fewer than 3 resting-HR days, an RHR
median outside Jurca's validated 40-100 bpm, or a 7-day RHR MAD above 8 bpm. The note
is explicit that this is a decision, not a gap: "Skip the derivation (show
'Insufficient data') ... never write a wrong value."

This payload used to read the last 95 days and take ``rows[-1]``. So on a withheld day
it rendered an OLDER day's estimate as the hero number. It carried ``as_of_date``, so
it was not fabrication — but a date in a field the UI may not render does not undo a
confident current-looking number, and the withhold gate exists precisely to say "we
don't have enough to tell you today". In user terms the gate was defeated.

The fix is structural, not a label: **an estimate is only reported when the newest row
is the owner's TODAY.** Otherwise ``estimate`` and ``as_of_date`` are both ``null``,
``data_confidence`` is ``insufficient_data`` (the outcome ledger's exact vocabulary —
``challenges/ledger.py``), and a ``withheld`` block names the reason and what it would
take to fix, in the shape ``data_health`` uses for a dead feed. A UI that renders the
hero number gets nothing to render; there is no "dated field" to miss.

The reason is RECOMPUTED, not persisted: ``derive.vo2max.withhold_reason_for_day``
re-runs the same gate over the same inputs, which are still in the database. No
migration, no backfill, and it works for rows written before this existed.

What is deliberately KEPT when the estimate is withheld: ``trend_90d`` (the note calls
the trend the trustworthy signal, and a trend that ends before today is honest as long
as nothing claims it ends now), ``median_for_age`` (a population fact about the owner's
age and sex, not a claim about them), and the last estimate itself — inside the
``withheld`` block, where it cannot be mistaken for today's.
"""

from __future__ import annotations

from datetime import date
from uuid import UUID

from healthee.analytics.reference_scales import vo2max_median_for
from healthee.core.tenancy import AS_OF_DAY_SQL, reference_day
from healthee.derive._common import Cur
from healthee.derive.freshness import withheld_block
from healthee.derive.vo2max import (
    METHOD_JURCA,
    WITHHOLD_MESSAGES,
    out_of_range_inputs,
)
from healthee.derive.vo2max_reserve import METHOD_RESERVE
from healthee.derive.vo2max_submax import METHOD_GRADED
from healthee.derive.vo2max_tier import estimate_unavailable_reason, method_of

_WINDOW_DAYS = 95  # the trend window; ~90 days of trend plus slack

# What each instrument's number is worth, in the second person. The sentences state a
# LIMIT rather than a confidence score, because the three methods do not differ in
# precision so much as in what they assume: the graded fit measures this owner's own
# VO2-HR line, the reserve inversion assumes a population equivalence that the largest
# study of it rejects ([[hr_reserve_vo2max]]), and the non-exercise model measures no
# exertion at all ([[non_exercise_vo2max]]).
#
# One of these ships with EVERY number this payload reports, because
# [[hr_reserve_vo2max]] Directive 4 is explicit that the instrument must be stated — an
# owner whose number comes from a run one week and a questionnaire the next has to be able
# to see that, or a change of instrument reads as a change in them.
_METHOD_CAVEATS = {
    METHOD_GRADED: (
        "Measured from a recorded session, by how your heart rate tracked your workload "
        "across it — the most direct of the three methods we have, because it measures "
        "the relationship on you rather than assuming it."
    ),
    METHOD_RESERVE: (
        "Measured from a recorded RUN, by how far into your heart-rate range you were, "
        "using a population relationship rather than one measured on you. It only runs on "
        "running, and it most likely reads a little LOW — the published bias in that "
        "relationship under-states fitness by roughly 2-3 mL/kg/min."
    ),
    METHOD_JURCA: (
        "Estimated without any exertion, from your age, sex, BMI, resting heart rate and "
        "your own answer about how much deliberate exercise you do — the fallback we use "
        "when no recent recorded session can measure it. It is the noisiest of the three."
    ),
}

# [[hr_reserve_vo2max]] D6 and [[submaximal_vo2max]] D5: "report the median across
# sessions … never one session as a fact". Inside the freshness horizon there is usually
# one session or none, so refusing at n = 1 would leave the measured tier permanently
# inert. The number ships and the fact-hood does not — this sentence is what makes the
# difference visible to the owner rather than only to the code.
_SINGLE_SESSION_CAVEAT = (
    " It comes from one session, not a run of them, so read it as that session rather "
    "than as a settled level."
)

# Which note licenses the number in front of the owner. The fitness↔mortality note is
# common to all three because it is what makes any VO₂max worth showing.
_METHOD_NOTES = {
    METHOD_GRADED: ["vo2max_fitness_mortality", "submaximal_vo2max"],
    METHOD_RESERVE: ["vo2max_fitness_mortality", "hr_reserve_vo2max"],
    METHOD_JURCA: ["vo2max_fitness_mortality", "non_exercise_vo2max"],
}


def method_caveat(method: str, n_sessions: int | None) -> str | None:
    """The instrument's sentence, plus the single-session qualifier when it applies."""
    base = _METHOD_CAVEATS.get(method)
    if base is None:
        return None
    return base + (_SINGLE_SESSION_CAVEAT if n_sessions == 1 else "")


def vo2max_payload(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> dict | None:
    """The tiered VO2max AS OF ``day`` + 90-day trend + the session record behind it.

    ``None`` only when the owner has no estimate at all in the window — genuinely
    nothing to say. When there IS history but the day has no estimate, the payload is
    returned with ``estimate: None`` and a ``withheld`` block: "we can't tell you
    for that day, and here is what we'd need" is a real answer, absence is not.
    [[vo2max]] (Mandsager 2018); derivation [[non_exercise_vo2max]].

    **This is the "latest" ``docs/AS_OF_DAY.md`` names first.** ``rows[-1]`` used to be
    the newest estimate the owner had; as of ``day`` it is the newest with ``day <=
    day``, because the window itself now closes there. A June answer that inherited an
    August measurement would be the future leak in its purest form — the same value
    dated wrongly, which is exactly what the stale-as-current gate below refuses in the
    other direction.
    """
    as_of = reference_day(day, tz)
    rows = _window(cur, user_id, as_of, "vo2max_estimate")
    if not rows:
        return None
    last_day, last_value, flags = rows[-1][0], float(rows[-1][1]), (rows[-1][2] or {})
    withheld = _withheld_block(cur, user_id, tz, as_of, last_day, last_value)
    age = int(flags.get("age_years") or 0)
    sex = str(flags.get("sex") or "male")
    median_ref = vo2max_median_for(age, sex) if age else None
    estimate = None if withheld else round(last_value, 1)
    # Rows written before #117 carry no ``method`` and are all Jurca. That default lives in
    # ``vo2max_tier.method_of`` because the coach's pivot resolves the same rows (#120) and
    # two answers to "what produced this row" is D4 half-kept.
    method = method_of(flags.get("method"))
    n_sessions = flags.get("n_sessions")
    return {
        "submax": _submax_block(cur, user_id, as_of),
        "estimate": estimate,
        "data_confidence": "insufficient_data" if withheld else "ok",
        "withheld": withheld,
        # WHICH INSTRUMENT produced the number above, on the wire, always. Paired with
        # `estimate`: null together, because naming the instrument behind a number we have
        # just declined to report would describe something the owner is not being shown.
        "method": None if withheld else method,
        "method_caveat": None if withheld else method_caveat(method, n_sessions),
        "measured_as_of": None if withheld else flags.get("measured_as_of"),
        "n_sessions": None if withheld else n_sessions,
        # The ± band, in the reporting instrument's own units of error — a MAPE for the
        # graded fit, a modelled SD for the reserve inversion, an SEE for Jurca.
        # ``see_source`` says WHICH, so a percentage error cannot be read as a standard
        # error of estimate. Older rows carry Jurca's SEE and nothing else.
        "see_source": flags.get("see_source"),
        "see_ml_kg_min": float(flags.get("see_ml_kg_min", 5.6)),
        # Paired with `estimate`: both describe today's number, so both are null when
        # there isn't one. The last day that DID have one lives in `withheld`.
        "as_of_date": None if withheld else last_day.isoformat(),
        "age_years": age,
        "sex": sex,
        "median_for_age": median_ref,
        "delta_from_median": _delta(estimate, median_ref),
        "trend_90d": [{"date": d.isoformat(), "value": round(float(v), 1)} for d, v, _ in rows],
        # v2 flag names: rhr_med_7d←rhr_med, pa_score←srpa; weekly_mvpa_min not
        # stored in v2 vo2max flags → null (documented WP7 note).
        "inputs": {
            "bmi": flags.get("bmi"),
            "rhr_med_7d": flags.get("rhr_med"),
            "weekly_mvpa_min": None,
            "pa_score": flags.get("srpa"),
        },
        # Directive 5 of [[non_exercise_vo2max]]: an estimate computed outside the
        # range the model was validated on says so. Recomputed from the inputs the
        # row already stores (no schema, no backfill), so it also covers rows
        # written before the flag existed. Empty list = every input in range.
        "out_of_range_inputs": out_of_range_inputs(age or None, flags.get("bmi")),
        # The notes that license THIS number, which depends on which instrument read it.
        "research_notes": _METHOD_NOTES[method],
    }


def _withheld_block(
    cur: Cur, user_id: UUID, tz: str, as_of: date, last_day: date, last_value: float
) -> dict | None:
    """Why there is no estimate for ``as_of``, or None when that day has one.

    A row for any day other than ``as_of`` does not make ``as_of``'s estimate exist, and
    ``derive.vo2max_tier.estimate_unavailable_reason`` is the check that makes that
    structural: a withheld day cannot "resurrect" on the next one just because some row
    survives inside the 95-day window. That rule lives beside the gate it belongs to
    because biological age needs the identical answer (standards §Duplication).

    The gate already took its reference day as an argument, so answering for a past day
    needed nothing added to it — only that this caller stop hardwiring the wall clock.
    Its own withhold checks (profile, SR-PA, the resting-HR window) are re-run AS OF that
    day, which is the point: a day whose inputs could not carry a number then must not be
    told they can now.

    Two queries, and only on the days that need them — a fresh estimate short-circuits
    before the gate is re-run, so the common path costs nothing extra.
    """
    reason = estimate_unavailable_reason(cur, user_id, tz, as_of, last_day)
    if reason is None:
        return None
    return withheld_block(
        reason, WITHHOLD_MESSAGES[reason], as_of, last_day, last_estimate=round(last_value, 1)
    )


def _delta(estimate: float | None, median_ref: float | None) -> float | None:
    """Estimate vs the age/sex population median — a claim about NOW, so it needs a
    current estimate. Null whenever the estimate is withheld."""
    if estimate is None or not median_ref:
        return None
    return round(estimate - median_ref, 1)


def _window(cur: Cur, user_id: UUID, as_of: date, metric: str) -> list[tuple]:
    """(day, value, flags) for one metric over the trend window ENDING at ``as_of``.

    Both bounds, and the closing one is the load-bearing half: ``rows[-1]`` is read as
    "the estimate that speaks for this day" by every caller, so a window open at the top
    would hand a past day a value measured after it.
    """
    cur.execute(
        "SELECT day, value, flags FROM derived_daily "
        "WHERE user_id = %s AND metric = %s "
        f"AND day >= ({AS_OF_DAY_SQL} - %s::int) AND day <= {AS_OF_DAY_SQL} ORDER BY day",
        (user_id, metric, as_of, _WINDOW_DAYS, as_of),
    )
    return cur.fetchall()


def _submax_block(cur: Cur, user_id: UUID, as_of: date) -> dict | None:
    """The SESSION RECORD beneath the estimate: what each recorded effort measured.

    ``vo2max_submax`` is one row per day that carried a scoreable session — an
    observation, not a second answer to "what is this person's VO₂max". Since #117 that
    question has exactly one answer, ``estimate`` above, and on any day a session inside
    the freshness horizon exists these numbers ARE that answer rather than a rival to it
    (``derive/vo2max_tier.py``). Two metrics both meaning the owner's VO₂max is what
    CLAUDE.md's canonical-definition rule forbids; a metric and its observations is not
    that, in the same way ``rhr_daily`` and the heart-rate samples under it are not.

    ``vs_jurca`` lived here until #117 and is GONE with the tiering: it was a difference
    between two definitions of one quantity, which is the object that should not have
    existed. The comparison an owner can still make honestly is the one against the
    population reference (``delta_from_median``), and the instrument behind today's number
    is now stated at the top level instead of implied by a gap.

    ``last_method`` records which instrument read the newest session, so a session-to-
    session move that is really an instrument change does not read as a fitness change
    (#114). Rows written before #114 carry no ``method``; they are all graded fits, which
    is what ``METHOD_GRADED`` defaults them to.
    """
    rows = _window(cur, user_id, as_of, "vo2max_submax")
    if not rows:
        return None
    s_day, s_val, s_flags = rows[-1][0], float(rows[-1][1]), (rows[-1][2] or {})
    method = str(s_flags.get("method") or METHOD_GRADED)
    return {
        "latest": round(s_val, 1),
        # There was a ``median`` here, over every session in the window regardless of
        # which instrument read it. It went with ``vs_jurca`` in #117: a median over mixed
        # instruments IS the average [[hr_reserve_vo2max]] D4 forbids whenever the count
        # is even, and the only thing it fed was the comparison that no longer exists. The
        # median that IS reported is the tier's, over one instrument, and it is the
        # ``estimate`` at the top of this payload.
        "n_sessions": len(rows),
        "as_of_date": s_day.isoformat(),
        "last_r2": s_flags.get("r2"),
        "last_speed_kmh": s_flags.get("speed_kmh"),
        "last_method": method,
        "method_caveat": _METHOD_CAVEATS.get(method),
        "trend": [{"date": d.isoformat(), "value": round(float(v), 1)} for d, v, _ in rows],
    }
