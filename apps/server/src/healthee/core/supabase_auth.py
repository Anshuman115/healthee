"""Supabase identity — verify the access JWT and resolve the tenant user.

Phase 6.1 (MULTI_USER.md §4). Supabase is the managed auth provider: it issues
the access JWT (HS256, signed with the legacy shared secret `SUPABASE_JWT_SECRET`).
This backend is a *resource server* — it only ever VERIFIES that token, never mints
one. `verify_supabase_jwt` checks signature + `exp` + `aud` + (optional) `iss` and
pins the algorithm to HS256 so an `alg=none` (or asymmetric-confusion) token is
rejected outright. `current_user` turns a verified token into a `RequestUser`,
JIT-provisioning the local `app_user` mirror on first sight — subject to the signup
gate (`_provision_user`), which is where invite-only is actually enforced.

Phase 6.4b wired this to every `/api/*` router through `core.request_auth`, which
layers the transitional legacy-shared-token branch on top of `current_user`. The
primitives here stay Supabase-only: this module never knows about the shared token.

Security note: never log the raw JWT, the signing secret, or a raw device token —
only the *type* of a verification failure is logged.
"""

from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from typing import Any
from uuid import UUID

import jwt
from fastapi import Header, HTTPException, status

from healthee.core.config import get_settings
from healthee.core.db import transaction
from healthee.core.logging import get_logger

log = get_logger(__name__)

_BEARER_PREFIX = "Bearer "
# Pin the accepted algorithm. Passing an explicit allow-list to jwt.decode is what
# makes an `alg=none` (or RS256→HS256 key-confusion) token fail — "none" is never
# in this list, so PyJWT raises InvalidAlgorithmError before any claim is trusted.
_ALLOWED_ALGS = ["HS256"]
_DEVICE_TOKEN_BYTES = 32  # secrets.token_urlsafe entropy — ~43 url-safe chars


@dataclass(frozen=True)
class RequestUser:
    """The authenticated tenant for a request: the Supabase UUID + their timezone."""

    id: UUID
    timezone: str


def unauthorized(detail: str) -> HTTPException:
    """A 401 with a clear, secret-free body."""
    return HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=detail)


def forbidden(detail: str) -> HTTPException:
    """A 403 with a clear, secret-free body.

    403, NOT 401: a refused signup authenticated perfectly well — the token is
    valid and we know exactly who they are. What they lack is permission to create
    an account. 401 would mean "your credentials failed", inviting the client to
    retry the login it just completed successfully; 403 says the honest thing.
    """
    return HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=detail)


def _expected_issuer(project_ref: str) -> str | None:
    """The issuer Supabase stamps for a project, or None to skip the `iss` check."""
    if not project_ref:
        return None
    return f"https://{project_ref}.supabase.co/auth/v1"


def verify_supabase_jwt(token: str) -> dict[str, Any]:
    """Verify a Supabase access JWT (HS256) and return its claims.

    Enforces: HMAC signature against `SUPABASE_JWT_SECRET`, presence + validity of
    `exp`, `aud == SUPABASE_JWT_AUD`, and — when `SUPABASE_PROJECT_REF` is set —
    `iss == https://<ref>.supabase.co/auth/v1`. Raises 401 on any failure. Pinning
    `algorithms=["HS256"]` rejects `alg=none` and algorithm-confusion tokens.
    """
    settings = get_settings()
    secret = settings.supabase_jwt_secret
    if not secret:  # misconfiguration fails closed, never open
        raise unauthorized("Supabase auth is not configured")
    try:
        return jwt.decode(
            token,
            secret,
            algorithms=_ALLOWED_ALGS,
            audience=settings.supabase_jwt_aud,
            issuer=_expected_issuer(settings.supabase_project_ref),
            options={"require": ["exp", "sub"]},
        )
    except jwt.InvalidTokenError as exc:
        # Log the failure TYPE only — never the token or secret.
        log.warning("supabase jwt rejected: %s", type(exc).__name__)
        raise unauthorized("Invalid or expired token") from exc


def bearer_token(authorization: str | None) -> str:
    """Extract the raw Bearer token from the Authorization header, or 401."""
    if not authorization or not authorization.startswith(_BEARER_PREFIX):
        raise unauthorized("Missing or malformed Bearer token")
    return authorization[len(_BEARER_PREFIX) :].strip()


def _claim_uuid(claims: dict[str, Any]) -> UUID:
    """Parse the `sub` claim into a UUID, or 401 if it isn't one."""
    try:
        return UUID(str(claims["sub"]))
    except (KeyError, ValueError, TypeError) as exc:
        raise unauthorized("Token subject is not a valid user id") from exc


