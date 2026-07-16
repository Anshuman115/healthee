"""Unit tests for core.supabase_auth JWT verification — no DB required.

Self-signs HS256 test tokens with a known secret (never a live Supabase) and
asserts that a valid token passes while expired / bad-signature / wrong-aud /
wrong-iss / alg=none tokens are all rejected with 401.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import uuid4

import jwt
import pytest
from fastapi import HTTPException

from healthee.core.config import get_settings
from healthee.core.supabase_auth import verify_supabase_jwt

# >= 32 bytes: PyJWT warns (InsecureKeyLengthWarning) on shorter HMAC keys.
_SECRET = "unit-test-supabase-secret-0123456789abcdef"
_WRONG_SECRET = "a-completely-different-secret-0123456789abcdef"
_AUD = "authenticated"
_REF = "abcdefghijklmnop"
_ISS = f"https://{_REF}.supabase.co/auth/v1"


def _make_token(
    *,
    secret: str = _SECRET,
    aud: str | None = _AUD,
    iss: str | None = None,
    exp_delta_s: int = 3600,
    algorithm: str = "HS256",
    sub: str | None = None,
    extra: dict[str, Any] | None = None,
) -> str:
    payload: dict[str, Any] = {
        "sub": sub or str(uuid4()),
        "exp": datetime.now(tz=UTC) + timedelta(seconds=exp_delta_s),
    }
    if aud is not None:
        payload["aud"] = aud
    if iss is not None:
        payload["iss"] = iss
    if extra:
        payload.update(extra)
    if algorithm == "none":
        return jwt.encode(payload, None, algorithm="none")  # type: ignore[arg-type]
    return jwt.encode(payload, secret, algorithm=algorithm)


@pytest.fixture
def supabase_env(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """Configure the Supabase secret + aud; no project ref (iss check off)."""
    monkeypatch.setenv("POSTGRES_PASSWORD", "unit-test-pw")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    monkeypatch.delenv("SUPABASE_PROJECT_REF", raising=False)
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def test_valid_token_passes(supabase_env: None) -> None:  # noqa: ARG001
    uid = str(uuid4())
    claims = verify_supabase_jwt(_make_token(sub=uid, extra={"email": "a@b.com"}))
    assert claims["sub"] == uid
    assert claims["email"] == "a@b.com"


def test_expired_token_is_rejected(supabase_env: None) -> None:  # noqa: ARG001
    with pytest.raises(HTTPException) as exc:
        verify_supabase_jwt(_make_token(exp_delta_s=-10))
    assert exc.value.status_code == 401


def test_bad_signature_is_rejected(supabase_env: None) -> None:  # noqa: ARG001
    with pytest.raises(HTTPException) as exc:
        verify_supabase_jwt(_make_token(secret=_WRONG_SECRET))
    assert exc.value.status_code == 401


def test_wrong_aud_is_rejected(supabase_env: None) -> None:  # noqa: ARG001
    with pytest.raises(HTTPException) as exc:
        verify_supabase_jwt(_make_token(aud="some-other-audience"))
    assert exc.value.status_code == 401


def test_missing_aud_is_rejected(supabase_env: None) -> None:  # noqa: ARG001
    with pytest.raises(HTTPException) as exc:
        verify_supabase_jwt(_make_token(aud=None))
    assert exc.value.status_code == 401


def test_alg_none_is_rejected(supabase_env: None) -> None:  # noqa: ARG001
    # The canonical forgery: strip the signature and set alg=none. Pinning the
    # decode to HS256 must reject it — an unverified token is never accepted.
    with pytest.raises(HTTPException) as exc:
        verify_supabase_jwt(_make_token(algorithm="none"))
    assert exc.value.status_code == 401


def test_wrong_iss_is_rejected_when_ref_set(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("POSTGRES_PASSWORD", "unit-test-pw")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    monkeypatch.setenv("SUPABASE_PROJECT_REF", _REF)
    get_settings.cache_clear()
    with pytest.raises(HTTPException) as exc:
        verify_supabase_jwt(_make_token(iss="https://evil.example.com/auth/v1"))
    assert exc.value.status_code == 401
    # And the matching issuer passes.
    claims = verify_supabase_jwt(_make_token(iss=_ISS))
    assert claims["iss"] == _ISS
    get_settings.cache_clear()


def test_unconfigured_secret_fails_closed(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("POSTGRES_PASSWORD", "unit-test-pw")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "")  # not configured
    get_settings.cache_clear()
    with pytest.raises(HTTPException) as exc:
        verify_supabase_jwt(_make_token())
    assert exc.value.status_code == 401
    assert "not configured" in exc.value.detail
    get_settings.cache_clear()
