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

from datetime import date, timedelta
from uuid import UUID

from healthee.core.tenancy import reference_day, user_today
from healthee.derive._common import Cur
from healthee.read.common import TodayReads, as_of_block, build_today_reads
from healthee.read.data_health import data_health_payload
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


def today_snapshot(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> dict:
    """Assemble the whole Today payload from a single cursor, AS OF one day.

    ``day`` defaults to the owner's today, so an unchanged caller gets an unchanged
    answer. Given an older one, every block below is read from the rows filed under it
    (``docs/AS_OF_DAY.md``) — the reference day is resolved ONCE here and threaded, so no
    two blocks of one payload can disagree about which day they describe. That is the
    same reason ``_latest_active_illness`` already took a pinned anchor: a request that
    straddled midnight would otherwise answer for two days at once.
    """
    as_of = reference_day(day, tz)
    reads = build_today_reads(cur, user_id, tz, _LATEST_METRICS, _BASELINE_METRICS, as_of)
    payload = {
        "date": as_of.isoformat(),
        "as_of": as_of_block(cur, user_id, tz, as_of),
        "metrics": secondary_cards(cur, user_id, tz, reads, as_of),
    }
    payload.update(_sleep_blocks(cur, user_id, tz, as_of))
    payload.update(_metric_blocks(cur, user_id, tz, reads, as_of))
    payload.update(_signal_blocks(cur, user_id, tz, reads, as_of))
    payload.update(_series_blocks(cur, user_id, tz, as_of))
    payload["anomalies"] = []  # legacy computed these live; app reads /api/notable (WP5)
    payload["top_findings"] = top_findings(cur, user_id, tz, day=as_of)
    return payload


def _sleep_blocks(cur: Cur, user_id: UUID, tz: str, as_of: date) -> dict:
    """The night ending on the day + its physiology extras + 4-dim health + 7 nights."""
    session = latest_main_session(cur, user_id, tz, as_of)
    extras = None
    if session is not None:
        extras = last_sleep_extras(cur, user_id, session[0], session[1])
    return {
        "last_sleep": last_sleep(session),
        "last_sleep_extras": extras,
        "sleep_health": sleep_health_today(cur, user_id, tz, as_of),
        "sleep_history_7d": sleep_history_7d(cur, user_id, tz, as_of),
    }


def _metric_blocks(cur: Cur, user_id: UUID, tz: str, reads: TodayReads, as_of: date) -> dict:
    """The headline metric payloads (each renders with its own breakdown)."""
    return {
        # WP7 gap: PAI not derived in v2 → None (see report)
        "pai": pai_payload(cur, user_id),
        "mvpa": mvpa_payload(cur, user_id, tz, as_of),
        "strength": strength_payload(cur, user_id, tz, as_of),
        "vo2max": vo2max_payload(cur, user_id, tz, as_of),
        "cardio_load": cardio_load_payload(cur, user_id, tz, as_of),
        "sleep_debt": sleep_debt_payload(cur, user_id, tz, reads, as_of),
        "biological_age": biological_age_payload(cur, user_id, tz, as_of),
        "illness_flag": illness_flag_payload(cur, user_id, tz, as_of),
    }


def _signal_blocks(cur: Cur, user_id: UUID, tz: str, reads: TodayReads, as_of: date) -> dict:
    """Recovery + data-trust + routine + the day's recommendations."""
    return {
        "recommendations": _recommendations_for(cur, user_id, as_of),
        "recovery": recovery_signals(cur, user_id, tz, reads, as_of),
        "recovery_score": recovery_score_payload(cur, user_id, tz, reads, as_of),
        # **Null on any day but the owner's today, and that is not a gap.** Every field in
        # this block — how many hours since the last sample, whether a feed is dead — is
        # measured against the request instant, so it is an observation made AFTER a past
        # day and cannot be one of that day's facts. The app already renders a null
        # `data_health` by drawing nothing (`today_snapshot.dart`), which is the right
        # answer: the trust card is about the live feeds, and there are none in June.
        "data_health": data_health_payload(cur, user_id) if as_of == user_today(tz) else None,
        "routine": routine_today(cur, user_id, tz, as_of),
    }


def _series_blocks(cur: Cur, user_id: UUID, tz: str, as_of: date) -> dict:
    """Sparklines + the day's intraday HR / step / stress shapes.

    The three intraday series were already per-day queries over raw ``sample`` rows with
    the wall clock supplying the day, so they answer for an older one unchanged. The
    ``today_`` prefixes are wire names the app parses and are left alone — renaming a
    contract key to improve a sentence is a breaking change for a comment's sake.
    """
    return {
        "sparklines": sparklines(cur, user_id, tz, as_of),
        "today_hr_series": hr_hourly(cur, user_id, tz, as_of),
        "today_step_buckets": step_buckets(cur, user_id, tz, as_of),
        "today_stress_series": stress_series(cur, user_id, tz, as_of),
    }


def _recommendations_for(cur: Cur, user_id: UUID, as_of: date) -> list[dict]:
    """The newest set of 1-3 recommendation rows at or before ``as_of`` (2-day reach).

    **Read, never regenerated.** ``docs/AS_OF_DAY.md`` puts the LLM surfaces out of scope
    because writing a past day's analysis now would be a new claim rather than a record —
    but these rows are already written, already dated, and already stored, exactly as
    ``derived_daily`` is. Serving the row filed under 29 July as 29 July's is the same
    move the whole document is built on; the thing not done here is authoring one.
    """
    cur.execute(
        "SELECT id, date, rank, action, rationale, expected_effect, category, evidence_grade, "
        "  research_note_ids, signal_source, adopted FROM recommendation "
        "WHERE user_id = %s AND date >= %s AND date <= %s ORDER BY date DESC, rank ASC",
        (user_id, as_of - timedelta(days=2), as_of),
    )
    rows = cur.fetchall()
    if not rows:
        return []
    latest_date = rows[0][1]
    return [recommendation_shape(r) for r in rows if r[1] == latest_date]
