"""The generated lines the product warms once per owner per local day.

Three texts the surfaces carry but do not author: the ``/api/today`` daily **action**,
the ``/api/sleep/consistency`` **tonight** line, and — since #95 — the **morning
briefing** body ``jobs.briefing`` Telegrams. All are generated through the §3 choke point
(``grounded_ask`` → validated) and cached per local day in ``kv``.

**The action and the briefing come from ONE call** (``insights.morning``): the briefing
task already asked for the action, so the product was paying twice for one answer. The
merge is a fast path, never a dependency — when it cannot ship, each surface falls back
to its own independent generation, so neither can be darkened by the other's sentence
(``morning``'s docstring argues the whole trade).

Read-path discipline (standards §Performance: "LLM generation never blocks a read
path"): the endpoints call ``cached_line`` which ONLY reads the cache and returns
``None`` when nothing is warmed. Generation happens off the read path in the
nightly per-owner chain, which calls ``warm_lines`` as its ``warm`` step
(``jobs/chain.py``) — so a cold ``/api/today`` never triggers an LLM call, and a
warmed one is served from ``kv``.

Every line is anchored to the OWNER's local day: ``today_iso(tz)`` stamps the
payload and ``get_cached`` only serves a payload stamped with the owner's today, so
two owners in different zones roll over independently (MULTI_USER.md §6).
"""

from __future__ import annotations

import time
from uuid import UUID

from healthee.core.logging import get_logger
from healthee.insights import morning as morning_mod
from healthee.insights.cache import get_cached, set_cached, today_iso
from healthee.insights.client import LLMClient
from healthee.insights.grounded import GroundedResult, grounded_ask

log = get_logger(__name__)

DAILY_ACTION_KEY = "coaching:daily_action"
SLEEP_TONIGHT_KEY = "coaching:sleep_tonight"
# The Telegram briefing BODY (briefing + the same action beneath it), warmed by the merged
# morning call so ``jobs.briefing`` can send it without generating a second time.
MORNING_BRIEFING_KEY = "coaching:morning_briefing"

_SLEEP_TONIGHT_PROMPT = (
    "In one short sentence, coach me on TONIGHT's sleep: the most useful thing to do "
    "this evening given my bedtime regularity and recent sleep. Concrete and specific "
    "to my numbers. Cite [note_id] for any health claim. No diagnosis, no alarmism."
)

# The metrics retrieval ranks each line's evidence notes against. Module constants
# rather than call-site literals so a test can rank the SHIPPED prompt against the
# SHIPPED metrics instead of a copy that drifts (task #23's retrieval guards do).
# The daily action's prompt/metrics/window live in ``insights.morning`` with the merged
# task they are assembled from — one statement of each ask, three prompts built from it.
SLEEP_TONIGHT_METRICS = ["sleep_regularity_index", "sleep_health_score_4dim", "sleep_debt_min"]
SLEEP_TONIGHT_CONTEXT_DAYS = 28


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
    """Warm EVERY generated line for ``user_id``'s local day. Returns a status dict.

    The one entry point the ``warm`` chain step calls: which lines the surfaces carry is
    this module's business, not the chain's, so adding a fourth line here needs no change
    to ``jobs/chain.py``.

    Cost: **two** LLM calls per owner per local day on the shipping path — the merged
    morning call (briefing + action, #95) and the sleep-tonight line — where it was three
    before, and the briefing step downstream now spends nothing at all. A merged call that
    cannot ship costs one more, by design (``morning``'s docstring). Bounded by the cache
    check, so a re-run of an already-warmed day (a forced chain, a second container) spends
    nothing.

    Never raises past a real transport failure: generation errors propagate to the
    chain's supervisor, which logs + Telegrams them (standards §1 — a failure here is
    reported, never swallowed into a permanently null card).
    """
    lines = {
        **warm_morning(user_id, tz, client=client, refresh=refresh),
        SLEEP_TONIGHT_KEY: warm_sleep_tonight(user_id, tz, client=client, refresh=refresh),
    }
    warmed = sorted(key for key, line in lines.items() if _is_shippable(line))
    expected = {MORNING_BRIEFING_KEY, DAILY_ACTION_KEY, SLEEP_TONIGHT_KEY}
    return {
        "ok": True,
        "day": today_iso(tz),
        "warmed": warmed,
        # A line the choke point refused or could not ground is a DEGRADED card, not a
        # crash: it stays uncached (the read serves None) and is named here so the
        # supervisor's log says which line is missing and why. A key that was never
        # ATTEMPTED (the briefing, when the merged call fell back) is degraded too — from
        # the reader's side "no line" is one fact, and `morning` logs which of the two it
        # was.
        "degraded": sorted(expected - set(warmed)),
    }


