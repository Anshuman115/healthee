"""The tenant owner constants — the ONE source of the sentinel in Python.

Phase 6.3a (MULTI_USER.md §8/§11). Every tenant-table write now sets `user_id`
explicitly, but the *source* of that id is still hardwired: the write entry points
(ingest service, write routers, job steps) pass `SENTINEL_USER_ID`. 6.4 flips those
call sites to the real authenticated user (`RequestUser.id` from the Supabase JWT /
device token) — the threading done here is what makes that a call-site change
rather than another sweep of the query layer.

Phase 6.3b extends the same shape to READS and to the timezone: every tenant-table
SELECT now filters `AND user_id = %s`, and the seven duplicate `Asia/Kolkata`
module constants collapsed into `SENTINEL_TZ`, threaded as an IANA name (`tz: str`)
alongside `user_id`. Read entry points (read routers, job steps, self-opening
insight surfaces) hardwire both constants exactly as the write path does.

Phase 6.3c adds `active_users()` — the first place an owner is DISCOVERED rather
than hardwired. The nightly sweep iterates it instead of firing one global chain, so
each owner's chain runs against their own data and their own local day.

The value matches the sentinel legacy owner seeded by `0003_tenant_column.sql`; in
6.4 that `app_user` row is re-keyed to the real Supabase UUID via the ON UPDATE
CASCADE FKs.
"""

from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from healthee.core.db import transaction

# The pre-auth legacy owner (matches 0003's sentinel). In 6.3 every write is
# attributed to it; 6.4 replaces these call sites with the real authenticated user.
SENTINEL_USER_ID: UUID = UUID("00000000-0000-0000-0000-000000000000")

# The sentinel owner's IANA timezone — matches the app_user row seeded by 0003.
# Transitional: 6.4 sources this from the authenticated user's app_user.timezone.
SENTINEL_TZ: str = "Asia/Kolkata"


@dataclass(frozen=True)
class Tenant:
    """One owner the science/jobs layers work on behalf of: their id + their zone.

    Deliberately NOT ``core.supabase_auth.RequestUser``: that type belongs to the
    auth edge and carries request concerns, and importing it here would couple the
    derive/analytics/jobs layers to authentication — which they must never know
    about (standards §"Modules depend downward only"; MULTI_USER.md §1.2: "the
    science is tenant-agnostic"). 6.4 converts a ``RequestUser`` into a ``Tenant``
    at the edge, so the request path and the job path hand the layers below the same
    shape.
    """

    id: UUID
    tz: str  # IANA name (app_user.timezone) — the owner's day boundary


def active_users() -> list[Tenant]:
    """Every active owner and their timezone — the set the nightly sweep iterates.

    Ordered by `created_at` so a sweep's order is deterministic (stable logs, and a
    reproducible sequence when a run is investigated). Suspended/deleted owners are
    excluded by `status`, so their chains stop without deleting their data.
    """
    with transaction() as cur:
        cur.execute("SELECT id, timezone FROM app_user WHERE status = 'active' ORDER BY created_at")
        return [Tenant(id=row[0], tz=row[1]) for row in cur.fetchall()]


__all__ = ["SENTINEL_TZ", "SENTINEL_USER_ID", "Tenant", "active_users"]
