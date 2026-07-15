"""Per-day kv cache for generated LLM text — the daily-warm caching element.

Insight generation is expensive and never belongs on a read or sync path
(standards §Performance: "LLM endpoints … cached per day; generation never blocks
a sync or a read path"). Each surface caches its result in the ``kv`` table keyed
by a stable string; a cached payload is served only while its ``date`` matches
today (IST), so text is regenerated at most once per local day.
"""

from __future__ import annotations

import json
from datetime import datetime
from zoneinfo import ZoneInfo

from healthee.core.db import transaction
from healthee.core.logging import get_logger

log = get_logger(__name__)

# User-local day boundary for cache freshness — matches derive/analytics anchoring.
_USER_TZ = ZoneInfo("Asia/Kolkata")


def today_iso() -> str:
    """Today's date in the user's timezone, ISO-formatted — the cache freshness key."""
    return datetime.now(tz=_USER_TZ).date().isoformat()


def get_cached(key: str) -> dict | None:
    """Return the cached payload for ``key`` iff it was generated today, else None.

    A malformed cache row is a degraded state, not a crash: it is logged and treated
    as a miss (the caller regenerates), never silently returned as good.
    """
    with transaction() as cur:
        cur.execute("SELECT value FROM kv WHERE key = %s", (key,))
        row = cur.fetchone()
    if not row:
        return None
    try:
        payload = json.loads(row[0])
    except (json.JSONDecodeError, TypeError) as exc:
        log.warning("kv cache %s is unparseable (%s) — treating as a miss", key, exc)
        return None
    return payload if payload.get("date") == today_iso() else None


def set_cached(key: str, value: dict) -> None:
    """Upsert a generated payload under ``key`` (expects a ``date`` field on it)."""
    with transaction() as cur:
        cur.execute(
            "INSERT INTO kv (key, value) VALUES (%s, %s) "
            "ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value",
            (key, json.dumps(value)),
        )
