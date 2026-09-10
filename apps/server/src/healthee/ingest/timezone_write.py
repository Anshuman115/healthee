"""Adopt the phone's timezone as the owner's, before anything is bucketed by it.

## Why this exists

`app_user.timezone` decides the owner's DAY BOUNDARY: which day a sample belongs
to, when the nightly chain may run, and which dates `/api/today` will accept. It is
read everywhere and, until 2026-09-11, was written nowhere — so every account
provisioned from a Supabase sign-in kept the column default `UTC`.

For an owner in `Asia/Kolkata` that is not a cosmetic error. Measured on real data:
**27.9% of samples** fall in the 00:00–05:30 local window that UTC bucketing files
under the PREVIOUS day, and `/api/today` refused the phone's real local date as "in
the future" for five and a half hours every night.

## Why it is adopted BEFORE the push is applied

`ingest_helio` buckets this push's samples with the timezone it is holding. Writing
the new zone and then using the old one for the same request would leave the first
push after a move bucketed wrong — the exact failure this fixes, one push later.

## Why a bad name is ignored rather than rejected

An unparseable zone is a client bug, and the honest response to one is not to throw
away a push full of measurements that are perfectly good. The zone is dropped, the
push proceeds under the stored one, and the name is logged. Storing it would be
worse than ignoring it: every later read would raise on a zone that does not exist.
"""

from __future__ import annotations

from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from healthee.core.logging import get_logger
from healthee.derive._common import Cur

log = get_logger(__name__)


def adopt_timezone(cur: Cur, user_id: UUID, offered: str | None, current: str) -> str:
    """The timezone this push should be bucketed by, storing it when it changed.

    Returns `current` unchanged when the push offers nothing, offers the zone
    already held, or offers one this system cannot resolve.
    """
    if offered is None:
        return current
    name = offered.strip()
    if not name or name == current:
        return current
    try:
        ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError, KeyError):
        # The name, because it is the client's own string and an operator needs to
        # see which one to fix. Never the owner, never their data.
        log.warning("ingest offered an unresolvable timezone: %r", name)
        return current
    cur.execute("UPDATE app_user SET timezone = %s WHERE id = %s", (name, str(user_id)))
    log.info("owner %s moved timezone: %s -> %s", user_id, current, name)
    return name
