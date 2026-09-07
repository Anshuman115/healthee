"""Sleep-debt, biological-age, illness-flag, and PAI payloads for the Today page.

v2-native reads (``derived_daily`` / ``illness_flag`` / ``profile``). The illness
"framing" and sleep-debt fields are metric-derived deterministic text, not LLM.

PAI (Personalized Activity Intelligence) is a documented v2 GAP: the ``derive``
layer does not emit ``pai_today`` / ``pai_total`` (analytics/metrics.py lists them
DROPPED), so ``pai_payload`` always returns ``None`` — the Today key stays present
(the app tolerates a null PAI card) but there is no v2 data behind it.
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from healthee.analytics.biological_age import compute_biological_age
from healthee.core.tenancy import reference_day
from healthee.derive._common import Cur
from healthee.derive.freshness import NOT_DERIVED_YET, unavailable_reason, withheld_block
from healthee.derive.sleep_score import SLEEP_DEBT_MESSAGES, sleep_debt_unavailable_reason
from healthee.read.common import TodayReads, latest_derived

# "Last night" is a claim about ONE night, and the only reason it can be absent is that
# the night has not been recorded/derived yet — there is no research gate to mirror here,
# so the shared ``NOT_DERIVED_YET`` covers it with a message in sleep's own voice.
_LAST_TST_MESSAGES = {
    NOT_DERIVED_YET: "Last night's sleep has not come through yet — sync the strap."
}


def sleep_debt_payload(
    cur: Cur, user_id: UUID, tz: str, reads: TodayReads | None = None, day: date | None = None
) -> dict | None:
    """Sleep need (NSF age-band) + rolling cumulative debt + Sleep Performance %.

    Two independent freshness questions, because they genuinely come apart: an owner who
    takes the strap off for one night still has a current 14-night DEBT and no "last
    night", and an owner with no profile has last night's sleep and no debt at all.

    ``None`` only when the owner has no debt row ever. When there IS one but it is not
    today's, the payload ships with ``debt_min: None`` and a ``withheld`` block — the debt
    is a cumulative claim over the 14 nights ending on its own day, and two weeks later
    that window shares no night with today's. ``need_min`` survives either way: the NSF
    age-band midpoint is a recommendation for someone of this owner's age, not a
    measurement of them (the same reason ``read/vo2max.py`` keeps ``median_for_age``).
    [[sleep_need_debt]]."""
    as_of = reference_day(day, tz)
    debt = (
        reads.latest.get("sleep_debt_min")
        if reads
        else latest_derived(cur, user_id, "sleep_debt_min", as_of)
    )
    if not debt:
        return None
    debt_day, debt_min, flags = debt
    withheld = _debt_withheld(cur, user_id, tz, as_of, debt_day, debt_min)
    need_row = (
        reads.latest.get("sleep_need_min")
        if reads
        else latest_derived(cur, user_id, "sleep_need_min", as_of)
    )
    need = need_row[1] if need_row else 480.0
    return {
        "need_min": round(need),
        "debt_min": None if withheld else round(debt_min),
        # The window stats describe the SAME fortnight the debt does, so they are dated
        # with it — a UI showing "avg 6.3 h/night" beside a withheld debt would restore
        # exactly the current-looking stale number the withhold exists to remove.
        "avg_tst_min": None if withheld else flags.get("avg_tst_min"),
        "avg_deficit_min": None if withheld else flags.get("avg_deficit_min"),
        "nights_below": None if withheld else flags.get("nights_below"),
        "window_nights": flags.get("window_nights"),
        "nights": None if withheld else flags.get("nights"),
        "as_of_date": None if withheld else debt_day.isoformat(),
        "data_confidence": "insufficient_data" if withheld else "ok",
        "withheld": withheld,
        **_last_night(cur, user_id, as_of, need),
        "research_notes": ["sleep_need_debt", "sleep_duration_mortality"],
    }


def _debt_withheld(
    cur: Cur, user_id: UUID, tz: str, today: date, day: date, debt_min: float
) -> dict | None:
    """Why there is no sleep debt for TODAY, or None when today's row is the newest."""
    reason = sleep_debt_unavailable_reason(cur, user_id, tz, today, day)
    if reason is None:
        return None
    return withheld_block(
        reason, SLEEP_DEBT_MESSAGES[reason], today, day, last_debt_min=round(debt_min)
    )


