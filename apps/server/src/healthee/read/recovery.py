"""Recovery + data-trust payloads for the Today page.

``recovery_score_payload`` (0-100 morning recovery + live readiness decay),
``recovery_signals`` (individual favourable/unfavourable markers, no composite),
``data_health_payload`` (per-feed freshness), and ``routine_today``. All v2-native:
``derived_daily`` / ``sample`` / ``sleep_session`` / ``manual_entry`` / ``workout``.

The readiness-decay formula is ported VERBATIM (audit-verified). The recovery
"guidance" string is DETERMINISTIC rule-based text (band + lowest factor), not an
LLM field — legacy generated it in-process without a model, so it ports here.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID

from healthee.analytics.baselines import compute_baseline
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur
from healthee.read.common import TodayReads, latest_derived, sport_name

_MAD_TO_SD = 1.4826  # MAD→σ for a normal distribution [[baselines]]

_BASE_GUIDANCE = {
    "high": "Well recovered — a good day to push: intervals or a harder session are on the table.",
    "moderate": "Moderate readiness — keep it easy-to-moderate (Zone 2 / brisk). "
    "Skip a hard session today.",
    "low": "Low readiness — prioritise recovery: easy movement only, and protect tonight's sleep.",
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
    return {
        "recovery": recovery,
        "readiness": readiness,
        "guidance": _guidance(band, readiness, recovery, flags.get("factors", {})),
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


def _guidance(band: str, readiness: int, recovery: int, factors: dict) -> str:
    """Deterministic, evidence-grounded daily guidance (NOT LLM): the band sets the
    ceiling and the lowest-scoring factor names the lever. Ported VERBATIM."""
    tail = ""
    limiter = min(factors.items(), key=lambda kv: kv[1].get("sub", 50)) if factors else None
    if limiter and limiter[1].get("sub", 50) < 45:
        tail = _FACTOR_TAILS.get(limiter[0], "")
    if readiness < recovery - 8:
        tail += " Today's training has already used some of your capacity."
    return _BASE_GUIDANCE[band] + tail


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
    z = (today_dur - median) / max(mad * _MAD_TO_SD, 1.0)
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


def routine_today(cur: Cur, user_id: UUID, tz: str) -> dict:
    """Open fast + today's meditation, workouts, and manual-log counts."""
    return {
        "open_fast": _open_fast(cur, user_id),
        "meditation_today": _meditation_today(cur, user_id, tz),
        "workouts": _workouts_today(cur, user_id, tz),
        "logs_summary": _logs_summary(cur, user_id, tz),
    }


def _open_fast(cur: Cur, user_id: UUID) -> dict | None:
    cur.execute(
        "SELECT id, ts FROM manual_entry WHERE user_id = %s AND kind='fasting' "
        "AND end_ts IS NULL ORDER BY ts DESC LIMIT 1",
        (user_id,),
    )
    row = cur.fetchone()
    if not row:
        return None
    elapsed = int((datetime.now(tz=UTC) - row[1]).total_seconds() // 60)
    return {"id": str(row[0]), "start_iso": row[1].isoformat(), "elapsed_min": elapsed}


def _meditation_today(cur: Cur, user_id: UUID, tz: str) -> dict:
    cur.execute(
        "SELECT COUNT(*), COALESCE(SUM(amount),0) FROM manual_entry "
        "WHERE user_id = %s AND kind='meditation' AND (ts AT TIME ZONE %s)::date = %s",
        (user_id, tz, user_today(tz)),
    )
    c, m = cur.fetchone() or (0, 0)
    return {"count": int(c or 0), "minutes": int(m or 0)}


def _workouts_today(cur: Cur, user_id: UUID, tz: str) -> list[dict]:
    """Today's device workouts (>=10 min), newest first."""
    cur.execute(
        "SELECT start_ts, duration_s, sport FROM workout WHERE user_id = %s "
        "AND (start_ts AT TIME ZONE %s)::date = %s AND COALESCE(duration_s,0) >= 600 "
        "ORDER BY start_ts DESC",
        (user_id, tz, user_today(tz)),
    )
    out = []
    for start_ts, dur_s, sport in cur.fetchall():
        dur_min = round((dur_s or 0) / 60) if dur_s else None
        end_iso = (start_ts + timedelta(seconds=int(dur_s or 0))).isoformat() if start_ts else None
        out.append(
            {
                "kind": "workout",
                "type": sport_name(sport),
                "start_iso": start_ts.isoformat() if start_ts else None,
                "end_iso": end_iso,
                "duration_min": dur_min,
                "intensity": None,
                "source": "strap",
            }
        )
    return out


def _logs_summary(cur: Cur, user_id: UUID, tz: str) -> dict:
    cur.execute(
        "SELECT kind, COUNT(*), COALESCE(SUM(amount),0) FROM manual_entry "
        "WHERE user_id = %s AND (ts AT TIME ZONE %s)::date = %s GROUP BY kind",
        (user_id, tz, user_today(tz)),
    )
    return {k: {"count": int(c), "total": float(t or 0)} for k, c, t in cur.fetchall()}
