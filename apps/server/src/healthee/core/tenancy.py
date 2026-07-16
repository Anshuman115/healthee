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

The value matches the sentinel legacy owner seeded by `0003_tenant_column.sql`; in
6.4 that `app_user` row is re-keyed to the real Supabase UUID via the ON UPDATE
CASCADE FKs.
"""

from __future__ import annotations

from uuid import UUID

# The pre-auth legacy owner (matches 0003's sentinel). In 6.3 every write is
# attributed to it; 6.4 replaces these call sites with the real authenticated user.
SENTINEL_USER_ID: UUID = UUID("00000000-0000-0000-0000-000000000000")

# The sentinel owner's IANA timezone — matches the app_user row seeded by 0003.
# Transitional: 6.4 sources this from the authenticated user's app_user.timezone.
SENTINEL_TZ: str = "Asia/Kolkata"

__all__ = ["SENTINEL_TZ", "SENTINEL_USER_ID"]
