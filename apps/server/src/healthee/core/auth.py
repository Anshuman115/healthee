"""Bearer-token auth — the FastAPI dependency guarding /ingest/* and /api/*.

Single-tenant: one shared token (`REALTIME_INGEST_TOKEN`) the mobile app sends as
`Authorization: Bearer <token>`. Compared in constant time (`hmac.compare_digest`)
so a wrong token can't be recovered by timing the response. A blank configured
token rejects everything — there is no unauthenticated bypass.

Routers depend on it with `Depends(require_token)`; it returns `None` on success
and raises 401 with a clear body otherwise.
"""

from __future__ import annotations

import hmac

from fastapi import Header, HTTPException, status

from healthee.core.config import get_settings

_BEARER_PREFIX = "Bearer "


def require_token(authorization: str | None = Header(default=None)) -> None:
    """FastAPI dependency: authorize a request by its Bearer token.

    Raises 401 when the header is missing, malformed, or the token doesn't match
    the configured `REALTIME_INGEST_TOKEN`. Returns `None` on success.
    """
    expected = get_settings().realtime_ingest_token
    if not expected:
        # Misconfiguration (no token set) must fail closed, never open.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Server auth is not configured",
        )
    if not authorization or not authorization.startswith(_BEARER_PREFIX):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or malformed Bearer token",
        )
    presented = authorization[len(_BEARER_PREFIX) :].strip()
    if not hmac.compare_digest(presented, expected):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )
