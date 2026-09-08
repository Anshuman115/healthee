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
from healthee.core.db import tenant_transaction
from healthee.insights.cache import get_cached, get_stored, set_cached, today_iso
from healthee.insights.grounded import grounded_ask
from healthee.read.meta import metric_label

_SLEEP_PROMPT = (
    "Analyse my recent SLEEP in 4–6 short lines using my real numbers: typical "
    "duration vs the 7–9h need and the ~2-week trend; sleep architecture "
    "(deep/REM/light) — anything notably low; consistency (SRI, bed/wake steadiness); "
    "and the ONE highest-impact change with a concrete step. Cite [note_id] for every "
    "health claim; honest and supportive, never alarmist. No diagnosis."
)
# The "what the gap means for healthspan" this used to ask for was a request for exactly
# what `output_guard`'s personal_death_risk_number rule forbids, and the model obliged: the
# guardrail fired on 2 of 3 generations of this surface in a paid eval arm (#99), i.e. the
# surface was reliably buying an answer it could never ship. The guardrail is a safety
# floor and does not bend, so the ASK is what changed — to the half of the same evidence
# that is allowed to reach one person: what the gap does to what they can DO.
_ACTIVITY_PROMPT = (
    "Coach me on my ACTIVITY & FITNESS in 4–6 short lines using my real numbers. Be "
    "direct — treat low fitness/inactivity as problems to FIX with a concrete weekly "
    "plan, never excuse them: my VO2max vs the age median and what closing that gap "
    "would change about what I can DO — capacity, everyday fatigue, how hard normal "
    "effort feels (never a personal risk, mortality or life-expectancy number for me); "
    "whether I hit MVPA≥150min and my step target; my training load; and "
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
        "data_coverage": result.data_coverage,
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


def metric_insight(user_id: UUID, tz: str, metric: str, *, refresh: bool = False) -> dict:
    """Grounded 1–2 line interpretation of one of ``user_id``'s metrics; '' if too thin.

    The metric's own display name comes from ``read.meta.metric_label`` — the same one
    definition ``notable`` puts on a shift — rather than from the caller. A label supplied
    by the caller was an unvalidated string inside the prompt's task sentence AND absent
    from the cache key, so the day's cached text could disagree with the label that asked
    for it.
    """
    key = f"metric_insight:{metric}"
    if not refresh:
        cached = get_cached(user_id, tz, key)
        if cached is not None:
            return cached
    numbers = _metric_numbers(user_id, metric)
    if numbers is None:
        return {"date": today_iso(tz), "metric": metric, "insight": "", "citations": []}
    prompt = (
        f"In 1–2 short sentences, interpret my {metric_label(metric)} for me right now. "
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
        "data_coverage": result.data_coverage,
        "validated": result.validated,
    }
    if result.validated and not result.refused:
        set_cached(user_id, key, out)
    return out


def _metric_numbers(user_id: UUID, metric: str) -> str | None:
    """A compact 'latest X, 30d median Y, recent [...]' line, or None if <3 points."""
    with tenant_transaction(user_id) as cur:
        series = daily_series(cur, user_id, metric)
    if len(series) < 3:
        return None
    ordered = [series[d] for d in sorted(series)]
    latest, med = ordered[-1], statistics.median(ordered)
    recent = [round(v) for v in ordered[-14:]]
    return f"Latest {latest:.0f}, 30-day median {med:.0f}; recent daily values (old→new): {recent}."


def workout_insight(user_id: UUID, tz: str, start: str, *, refresh: bool = False) -> dict:
    """Grounded coach review of ONE of ``user_id``'s workouts, stored per workout.

    ## Why this one is stored rather than cached-per-day

    The key was already the workout (``workout_insight:{start}``) but it was read
    through ``get_cached``, which serves a payload only while its ``date`` is the
    owner's today. So opening a three-week-old session regenerated its review every
    day — each time against *this* week's context, while the session's own numbers
    stayed the session's. One fixed past workout was getting a different verdict
    depending on which day somebody scrolled past it, and paying for each one.
    ``get_stored`` keys it to the subject instead, which is what the key already said.

    ## The window is NAMED for what it covers, which is not the workout's week

    ``context_days=7`` is seven days ending at the owner's **today**, and it cannot be
    anything else: ``context.build_context`` takes no reference day, and that is a
    property worth keeping — it is the whole reason ``docs/AS_OF_DAY.md`` §6's "the LLM
    surfaces do not author past days" is structural here rather than remembered. So the
    context is not bent to the workout; the PROMPT is told what it is instead, and told
    to keep the two apart. A window named for a period it does not cover is the defect
    (the last audit raised the same class twice); a window named accurately is not.
    """
    numbers = _workout_numbers(user_id, start)
    if numbers is None:
        return {"insight": "", "citations": [], "error": "workout not found"}
    key = f"workout_insight:{start}"
    if not refresh:
        stored = get_stored(user_id, key)
        if stored is not None:
            return stored
    prompt = (
        "Review THIS single workout like a coach in 4–6 short lines: what went well; "
        "what was off (intensity/duration/HR drift); how it fits my goal of raising a "
        "low VO2max; and one concrete fix for the NEXT session of this kind. Cite "
        "[note_id] for health claims. No diagnosis.\n\n"
        "The WORKOUT below is the session under review, with its own numbers. The "
        "CONTEXT block is my LAST 7 DAYS UP TO TODAY, which may be long after this "
        "session — do not describe it as the week around this workout, and do not read "
        "a trend in it as something this session caused or was caused by."
        f"\n\nWORKOUT:\n{numbers}"
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
        "data_coverage": result.data_coverage,
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
    with tenant_transaction(user_id) as cur:
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
