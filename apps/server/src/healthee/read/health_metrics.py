"""Sleep-debt, biological-age, illness-flag, and PAI payloads for the Today page.

v2-native reads (``derived_daily`` / ``illness_flag`` / ``profile``). The illness
"framing" and sleep-debt fields are metric-derived deterministic text, not LLM.

PAI (Personalized Activity Intelligence) is a documented v2 GAP: the ``derive``
layer does not emit ``pai_today`` / ``pai_total`` (analytics/metrics.py lists them
DROPPED), so ``pai_payload`` always returns ``None`` — the Today key stays present
(the app tolerates a null PAI card) but there is no v2 data behind it.
"""

from __future__ import annotations

from datetime import timedelta
from uuid import UUID

from healthee.analytics.biological_age import compute_biological_age
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur
from healthee.read.common import TodayReads, latest_derived


def sleep_debt_payload(cur: Cur, user_id: UUID, reads: TodayReads | None = None) -> dict | None:
    """Sleep need (NSF age-band) + rolling cumulative debt + Sleep Performance %.
    [[sleep_need_debt]]."""
    debt = (
        reads.latest.get("sleep_debt_min")
        if reads
        else latest_derived(cur, user_id, "sleep_debt_min")
    )
    if not debt:
        return None
    _day, debt_min, flags = debt
    need_row = (
        reads.latest.get("sleep_need_min")
        if reads
        else latest_derived(cur, user_id, "sleep_need_min")
    )
    need = need_row[1] if need_row else 480.0
    last_tst = _last_tst(cur, user_id)
    return {
        "need_min": round(need),
        "debt_min": round(debt_min),
        "last_tst_min": round(last_tst) if last_tst is not None else None,
        "performance_pct": sleep_performance_pct(last_tst, need),
        "avg_tst_min": flags.get("avg_tst_min"),
        "avg_deficit_min": flags.get("avg_deficit_min"),
        "nights_below": flags.get("nights_below"),
        "window_nights": flags.get("window_nights"),
        "nights": flags.get("nights"),
        "research_notes": ["sleep_need_debt", "sleep_duration_mortality"],
    }


def sleep_performance_pct(last_tst: float | None, need: float) -> int | None:
    """Sleep Performance %: last night's actual sleep ÷ need, capped at 100% (one
    honest ratio, not a composite). Ported VERBATIM. [[sleep_need_debt]]."""
    if not (last_tst and need):
        return None
    return round(min(100.0, 100.0 * last_tst / need))


def _last_tst(cur: Cur, user_id: UUID) -> float | None:
    """Last night's total sleep time from the sleep-score flags."""
    cur.execute(
        "SELECT (flags->>'tst_min')::float FROM derived_daily "
        "WHERE user_id = %s AND metric='sleep_health_score_4dim' AND flags ? 'tst_min' "
        "ORDER BY day DESC LIMIT 1",
        (user_id,),
    )
    r = cur.fetchone()
    return float(r[0]) if r and r[0] is not None else None


def biological_age_payload(cur: Cur, user_id: UUID, tz: str) -> dict | None:
    """Motivational biological-age estimate (Gompertz hazard→years). Thin wrapper over
    the shared analytics module. research/metrics/biological_age_estimate.md."""
    return compute_biological_age(cur, user_id, tz)


def illness_flag_payload(cur: Cur, user_id: UUID, tz: str) -> dict | None:
    """Latest active illness flag (within 2 days). Auto-clears when the deltas fall
    below threshold (no row → no flag). The "framing" is deterministic metric text,
    not LLM. [[respiratory_rate_normal]], [[skin_temp_signals]]."""
    cur.execute(
        "SELECT date, severity, rr_delta_bpm, temp_delta_c, sustained, research_note_ids "
        "FROM illness_flag WHERE user_id = %s AND date >= %s ORDER BY date DESC LIMIT 1",
        (user_id, user_today(tz) - timedelta(days=2)),
    )
    row = cur.fetchone()
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
    """Deterministic early-signal framing from the deltas (ported VERBATIM)."""
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
        f"{'; '.join(parts).capitalize()}{suffix}. Not a diagnosis."
    )


def pai_payload(cur: Cur, user_id: UUID) -> None:  # noqa: ARG001 — v2 gap: no pai metric
    """PAI is not derived in v2 (analytics/metrics.py lists pai_* DROPPED). Always
    None so the Today key stays present without fabricating a number. See report."""
    return None
