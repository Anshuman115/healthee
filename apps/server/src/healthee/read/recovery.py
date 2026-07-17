"""Recovery + data-trust payloads for the Today page.

``recovery_score_payload`` (0-100 morning recovery + live readiness decay),
``recovery_signals`` (individual favourable/unfavourable markers, no composite), and
``data_health_payload`` (per-feed freshness). All v2-native: ``derived_daily`` /
``sample`` / ``sleep_session``.

``routine_today`` lived here until the illness override pushed this file past the
400-line gate; it moved to ``read/routine.py``, which was the right home anyway —
logging what the owner DID today is not a recovery concern (standards §1: a file has
one reason to change).

The readiness-decay formula is ported VERBATIM (audit-verified). The recovery
"guidance" string is DETERMINISTIC rule-based text (band + lowest factor), not an
LLM field — legacy generated it in-process without a model, so it ports here.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID

from healthee.analytics.baselines import compute_baseline
from healthee.core.logging import get_logger
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur
from healthee.derive.robust import robust_sd
from healthee.read.common import TodayReads, latest_derived
from healthee.read.health_metrics import active_illness_severity

log = get_logger(__name__)

# Degenerate-history guard on the sleep signal's robust SD, in MINUTES — the units of
# the only baseline in this module that computes its own dispersion (`_sleep_signal`
# medians sleep-session durations; the RHR/HRV signals delegate to
# `analytics.baselines`, which is unfloored). It binds only when the trailing MAD is
# under ~0.67 min, i.e. a sleep history flat to within 40 seconds.
#
# NOT the 0.5 that [[recovery_readiness]] pins on the recovery derivation
# (derive/recovery.py:_AUTONOMIC_MIN_SD): that floor guards ms/bpm, this one guards
# minutes, and a floor is scale-dependent — the same number would mean something
# different here. Both descend from legacy, where the value tracked the FILE rather
# than the metric (legacy api/app.py:1908 floored sleep-MINUTES at 1.0 and :1967
# floored HRV-ms at 1.0, while v2/derive.py:745 floored the same HRV at 0.5). The
# rebuild left them on disjoint metrics, so they no longer contradict each other; they
# are kept distinct and named rather than unified, because unifying them would change
# an ungoverned metric's z-score with no note behind it.
_SLEEP_MIN_SD_MIN = 1.0

_BASE_GUIDANCE = {
    "high": "Well recovered — a good day to push: intervals or a harder session are on the table.",
    "moderate": "Moderate readiness — keep it easy-to-moderate (Zone 2 / brisk). "
    "Skip a hard session today.",
    "low": "Low readiness — prioritise recovery: easy movement only, and protect tonight's sleep.",
}
# An active illness flag OVERRIDES the band. The flag exists precisely to catch what a
# recovery score misses — respiratory rate and skin temperature move first, and the
# score does not weight them the way an infection does — so a "high" band must never
# clear a flagged owner to push. Without this, `/api/today` told an actively-flagged
# owner "a good day to push" in the SAME payload that rendered their illness card.
# Sourced: sports-science COACHING-RULES.md rule 6 ("Illness pause ... do not train
# through it — default to rest ... Illness symptoms veto hard training regardless of
# fresh form") and rule 13 ("readiness hard overrides are not votes ... never let
# high/green readiness clear a runner reporting illness").
# The recovery NUMBER is never dropped: the payload still reports `recovery` and `band`
# (hiding a measured number would be its own dishonesty). Only the GUIDANCE changes.
# [[respiratory_rate_normal]], [[skin_temp_signals]]
_ILLNESS_GUIDANCE = {
    "high": "An illness signal is active — it overrides today's recovery number. Rest "
    "today: easy movement at most, nothing hard, and protect tonight's sleep. "
    "Not a diagnosis.",
    "moderate": "An illness signal is active — it overrides today's recovery number. "
    "Keep today easy and skip anything hard until the signal clears. Not a diagnosis.",
}
_FACTOR_TAILS = {
    "sleep": " Short sleep is the main drag — an earlier night is your highest-leverage move.",
    "hrv": " HRV is below your baseline — your nervous system is still catching up.",
    "rhr": " Resting HR is up vs baseline — could be early strain or illness, so go easy.",
    "rr": " Breathing rate is elevated vs baseline — a possible early strain/illness signal; "
    "ease off.",
}


def recovery_score_payload(
    cur: Cur, user_id: UUID, tz: str, reads: TodayReads | None = None
) -> dict | None:
    """Morning recovery (0-100) + LIVE readiness that decays with today's strain.
    Always returns the per-factor breakdown so no bare number is shown.
    research/recovery/recovery_readiness.md."""
    latest = (
        reads.latest.get("recovery_score")
        if reads
        else latest_derived(cur, user_id, "recovery_score")
    )
    if not latest:
        return None
    day, score, flags = latest
    recovery = round(score)
    readiness, strain_today, typical = _live_readiness(cur, user_id, tz, day, recovery)
    band = "high" if recovery >= 67 else "moderate" if recovery >= 34 else "low"
    illness = active_illness_severity(cur, user_id, tz)
    return {
        "recovery": recovery,
        "readiness": readiness,
        "guidance": _guidance(band, readiness, recovery, flags.get("factors", {}), illness),
        "date": day.isoformat(),
        "band": band,
        "factors": flags.get("factors", {}),
        "weights": flags.get("weights", {}),
        "strain_today": round(strain_today, 1) if strain_today is not None else None,
        "typical_strain": round(typical, 1) if typical is not None else None,
        "note_id": "recovery_readiness",
    }


def _live_readiness(
    cur: Cur, user_id: UUID, tz: str, day, recovery: int
) -> tuple[int, float | None, float | None]:
    """Only TODAY's recovery decays (recovery is set at wake). Decay scales with
    today's cardio-load vs the personal 30-day median, capped at -50%. Ported
    VERBATIM — conservative + transparent (no validated intraday formula)."""
    if day != user_today(tz):
        return recovery, None, None
    cur.execute(
        "SELECT value FROM derived_daily WHERE user_id = %s AND metric='cardio_load' AND day=%s",
        (user_id, day),
    )
    cr = cur.fetchone()
    cur.execute(
        "SELECT value FROM derived_daily WHERE user_id = %s AND metric='cardio_load' "
        "AND day < %s AND day >= %s",
        (user_id, day, day - timedelta(days=30)),
    )
    hist = sorted(float(r[0]) for r in cur.fetchall() if r[0] is not None)
    if not (cr and cr[0] is not None and len(hist) >= 5):
        return recovery, None, None
    strain_today = float(cr[0])
    typical = hist[len(hist) // 2] or 1.0
    return decayed_readiness(recovery, strain_today, typical), strain_today, typical


def decayed_readiness(recovery: int, strain_today: float, typical: float) -> int:
    """Live readiness = recovery × (1 − decay); decay = 0.5·min(1, strain/typical),
    capped at −50%. Ported VERBATIM (conservative, no validated intraday formula)."""
    decay = 0.5 * min(1.0, strain_today / typical) if typical > 0 else 0.0
    return round(recovery * (1 - decay))


def _base_guidance(band: str, illness: str | None) -> str:
    """The guidance ceiling: an active illness flag replaces the band's text entirely."""
    if illness is None:
        return _BASE_GUIDANCE[band]
    override = _ILLNESS_GUIDANCE.get(illness)
    if override is None:
        # Unreachable: the schema CHECK-constrains severity to moderate|high. But an
        # unrecognised severity must fail SAFE (toward rest), never fall through to "a
        # good day to push" — that silent fall-through is the bug this function fixes.
        log.warning("unknown illness severity %r — using the strictest guidance", illness)
        return _ILLNESS_GUIDANCE["high"]
    return override


