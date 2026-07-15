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

from healthee.derive._common import Cur
from healthee.read.common import user_today
from healthee.read.findings import top_findings
from healthee.read.fitness import (
    cardio_load_payload,
    mvpa_payload,
    strength_payload,
    vo2max_payload,
)
from healthee.read.health_metrics import (
    biological_age_payload,
    illness_flag_payload,
    pai_payload,
    sleep_debt_payload,
)
from healthee.read.recovery import (
    data_health_payload,
    recovery_score_payload,
    recovery_signals,
    routine_today,
)
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


def today_snapshot(cur: Cur) -> dict:
    """Assemble the whole Today payload from a single cursor."""
    payload = {"date": user_today().isoformat(), "metrics": secondary_cards(cur)}
    payload.update(_sleep_blocks(cur))
    payload.update(_metric_blocks(cur))
    payload.update(_signal_blocks(cur))
    payload.update(_series_blocks(cur))
    payload["anomalies"] = []  # legacy computed these live; app reads /api/notable (WP5)
    payload["top_findings"] = top_findings()
    return payload


def _sleep_blocks(cur: Cur) -> dict:
    """Last-night sleep + its physiology extras + 4-dim health + 7-night history."""
    session = latest_main_session(cur)
    extras = None
    if session is not None:
        extras = last_sleep_extras(cur, session[0], session[1])
    return {
        "last_sleep": last_sleep(session),
        "last_sleep_extras": extras,
        "sleep_health": sleep_health_today(cur),
        "sleep_history_7d": sleep_history_7d(cur),
    }


def _metric_blocks(cur: Cur) -> dict:
    """The headline metric payloads (each renders with its own breakdown)."""
    return {
        "pai": pai_payload(cur),  # WP7 gap: PAI not derived in v2 → None (see report)
        "mvpa": mvpa_payload(cur),
        "strength": strength_payload(cur),
        "vo2max": vo2max_payload(cur),
        "cardio_load": cardio_load_payload(cur),
        "sleep_debt": sleep_debt_payload(cur),
        "biological_age": biological_age_payload(cur),
        "illness_flag": illness_flag_payload(cur),
    }


def _signal_blocks(cur: Cur) -> dict:
    """Recovery + data-trust + routine + today's recommendations."""
    return {
        "recommendations": _recommendations_today(cur),
        "recovery": recovery_signals(cur),
        "recovery_score": recovery_score_payload(cur),
        "data_health": data_health_payload(cur),
        "routine": routine_today(cur),
    }


def _series_blocks(cur: Cur) -> dict:
    """Sparklines + today's intraday HR / step / stress shapes."""
    return {
        "sparklines": sparklines(cur),
        "today_hr_series": hr_hourly(cur),
        "today_step_buckets": step_buckets(cur),
        "today_stress_series": stress_series(cur),
    }


def _recommendations_today(cur: Cur) -> list[dict]:
    """Latest set of 1-3 recommendation rows (falls back up to 2 days). The row
    CONTENT is authored by WP5/WP8 into the ``recommendation`` table; here we only
    read the most-recent day's rows."""
    cur.execute(
        "SELECT id, date, rank, action, rationale, expected_effect, category, evidence_grade, "
        "  research_note_ids, signal_source, adopted FROM recommendation "
        "WHERE date >= %s ORDER BY date DESC, rank ASC",
        (user_today() - timedelta(days=2),),
    )
    rows = cur.fetchall()
    if not rows:
        return []
    latest_date = rows[0][1]
    return [_rec_shape(r) for r in rows if r[1] == latest_date]


def _rec_shape(r: tuple) -> dict:
    return {
        "id": r[0],
        "date": r[1].isoformat(),
        "rank": r[2],
        "action": r[3],
        "rationale": r[4],
        "expected_effect": r[5],
        "category": r[6],
        "evidence_grade": r[7],
        "research_note_ids": list(r[8] or []),
        "signal_source": r[9],
        "adopted": r[10],
    }
