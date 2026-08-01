"""The coach's tools — real reads/writes the model MUST call, never guess (WP5b/WP-C5).

Seven tools are live (INTELLIGENCE §4). Five are declared here: ``query_metric``,
``compare_event``, ``sleep_consistency`` (reads), ``log_entry`` (write),
``get_knowledge`` (corpus). The two challenge tools — ``adopt_challenge`` and
``create_challenge`` — are declared and implemented in ``challenge_tools`` and spliced
into ``COACH_TOOLS`` below, because they carry a package dependency (``challenges``)
that the rest of this module does not, and their honesty rails need arguing at length.
``adopt_challenge`` was DEFERRED until the challenges subsystem existed — a tool that
cannot really adopt anything is the exact hallucination the anti-hallucination rule
forbids — and WP-C5 is where it stopped being a promise.

Each returns real JSON the model echoes; a tool that has no data says so honestly
rather than returning a fake number.

Every tool reads/writes v2-native through ``core.db`` (no v1 views, no source
filter) and reuses the existing read services — no second definition of a metric.
"""

from __future__ import annotations

import json
from datetime import date, timedelta
from typing import Any
from uuid import UUID

from healthee.analytics.metrics import EVENT_KINDS
from healthee.analytics.series import daily_series, event_days
from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger
from healthee.core.tenancy import user_today
from healthee.insights import challenge_tools, manifest
from healthee.insights.retrieval import rank_notes
from healthee.insights.tool_spec import function_tool
from healthee.read.logs import LogRequest, record_log
from healthee.read.sleep_extras import sleep_consistency as _sleep_consistency

log = get_logger(__name__)

# The action tools — a claim of "logged/started/adopted/created" is only truthful if
# one of these ran AND returned ok this turn (the anti-hallucination guard keys off
# this set, and ``coach._CLAIM_TOOLS`` narrows it per claim).
ACTION_TOOLS: frozenset[str] = frozenset({"log_entry"}) | challenge_tools.ACTION_TOOLS

_METRIC_HINT = (
    "rhr_daily, hrv_sleep_avg, sleep_health_score_4dim, sleep_regularity_index, "
    "recovery_score, steps_total, mvpa_min, cardio_load, active_calories, "
    "vo2max_estimate, sleep_debt_min, respiratory_rate_sleep, spo2_overnight"
)


COACH_TOOLS: list[dict] = [
    function_tool(
        "query_metric",
        "Look up the user's OWN measured data for a metric over a time range. Call "
        "whenever you need a number not already in CONTEXT — never invent one. "
        "Returns real values.",
        {
            "metric": {"type": "string", "description": "Metric key, one of: " + _METRIC_HINT},
            "days": {"type": "integer", "description": "Days back from today (1-365). Default 30."},
            "stat": {
                "type": "string",
                "enum": ["avg", "series", "latest", "min", "max", "sum", "trend"],
                "description": "aggregate (avg/min/max/sum), per-day (series), newest "
                "(latest), or first-vs-last (trend).",
            },
        },
        ["metric"],
    ),
    function_tool(
        "compare_event",
        "Compare a metric on days the user DID a logged thing vs days they didn't — "
        "'how did fasting affect my HRV', 'is my sleep better on meditation nights'. "
        "This is how you quantify a logged routine's effect on THEIR metrics.",
        {
            "event": {
                "type": "string",
                "description": "logged kind: fasting, caffeine, alcohol, meditation, "
                "exercise, or a custom habit name.",
            },
            "metric": {
                "type": "string",
                "description": "outcome metric key, e.g. hrv_sleep_avg, rhr_daily, "
                "recovery_score, sleep_regularity_index.",
            },
            "days": {"type": "integer", "description": "lookback window, default 60."},
        },
        ["event", "metric"],
    ),
    function_tool(
        "sleep_consistency",
        "The user's bedtime/wake REGULARITY over recent weeks: median bedtime, "
        "onset/wake SD, their SRI, and the irregular nights surfaced. Call for any "
        "question about sleep regularity, schedule steadiness, or why SRI is low.",
        {"days": {"type": "integer", "description": "lookback nights, default 28."}},
        [],
    ),
    function_tool(
        "log_entry",
        "Record something the user did/consumed, ONLY when they ask ('log a coffee', "
        "'start a fast', 'I weigh 79'). Acts on their data. Never claim you logged "
        "anything unless this returned ok.",
        {
            "type": {
                "type": "string",
                "enum": [
                    "caffeine",
                    "alcohol",
                    "water",
                    "meditation",
                    "exercise",
                    "weight",
                    "fast_start",
                    "fast_end",
                ],
            },
            "amount": {"type": "number", "description": "caffeine=mg, alcohol=units, weight=kg"},
            "minutes": {"type": "integer", "description": "for meditation / exercise"},
        },
        ["type"],
    ),
    function_tool(
        "get_knowledge",
        "Pull a research note from our graded corpus so you can ground a claim "
        "mid-conversation. Give a topic (e.g. 'sleep regularity mortality') or an "
        "exact note_id. Returns the note body + its evidence grade to cite.",
        {
            "topic": {"type": "string", "description": "a topic to search the corpus for"},
            "note_id": {"type": "string", "description": "an exact note id to fetch"},
        },
        [],
    ),
    # WP-C5's two, declared where their rails are argued (``challenge_tools``). Spliced
    # rather than re-declared so ``COACH_TOOLS`` stays the ONE list of what the model is
    # offered — ``tests/insights/test_coach_prompt.py`` pins the persona against it.
    *challenge_tools.CHALLENGE_TOOLS,
]


