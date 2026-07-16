"""Per-day kv cache for generated LLM text — the daily-warm caching element.

Insight generation is expensive and never belongs on a read or sync path
(standards §Performance: "LLM endpoints … cached per day; generation never blocks
a sync or a read path"). Each surface caches its result in the ``kv`` table keyed
by a stable string; a cached payload is served only while its ``date`` matches
the owner's local today, so text is regenerated at most once per local day.
"""

from __future__ import annotations

import json
from datetime import datetime
from uuid import UUID
from zoneinfo import ZoneInfo

from healthee.core.db import transaction
from healthee.core.logging import get_logger

log = get_logger(__name__)


def today_iso(tz: str) -> str:
    """Today's date in the owner's timezone, ISO-formatted — the cache freshness key.

    The day boundary matches derive/analytics anchoring; ``tz`` is threaded from the
    entry point (6.3b) rather than read from a module constant."""
    return datetime.now(tz=ZoneInfo(tz)).date().isoformat()


def get_cached(user_id: UUID, tz: str, key: str) -> dict | None:
    """Return ``user_id``'s cached payload for ``key`` iff generated today, else None.

    A malformed cache row is a degraded state, not a crash: it is logged and treated
    as a miss (the caller regenerates), never silently returned as good.
    """
    with transaction() as cur:
        cur.execute("SELECT value FROM kv WHERE user_id = %s AND key = %s", (user_id, key))
        row = cur.fetchone()
    if not row:
        return None
    try:
        payload = json.loads(row[0])
    except (json.JSONDecodeError, TypeError) as exc:
        log.warning("kv cache %s is unparseable (%s) — treating as a miss", key, exc)
        return None
    return payload if payload.get("date") == today_iso(tz) else None


def set_cached(user_id: UUID, key: str, value: dict) -> None:
    """Upsert ``user_id``'s generated payload under ``key`` (expects a ``date`` field).

    The kv key itself stays un-namespaced BY DESIGN: 0004 folded the owner into the kv
    PRIMARY KEY and `get_cached` filters by it, so two users' same-named entries are
    already distinct rows that cannot collide. Prefixing the string with the user id
    would state the tenant twice — in the key column and again inside the key — so it
    is not done (MULTI_USER.md §6).
    """
    with transaction() as cur:
        cur.execute(
            "INSERT INTO kv (user_id, key, value) VALUES (%s, %s, %s) "
            "ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value",
            (user_id, key, json.dumps(value)),
        )