def _guidance(band: str, readiness: int, recovery: int, factors: dict, illness: str | None) -> str:
    """Deterministic, evidence-grounded daily guidance (NOT LLM): the band sets the
    ceiling — unless an active illness flag overrides it (see ``_ILLNESS_GUIDANCE``) —
    and the lowest-scoring factor names the lever. Band/tail logic ported VERBATIM."""
    tail = ""
    limiter = min(factors.items(), key=lambda kv: kv[1].get("sub", 50)) if factors else None
    if limiter and limiter[1].get("sub", 50) < 45:
        tail = _FACTOR_TAILS.get(limiter[0], "")
    if readiness < recovery - 8:
        tail += " Today's training has already used some of your capacity."
    return _base_guidance(band, illness) + tail


def recovery_signals(cur: Cur, user_id: UUID, reads: TodayReads | None = None) -> dict | None:
    """Individual recovery markers (RHR / sleep duration / overnight HRV), each with
    its evidence citation. No composite score — the literature backs the markers
    individually but has no replicated composite formula. Ported to v2-native reads."""
    candidates = (
        _rhr_signal(cur, user_id, reads),
        _sleep_signal(cur, user_id),
        _hrv_signal(cur, user_id, reads),
    )
    signals = [s for s in candidates if s]
    if not signals:
        return None
    favorable = sum(1 for s in signals if s["direction"] == "favorable")
    unfavorable = sum(1 for s in signals if s["direction"] == "unfavorable")
    summary = (
        "Recovery signals lean favorable"
        if favorable > unfavorable
        else "Recovery signals lean unfavorable"
        if unfavorable > favorable
        else "Mixed recovery signals"
    )
    return {
        "summary": summary,
        "favorable": favorable,
        "unfavorable": unfavorable,
        "neutral": len(signals) - favorable - unfavorable,
        "total": len(signals),
        "signals": signals,
    }


