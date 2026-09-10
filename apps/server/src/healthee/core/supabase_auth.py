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

The credential this server MINTS rather than verifies — the long-lived device
token `/ingest/*` takes — is `core/device_token.py`. The two are deliberately
apart: this module never issues anything, and that one never checks a signature.

Security note: never log the raw JWT or the signing secret — only the *type* of a
verification failure is logged.
"""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from typing import Any
from uuid import UUID

import jwt
from fastapi import Header, HTTPException, status

from healthee.core.config import get_settings
from healthee.core.db import transaction
from healthee.core.logging import get_logger

log = get_logger(__name__)

_BEARER_PREFIX = "Bearer "

# ── the two ways a Supabase project signs a token, and why the lists are apart ──
#
# Supabase has moved to ASYMMETRIC signing keys: a project publishes an EC or RSA
# public key at `/auth/v1/.well-known/jwks.json` and signs access tokens with the
# private half. Older projects still sign HS256 with the shared
# `SUPABASE_JWT_SECRET`, and a self-hosted GoTrue can be either. Both have to
# verify, so both are here — but never in the same list.
#
# ⛔ **A single allow-list of `["HS256", "ES256", "RS256"]` is the classic key
# confusion hole.** With a public key available, an attacker signs `alg: HS256`
# using that public key AS THE HMAC SECRET; a verifier that accepts both families
# against whichever key it happens to hold will check the forgery against the
# same bytes and pass it. The defence is that the KEY SOURCE picks the algorithm
# and the token never does: a token resolved through JWKS is verified with
# `_ASYMMETRIC_ALGS` and nothing else, and the shared secret is only ever used
# with `_SHARED_SECRET_ALGS`.
_SHARED_SECRET_ALGS = ["HS256"]
_ASYMMETRIC_ALGS = ["ES256", "RS256"]


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


# `app_user.status`'s one permitted value for a request. The column is
# `NOT NULL DEFAULT 'active'` (`0002_identity.sql`), and `core.tenancy.active_users`
# already filters the nightly sweep on it — this constant is the same word, named
# once, so the request path and the job path cannot drift apart about what "active"
# is (CLAUDE.md: ONE canonical definition).
ACTIVE_STATUS = "active"


def refuse_unless_active(user_id: UUID, status_value: str) -> None:
    """403 unless `status_value` is `active` — the request-path half of suspension.

    ## What this closes

    `app_user.status` existed, was documented as the kill switch, and was read by
    EXACTLY ONE thing: `core.tenancy.active_users`, the scheduler sweep, whose
    docstring says "Suspended/deleted owners are excluded by `status`, so their chains
    stop without deleting their data." That sentence was true of the nightly LLM chain
    and false of everything else. Setting `status='suspended'` stopped the chain and
    left full `/api/*` read/write and full `/ingest/*` write access intact.

    The consequence was that the ONLY working kill switch was `DELETE FROM app_user` —
    and every FK to it is `ON DELETE CASCADE` (`0003_tenant_column.sql`), so the only
    way to stop an owner was to destroy their entire health history. Destroying the
    data is not a kill switch; it is the absence of one.

    403 and not 401: the credential is valid and we know exactly who presented it.
    401 would tell the client its login failed and invite it to retry the login it just
    completed — the same argument `forbidden` already makes for a refused signup.
    """
    if status_value == ACTIVE_STATUS:
        return
    # The status word and the owner's id, both non-secret and both what an operator
    # needs to see; never the token.
    log.warning("refused a request from %s: app_user.status is %r", user_id, status_value)
    raise forbidden("This account is not active")


def _expected_issuer(project_ref: str) -> str | None:
    """The issuer Supabase stamps for a project, or None to skip the `iss` check."""
    if not project_ref:
        return None
    return f"https://{project_ref}.supabase.co/auth/v1"


def _jwks_url(project_ref: str) -> str:
    """Where a project publishes the public half of its signing keys."""
    return f"https://{project_ref}.supabase.co/auth/v1/.well-known/jwks.json"


@lru_cache(maxsize=4)
def _jwk_client(url: str) -> jwt.PyJWKClient:
    """A cached JWKS client for `url`.

    Cached because it holds the fetched key set: without this every request would
    make an outbound HTTPS call to Supabase before it could check a signature,
    which is a network round trip on the hot path and an availability dependency
    on somebody else's uptime for every read this API serves.

    `PyJWKClient`'s own cache is what refetches when a `kid` is not known, so a
    rotated key is picked up on the first token that uses it rather than needing
    a restart. `lru_cache` keys on the URL, so a project ref change makes a new
    client rather than reusing a stale one.
    """
    return jwt.PyJWKClient(url, cache_keys=True, lifespan=_JWKS_LIFESPAN_S)


# How long a fetched key set is trusted before `PyJWKClient` refreshes it.
# Twelve hours: Supabase key rotation is a deliberate, rare operator action, and
# an unknown `kid` triggers a refetch regardless — this bound is for a key that
# was REVOKED rather than rotated, which is the case nothing else notices.
_JWKS_LIFESPAN_S = 43200


def _signing_key(token: str, project_ref: str) -> Any | None:
    """The public key this token names, or None when JWKS cannot supply one.

    None means "fall back to the shared secret" and is the honest answer for a
    self-hosted GoTrue with no JWKS endpoint, for a project still on HS256, and
    for a deployment with no `SUPABASE_PROJECT_REF` to build a URL from.
    """
    if not project_ref:
        return None
    try:
        return _jwk_client(_jwks_url(project_ref)).get_signing_key_from_jwt(token).key
    except jwt.PyJWKClientError as exc:
        # The key set does not name this token's `kid` — an HS256 token from a
        # project that also publishes a JWKS reaches here, and so does a
        # genuinely unknown key. Both fall through to the shared secret, which
        # refuses anything it cannot verify.
        log.info("jwks lookup did not resolve a key: %s", type(exc).__name__)
        return None
    except Exception as exc:  # noqa: BLE001 — network/parse; must not 500
        # A JWKS fetch is an outbound call and it can fail. It must not take the
        # API down, and it must not authorise anything either: fall through to
        # the shared secret, which is a real check and not a bypass.
        log.warning("jwks fetch failed: %s", type(exc).__name__)
        return None


def verify_supabase_jwt(token: str) -> dict[str, Any]:
    """Verify a Supabase access JWT and return its claims.

    Enforces: a signature, presence + validity of `exp` and `sub`,
    `aud == SUPABASE_JWT_AUD`, and — when `SUPABASE_PROJECT_REF` is set —
    `iss == https://<ref>.supabase.co/auth/v1`. Raises 401 on any failure.

    ## Two signing schemes, one at a time

    A project that publishes a JWKS is verified against the PUBLIC key its token
    names, with only the asymmetric algorithms permitted. Anything else falls to
    the legacy shared secret with only HS256 permitted. The key source decides
    the algorithm; the token never does — see `_SHARED_SECRET_ALGS`.

    This is what `InvalidAlgorithmError` in production was: Supabase migrated
    projects to ES256 signing keys, this function pinned HS256, and every
    correctly signed token was refused with a 401 that read to the owner as a
    rejected credential.
    """
    settings = get_settings()
    key = _signing_key(token, settings.supabase_project_ref)
    algorithms = _ASYMMETRIC_ALGS
    if key is None:
        key = settings.supabase_jwt_secret
        algorithms = _SHARED_SECRET_ALGS
        if not key:  # misconfiguration fails closed, never open
            raise unauthorized("Supabase auth is not configured")
    try:
        return jwt.decode(
            token,
            key,
            algorithms=algorithms,
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
        # `status` travels with `timezone`, because an existing row is exactly where a
        # suspension lives and this is one of the two places a request resolves an owner.
        cur.execute("SELECT timezone, status FROM app_user WHERE id = %s", (str(user_id),))
        existing = cur.fetchone()
        if existing is not None:
            refuse_unless_active(user_id, existing[1])
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
