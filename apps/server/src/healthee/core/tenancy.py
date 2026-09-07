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

Phase 6.4a finishes the timezone job by owning the day BOUNDARY as well as the
conversions: `USER_TODAY_SQL` + `user_today()` are the one definition of "the owner's
today", in SQL and in Python. 6.3b parameterized every `AT TIME ZONE`, but every
window still anchored to SQL `current_date` — the database session's date — so two
owners in different zones got identical windows. Those anchors are gone.

Phase 6.3c adds `active_users()` — the first place an owner is DISCOVERED rather
than hardwired. The nightly sweep iterates it instead of firing one global chain, so
each owner's chain runs against their own data and their own local day.

The value matches the sentinel legacy owner seeded by `0003_tenant_column.sql`; in
6.4 that `app_user` row is re-keyed to the real Supabase UUID via the ON UPDATE
CASCADE FKs.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from typing import LiteralString
from uuid import UUID
from zoneinfo import ZoneInfo

from healthee.core.db import transaction

# The pre-auth legacy owner (matches 0003's sentinel). In 6.3 every write is
# attributed to it; 6.4 replaces these call sites with the real authenticated user.
SENTINEL_USER_ID: UUID = UUID("00000000-0000-0000-0000-000000000000")

# The sentinel owner's IANA timezone — matches the app_user row seeded by 0003.
# Transitional: 6.4 sources this from the authenticated user's app_user.timezone.
SENTINEL_TZ: str = "Asia/Kolkata"

# "The owner's today" in SQL — the ONE canonical definition (CLAUDE.md), paired with
# the Python form `user_today()` below. Both take the owner's IANA zone, so they can
# never disagree about which day it is for that owner.
#
# NOT `current_date`: that resolves in the DATABASE SESSION's timezone (UTC in every
# environment we run), which is nobody's local day — it would anchor every owner's
# window to the same date no matter where they are, which is exactly what per-user
# timezones exist to prevent. `now()` is the transaction instant (absolute, so it is
# session-timezone independent); shifting it into the owner's zone before truncating
# to a date is what makes the day boundary theirs.
#
# The `%s` binds the owner's tz — a hardcoded constant fragment, safe to interpolate
# into a query string (standards §2), and typed LiteralString so composing it into an
# f-string keeps the result a LiteralString.
USER_TODAY_SQL: LiteralString = "(now() AT TIME ZONE %s)::date"


def user_today(tz: str) -> date:
    """Today's date in the owner's timezone — the Python form of ``USER_TODAY_SQL``."""
    return datetime.now(tz=ZoneInfo(tz)).date()


# "The day this read answers for" in SQL — ``USER_TODAY_SQL``'s as-of twin, and a bound
# DATE rather than an expression over the clock. Every read-layer window that used to
# subtract from ``USER_TODAY_SQL`` now subtracts from this, with :func:`reference_day`'s
# result bound in place of the timezone.
#
# It is a named constant and not an inline ``%s::date`` for one reason: the substitution
# is the whole of ``docs/AS_OF_DAY.md``'s section 3, and a grep for this name is what
# tells a reader which windows have been made answerable for a past day and which are
# still pinned to the wall clock. An anonymous cast would be invisible.
#
# The default is unchanged behaviour: ``reference_day(None, tz)`` IS ``user_today(tz)``,
# which is what ``USER_TODAY_SQL`` evaluates to for the same owner.
AS_OF_DAY_SQL: LiteralString = "%s::date"


def reference_day(day: date | None, tz: str) -> date:
    """The day a read answers for: ``day`` when one was asked for, else the owner's today.

    The ONE way an optional reference day is resolved (``docs/AS_OF_DAY.md`` section 2).
    It generalises the convention ``analytics/baselines.py`` already used
    (``end_date = end_date or user_today(tz)``) rather than inventing a second one, and it
    is a function rather than that idiom repeated so the default cannot drift: an ``or``
    would also swallow a falsy day, and every read that skipped the helper would be a
    place the owner's zone could stop being consulted.

    Nothing here validates the day, deliberately: this is the resolver, and the boundary
    is where a request is judged. ``api.validation.require_reference_day`` refuses a
    malformed date and a day in the owner's future — the second because every window
    would be bounded by it and every surface would withhold, so the payload would be
    technically honest while reading as "we have nothing for you" instead of "that day
    has not happened". Putting that judgement here as well would be a second opinion
    about what a day means, and the job path (jobs, ops tooling) legitimately asks for
    days this function must simply answer.
    """
    return day if day is not None else user_today(tz)


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


__all__ = [
    "AS_OF_DAY_SQL",
    "SENTINEL_TZ",
    "SENTINEL_USER_ID",
    "USER_TODAY_SQL",
    "Tenant",
    "active_users",
    "reference_day",
    "user_today",
]
