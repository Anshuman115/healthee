"""Request identity for `/api/*` and `/ingest/*` — the 6.4b flip, TRANSITIONAL.

This module is the ONE place a request becomes a `RequestUser`. It exists as its own
file (rather than inside `core.supabase_auth`) because everything in it is scaffolding
with a scheduled demolition date: `supabase_auth` is the permanent Supabase resource-
server code, and this is the temporary bridge that lets the *un-rebuilt* mobile app —
which still holds only the single shared `REALTIME_INGEST_TOKEN` — keep working while
`/api/*` starts authenticating real users. Deleting the transition is deleting the
legacy branch of the two dependencies below (see `_legacy_shared_token`).

**Removal condition (MULTI_USER.md §4, §12.7):** the legacy branch goes when the
Phase-2 app ships Supabase login, or at 6.5, whichever comes first. It MUST NOT
survive into public signups: a shared secret that resolves to a real tenant would let
anyone holding it read and write that tenant's health data, which is exactly the
"server is the trust boundary" invariant §12.7 exists to protect. It is safe *today*
only because that secret already grants precisely this one tenant's data — the legacy
branch reproduces today's behaviour byte-for-byte and grants no new privilege.

## The ordering rule (why a rejected JWT can never become sentinel access)

The legacy constant-time comparison runs **first**, and the Supabase branch is the
`return` that follows it. So the two interpretations are ordered, not raced:

1. the presented token is compared (`hmac.compare_digest`) against the configured
   shared token → match means the sentinel owner, and nothing else is tried;
2. otherwise the token is handed to `supabase_auth.current_user`, whose every failure
   path *raises* 401.

There is no code after step 2 that could grant anything, so a malformed/expired/
tampered/alg-swapped JWT is terminal — it cannot "fall through" to the legacy branch,
because the legacy branch has already been evaluated and rejected it. This is
deliberately the inverse of a JWT-first design with a shape heuristic: a heuristic
("does this look like a JWT?") is a guard that has to be *maintained* correctly, while
ordering makes the fall-through structurally unrepresentable. It also removes a prod
hazard — a shared token that happened to be JWT-shaped would be misrouted by a
heuristic and break the live app.

Security note: never log a raw token. Only failure *types* and non-secret ids.
"""

from __future__ import annotations

import hmac
from typing import Annotated
from uuid import UUID

from fastapi import Depends, Header

from healthee.core.config import get_settings
from healthee.core.db import transaction
from healthee.core.logging import get_logger
from healthee.core.supabase_auth import (
    RequestUser,
    bearer_token,
    current_user,
    resolve_device_token,
    unauthorized,
)
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID

log = get_logger(__name__)


def _timezone_of(user_id: UUID) -> str | None:
    """The owner's IANA timezone from `app_user`, or None when they have no row."""
    with transaction() as cur:
        cur.execute("SELECT timezone FROM app_user WHERE id = %s", (str(user_id),))
        row = cur.fetchone()
    return row[0] if row else None


def _legacy_shared_token(presented: str) -> bool:
    """True iff `presented` is the single legacy shared token (TRANSITIONAL).

    Constant-time (`hmac.compare_digest`) so a wrong token can't be recovered by
    timing, and fails closed when the token is not configured: a blank
    `REALTIME_INGEST_TOKEN` authorizes *nobody* through this branch (it does not
    become "match everything"), exactly as the removed shared-token guard behaved.
    """
    expected = get_settings().realtime_ingest_token
    if not expected:
        return False
    return hmac.compare_digest(presented, expected)


def _sentinel_user() -> RequestUser:
    """The legacy shared token's owner: the sentinel tenant + ITS stored timezone.

    The timezone is read from the sentinel's `app_user` row rather than returned from
    the `SENTINEL_TZ` constant, so per-user timezone is real for this owner too — the
    row is the source of truth and the constant is only the last-resort fallback for a
    database whose sentinel row is missing, which is an anomaly worth logging.
    """
    tz = _timezone_of(SENTINEL_USER_ID)
    if tz is None:
        log.warning(
            "sentinel app_user row is missing — falling back to the compiled-in timezone %s",
            SENTINEL_TZ,
        )
        tz = SENTINEL_TZ
    return RequestUser(id=SENTINEL_USER_ID, timezone=tz)


def request_user(authorization: str | None = Header(default=None)) -> RequestUser:
    """FastAPI dependency: the authenticated tenant for an `/api/*` request.

    Supabase JWT → that real user (JIT-provisioned). Legacy shared token → the
    sentinel owner (TRANSITIONAL — see the module docstring). Anything else → 401.
    """
    if _legacy_shared_token(bearer_token(authorization)):
        return _sentinel_user()
    return current_user(authorization)


def ingest_user(authorization: str | None = Header(default=None)) -> RequestUser:
    """FastAPI dependency: the owner an `/ingest/*` push is attributed to (§7).

    Device token → its owner; legacy shared token → the sentinel (TRANSITIONAL). An
    unknown device token is 401: ingest under the wrong owner would be silent
    cross-tenant corruption of health data, so attribution is never guessed.
    """
    raw = bearer_token(authorization)
    if _legacy_shared_token(raw):
        return _sentinel_user()
    owner = resolve_device_token(raw)
    if owner is None:
        raise unauthorized("Invalid token")
    tz = _timezone_of(owner)
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
