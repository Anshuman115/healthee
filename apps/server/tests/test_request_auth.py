"""The dual-auth matrix — every REJECTION path, unit-level and DB-free (6.4b).

The security property this file exists for: **a rejected JWT must never become
sentinel access.** During the transition a valid legacy shared token resolves to the
sentinel owner, so if a bad JWT could fall through to that branch, anyone could read
and write the sentinel's health data with a forged token — the whole flip would be a
privilege escalation rather than an identity fix.

`request_auth` makes that unrepresentable by ORDER: the legacy comparison runs first
and the Supabase branch is the `return` after it, so a JWT that fails verification
raises out with nothing downstream of it. Asserting "401" alone would not prove that
— a 401 says nothing about which branch produced it. So every rejection test here
also asserts, via a spy, that **`_sentinel_user` was never called**: the owner was not
merely refused, it was never resolved.

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

from healthee.core import request_auth
from healthee.core.config import get_settings
from healthee.core.request_auth import CurrentUser, IngestUser

# >= 32 bytes: PyJWT warns (InsecureKeyLengthWarning) on shorter HMAC keys.
_SECRET = "request-auth-supabase-secret-0123456789abcdef"
_WRONG_SECRET = "a-completely-different-secret-0123456789abcdef"
_AUD = "authenticated"
_LEGACY_TOKEN = "unit-test-token"  # what the `env` fixture configures


class SentinelSpy:
    """Records whether the transitional legacy branch resolved an owner."""

    def __init__(self) -> None:
        self.calls = 0

    def __call__(self) -> Any:
        self.calls += 1
        raise AssertionError("the sentinel branch must not be reached for this token")


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
def spy(monkeypatch: pytest.MonkeyPatch, env: None) -> Iterator[SentinelSpy]:  # noqa: ARG001
    """Supabase verification configured + a spy on the transitional sentinel branch."""
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    monkeypatch.delenv("SUPABASE_PROJECT_REF", raising=False)
    get_settings.cache_clear()
    watcher = SentinelSpy()
    monkeypatch.setattr(request_auth, "_sentinel_user", watcher)
    yield watcher
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


# --- rejected JWTs are terminal: 401, and the sentinel is never resolved ------


@pytest.mark.parametrize(
    ("name", "token_kwargs"),
    [
        ("expired", {"exp_delta_s": -10}),
        ("tampered_signature", {"secret": _WRONG_SECRET}),
        ("alg_none_forgery", {"algorithm": "none"}),
    ],
)
def test_a_rejected_jwt_is_401_and_never_falls_through_to_the_sentinel(
    spy: SentinelSpy, name: str, token_kwargs: dict
) -> None:
    resp = _get(_API, _make_token(**token_kwargs))
    assert resp.status_code == 401, name
    assert spy.calls == 0, f"{name}: a rejected JWT reached the transitional sentinel branch"


# The `/ingest/*` dependency has no JWT branch at all (§7: device token or the
# transitional shared token, nothing else), so a JWT reaching it is simply an unknown
# device token — resolving that needs the DB, and the case lives in
# `tests/integration/test_ingest_attribution.py` with the rest of the attribution proof.


def test_garbage_token_is_401_and_not_sentinel_access(spy: SentinelSpy) -> None:
    resp = _get(_API, "not-a-token-at-all")
    assert resp.status_code == 401
    assert spy.calls == 0


def test_a_near_miss_of_the_legacy_token_is_not_accepted(spy: SentinelSpy) -> None:
    """One character off the shared token must not resolve to the sentinel."""
    resp = _get(_API, _LEGACY_TOKEN + "x")
    assert resp.status_code == 401
    assert spy.calls == 0


# --- the header contract -----------------------------------------------------


def test_missing_header_is_401(spy: SentinelSpy) -> None:
    resp = _get(_API, None)
    assert resp.status_code == 401
    assert "Missing" in resp.json()["detail"]
    assert spy.calls == 0


def test_malformed_header_without_bearer_is_401(spy: SentinelSpy) -> None:
    resp = _client().get(_API, headers={"Authorization": _LEGACY_TOKEN})  # no "Bearer "
    assert resp.status_code == 401
    assert spy.calls == 0


def test_missing_header_is_401_on_ingest(spy: SentinelSpy) -> None:
    assert _get(_INGEST, None).status_code == 401
    assert spy.calls == 0


# --- misconfiguration fails closed -------------------------------------------


def test_blank_configured_legacy_token_authorizes_nobody(
    monkeypatch: pytest.MonkeyPatch, spy: SentinelSpy
) -> None:
    """A blank REALTIME_INGEST_TOKEN must not become "match everything"."""
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", "")
    get_settings.cache_clear()
    for presented in (_LEGACY_TOKEN, "", "anything"):
        assert request_auth._legacy_shared_token(presented) is False
    resp = _get(_API, _LEGACY_TOKEN)
    assert resp.status_code == 401
    assert spy.calls == 0


def test_blank_supabase_secret_fails_closed(monkeypatch: pytest.MonkeyPatch) -> None:
    """No Supabase secret → a JWT is refused, never trusted unverified."""
    monkeypatch.setenv("POSTGRES_PASSWORD", "unit-test-pw")
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", _LEGACY_TOKEN)
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "")
    get_settings.cache_clear()
    resp = _get(_API, _make_token())
    assert resp.status_code == 401
    assert "not configured" in resp.json()["detail"]
    get_settings.cache_clear()


# --- the legacy branch itself ------------------------------------------------


def test_the_configured_legacy_token_takes_the_sentinel_branch(
    monkeypatch: pytest.MonkeyPatch,
    env: None,  # noqa: ARG001 — sets the token
) -> None:
    """The transition's whole point: today's app token still resolves an owner.

    Asserted at the branch level (the resolved owner needs a DB; that round-trip is
    covered in `tests/integration/test_request_auth_integration.py`).
    """
    assert request_auth._legacy_shared_token(_LEGACY_TOKEN) is True
