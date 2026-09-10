"""Every REJECTION path on both dependencies — unit-level and DB-free.

The property: **a credential that does not verify resolves nobody.** There is one way
into `/api/*` (a Supabase JWT) and one into `/ingest/*` (a device token this server
minted), and everything else is 401.

This file used to be a dual-auth matrix, and most of it was a spy. A single shared
`REALTIME_INGEST_TOKEN` resolved to the sentinel owner ahead of the Supabase branch,
so "401" was not enough to assert — a rejected JWT that fell through to that branch
would have been a privilege escalation wearing an identity fix, and only a spy on
`_sentinel_user` could tell the two 401s apart. The branch is gone (2026-09-10), so
the fall-through it guarded against is now unrepresentable rather than merely
untaken, and these are plain rejection tests again.

DB-free by construction: every path exercised rejects before any owner lookup, which
is itself part of the proof (a request that touched `app_user` would hang on the
absent database instead of returning 401).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import uuid4

import jwt
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from healthee.core.config import get_settings
from healthee.core.request_auth import CurrentUser, IngestUser

# >= 32 bytes: PyJWT warns (InsecureKeyLengthWarning) on shorter HMAC keys.
_SECRET = "request-auth-supabase-secret-0123456789abcdef"
_WRONG_SECRET = "a-completely-different-secret-0123456789abcdef"
_AUD = "authenticated"
_OPAQUE = "unit-test-token"  # a bearer that is not a JWT and never was a credential


def _make_token(
    *,
    secret: str = _SECRET,
    exp_delta_s: int = 3600,
    algorithm: str = "HS256",
) -> str:
    payload: dict[str, Any] = {
        "sub": str(uuid4()),
        "aud": _AUD,
        "exp": datetime.now(tz=UTC) + timedelta(seconds=exp_delta_s),
    }
    if algorithm == "none":
        return jwt.encode(payload, None, algorithm="none")  # type: ignore[arg-type]
    return jwt.encode(payload, secret, algorithm=algorithm)


@pytest.fixture
def configured(monkeypatch: pytest.MonkeyPatch, env: None) -> Iterator[None]:  # noqa: ARG001
    """Supabase verification configured against the shared secret (no JWKS)."""
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    monkeypatch.delenv("SUPABASE_PROJECT_REF", raising=False)
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


# The two real exported dependencies, mounted on a throwaway app (no real router):
# `/api` is what every read endpoint uses, `/ingest` what the push endpoint uses.
_API = "/api-guarded"
_INGEST = "/ingest-guarded"


def _client() -> TestClient:
    app = FastAPI()

    @app.get(_API)
    def _api(user: CurrentUser) -> dict[str, str]:
        return {"id": str(user.id), "timezone": user.timezone}

    @app.get(_INGEST)
    def _ingest(user: IngestUser) -> dict[str, str]:
        return {"id": str(user.id), "timezone": user.timezone}

    return TestClient(app)


def _get(path: str, token: str | None) -> Any:
    headers = {"Authorization": f"Bearer {token}"} if token is not None else {}
    return _client().get(path, headers=headers)


# --- rejected JWTs are terminal ----------------------------------------------


@pytest.mark.parametrize(
    ("name", "token_kwargs"),
    [
        ("expired", {"exp_delta_s": -10}),
        ("tampered_signature", {"secret": _WRONG_SECRET}),
        ("alg_none_forgery", {"algorithm": "none"}),
    ],
)
def test_a_rejected_jwt_is_401(configured: None, name: str, token_kwargs: dict) -> None:  # noqa: ARG001
    assert _get(_API, _make_token(**token_kwargs)).status_code == 401, name


# The `/ingest/*` dependency has no JWT branch at all — a device token this server
# minted, and nothing else — so a JWT reaching it is simply an unknown device token.
# Resolving that needs the DB, and the case lives in
# `tests/integration/test_ingest_attribution.py` with the rest of the attribution proof.


def test_garbage_token_is_401(configured: None) -> None:  # noqa: ARG001
    assert _get(_API, "not-a-token-at-all").status_code == 401


def test_AN_OPAQUE_BEARER_IS_401_ON_BOTH_PATHS(configured: None) -> None:  # noqa: ARG001, N802
    """The removed transition, at the unit level.

    A string like this was a credential on both dependencies until 2026-09-10, and
    resolved the sentinel owner on each. `/api/*` refuses it because it is not a JWT;
    `/ingest/*` would refuse it as an unminted device token, which needs the DB — so
    only the `/api/*` half is asserted here and the other half is in the attribution
    suite. Both halves matter: the read side leaked one owner's history, the write
    side wrote into it.
    """
    assert _get(_API, _OPAQUE).status_code == 401
    assert _get(_API, _OPAQUE + "x").status_code == 401


# --- the header contract -----------------------------------------------------


def test_missing_header_is_401(configured: None) -> None:  # noqa: ARG001
    resp = _get(_API, None)
    assert resp.status_code == 401
    assert "Missing" in resp.json()["detail"]


def test_malformed_header_without_bearer_is_401(configured: None) -> None:  # noqa: ARG001
    assert _client().get(_API, headers={"Authorization": _OPAQUE}).status_code == 401


def test_missing_header_is_401_on_ingest(configured: None) -> None:  # noqa: ARG001
    assert _get(_INGEST, None).status_code == 401


# --- misconfiguration fails closed -------------------------------------------


def test_blank_supabase_secret_fails_closed(monkeypatch: pytest.MonkeyPatch) -> None:
    """No Supabase secret → a JWT is refused, never trusted unverified.

    This is the whole of "fails closed" now. It used to share the section with a
    blank `REALTIME_INGEST_TOKEN` not becoming "match everything" — a real hazard
    while that comparison existed, and no longer a reachable state.
    """
    monkeypatch.setenv("POSTGRES_PASSWORD", "unit-test-pw")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "")
    get_settings.cache_clear()
    resp = _get(_API, _make_token())
    assert resp.status_code == 401
    assert "not configured" in resp.json()["detail"]
    get_settings.cache_clear()
