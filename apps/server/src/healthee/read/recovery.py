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
"guidance" string — DETERMINISTIC rule-based text, never an LLM field — moved to
``read/recovery_guidance.py`` when a second caller needed the band vocabulary and this
file was at the 400-line gate again.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from uuid import UUID

from healthee.analytics.baselines import compute_baseline_cur
from healthee.core.logging import get_logger
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur
from healthee.derive.freshness import NOT_DERIVED_YET, unavailable_reason, withheld_block
from healthee.derive.robust import median, median_abs_deviation, robust_sd
from healthee.read.common import TodayReads, latest_derived
from healthee.read.health_metrics import active_illness_severity
from healthee.read.recovery_guidance import daily_guidance, recovery_band

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
    band = recovery_band(recovery)
    illness = active_illness_severity(cur, user_id, tz)
    return {
        "recovery": recovery,
        "readiness": readiness,
        "guidance": daily_guidance(band, readiness, recovery, flags.get("factors", {}), illness),
        "date": day.isoformat(),
        "band": band,
        "factors": flags.get("factors", {}),
        "weights": flags.get("weights", {}),
        "strain_today": round(strain_today, 1) if strain_today is not None else None,
        "typical_strain": round(typical, 1) if typical is not None else None,
        "note_id": "recovery_readiness",
    }


# ── Is that score TODAY's? — one answer for both LLM surfaces ────────────────
#
# ``recovery_score_payload`` has always carried ``date``. Both prompt builders DROPPED it
# and relabelled the value: ``insights/coach_context._recovery_block`` wrote "## Today's
# recovery … let it set intensity advice" and ``jobs/recs_context._recovery_line`` wrote
# "SETS today's intensity ceiling". So an unsynced strap fed a days-old score to the model
# as today's readiness, and it drove the intensity prescription — the worst version of this
# defect, because the number never reaches a UI where a date could rescue it.
#
# The fix is not to hide the score. A stale recovery is still the most recent evidence we
# have, and DELETING it would remove the conservative ceiling ("never prescribe a hard
# session on low recovery") that [[recovery_readiness]] exists to impose — trading a
# mislabelled number for an unconstrained model is a worse trade. So the value is kept,
# dated, and the dependent claim ("today's", "sets the ceiling") is dropped.
RECOVERY_MESSAGES = {
    NOT_DERIVED_YET: "There is no recovery score for today yet — sync the strap.",
}

# The instruction that must accompany a stale score, in ONE place so the coach prompt and
# the recs prompt cannot drift apart on it (they are separate LLM surfaces enforcing the
# same rule — ARCHITECTURE.md's "a new rule must be added in both places").
STALE_RECOVERY_DIRECTIVE = (
    "This is NOT today's recovery and must not be presented as today's readiness. Today's "
    "has not been computed. Without a current score there is no intensity ceiling to "
    "quote: say so plainly and advise on the conservative side."
)


def recovery_freshness(payload: dict, tz: str) -> dict | None:
    """``None`` when the score IS the owner's today, else why it isn't and how old it is.

    The FACT is shared; the wording is not. Each prompt builder renders this in its own
    voice but neither gets to decide whether the score is current — that question has one
    answer (``derive/freshness.py``).
    """
    today = user_today(tz)
    last_day = date.fromisoformat(payload["date"])
    reason = unavailable_reason(today, last_day)
    if reason is None:
        return None
    return withheld_block(reason, RECOVERY_MESSAGES[reason], today, last_day)


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
    hist = [float(r[0]) for r in cur.fetchall() if r[0] is not None]
    if not (cr and cr[0] is not None and len(hist) >= 5):
        return recovery, None, None
    strain_today = float(cr[0])
    typical = median(hist) or 1.0
    return decayed_readiness(recovery, strain_today, typical), strain_today, typical


def decayed_readiness(recovery: int, strain_today: float, typical: float) -> int:
    """Live readiness = recovery × (1 − decay); decay = 0.5·min(1, strain/typical),
    capped at −50%. Ported VERBATIM (conservative, no validated intraday formula)."""
    decay = 0.5 * min(1.0, strain_today / typical) if typical > 0 else 0.0
    return round(recovery * (1 - decay))


