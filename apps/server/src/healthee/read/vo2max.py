"""The VO2max payload — the estimate, its freshness, and why there isn't one.

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
from healthee.core.tenancy import USER_TODAY_SQL, user_today
from healthee.derive._common import Cur
from healthee.derive.freshness import withheld_block
from healthee.derive.gps import METHOD_GRADED, METHOD_RESERVE
from healthee.derive.robust import median
from healthee.derive.vo2max import (
    WITHHOLD_MESSAGES,
    estimate_unavailable_reason,
    out_of_range_inputs,
)

_WINDOW_DAYS = 95  # the trend window; ~90 days of trend plus slack

# What each instrument's number is worth, in the second person. Both sentences state a
# LIMIT rather than a confidence score, because the two methods do not differ in
# precision so much as in what they assume: the graded fit measures this owner's own
# VO2-HR line, the reserve inversion assumes a population equivalence that the largest
# study of it rejects ([[hr_reserve_vo2max]]).
_METHOD_CAVEATS = {
    METHOD_GRADED: (
        "Read from how your heart rate tracked your workload across this session — the "
        "more direct of the two methods we have, because it measures the relationship on "
        "you rather than assuming it."
    ),
    METHOD_RESERVE: (
        "Read from how far into your heart-rate range you were while running, using a "
        "population relationship rather than one measured on you. It only runs on "
        "running, and it most likely reads a little LOW — the published bias in that "
        "relationship under-states fitness by roughly 2-3 mL/kg/min."
    ),
}


def vo2max_payload(cur: Cur, user_id: UUID, tz: str) -> dict | None:
    """Jurca non-exercise VO2max for TODAY + 90-day trend + submax GPS estimate.

    ``None`` only when the owner has no estimate at all in the window — genuinely
    nothing to say. When there IS history but today has no estimate, the payload is
    returned with ``estimate: None`` and a ``withheld`` block: "we can't tell you
    today, and here is what we'd need" is a real answer, absence is not.
    [[vo2max]] (Mandsager 2018); derivation [[non_exercise_vo2max]].
    """
    rows = _window(cur, user_id, tz, "vo2max_estimate")
    if not rows:
        return None
    today = user_today(tz)
    last_day, last_value, flags = rows[-1][0], float(rows[-1][1]), (rows[-1][2] or {})
    withheld = _withheld_block(cur, user_id, tz, today, last_day, last_value)
    age = int(flags.get("age_years") or 0)
    sex = str(flags.get("sex") or "male")
    median_ref = vo2max_median_for(age, sex) if age else None
    estimate = None if withheld else round(last_value, 1)
    return {
        "submax": _submax_block(cur, user_id, tz, estimate),
        "estimate": estimate,
        "data_confidence": "insufficient_data" if withheld else "ok",
        "withheld": withheld,
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
        "research_notes": ["vo2max_fitness_mortality", "non_exercise_vo2max"],
    }


def _withheld_block(
    cur: Cur, user_id: UUID, tz: str, today: date, last_day: date, last_value: float
) -> dict | None:
    """Why there is no estimate for TODAY, or None when today has one.

    A row for any day other than the owner's today does not make today's estimate
    exist, and ``derive.vo2max.estimate_unavailable_reason`` is the check that makes that
    structural: a withheld today cannot "resurrect" tomorrow just because some row
    survives inside the 95-day window. That rule lives beside the gate it belongs to
    because biological age needs the identical answer (standards §Duplication).

    Two queries, and only on the days that need them — a fresh estimate short-circuits
    before the gate is re-run, so the common path costs nothing extra.
    """
    reason = estimate_unavailable_reason(cur, user_id, tz, today, last_day)
    if reason is None:
        return None
    return withheld_block(
        reason, WITHHOLD_MESSAGES[reason], today, last_day, last_estimate=round(last_value, 1)
    )


def _delta(estimate: float | None, median_ref: float | None) -> float | None:
    """Estimate vs the age/sex population median — a claim about NOW, so it needs a
    current estimate. Null whenever the estimate is withheld."""
    if estimate is None or not median_ref:
        return None
    return round(estimate - median_ref, 1)


def _window(cur: Cur, user_id: UUID, tz: str, metric: str) -> list[tuple]:
    """(day, value, flags) for one metric over the trend window, oldest first."""
    cur.execute(
        "SELECT day, value, flags FROM derived_daily "
        "WHERE user_id = %s AND metric = %s "
        f"AND day >= ({USER_TODAY_SQL} - %s::int) ORDER BY day",
        (user_id, metric, tz, _WINDOW_DAYS),
    )
    return cur.fetchall()


def _submax_block(cur: Cur, user_id: UUID, tz: str, jurca_estimate: float | None) -> dict | None:
    """VO2max measured from GPS workouts (``vo2max_submax``), and which instrument read it.

    ``vs_jurca`` compares the two methods as they stand TODAY, so it is null whenever
    the Jurca side is withheld — a difference against a number we have just declined
    to report would be an interpretation of data we said we do not have.

    ``last_method`` and ``method_caveat`` are not decoration (#114). One metric is now
    written by two instruments — the graded HR-vs-workload fit and the %HRR reserve
    inversion — and a session-to-session move that is really an instrument change must
    not read as a fitness change. That is the same class of defect as showing a stale
    row as current, one layer along: the number is fresh, but what produced it moved.
    Rows written before #114 carry no ``method`` flag; they are all graded fits, which is
    what ``METHOD_GRADED`` defaults them to.
    """
    rows = _window(cur, user_id, tz, "vo2max_submax")
    if not rows:
        return None
    vals = [float(v) for _, v, _ in rows]
    med = median(vals)
    s_day, s_val, s_flags = rows[-1][0], float(rows[-1][1]), (rows[-1][2] or {})
    method = str(s_flags.get("method") or METHOD_GRADED)
    return {
        "latest": round(s_val, 1),
        "median": round(med, 1),
        "n_sessions": len(vals),
        "as_of_date": s_day.isoformat(),
        "last_r2": s_flags.get("r2"),
        "last_speed_kmh": s_flags.get("speed_kmh"),
        "last_method": method,
        "method_caveat": _METHOD_CAVEATS.get(method),
        "vs_jurca": None if jurca_estimate is None else round(med - jurca_estimate, 1),
        "trend": [{"date": d.isoformat(), "value": round(float(v), 1)} for d, v, _ in rows],
    }
