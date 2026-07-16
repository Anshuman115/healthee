"""The tenant owner constant — the ONE source of the sentinel in Python.

Phase 6.3a (MULTI_USER.md §8/§11). Every tenant-table write now sets `user_id`
explicitly, but the *source* of that id is still hardwired: the write entry points
(ingest service, write routers, job steps) pass `SENTINEL_USER_ID`. 6.4 flips those
call sites to the real authenticated user (`RequestUser.id` from the Supabase JWT /
device token) — the threading done here is what makes that a call-site change
rather than another sweep of the query layer.

The value matches the sentinel legacy owner seeded by `0003_tenant_column.sql`; in
6.4 that `app_user` row is re-keyed to the real Supabase UUID via the ON UPDATE
CASCADE FKs.
"""

from __future__ import annotations

from uuid import UUID

# The pre-auth legacy owner (matches 0003's sentinel). In 6.3 every write is
# attributed to it; 6.4 replaces these call sites with the real authenticated user.
SENTINEL_USER_ID: UUID = UUID("00000000-0000-0000-0000-000000000000")

__all__ = ["SENTINEL_USER_ID"]
