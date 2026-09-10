"""Request identity for `/api/*` and `/ingest/*` — the ONE place a request becomes a user.

A request presents exactly one kind of credential and each path has exactly one
interpretation: `/api/*` takes a Supabase JWT (`supabase_auth.current_user`,
JIT-provisioning the `app_user` row), `/ingest/*` takes a device token minted by
this server for one phone (`core.device_token`). Anything else is 401.

## What used to be here, and why its absence is the point

Until 2026-09-10 both dependencies had a branch in front of them for a single shared
`REALTIME_INGEST_TOKEN` that resolved to one real tenant, never expired, and shipped
inside the APK. It was the bridge that kept the un-rebuilt app working while `/api/*`
learned to authenticate real people, and `MULTI_USER.md` section 4 always said it MUST NOT
survive into public signups — a static string that reads and writes a real owner's
health data is the whole "server is the trust boundary" invariant, inverted.

It is gone now: the owner signs in as themselves, their phone holds a device token of
its own, and the shared secret has been cleared in production and verified to 401 on
both paths. `refuse_a_shared_token_beside_open_signups` went with it — a validator
that existed to stop two settings coexisting has nothing to guard once one of them
does not exist, and `signups_open` is no longer gated on a removal that has happened.

**A missing `app_user` row is a 401, never a fallback.** Both dependencies below take
that line; `_active_timezone_of` returning None means the credential names an owner
who is not there, and authorising one of those is how a request ends up reading zero
rows under RLS while the person is told their data is missing.

Security note: never log a raw token. Only failure *types* and non-secret ids.
"""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import Depends, Header

from healthee.core.db import transaction
from healthee.core.device_token import resolve_device_token
from healthee.core.logging import get_logger
from healthee.core.supabase_auth import (
    RequestUser,
    bearer_token,
    current_user,
    refuse_unless_active,
    unauthorized,
)

log = get_logger(__name__)


def _active_timezone_of(user_id: UUID) -> str | None:
    """The owner's IANA timezone from `app_user`, or None when they have no row.

    Raises 403 for a row whose `status` is not `active`. `status` is selected here
    rather than in the callers because this is the one `app_user` read on the
    `/api/*` and `/ingest/*` paths, and a suspension that only some of them consult
    is not a suspension — see `supabase_auth.refuse_unless_active`.
    """
    with transaction() as cur:
        cur.execute("SELECT timezone, status FROM app_user WHERE id = %s", (str(user_id),))
        row = cur.fetchone()
    if row is None:
        return None
    refuse_unless_active(user_id, row[1])
    return row[0]


def request_user(authorization: str | None = Header(default=None)) -> RequestUser:
    """FastAPI dependency: the authenticated tenant for an `/api/*` request.

    Supabase JWT → that real user (JIT-provisioned). Anything else → 401.
    """
    return current_user(authorization)


def ingest_user(authorization: str | None = Header(default=None)) -> RequestUser:
    """FastAPI dependency: the owner an `/ingest/*` push is attributed to (§7).

    Device token → its owner. An unknown one is 401: ingest under the wrong owner
    would be silent cross-tenant corruption of health data, so attribution is never
    guessed.
    """
    owner = resolve_device_token(bearer_token(authorization))
    if owner is None:
        raise unauthorized("Invalid token")
    tz = _active_timezone_of(owner)
    if tz is None:
        # The device_token → app_user FK makes this unreachable; if it ever happens the
        # owner is unknowable, so refuse rather than write the push under a guess.
        log.warning("device token resolved to %s, which has no app_user row", owner)
        raise unauthorized("Invalid token")
    return RequestUser(id=owner, timezone=tz)


# The authenticated tenant, injected per-endpoint. The Annotated alias (not a
# `Depends(...)` default) is what keeps ruff B008 happy — same pattern as the
# identity router's, and `RequestUser` is the ONE canonical request-identity type.
CurrentUser = Annotated[RequestUser, Depends(request_user)]
IngestUser = Annotated[RequestUser, Depends(ingest_user)]

__all__ = ["CurrentUser", "IngestUser", "ingest_user", "request_user"]