def warm_morning(
    user_id: UUID, tz: str, *, client: LLMClient | None = None, refresh: bool = False
) -> dict[str, dict]:
    """Fill BOTH morning surfaces from one call — or let the action fall back to its own.

    Returns the warmed payload per cache key, which is what ``warm_lines`` reports on. Two
    keys on the merged path (briefing + action), one on the fallback path (the action
    alone — the briefing then generates for itself inside ``jobs.briefing``, which is the
    only place that knows whether it is even running).

    The action cache is overwritten by a merged generation even when today already holds
    one (from an ``/api/today/action`` reveal): the briefing renders the action it was
    generated WITH, so leaving a different one cached would put two different "today's one
    thing" on two surfaces — the exact disagreement merging the calls removes.
    """
    if not refresh:
        cached = {
            key: payload
            for key in (MORNING_BRIEFING_KEY, DAILY_ACTION_KEY)
            if (payload := get_cached(user_id, tz, key)) is not None
        }
        if len(cached) == 2:
            return cached
    generated = morning_mod.generate_morning(user_id, tz, client=client)
    if generated is None:
        return {DAILY_ACTION_KEY: warm_daily_action(user_id, tz, client=client, refresh=refresh)}
    log.info("morning[%s] %s: one call filled the briefing and the action", user_id, today_iso(tz))
    shipped = generated.result
    return {
        MORNING_BRIEFING_KEY: _cache(user_id, tz, MORNING_BRIEFING_KEY, generated.message, shipped),
        DAILY_ACTION_KEY: _cache(user_id, tz, DAILY_ACTION_KEY, generated.action, shipped),
    }


def _is_shippable(line: dict) -> bool:
    """True iff a warmed line validated and was not refused — i.e. it was cached."""
    return bool(line.get("validated")) and not line.get("refused")


def warm_daily_action(
    user_id: UUID, tz: str, *, client: LLMClient | None = None, refresh: bool = False
) -> dict:
    """Generate + cache ``user_id``'s daily-action line ALONE (off the read path).

    The independent path, and the reason merging the morning call costs no availability:
    it is what ``/api/today/action`` generates on demand, and what ``warm_morning`` falls
    back to when the merged generation could not ship.
    """
    return _warm(
        user_id,
        tz,
        DAILY_ACTION_KEY,
        morning_mod.DAILY_ACTION_PROMPT,
        metrics=morning_mod.DAILY_ACTION_METRICS,
        context_days=morning_mod.DAILY_ACTION_CONTEXT_DAYS,
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
        context_days=SLEEP_TONIGHT_CONTEXT_DAYS,
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
    return _cache(user_id, tz, key, result.text, result)


def _cache(user_id: UUID, tz: str, key: str, text: str, result: GroundedResult) -> dict:
    """The warmed payload for one line — stored only when it is a line worth serving.

    ``text`` is passed separately from ``result`` because the briefing's stored text is
    ASSEMBLED from one result (body + the action beneath it) while every other line's is
    the answer itself. The grounding metadata is the generation's either way: two surfaces
    out of one judged answer publish one set of citations, not two invented ones.

    An unvalidated or refused line is returned to the caller (which reports it as degraded)
    and NOT cached: a read then serves ``None``, which says "nothing today" rather than
    showing text the validator rejected.
    """
    payload = {
        "text": text,
        "citations": result.citations,
        "grade_floor": result.grade_floor,
        "data_coverage": result.data_coverage,
        "refused": result.refused,
        "validated": result.validated,
        "date": today_iso(tz),
        "generated_at": int(time.time()),
    }
    if result.validated and not result.refused:
        set_cached(user_id, key, payload)
    return payload