def _last_night(cur: Cur, user_id: UUID, as_of: date, need: float) -> dict:
    """The night ending on ``as_of``, and its Sleep Performance %, or a dated withhold.

    ``last_tst_min`` was the newest ``sleep_health_score_4dim`` row's TST with the day
    thrown away, and it drove ``performance_pct`` — so after a week without syncing, a
    field named "last night" and a percentage named "performance" both described a night
    a week ago. The percentage is the dependent claim and goes with it: a ratio of a
    stale night to today's need is not a number about either.
    """
    row = _last_tst(cur, user_id, as_of)
    last_day = row[0] if row else None
    reason = unavailable_reason(as_of, last_day)
    if row is not None and reason is None:
        return {
            "last_tst_min": round(row[1]),
            "last_tst_as_of_date": row[0].isoformat(),
            "performance_pct": sleep_performance_pct(row[1], need),
            "last_tst_withheld": None,
        }
    named = reason or NOT_DERIVED_YET
    return {
        "last_tst_min": None,
        "last_tst_as_of_date": None,
        "performance_pct": None,
        "last_tst_withheld": withheld_block(
            named,
            _LAST_TST_MESSAGES[named],
            as_of,
            last_day,
            last_tst_min=round(row[1]) if row else None,
        ),
    }


def sleep_performance_pct(last_tst: float | None, need: float) -> int | None:
    """Sleep Performance %: last night's actual sleep ÷ need, capped at 100% (one
    honest ratio, not a composite). Ported VERBATIM. [[sleep_need_debt]]."""
    if not (last_tst and need):
        return None
    return round(min(100.0, 100.0 * last_tst / need))


def _last_tst(cur: Cur, user_id: UUID, on_or_before: date) -> tuple[date, float] | None:
    """The newest night AT OR BEFORE ``on_or_before`` as ``(day, total sleep time)``.

    Returns the DAY as well as the value — dropping it here is where "last night's sleep"
    stopped meaning last night. The day bound is the other half of the same sentence:
    without it, "last night" on a past day would mean the most recent night there has
    ever been."""
    cur.execute(
        "SELECT day, (flags->>'tst_min')::float FROM derived_daily "
        "WHERE user_id = %s AND metric='sleep_health_score_4dim' AND flags ? 'tst_min' "
        "AND day <= %s ORDER BY day DESC LIMIT 1",
        (user_id, on_or_before),
    )
    r = cur.fetchone()
    return (r[0], float(r[1])) if r and r[1] is not None else None


def biological_age_payload(
    cur: Cur, user_id: UUID, tz: str, day: date | None = None
) -> dict | None:
    """Motivational biological-age estimate (Gompertz hazard→years). Thin wrapper over
    the shared analytics module. research/metrics/biological_age_estimate.md."""
    return compute_biological_age(cur, user_id, tz, day)


# How long a flag stays "active" after its date. ONE definition, shared by every
# reader below — "is this owner flagged ill right now?" must not have two answers
# (CLAUDE.md: one canonical definition per metric). [[illness_flag_plan]]
_ILLNESS_ACTIVE_DAYS = 2