def _signup_permitted(email: str | None) -> bool:
    """May a brand-new owner with this verified email create an account? (§4, §13 [D1])

    True when signups are open to everyone, or when the email is on the invite
    allowlist. A token carrying NO email is refused whenever signups are closed: it
    cannot be on a list it has no name for, and guessing "probably fine" is exactly
    the optimistic assumption this codebase refuses to make.
    """
    settings = get_settings()
    if settings.signups_open:
        return True
    if not email:
        return False
    return email.lower() in settings.signup_allowlist_emails


def _gate_new_owner(user_id: UUID, email: str | None) -> None:
    """Refuse (403) to create an account for a new owner who isn't permitted.

    Called only when there is no `app_user` row yet, and BEFORE any write — a
    refused signup leaves no trace in the database.

    An operator needs to see blocked signup attempts (that is the whole point of an
    invite gate), so the refusal is logged with the non-secret identifiers: the
    email and the Supabase UUID. Never the token.
    """
    if _signup_permitted(email):
        return
    log.warning("signup refused (closed + not allowlisted): user_id=%s email=%s", user_id, email)
    raise forbidden("Signups are closed")


def _provision_user(user_id: UUID, email: str | None) -> RequestUser:
    """JIT-provision the local `app_user` mirror and return the RequestUser.

    Signup gating is enforced HERE, in the backend — not at Supabase. A Supabase
    dashboard toggle is not a control this server owns, and §12.7 is explicit that
    the server is the trust boundary. Concretely this is a cost gate: since 6.4c the
    scheduler runs a nightly LLM chain for every active owner, so provisioning is
    what commits us to spend (PRICING.md §6).

    Gating applies ONLY to creating a new account: an owner who already has a row
    always passes, so flipping the flag can never lock out an existing user. The
    `email` comes from the JWT claim, and is trustworthy precisely because
    `verify_supabase_jwt` checked the signature first — Supabase populates it from
    the authenticated identity. An unverified claim would gate nothing.

    `ON CONFLICT DO NOTHING` keeps a concurrent second request a race-safe no-op; we
    then read back the row's canonical timezone.
    """
    with transaction() as cur:
        cur.execute("SELECT timezone FROM app_user WHERE id = %s", (str(user_id),))
        existing = cur.fetchone()
        if existing is not None:
            return RequestUser(id=user_id, timezone=existing[0])
        _gate_new_owner(user_id, email)  # raises 403 before anything is written
        cur.execute(
            "INSERT INTO app_user (id, email) VALUES (%s, %s) ON CONFLICT (id) DO NOTHING",
            (str(user_id), email),
        )
        cur.execute("SELECT timezone FROM app_user WHERE id = %s", (str(user_id),))
        row = cur.fetchone()
    return RequestUser(id=user_id, timezone=row[0] if row else "UTC")


def current_user(authorization: str | None = Header(default=None)) -> RequestUser:
    """FastAPI dependency: verify the Supabase JWT → JIT-provision → RequestUser."""
    claims = verify_supabase_jwt(bearer_token(authorization))
    user_id = _claim_uuid(claims)
    email = claims.get("email")
    return _provision_user(user_id, email if isinstance(email, str) else None)


def _hash_token(raw: str) -> str:
    """SHA-256 hex of a device token — the only form we ever store or compare."""
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def mint_device_token(user_id: UUID, label: str | None) -> str:
    """Mint a long-lived device ingest token for `user_id`; store only its hash.

    Returns the raw token ONCE (it is never persisted and cannot be recovered).
    """
    raw = secrets.token_urlsafe(_DEVICE_TOKEN_BYTES)
    with transaction() as cur:
        cur.execute(
            "INSERT INTO device_token (user_id, token_hash, label) VALUES (%s, %s, %s)",
            (str(user_id), _hash_token(raw), label),
        )
    return raw


def resolve_device_token(raw: str) -> UUID | None:
    """Resolve a raw device token to its owner UUID, touching `last_seen`.

    Returns None for an unknown/blank token — the caller distinguishes "no match"
    (None) from a successful lookup (a UUID).
    """
    if not raw:
        return None
    with transaction() as cur:
        cur.execute(
            "UPDATE device_token SET last_seen = now() WHERE token_hash = %s RETURNING user_id",
            (_hash_token(raw),),
        )
        row = cur.fetchone()
    if row is None:
        return None
    return row[0] if isinstance(row[0], UUID) else UUID(str(row[0]))