def _rhr_signal(cur: Cur, user_id: UUID, reads: TodayReads | None = None) -> dict | None:
    """Resting HR vs personal baseline — LOWER is favourable (Aune 2017)."""
    latest = reads.latest.get("rhr_daily") if reads else latest_derived(cur, user_id, "rhr_daily")
    if not latest:
        return None
    value = latest[1]
    b = (reads.baselines.get("rhr_daily") if reads else None) or compute_baseline(
        user_id, "rhr_daily", window_days=30
    )
    if b.median is None or not b.robust_sd:
        return None
    z = (value - b.median) / b.robust_sd
    direction = "favorable" if z < -0.3 else "unfavorable" if z > 0.5 else "neutral"
    return {
        "name": "Resting HR",
        "value": value,
        "unit": "bpm",
        "baseline": b.median,
        "z": z,
        "direction": direction,
        "research_note_id": "resting_hr_health_marker",
    }


def _sleep_signal(cur: Cur, user_id: UUID) -> dict | None:
    """Last night's total sleep vs personal usual — Cappuccio 2010 (v2: TST from
    sleep_session stage minutes)."""
    cur.execute(
        "SELECT (light_min+deep_min+rem_min) FROM sleep_session "
        "WHERE user_id = %s AND kind='main' ORDER BY start_ts DESC LIMIT 1",
        (user_id,),
    )
    row = cur.fetchone()
    if not row or not row[0]:
        return None
    today_dur = float(row[0])
    cur.execute(
        "SELECT (light_min+deep_min+rem_min) FROM sleep_session "
        "WHERE user_id = %s AND kind='main' AND start_ts > now() - interval '30 days'",
        (user_id,),
    )
    durs = sorted(float(r[0]) for r in cur.fetchall() if r[0])
    if len(durs) < 5:
        return None
    median = durs[len(durs) // 2]
    mad = sorted(abs(d - median) for d in durs)[len(durs) // 2]
    z = (today_dur - median) / robust_sd(mad, _SLEEP_MIN_SD_MIN)
    direction = (
        "favorable"
        if today_dur >= 360 and z > -0.5
        else "unfavorable"
        if today_dur < 300 or z < -1
        else "neutral"
    )
    return {
        "name": "Sleep duration",
        "value": today_dur,
        "unit": "min",
        "baseline": median,
        "z": z,
        "direction": direction,
        "research_note_id": "sleep_duration_mortality",
    }


def _hrv_signal(cur: Cur, user_id: UUID, reads: TodayReads | None = None) -> dict | None:
    """Overnight HRV vs personal usual — HIGHER is favourable (Plews 2013)."""
    latest = (
        reads.latest.get("hrv_sleep_avg")
        if reads
        else latest_derived(cur, user_id, "hrv_sleep_avg")
    )
    if not latest:
        return None
    value = latest[1]
    b = (reads.baselines.get("hrv_sleep_avg") if reads else None) or compute_baseline(
        user_id, "hrv_sleep_avg", window_days=30
    )
    if b.median is None or not b.robust_sd:
        return None
    z = (value - b.median) / b.robust_sd
    direction = "favorable" if z > 0.3 else "unfavorable" if z < -0.5 else "neutral"
    return {
        "name": "Overnight HRV",
        "value": round(value, 1),
        "unit": "ms",
        "baseline": round(b.median, 1),
        "z": z,
        "direction": direction,
        "research_note_id": "hrv_recovery_marker",
    }


# (raw metric, label, expected-cadence days). A feed silent longer than this is dead.
_DATA_HEALTH_SPEC = [
    ("hr", "Heart rate", 2),
    ("steps_per_minute", "Steps", 2),
    ("hrv", "HRV", 4),
    ("spo2", "Blood oxygen", 4),
    ("respiratory_rate", "Breathing", 4),
    ("stress", "Stress", 3),
]


def data_health_payload(cur: Cur, user_id: UUID) -> dict:
    """Per-feed freshness + sync recency so the app flags stale/dead data instead of
    rendering it as real. Conservative: only 'unavailable' when a feed delivered
    NOTHING within its cadence. Reads the v2 ``sample`` table (already v2-native)."""
    now = datetime.now(tz=UTC)
    items, degraded = [], []
    # One grouped scan for all feeds' last-seen instead of a probe per metric.
    cur.execute(
        "SELECT metric, max(ts) FROM sample "
        "WHERE user_id = %s AND metric = ANY(%s) GROUP BY metric",
        (user_id, [m for m, _, _ in _DATA_HEALTH_SPEC]),
    )
    last_by_metric = {m: ts for m, ts in cur.fetchall()}
    for metric, label, days in _DATA_HEALTH_SPEC:
        last = last_by_metric.get(metric)
        age_h = (now - last).total_seconds() / 3600 if last else None
        status = "unavailable" if (age_h is None or age_h > days * 24) else "ok"
        if status != "ok":
            degraded.append(label)
        items.append(
            {
                "metric": metric,
                "label": label,
                "last_iso": last.isoformat() if last else None,
                "age_h": round(age_h, 1) if age_h is not None else None,
                "status": status,
            }
        )
    return _sync_recency(cur, user_id, now, items, degraded)


def _sync_recency(cur: Cur, user_id: UUID, now, items: list[dict], degraded: list[str]) -> dict:
    """Sync recency = newest sample of ANY metric; overall trust rollup."""
    cur.execute("SELECT max(ts) FROM sample WHERE user_id = %s", (user_id,))
    r = cur.fetchone()
    newest = r[0] if r and r[0] else None
    age_h = (now - newest).total_seconds() / 3600 if newest else None
    sync_status = (
        "unavailable"
        if age_h is None
        else "ok"
        if age_h <= 8
        else "stale"
        if age_h <= 24
        else "very_stale"
    )
    overall = "ok" if (sync_status == "ok" and not degraded) else "degraded"
    return {
        "overall": overall,
        "sync_status": sync_status,
        "synced_age_h": round(age_h, 1) if age_h is not None else None,
        "synced_iso": newest.isoformat() if newest else None,
        "degraded": degraded,
        "items": items,
    }
