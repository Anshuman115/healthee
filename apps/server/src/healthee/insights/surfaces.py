"""Insight surfaces — each builds a task, runs it through the choke point, caches.

Sleep / activity / per-metric / per-workout insights. Every one is a thin task
description handed to ``grounded_ask`` (the §3 choke point does context, retrieval,
refusal-gating, and blocking validation) then cached per day (``cache.py``). No
surface touches the LLM directly and none re-implements grounding — that is the
whole design (INTELLIGENCE §3/§4).

Only *validated* results are cached: a fallback (validation failed twice) is
returned uncached so a later refresh retries rather than pinning a non-answer for
the whole day.
"""

from __future__ import annotations

import statistics
import time
from datetime import datetime
from uuid import UUID

from healthee.analytics.series import daily_series
from healthee.core.db import transaction
from healthee.insights.cache import get_cached, set_cached, today_iso
from healthee.insights.grounded import grounded_ask

_SLEEP_PROMPT = (
    "Analyse my recent SLEEP in 4–6 short lines using my real numbers: typical "
    "duration vs the 7–9h need and the ~2-week trend; sleep architecture "
    "(deep/REM/light) — anything notably low; consistency (SRI, bed/wake steadiness); "
    "and the ONE highest-impact change with a concrete step. Cite [note_id] for every "
    "health claim; honest and supportive, never alarmist. No diagnosis."
)
_ACTIVITY_PROMPT = (
    "Coach me on my ACTIVITY & FITNESS in 4–6 short lines using my real numbers. Be "
    "direct — treat low fitness/inactivity as problems to FIX with a concrete weekly "
    "plan, never excuse them: my VO2max vs the age median and what the gap means for "
    "healthspan; whether I hit MVPA≥150min and my step target; my training load; and "
    "the ONE highest-impact move THIS week as specific sessions. Cite [note_id] for "
    "every health claim, scale intensity to my recovery. No diagnosis."
)


def _generate(
    user_id: UUID,
    tz: str,
    key: str,
    prompt: str,
    *,
    metrics: list[str],
    context_days: int,
    refresh: bool,
) -> dict:
    """Cache-or-generate one grounded surface. Only validated output is cached."""
    if not refresh:
        cached = get_cached(user_id, tz, key)
        if cached is not None:
            return cached
    result = grounded_ask(prompt, user_id, tz, metrics=metrics, context_days=context_days)
    out = {
        "insight": result.text,
        "citations": result.citations,
        "grade_floor": result.grade_floor,
        "refused": result.refused,
        "validated": result.validated,
        "date": today_iso(tz),
        "generated_at": int(time.time()),
    }
    if result.validated and not result.refused:
        set_cached(user_id, key, out)
    return out


def sleep_insight(user_id: UUID, tz: str, *, refresh: bool = False) -> dict:
    """Grounded analysis of ``user_id``'s recent sleep, cached per day."""
    return _generate(
        user_id,
        tz,
        "sleep_insight",
        _SLEEP_PROMPT,
        metrics=["sleep_health_score_4dim", "sleep_regularity_index", "hrv_sleep_avg"],
        context_days=14,
        refresh=refresh,
    )


def activity_insight(user_id: UUID, tz: str, *, refresh: bool = False) -> dict:
    """Grounded activity/fitness coaching for ``user_id``, cached per day."""
    return _generate(
        user_id,
        tz,
        "activity_insight",
        _ACTIVITY_PROMPT,
        metrics=["vo2max_estimate", "mvpa_min", "steps_total", "cardio_load"],
        context_days=14,
        refresh=refresh,
    )


def metric_insight(
    user_id: UUID, tz: str, metric: str, label: str = "", *, refresh: bool = False
) -> dict:
    """Grounded 1–2 line interpretation of one of ``user_id``'s metrics; '' if too thin."""
    key = f"metric_insight:{metric}"
    if not refresh:
        cached = get_cached(user_id, tz, key)
        if cached is not None:
            return cached
    numbers = _metric_numbers(user_id, metric)
    if numbers is None:
        return {"date": today_iso(tz), "metric": metric, "insight": "", "citations": []}
    prompt = (
        f"In 1–2 short sentences, interpret my {label or metric} for me right now. "
        f"{numbers} If it's off my baseline, give the most likely cause from my recent "
        "context plus one evidence-based lever. Cite [note_id] for any health claim; if "
        "nothing fits, say the cause is unclear. n=1, honest, no diagnosis."
    )
    result = grounded_ask(prompt, user_id, tz, metrics=[metric], context_days=14)
    out = {
        "date": today_iso(tz),
        "metric": metric,
        "insight": result.text,
        "citations": result.citations,
        "grade_floor": result.grade_floor,
        "validated": result.validated,
    }
    if result.validated and not result.refused:
        set_cached(user_id, key, out)
    return out


def _metric_numbers(user_id: UUID, metric: str) -> str | None:
    """A compact 'latest X, 30d median Y, recent [...]' line, or None if <3 points."""
    with transaction() as cur:
        series = daily_series(cur, user_id, metric)
    if len(series) < 3:
        return None
    ordered = [series[d] for d in sorted(series)]
    latest, med = ordered[-1], statistics.median(ordered)
    recent = [round(v) for v in ordered[-14:]]
    return f"Latest {latest:.0f}, 30-day median {med:.0f}; recent daily values (old→new): {recent}."


def workout_insight(user_id: UUID, tz: str, start: str, *, refresh: bool = False) -> dict:
    """Grounded coach review of ONE of ``user_id``'s workouts, cached per workout."""
    numbers = _workout_numbers(user_id, start)
    if numbers is None:
        return {"insight": "", "citations": [], "error": "workout not found"}
    key = f"workout_insight:{start}"
    if not refresh:
        cached = get_cached(user_id, tz, key)
        if cached is not None:
            return cached
    prompt = (
        "Review THIS single workout like a coach in 4–6 short lines: what went well; "
        "what was off (intensity/duration/HR drift); how it fits my goal of raising a "
        "low VO2max; and one concrete fix for the NEXT session. Cite [note_id] for "
        f"health claims. No diagnosis.\n\nWORKOUT:\n{numbers}"
    )
    result = grounded_ask(
        prompt,
        user_id,
        tz,
        metrics=["cardio_load", "vo2max_estimate"],
        context_days=7,
    )
    out = {
        "insight": result.text,
        "citations": result.citations,
        "grade_floor": result.grade_floor,
        "validated": result.validated,
        "date": today_iso(tz),
        "generated_at": int(time.time()),
    }
    if result.validated and not result.refused:
        set_cached(user_id, key, out)
    return out


def _workout_numbers(user_id: UUID, start: str) -> str | None:
    """One workout's summary line from the ``workout`` table, or None if absent."""
    try:
        ts = datetime.fromisoformat(start)
    except ValueError:
        return None
    with transaction() as cur:
        cur.execute(
            "SELECT sport, duration_s, calories, distance_m, avg_hr, max_hr FROM workout "
            "WHERE user_id = %s "
            "AND start_ts BETWEEN %s - interval '3 seconds' AND %s + interval '3 seconds' "
            "ORDER BY start_ts LIMIT 1",
            (user_id, ts, ts),
        )
        row = cur.fetchone()
    if not row:
        return None
    sport, dur_s, cal, dist, avg_hr, max_hr = row
    return (
        f"- sport code {sport}, duration {round((dur_s or 0) / 60)} min\n"
        f"- avg HR {avg_hr}, peak {max_hr}; calories {cal}; distance {round(dist or 0)} m"
    )