def execute_tool(name: str, args: dict[str, Any], user_id: UUID, tz: str) -> dict:
    """Dispatch one tool call to its implementation, acting ONLY on ``user_id``'s data.

    Unknown names fail honestly. The owner is threaded in from the authenticated
    request (6.4b) — no tool can reach a different tenant's rows.
    """
    if name == "query_metric":
        return query_metric(
            user_id, tz, str(args.get("metric", "")), args.get("days", 30), args.get("stat")
        )
    if name == "compare_event":
        return compare_event(
            user_id,
            tz,
            str(args.get("event", "")),
            str(args.get("metric", "")),
            args.get("days", 60),
        )
    if name == "sleep_consistency":
        with tenant_transaction(user_id) as cur:
            return _sleep_consistency(cur, user_id, tz, int(args.get("days", 28) or 28))
    if name == "log_entry":
        return log_entry(
            user_id, str(args.get("type", "")), args.get("amount"), args.get("minutes")
        )
    if name == "get_knowledge":
        return get_knowledge(args.get("topic"), args.get("note_id"))
    if name in challenge_tools.TOOL_NAMES:
        return challenge_tools.execute(name, args, user_id, tz)
    log.warning("coach requested unknown tool %s", name)
    return {"error": f"unknown tool {name}"}


def _clamp(value: Any, lo: int, hi: int, default: int) -> int:
    try:
        return max(lo, min(int(value), hi))
    except (TypeError, ValueError):
        return default


def query_metric(
    user_id: UUID, tz: str, metric: str, days: Any = 30, stat: str | None = None
) -> dict:
    """Aggregate/series/latest/trend for one metric from ``derived_daily`` (v2-native)."""
    days = _clamp(days, 1, 365, 30)
    stat = stat or "avg"
    cutoff = user_today(tz) - timedelta(days=days)
    with tenant_transaction(user_id) as cur:
        series = daily_series(cur, user_id, metric)
    windowed = {d: v for d, v in series.items() if d >= cutoff}
    if not windowed:
        return {"metric": metric, "days": days, "note": "no data for this metric/range"}
    ordered = [windowed[d] for d in sorted(windowed)]
    base: dict[str, Any] = {"metric": metric, "days": days, "n": len(ordered)}
    return {**base, **_stat_value(stat, windowed, ordered)}


def _stat_value(stat: str, windowed: dict[date, float], ordered: list[float]) -> dict:
    """The requested statistic over the windowed daily values."""
    if stat == "series":
        return {
            "series": [
                {"date": d.isoformat(), "value": round(v, 2)} for d, v in sorted(windowed.items())
            ]
        }
    if stat == "latest":
        newest = max(windowed)
        return {"latest": round(windowed[newest], 2), "as_of": newest.isoformat()}
    if stat == "min":
        return {"min": round(min(ordered), 2)}
    if stat == "max":
        return {"max": round(max(ordered), 2)}
    if stat == "sum":
        return {"sum": round(sum(ordered), 2)}
    if stat == "trend":
        return {
            "first": round(ordered[0], 2),
            "last": round(ordered[-1], 2),
            "change": round(ordered[-1] - ordered[0], 2),
        }
    return {"avg": round(sum(ordered) / len(ordered), 2)}


