"""ONE ``vo2max_estimate``, three instruments, the notes' precedence — and no blending.

## The defect this module closes (#117)

Three notes specify one tiered metric and the code implemented no precedence at all.
[[submaximal_vo2max]] D1: "use the submaximal estimate as the **primary**
``vo2max_estimate`` path … otherwise fall back to [[non_exercise_vo2max]]".
[[non_exercise_vo2max]] D1: "compute the non-exercise estimate only as the **fallback**".
[[hr_reserve_vo2max]] D2: the reserve inversion runs "only as the fallback when the graded
fit cannot fit a line".

What shipped instead: ``vo2max_estimate`` was Jurca and only Jurca, while the measured
values sat in ``vo2max_submax``, which nothing read — ``derive/orchestrator.py`` said so
in as many words. Measured live on 2026-08-02: the owner's SR-PA was unanswered, so Jurca
withheld and wrote nothing; the measured tier held 39.6 (graded) and 41.7 (reserve); and
``analytics/biological_age.py`` read ``vo2max_estimate`` alone and returned ``null``. We
refused to produce a number while holding a better version of the input we refused for.

## The precedence, and the one place it lives

    1. METHOD_GRADED   — the graded HR-vs-workload fit           (primary)
    2. METHOD_RESERVE  — the %HRR inversion, running windows only (when 1 cannot fit)
    3. METHOD_JURCA    — the non-exercise model                   (fallback)

Each instrument names itself in its own module; this one owns nothing but the ORDER, the
horizon, and the write. Every row it writes carries ``flags.method``, and every surface
that carries the number carries the instrument with it.

## Never averaged, and structurally so ([[hr_reserve_vo2max]] D4)

"Never average the two methods. They are different instruments; a blended number has no
validation behind it. State which one produced the value." That is a hard guardrail here,
not a preference, and the code is arranged so there is nowhere for a blend to happen:
:func:`select_measured_tier` picks ONE method first and only then computes a median, over
a list filtered to that method alone. No sum, mean or median in this module ever sees two
methods' values, and ``tests/derive/test_vo2max_tier.py`` fails if one can.

That constraint is also why the tier's value is a median ACROSS SESSIONS rather than the
newest session: [[hr_reserve_vo2max]] D6 and [[submaximal_vo2max]] D5 both require it
("report the median across sessions and the trend, never one session as a fact"), and a
median taken across mixed instruments would BE the forbidden average whenever the count
is even. Within one instrument it is what the notes ask for.

**When a median is not available.** Inside the horizon below there is usually one session
or none. One session still ships — refusing would leave the tier permanently inert, which
is not what "never one session as a fact" asks for — but it never ships bare: the row and
the payload carry ``n_sessions``, and at n = 1 the payload's method caveat says in the
second person that this is a single session rather than a settled level. The number is
offered; the fact-hood is not.

## How stale a MEASURED value may be

A session-measured VO₂max is not derived nightly, so ``derive/freshness.py``'s
today-or-nothing rule would make this tier unreachable. It gets a horizon by the same rule
weight gets one, and the evidence — detraining decay against our own instruments'
resolution — is written where the constant is
(``freshness.MEASURED_VO2MAX_MAX_AGE_DAYS``, 14 days). Two consequences worth stating
here, where the precedence is decided:

* The horizon is applied when the day's row is WRITTEN, never at read time. So the
  canonical metric stays what ``freshness.py`` says every daily row is — a claim about the
  day it is keyed to — and there is exactly one place staleness is decided.
* A measured tier that has gone stale FALLS THROUGH to Jurca; it does not blank the
  metric. Keeping an honest number on screen on sedentary days is the fallback tier's
  entire stated purpose ([[non_exercise_vo2max]]).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from uuid import UUID

from healthee.core.logging import get_logger
from healthee.derive._common import Cur, _age, _upsert_daily
from healthee.derive.freshness import (
    MEASURED_VO2MAX_MAX_AGE_DAYS,
    measured_fitness_is_stale,
    unavailable_reason,
)
from healthee.derive.robust import median
from healthee.derive.vo2max import (
    METHOD_JURCA,
    derive_vo2max,
)
from healthee.derive.vo2max import (
    withhold_reason_for_day as jurca_withhold_reason,
)
from healthee.derive.vo2max_reserve import METHOD_RESERVE, reserve_sd_ml_kg_min
from healthee.derive.vo2max_submax import METHOD_GRADED

log = get_logger(__name__)

# The measured instruments in the order the notes rank them. Jurca is not in this tuple
# because it is not a measurement and it is not selected the same way — it is what runs
# when nothing measured can speak for the day.
MEASURED_PRECEDENCE: tuple[str, ...] = (METHOD_GRADED, METHOD_RESERVE)

# Every instrument that may produce a ``vo2max_estimate``, best first. Exported so a
# consumer can render them without re-deciding the order.
TIER_PRECEDENCE: tuple[str, ...] = (*MEASURED_PRECEDENCE, METHOD_JURCA)

# Carrier et al. 2023 (Technologies 11(3):71), the ONLY independent peer-reviewed accuracy
# figure for the graded wearable method: MAPE 6.85% against lab CPET (n=21, structured
# outdoor running). It is a mean absolute PERCENTAGE error, not an SEE — hence a fraction
# of the value rather than a constant, and hence ``see_source`` naming the statistic on
# the wire. [[submaximal_vo2max]].
GRADED_MAPE = 0.0685

# What each instrument's error figure IS, so nothing downstream can read a MAPE as an SEE
# or a modelled SD as a measured one.
SEE_SOURCES = {
    METHOD_GRADED: "Carrier 2023: MAPE 6.85% vs lab CPET, structured outdoor running",
    METHOD_RESERVE: (
        "hr_reserve_vo2max: modelled 1 SD of a six-window session median at this "
        "session's fraction of heart-rate reserve"
    ),
    METHOD_JURCA: "Jurca 2005 (NASA): SEE 1.45 METs within the development cohort",
}


def method_of(stored: object) -> str:
    """The instrument behind a stored ``vo2max_estimate`` row's ``flags.method``.

    Rows written before #117 carry no ``method`` and are all Jurca — the tiered writer is
    what introduced the other two, so this default cannot mislabel an older row.

    It is a function rather than a default repeated at each read because there are now two
    surfaces that must not be able to disagree about what an unstamped row was produced by
    (standards §Duplication): the payload (``read/vo2max.py``) and the coach's compact
    metric pivot (``insights/context_provenance.py``). A number whose instrument is named
    one way on screen and another way to the model is [[hr_reserve_vo2max]] D4 half-kept.
    """
    return str(stored or METHOD_JURCA)


def submax_method_of(flags: dict | None) -> str:
    """The instrument behind a stored ``vo2max_submax`` row, from its flags.

    NOT :func:`method_of`, and the difference is the whole reason this exists: that one
    answers for ``vo2max_estimate``, whose unstamped rows are all Jurca. A ``vo2max_submax``
    row is a SESSION measurement, so an unstamped one is a graded fit — everything written
    before #114, when the reserve inversion arrived ([[submaximal_vo2max]]). One default
    used for both would relabel every old measured session as a model estimate.

    Two callers, hence one function (standards, "Duplication"): :func:`measured_sessions`
    reading the tier out of the day cells, and ``derive/gps._store`` deciding whether a new
    session may replace the one already in a day's cell.
    """
    return str((flags or {}).get("method") or METHOD_GRADED)


def outranks(challenger: str, incumbent: str) -> bool:
    """Does ``challenger`` come EARLIER in the measured precedence than ``incumbent``?

    ``False`` for equal methods, so a re-score of the same instrument still overwrites
    (``--rescore-tracks`` has to be able to move a value) while a weaker instrument cannot
    displace a stronger one. A method not in :data:`MEASURED_PRECEDENCE` ranks last, which
    is the safe direction: an instrument this module has never heard of does not get to
    outrank a graded fit on the strength of being unknown.
    """
    order = {method: rank for rank, method in enumerate(MEASURED_PRECEDENCE)}
    last = len(MEASURED_PRECEDENCE)
    return order.get(challenger, last) < order.get(incumbent, last)


@dataclass(frozen=True)
class MeasuredSession:
    """One stored ``vo2max_submax`` row: what a recorded session measured, and with what.

    ``hrr_median`` is the reserve instrument's own diagnostic and is ``None`` for graded
    rows and for rows written before #114 (all of which are graded fits).
    """

    day: date
    value: float
    method: str
    hrr_median: float | None


@dataclass(frozen=True)
class MeasuredTier:
    """The measured answer for one day: one instrument, its sessions, their median."""

    method: str
    value: float
    n_sessions: int
    first_day: date
    last_day: date
    hrr_median: float | None


def select_measured_tier(sessions: list[MeasuredSession], day: date) -> MeasuredTier | None:
    """The measured value that may speak for ``day``, or None when none may.

    Pure and total, so the two properties that matter can be tested without a database:
    the PRECEDENCE (a graded session beats a reserve session, whatever their dates) and
    the NO-BLENDING guarantee (the median is computed over one method's values only, and
    the loop returns on the first method that has any).

    Note what the precedence is NOT: recency. A graded fit three days older than a reserve
    inversion still wins, because [[hr_reserve_vo2max]] D2 ranks them by what they assume
    — the graded fit measures this person's own VO₂–HR line, the inversion assumes a
    population equivalence the largest study of it rejects — and that ranking does not
    decay over a fortnight.
    """
    fresh = [s for s in sessions if not measured_fitness_is_stale(s.day, day)]
    for method in MEASURED_PRECEDENCE:
        # ONE method's sessions. Everything below this line sees a single instrument, which
        # is the whole of the no-blending guarantee.
        same = [s for s in fresh if s.method == method]
        if not same:
            continue
        days = sorted(s.day for s in same)
        hrrs = [s.hrr_median for s in same if s.hrr_median is not None]
        return MeasuredTier(
            method=method,
            value=round(median([s.value for s in same]), 1),
            n_sessions=len(same),
            first_day=days[0],
            last_day=days[-1],
            # The LOWEST fraction of reserve among the admitted sessions, because the
            # published precision widens as the fraction falls: the band we quote must
            # cover the weakest session that fed the median, not the strongest.
            hrr_median=min(hrrs) if hrrs else None,
        )
    return None


def measured_sessions(cur: Cur, user_id: UUID, day: date) -> list[MeasuredSession]:
    """Stored session measurements that could speak for ``day``, oldest first.

    Bounded in SQL to the horizon so the query is indexed and the pure selector is handed
    only candidates; :func:`select_measured_tier` applies the horizon again on the values
    themselves, which is not redundancy but the guarantee that the rule is the same one
    wherever it is asked. Rows written before #114 carry no ``method`` and are graded fits
    ([[submaximal_vo2max]]).
    """
    cur.execute(
        "SELECT day, value, flags FROM derived_daily "
        "WHERE user_id = %s AND metric = 'vo2max_submax' AND day <= %s AND day >= %s "
        "ORDER BY day",
        (user_id, day, day - timedelta(days=MEASURED_VO2MAX_MAX_AGE_DAYS)),
    )
    out: list[MeasuredSession] = []
    for row_day, value, flags in cur.fetchall():
        hrr = (flags or {}).get("hrr_median")
        out.append(
            MeasuredSession(
                day=row_day,
                value=float(value),
                method=submax_method_of(flags),
                hrr_median=float(hrr) if hrr is not None else None,
            )
        )
    return out


def measured_tier(cur: Cur, user_id: UUID, day: date) -> MeasuredTier | None:
    """The measured tier for ``day``, read from the stored session records."""
    return select_measured_tier(measured_sessions(cur, user_id, day), day)


def precision_ml_kg_min(tier: MeasuredTier) -> float:
    """The ± band a measured value ships with, in the instrument's own published terms.

    Never Jurca's SEE: a measurement carried under the model's error figure would be the
    laundering [[non_exercise_vo2max]] forbids in the other direction. The graded fit's
    figure is a percentage of the value (a MAPE); the reserve inversion's is a modelled SD
    that depends on how deep into the reserve the session sat.
    """
    if tier.method == METHOD_RESERVE:
        return reserve_sd_ml_kg_min(tier.hrr_median if tier.hrr_median is not None else 0.0)
    return round(tier.value * GRADED_MAPE, 2)


def _measured_flags(cur: Cur, user_id: UUID, tier: MeasuredTier, day: date) -> dict:
    """The stored row's flags for a MEASURED estimate.

    ``age_years``/``sex`` are read straight from ``profile`` rather than through
    ``_load_profile``: they are here only so the payload can name the owner's age/sex
    reference median, and a measured VO₂max must not inherit the model's dependency on a
    logged weight — nothing in a measured session divides by a mass.
    """
    cur.execute("SELECT sex, dob FROM profile WHERE user_id = %s", (user_id,))
    prof = cur.fetchone()
    sex, dob = (prof[0], prof[1]) if prof else (None, None)
    return {
        "method": tier.method,
        "n_sessions": tier.n_sessions,
        "measured_first_day": tier.first_day.isoformat(),
        "measured_as_of": tier.last_day.isoformat(),
        # How far the newest session that fed this number sits from the day it speaks for.
        # Always inside ``freshness.MEASURED_VO2MAX_MAX_AGE_DAYS`` by construction — it is
        # stored so an operator can see WHERE inside, without re-deriving.
        "measured_age_days": (day - tier.last_day).days,
        "hrr_median": tier.hrr_median,
        "see_ml_kg_min": precision_ml_kg_min(tier),
        "see_source": SEE_SOURCES[tier.method],
        "age_years": _age(dob, day) if dob else None,
        "sex": sex,
    }


def derive_vo2max_estimate(cur: Cur, user_id: UUID, tz: str, day: date) -> dict | None:
    """THE ``vo2max_estimate`` writer: the best instrument that can speak for ``day``.

    Measured first, in the notes' order, then the Jurca model. ``None`` only when NO tier
    can produce an honest number — a withheld measured tier falls through rather than
    blanking the metric, and a withheld Jurca tier is the last word only because there is
    nothing below it.

    Must run AFTER the day's tracks are scored (``derive/gps_scoring.py``): this function
    reads what that one writes. ``derive/orchestrator.py`` owns that order.
    [[submaximal_vo2max]], [[hr_reserve_vo2max]], [[non_exercise_vo2max]].
    """
    tier = measured_tier(cur, user_id, day)
    if tier is None:
        return derive_vo2max(cur, user_id, tz, day)
    log.info(
        "vo2max_estimate measured",
        extra={
            "user_id": str(user_id),
            "day": str(day),
            "method": tier.method,
            "n_sessions": tier.n_sessions,
        },
    )
    flags = _measured_flags(cur, user_id, tier, day)
    _upsert_daily(cur, user_id, day, "vo2max_estimate", tier.value, flags)
    return {"vo2max_estimate": round(tier.value, 1)}


def withhold_reason_for_day(cur: Cur, user_id: UUID, tz: str, day: date) -> str | None:
    """Why ``day`` can carry no estimate FROM ANY TIER, or None when one of them can.

    The read-side twin of :func:`derive_vo2max_estimate`, and it has to be tiered for the
    same reason the writer does: before #117 a consumer asked the Jurca gate whether the
    owner had a VO₂max, and got "no, they never answered the activity question" on a day
    we held a measurement. ``tests/derive/test_vo2max_tier.py`` pins the equivalence —
    the writer writes nothing exactly when this names a reason.
    """
    if measured_tier(cur, user_id, day) is not None:
        return None
    return jurca_withhold_reason(cur, user_id, tz, day)


def estimate_unavailable_reason(
    cur: Cur, user_id: UUID, tz: str, today: date, last_day: date | None
) -> str | None:
    """Why this owner has no estimate FOR TODAY, or ``None`` when ``last_day`` IS today.

    The FRESHNESS half of the gate, bound to the tiered withhold gate above.
    :func:`withhold_reason_for_day` answers "could today carry an estimate";
    ``derive.freshness.unavailable_reason`` answers the question a *consumer* actually
    has, which is "is the newest stored row today's". They are different questions and the
    second is the one that was getting skipped: a row is not evidence about today merely
    because it is the newest row.

    There are TWO consumers and the rule must not fork — the VO₂max payload
    (``read/vo2max.py``) and the biological-age fitness term
    (``analytics/biological_age.py``), where a stale estimate is laundered into a headline
    composite. It moved here from ``derive/vo2max.py`` in #117 with the metric itself: it
    was answering for one tier while claiming to answer for the metric.
    [[non_exercise_vo2max]], [[biological_age_estimate]].
    """
    return unavailable_reason(
        today, last_day, lambda: withhold_reason_for_day(cur, user_id, tz, today)
    )
