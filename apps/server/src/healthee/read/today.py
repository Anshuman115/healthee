"""The Today page aggregator (``/api/today``).

One cursor, one pass: the secondary cards, last-night sleep, the metric payloads
(MVPA / VO2max / cardio-load / sleep-debt / bio-age / illness), the recovery
blocks, the data-trust card, today's intraday series, and the top findings.

WP5 (insights) OWNS the AI narrative that legacy embedded here — the daily
recommendation "action"/rationale text is written by the insights job into the
``recommendation`` table; this endpoint only READS whatever rows exist (so the
metric/data content is complete and the LLM text arrives when WP5/WP8 populate the
table). The legacy live-computed ``anomalies`` block stays ``[]`` exactly as
legacy returned it (the app reads notable shifts from ``/api/notable``, a WP5
endpoint).
"""

from __future__ import annotations

from datetime import timedelta
from uuid import UUID

from healthee.core.tenancy import user_today
from healthee.derive._common import Cur
from healthee.read.common import TodayReads, build_today_reads
from healthee.read.findings import top_findings
from healthee.read.fitness import (
    cardio_load_payload,
    mvpa_payload,
    strength_payload,
)
from healthee.read.health_metrics import (
    biological_age_payload,
    illness_flag_payload,
    pai_payload,
    sleep_debt_payload,
)
from healthee.read.recommendations import recommendation_shape
from healthee.read.recovery import (
    data_health_payload,
    recovery_score_payload,
    recovery_signals,
)
from healthee.read.routine import routine_today
from healthee.read.sleep_extras import (
    last_sleep,
    last_sleep_extras,
    latest_main_session,
    sleep_health_today,
    sleep_history_7d,
)
from healthee.read.today_series import (
    hr_hourly,
    secondary_cards,
    sparklines,
    step_buckets,
    stress_series,
)
from healthee.read.vo2max import vo2max_payload

# Metrics the aggregator preloads once (latest row per metric + 30-day baselines)
# so the per-card and recovery-signal payloads look them up instead of each
# issuing its own latest_derived + compute_baseline. Baselines are only needed for
# the metrics that carry a z-anomaly (the cards + RHR/HRV signals).
_LATEST_METRICS: tuple[str, ...] = (
    "rhr_daily", "steps_total", "active_calories", "total_calories", "basal_calories",
    "distance_m_daily", "hrv_sleep_avg", "recovery_score", "sleep_debt_min", "sleep_need_min",
)  # fmt: skip
_BASELINE_METRICS: tuple[str, ...] = (
    "rhr_daily", "steps_total", "active_calories", "total_calories", "basal_calories",
    "distance_m_daily", "hrv_sleep_avg",
)  # fmt: skip


def today_snapshot(cur: Cur, user_id: UUID, tz: str) -> dict:
    """Assemble the whole Today payload from a single cursor."""
    reads = build_today_reads(cur, user_id, tz, _LATEST_METRICS, _BASELINE_METRICS)
    payload = {
        "date": user_today(tz).isoformat(),
        "metrics": secondary_cards(cur, user_id, tz, reads),
    }
    payload.update(_sleep_blocks(cur, user_id, tz))
    payload.update(_metric_blocks(cur, user_id, tz, reads))
    payload.update(_signal_blocks(cur, user_id, tz, reads))
    payload.update(_series_blocks(cur, user_id, tz))
    payload["anomalies"] = []  # legacy computed these live; app reads /api/notable (WP5)
    payload["top_findings"] = top_findings(cur, user_id)
    return payload


def _sleep_blocks(cur: Cur, user_id: UUID, tz: str) -> dict:
    """Last-night sleep + its physiology extras + 4-dim health + 7-night history."""
    session = latest_main_session(cur, user_id)
    extras = None
    if session is not None:
        extras = last_sleep_extras(cur, user_id, session[0], session[1])
    return {
        "last_sleep": last_sleep(session),
        "last_sleep_extras": extras,
        "sleep_health": sleep_health_today(cur, user_id),
        "sleep_history_7d": sleep_history_7d(cur, user_id, tz),
    }


def _metric_blocks(cur: Cur, user_id: UUID, tz: str, reads: TodayReads) -> dict:
    """The headline metric payloads (each renders with its own breakdown)."""
    return {
        # WP7 gap: PAI not derived in v2 → None (see report)
        "pai": pai_payload(cur, user_id),
        "mvpa": mvpa_payload(cur, user_id, tz),
        "strength": strength_payload(cur, user_id, tz),
        "vo2max": vo2max_payload(cur, user_id, tz),
        "cardio_load": cardio_load_payload(cur, user_id, tz),
        "sleep_debt": sleep_debt_payload(cur, user_id, tz, reads),
        "biological_age": biological_age_payload(cur, user_id, tz),
        "illness_flag": illness_flag_payload(cur, user_id, tz),
    }


def _signal_blocks(cur: Cur, user_id: UUID, tz: str, reads: TodayReads) -> dict:
    """Recovery + data-trust + routine + today's recommendations."""
    return {
        "recommendations": _recommendations_today(cur, user_id, tz),
        "recovery": recovery_signals(cur, user_id, tz, reads),
        "recovery_score": recovery_score_payload(cur, user_id, tz, reads),
        "data_health": data_health_payload(cur, user_id),
        "routine": routine_today(cur, user_id, tz),
    }


def _series_blocks(cur: Cur, user_id: UUID, tz: str) -> dict:
    """Sparklines + today's intraday HR / step / stress shapes."""
    return {
        "sparklines": sparklines(cur, user_id, tz),
        "today_hr_series": hr_hourly(cur, user_id, tz),
        "today_step_buckets": step_buckets(cur, user_id, tz),
        "today_stress_series": stress_series(cur, user_id, tz),
    }


def _recommendations_today(cur: Cur, user_id: UUID, tz: str) -> list[dict]:
    """Latest set of 1-3 recommendation rows (falls back up to 2 days). The row
    CONTENT is authored by WP5/WP8 into the ``recommendation`` table; here we only
    read the most-recent day's rows."""
    cur.execute(
        "SELECT id, date, rank, action, rationale, expected_effect, category, evidence_grade, "
        "  research_note_ids, signal_source, adopted FROM recommendation "
        "WHERE user_id = %s AND date >= %s ORDER BY date DESC, rank ASC",
        (user_id, user_today(tz) - timedelta(days=2)),
    )
    rows = cur.fetchall()
    if not rows:
        return []
    latest_date = rows[0][1]
    return [recommendation_shape(r) for r in rows if r[1] == latest_date]