def compare_event(user_id: UUID, tz: str, event: str, metric: str, days: Any = 60) -> dict:
    """On-days vs off-days for a logged intervention — observational, single-subject."""
    days = _clamp(days, 7, 365, 60)
    cutoff = user_today(tz) - timedelta(days=days)
    ev = event.lower().strip()
    with tenant_transaction(user_id) as cur:
        on_days = _event_dates(cur, user_id, tz, ev)
        series = daily_series(cur, user_id, metric)
    daily = {d: v for d, v in series.items() if d >= cutoff}
    if not daily:
        return {"event": event, "metric": metric, "note": f"no data for metric {metric}"}
    if not on_days:
        return {"event": event, "note": f"no '{event}' logged yet — log it a few times first"}
    on = [v for d, v in daily.items() if d in on_days]
    off = [v for d, v in daily.items() if d not in on_days]
    if len(on) < 2 or len(off) < 2:
        return {
            "event": event,
            "metric": metric,
            "note": f"not enough days yet (on={len(on)}, off={len(off)}) — keep logging",
        }
    return _event_deltas(event, metric, on, off)


def _event_dates(cur: Any, user_id: UUID, tz: str, ev: str) -> set[date]:
    """Local dates the event occurred: a known EVENT_KIND, else any manual_entry kind/habit."""
    spec = EVENT_KINDS.get(ev)
    if spec:
        return event_days(cur, user_id, tz, spec[1])
    cur.execute(
        "SELECT DISTINCT (ts AT TIME ZONE %s)::date FROM manual_entry "
        "WHERE user_id = %s AND (kind=%s OR (kind='habit' AND name ILIKE %s))",
        (tz, user_id, ev, f"%{ev}%"),
    )
    return {r[0] for r in cur.fetchall()}


def _event_deltas(event: str, metric: str, on: list[float], off: list[float]) -> dict:
    """The on/off averages + delta, with the honest single-subject framing."""
    on_avg, off_avg = sum(on) / len(on), sum(off) / len(off)
    return {
        "event": event,
        "metric": metric,
        "on_days_avg": round(on_avg, 1),
        "off_days_avg": round(off_avg, 1),
        "n_on": len(on),
        "n_off": len(off),
        "delta": round(on_avg - off_avg, 1),
        "delta_pct": round((on_avg - off_avg) / off_avg * 100) if off_avg else None,
        "note": "observational, single-subject — a hint, not proof",
    }


def log_entry(user_id: UUID, entry_type: str, amount: Any = None, minutes: Any = None) -> dict:
    """Write one manual log (v2-native) via the shared read service. An ACTION tool."""
    req = LogRequest(
        type=entry_type,
        amount=float(amount) if amount is not None else None,
        minutes=int(minutes) if minutes is not None else None,
    )
    with tenant_transaction(user_id) as cur:
        return record_log(cur, user_id, req)


def get_knowledge(topic: str | None, note_id: str | None) -> dict:
    """Fetch a research note body + grade so the coach can cite it mid-conversation."""
    if note_id:
        note = manifest.by_id(note_id.strip())
        if note is None:
            return {"error": f"no note with id {note_id}"}
        return _note_payload(note.id)
    if topic:
        ranked = rank_notes(topic)
        if ranked:
            return _note_payload(ranked[0].id)
    return {"error": "give a topic or a note_id"}


def _note_payload(note_id: str) -> dict:
    """One note as a tool result. ``prompt_body``, because this lands in a prompt.

    The bibliography is dropped for the same reason retrieval drops it — the model can
    only cite ``[note_id]``, so author/year/DOI lines are tokens it cannot spend. Here
    they cost twice over: the payload is truncated at 4,000 characters, so a note whose
    references sat inside that window was handing the coach a reading list in place of
    the evidence it asked for.
    """
    note = manifest.by_id(note_id)
    body = manifest.prompt_body(note_id)
    return {
        "note_id": note_id,
        "name": note.name if note else "",
        "grade": note.grade if note else "",
        "cite_as": f"[{note_id}]",
        "body": body[:4000],
    }


def dumps(result: dict) -> str:
    """Serialize a tool result for the tool message (dates → iso via default=str)."""
    return json.dumps(result, default=str)
