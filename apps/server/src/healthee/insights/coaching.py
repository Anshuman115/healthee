"""Short grounded coaching lines for the read surfaces (WP5a/WP7-deferred fields).

Two one-liners the read endpoints carry but do not author: the ``/api/today``
daily **action** and the ``/api/sleep/consistency`` **tonight** line. Both are
generated through the §3 choke point (``grounded_ask`` → validated) and cached per
local day in ``kv`` — exactly like the other insight surfaces.

Read-path discipline (standards §Performance: "LLM generation never blocks a read
path"): the endpoints call ``cached_line`` which ONLY reads the cache and returns
``None`` when nothing is warmed. Generation happens off the read path via
``warm_daily_action`` / ``warm_sleep_tonight`` (a scheduler/refresh caller), so a
cold ``/api/today`` never triggers an LLM call.
"""

from __future__ import annotations

import time

from healthee.insights.cache import get_cached, set_cached, today_iso
from healthee.insights.grounded import grounded_ask

DAILY_ACTION_KEY = "coaching:daily_action"
SLEEP_TONIGHT_KEY = "coaching:sleep_tonight"

_DAILY_ACTION_PROMPT = (
    "In one or two short sentences, give me the single highest-impact thing to do "
    "TODAY, chosen from my recent data and today's recovery. Name the lever and one "
    "concrete move I can make today. Cite [note_id] for any health claim; be direct "
    "and kind, never alarmist. No diagnosis."
)
_SLEEP_TONIGHT_PROMPT = (
    "In one short sentence, coach me on TONIGHT's sleep: the most useful thing to do "
    "this evening given my bedtime regularity and recent sleep. Concrete and specific "
    "to my numbers. Cite [note_id] for any health claim. No diagnosis, no alarmism."
)


def cached_line(key: str) -> str | None:
    """The cached coaching text for ``key`` if warmed today, else None (never generates)."""
    cached = get_cached(key)
    if cached is None:
        return None
    return cached.get("text")


def warm_daily_action(*, refresh: bool = False) -> dict:
    """Generate + cache today's daily-action line (off the read path)."""
    return _warm(
        DAILY_ACTION_KEY,
        _DAILY_ACTION_PROMPT,
        metrics=["recovery_score", "mvpa_min", "cardio_load", "sleep_debt_min"],
        context_days=30,
        refresh=refresh,
    )


def warm_sleep_tonight(*, refresh: bool = False) -> dict:
    """Generate + cache tonight's sleep coaching line (off the read path)."""
    return _warm(
        SLEEP_TONIGHT_KEY,
        _SLEEP_TONIGHT_PROMPT,
        metrics=["sleep_regularity_index", "sleep_health_score_4dim", "sleep_debt_min"],
        context_days=28,
        refresh=refresh,
    )


def _warm(key: str, prompt: str, *, metrics: list[str], context_days: int, refresh: bool) -> dict:
    """Cache-or-generate one grounded line through the choke point (validated only cached)."""
    if not refresh:
        cached = get_cached(key)
        if cached is not None:
            return cached
    result = grounded_ask(prompt, metrics=metrics, context_days=context_days)
    out = {
        "text": result.text,
        "citations": result.citations,
        "grade_floor": result.grade_floor,
        "refused": result.refused,
        "validated": result.validated,
        "date": today_iso(),
        "generated_at": int(time.time()),
    }
    if result.validated and not result.refused:
        set_cached(key, out)
    return out
