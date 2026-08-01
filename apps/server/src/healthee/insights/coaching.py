"""Short grounded coaching lines for the read surfaces (WP5a/WP7-deferred fields).

Two one-liners the read endpoints carry but do not author: the ``/api/today``
daily **action** and the ``/api/sleep/consistency`` **tonight** line. Both are
generated through the §3 choke point (``grounded_ask`` → validated) and cached per
local day in ``kv`` — exactly like the other insight surfaces.

Read-path discipline (standards §Performance: "LLM generation never blocks a read
path"): the endpoints call ``cached_line`` which ONLY reads the cache and returns
``None`` when nothing is warmed. Generation happens off the read path in the
nightly per-owner chain, which calls ``warm_lines`` as its ``warm`` step
(``jobs/chain.py``) — so a cold ``/api/today`` never triggers an LLM call, and a
warmed one is served from ``kv``.

Both lines are anchored to the OWNER's local day: ``today_iso(tz)`` stamps the
payload and ``get_cached`` only serves a payload stamped with the owner's today, so
two owners in different zones roll over independently (MULTI_USER.md §6).
"""

from __future__ import annotations

import time
from uuid import UUID

from healthee.insights.cache import get_cached, set_cached, today_iso
from healthee.insights.client import LLMClient
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

# The metrics retrieval ranks each line's evidence notes against. Module constants
# rather than call-site literals so a test can rank the SHIPPED prompt against the
# SHIPPED metrics instead of a copy that drifts (task #23's retrieval guards do).
DAILY_ACTION_METRICS = ["recovery_score", "mvpa_min", "cardio_load", "sleep_debt_min"]
SLEEP_TONIGHT_METRICS = ["sleep_regularity_index", "sleep_health_score_4dim", "sleep_debt_min"]


def cached_payload(user_id: UUID, tz: str, key: str) -> dict | None:
    """``user_id``'s whole cached line payload for ``key`` if warmed today, else None.

    The full payload rather than the text, for the one caller that needs the citations
    too (the metered reveal, ``api.routers.daily_action``). It exists here rather than
    letting a router reach into ``insights.cache`` because which cache key holds which
    line is this module's business — the same reason ``warm_lines`` exists.
    """
    return get_cached(user_id, tz, key)


def cached_line(user_id: UUID, tz: str, key: str) -> str | None:
    """``user_id``'s cached coaching text for ``key`` if warmed today, else None.

    Never generates — the read endpoints call this, and LLM generation must never
    block a read path (standards §Performance).
    """
    cached = cached_payload(user_id, tz, key)
    if cached is None:
        return None
    return cached.get("text")


def warm_lines(
    user_id: UUID, tz: str, *, client: LLMClient | None = None, refresh: bool = False
) -> dict:
    """Warm EVERY read-surface coaching line for ``user_id``'s local day. Returns a status dict.

    The one entry point the ``warm`` chain step calls: which lines the read surfaces
    carry is this module's business, not the chain's, so adding a third line here
    needs no change to ``jobs/chain.py``.

    Cost: one LLM call per line per owner per local day (2 today) — already inside
    PRICING.md §3.1's per-user budget. It is bounded by ``_warm``'s cache check, so a
    re-run of an already-warmed day (a forced chain, a second container) spends
    nothing.

    Never raises past a real transport failure: generation errors propagate to the
    chain's supervisor, which logs + Telegrams them (standards §1 — a failure here is
    reported, never swallowed into a permanently null card).
    """
    lines = {
        DAILY_ACTION_KEY: warm_daily_action(user_id, tz, client=client, refresh=refresh),
        SLEEP_TONIGHT_KEY: warm_sleep_tonight(user_id, tz, client=client, refresh=refresh),
    }
    warmed = sorted(key for key, line in lines.items() if _is_shippable(line))
    return {
        "ok": True,
        "day": today_iso(tz),
        "warmed": warmed,
        # A line the choke point refused or could not ground is a DEGRADED card, not a
        # crash: it stays uncached (the read serves None) and is named here so the
        # supervisor's log says which line is missing and why.
        "degraded": sorted(key for key in lines if key not in warmed),
    }


def _is_shippable(line: dict) -> bool:
    """True iff a warmed line validated and was not refused — i.e. it was cached."""
    return bool(line.get("validated")) and not line.get("refused")


def warm_daily_action(
    user_id: UUID, tz: str, *, client: LLMClient | None = None, refresh: bool = False
) -> dict:
    """Generate + cache ``user_id``'s daily-action line for today (off the read path)."""
    return _warm(
        user_id,
        tz,
        DAILY_ACTION_KEY,
        _DAILY_ACTION_PROMPT,
        metrics=DAILY_ACTION_METRICS,
        context_days=30,
        client=client,
        refresh=refresh,
    )


def warm_sleep_tonight(
    user_id: UUID, tz: str, *, client: LLMClient | None = None, refresh: bool = False
) -> dict:
    """Generate + cache ``user_id``'s sleep coaching line for tonight (off the read path)."""
    return _warm(
        user_id,
        tz,
        SLEEP_TONIGHT_KEY,
        _SLEEP_TONIGHT_PROMPT,
        metrics=SLEEP_TONIGHT_METRICS,
        context_days=28,
        client=client,
        refresh=refresh,
    )


def _warm(
    user_id: UUID,
    tz: str,
    key: str,
    prompt: str,
    *,
    metrics: list[str],
    context_days: int,
    client: LLMClient | None,
    refresh: bool,
) -> dict:
    """Cache-or-generate one grounded line through the choke point (validated only cached).

    ``client`` is injectable so the chain (and its tests) can drive a deterministic
    stub offline — the same seam ``step_recs``/``step_briefing`` use.
    """
    if not refresh:
        cached = get_cached(user_id, tz, key)
        if cached is not None:
            return cached
    result = grounded_ask(
        prompt, user_id, tz, metrics=metrics, context_days=context_days, client=client
    )
    out = {
        "text": result.text,
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