def recovery_signals(
    cur: Cur, user_id: UUID, tz: str, reads: TodayReads | None = None
) -> dict | None:
    """Individual recovery markers (RHR / sleep duration / overnight HRV), each with
    its evidence citation. No composite score — the literature backs the markers
    individually but has no replicated composite formula. Ported to v2-native reads."""
    candidates = (
        _rhr_signal(cur, user_id, tz, reads),
        _sleep_signal(cur, user_id),
        _hrv_signal(cur, user_id, tz, reads),
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


def _rhr_signal(cur: Cur, user_id: UUID, tz: str, reads: TodayReads | None = None) -> dict | None:
    """Resting HR vs personal baseline — LOWER is favourable (Aune 2017)."""
    latest = reads.latest.get("rhr_daily") if reads else latest_derived(cur, user_id, "rhr_daily")
    if not latest:
        return None
    value = latest[1]
    b = (reads.baselines.get("rhr_daily") if reads else None) or compute_baseline_cur(
        cur, user_id, tz, "rhr_daily", window_days=30
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
    durs = [float(r[0]) for r in cur.fetchall() if r[0]]
    if len(durs) < 5:
        return None
    # The ONE median/MAD (``derive/robust``). This used to take the UPPER-middle value
    # of an even-length window rather than interpolating — not a median, and a second
    # definition of one alongside ``derive/recovery``'s. See that module's baseline.
    med = median(durs)
    z = (today_dur - med) / robust_sd(median_abs_deviation(durs), _SLEEP_MIN_SD_MIN)
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
        "baseline": med,
        "z": z,
        "direction": direction,
        "research_note_id": "sleep_duration_mortality",
    }


def _hrv_signal(cur: Cur, user_id: UUID, tz: str, reads: TodayReads | None = None) -> dict | None:
    """Overnight HRV vs personal usual — HIGHER is favourable (Plews 2013)."""
    latest = (
        reads.latest.get("hrv_sleep_avg")
        if reads
        else latest_derived(cur, user_id, "hrv_sleep_avg")
    )
    if not latest:
        return None
    value = latest[1]
    b = (reads.baselines.get("hrv_sleep_avg") if reads else None) or compute_baseline_cur(
        cur, user_id, tz, "hrv_sleep_avg", window_days=30
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


def _last_seen(cur: Cur, user_id: UUID, metric: str) -> datetime | None:
    """Newest sample instant for one feed — a targeted index probe, not a scan.

    Six of these beat the one grouped `SELECT metric, max(ts) … GROUP BY metric`
    they replace by ~580x. Measured with EXPLAIN (ANALYZE, BUFFERS) on a year of
    realistic multi-metric data (1.37 M rows / 53 chunks): grouped = 10,481 buffers;
    these six probes = 3 buffers each, 18 total. The grouped form's cost also scales
    with history, while a probe's does not.

    The mechanism is NOT our `0008` `timescaledb.enable_skipscan=off` workaround —
    measured identical with SkipScan on and off, because SkipScan applies to
    `DISTINCT ON`, not to `GROUP BY … max()`. The real reason is that `GROUP BY`
    defeats Postgres' min/max index rewrite: it reads every matching row to compute
    each group's max, where `ORDER BY ts DESC LIMIT 1` walks the index backwards and
    stops at the first row.

    So this is not "N+1 queries are fine". A round-trip per ITEM is still the thing
    standards §1 bans; six bounded probes on the caller's cursor against one scan of
    all history is a different trade, and the numbers are why it goes this way.
    """
    cur.execute(
        "SELECT ts FROM sample WHERE user_id = %s AND metric = %s ORDER BY ts DESC LIMIT 1",
        (user_id, metric),
    )
    row = cur.fetchone()
    return row[0] if row else None


def data_health_payload(cur: Cur, user_id: UUID) -> dict:
    """Per-feed freshness + sync recency so the app flags stale/dead data instead of
    rendering it as real. Conservative: only 'unavailable' when a feed delivered
    NOTHING within its cadence. Reads the v2 ``sample`` table (already v2-native)."""
    now = datetime.now(tz=UTC)
    items, degraded = [], []
    last_by_metric = {m: _last_seen(cur, user_id, m) for m, _, _ in _DATA_HEALTH_SPEC}
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
    """Sync recency = newest sample of ANY metric; overall trust rollup.

    The bare `max(ts)` with no metric filter is left exactly as it is, deliberately.
    Unlike the grouped scan `_last_seen` replaced, a plain ungrouped `max()` DOES get
    Postgres' min/max index rewrite: measured at 3 buffers on the 1.37 M-row year
    (Result -> ChunkAppend -> index scan of the newest chunk, every older chunk
    "never executed"). It is already optimal and derives no benefit from a metric
    filter or a probe rewrite — the `GROUP BY` was the whole problem, not `max(ts)`.
    """
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