def _latest_active_illness(
    cur: Cur, user_id: UUID, tz: str, today: date | None = None
) -> tuple | None:
    """The illness-flag row still active AS OF the anchor day, or None.

    The single source of truth for what "active" means; ``illness_flag_payload`` shapes
    it for the Today card and ``active_illness_severity`` reduces it to the one field
    the recovery guidance needs. Both run on the CALLER's cursor — no second
    transaction (these are RLS-scoped read paths).

    ``today`` is the owner's local anchor. It defaults to the wall clock because the
    Today page genuinely asks "right now", but a caller that already holds a pinned
    anchor passes it — otherwise the same request would read two different days if it
    straddled midnight, which is the calendar-date-vs-instant bug class this repo has
    already shipped twice. A past-day read passes that day, and the window then sits
    entirely behind it.

    The window has both ends, and the upper one is not decoration: "active" is a
    two-day span AROUND the anchor, so an open-topped window would let a flag raised
    last week make a day in June read as flagged ill.
    """
    anchor = reference_day(today, tz)
    cur.execute(
        "SELECT date, severity, rr_delta_bpm, temp_delta_c, sustained, research_note_ids "
        "FROM illness_flag WHERE user_id = %s AND date >= %s AND date <= %s "
        "ORDER BY date DESC LIMIT 1",
        (user_id, anchor - timedelta(days=_ILLNESS_ACTIVE_DAYS), anchor),
    )
    return cur.fetchone()


def active_illness_severity(
    cur: Cur, user_id: UUID, tz: str, today: date | None = None
) -> str | None:
    """'moderate' | 'high' if the owner is currently flagged ill, else None.

    Exists so ``read/recovery.py`` can let an active flag override push-style guidance
    without re-deciding what "active" means (or opening its own transaction), and so
    ``challenges/levers.py`` can apply [[recovery_readiness]] D7 to the same definition.
    """
    row = _latest_active_illness(cur, user_id, tz, today)
    return row[1] if row else None


def illness_flag_payload(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> dict | None:
    """Active illness flag (within 2 days of ``day``). Auto-clears when the deltas fall
    below threshold (no row → no flag). The "framing" is deterministic metric text,
    not LLM. [[respiratory_rate_normal]], [[skin_temp_signals]]."""
    row = _latest_active_illness(cur, user_id, tz, day)
    if not row:
        return None
    d, severity, rr_delta, temp_delta, sustained, note_ids = row
    return {
        "date": d.isoformat(),
        "severity": severity,
        "rr_delta_bpm": float(rr_delta) if rr_delta is not None else None,
        "temp_delta_c": float(temp_delta) if temp_delta is not None else None,
        "sustained": bool(sustained),
        "research_note_ids": list(note_ids or []),
        "framing": _illness_framing(rr_delta, temp_delta, sustained),
    }


def _illness_framing(rr_delta, temp_delta, sustained: bool) -> str:
    """Deterministic early-signal framing from the deltas (ported VERBATIM).

    The 14-day window is named in the sentence because a deviation is meaningless
    without it: [[respiratory_rate_normal]] ships THREE baseline windows (14 nights
    here, 42 days in ``recovery_score``, 30 in the anomaly layer) and its Coach
    Directive 1 is explicit — "never quote a '+X br/min above baseline' without saying
    which baseline".
    """
    parts: list[str] = []
    if rr_delta is not None:
        parts.append(f"breathing rate +{rr_delta:.1f} bpm vs your 14-day baseline")
    if temp_delta is not None:
        parts.append(f"skin temperature +{temp_delta:.2f}°C")
    suffix = (
        " — sustained across two nights, the Smarr 2020 / Quer 2021 pattern" if sustained else ""
    )
    return (
        "Possible early signal — consider lighter activity today. "
        f"{_sentence_case('; '.join(parts))}{suffix}. Not a diagnosis."
    )


def _sentence_case(text: str) -> str:
    """Upper-case the first character and leave every other one alone.

    NOT ``str.capitalize()``, which also lower-cases the rest — and so rendered the
    Celsius symbol as "+0.35°c" in every flag this string has ever produced, including
    the committed contract snapshot. The unit is the one part of the sentence whose
    case is not style, and the flag's whole job is to be quotable.
    """
    return text[:1].upper() + text[1:]


def pai_payload(cur: Cur, user_id: UUID) -> None:  # noqa: ARG001 — v2 gap: no pai metric
    """PAI is not derived in v2 (analytics/metrics.py lists pai_* DROPPED). Always
    None so the Today key stays present without fabricating a number. See report."""
    return None
