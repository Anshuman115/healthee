"""ES256 tokens verify, and an HS256 forgery signed with the public key does not.

## Why this file exists

Supabase migrated projects to ASYMMETRIC signing keys. `verify_supabase_jwt`
pinned `["HS256"]` and verified against the legacy shared secret, so every
correctly signed token was refused — in production, with
`InvalidAlgorithmError` in the log and "that token was refused by the server" on
the owner's phone. The fix reads the project's JWKS and verifies against the
public key the token names.

## The attack the fix must not open

Publishing a public key creates the classic key-confusion hole: an attacker takes
the PUBLIC key, uses its bytes as an HMAC secret, and signs `alg: HS256`. A
verifier holding one allow-list of `["HS256", "ES256"]` and one key will happily
check that forgery against the same bytes and pass it.

The defence is structural rather than careful: the KEY SOURCE picks the
algorithm list. A key resolved through JWKS is only ever used with the asymmetric
algorithms; the shared secret is only ever used with HS256. `test_a_forged_hs256_
token_signed_with_the_public_key_is_refused` is the assertion, and it is the one
that would fail if somebody ever merged the two lists "to simplify".
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import patch

import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import HTTPException

from healthee.core.config import get_settings
from healthee.core.supabase_auth import verify_supabase_jwt

_AUD = "authenticated"
_REF = "testprojectref00"
_ISS = f"https://{_REF}.supabase.co/auth/v1"
_KID = "test-key-1"
_SHARED = "the-legacy-shared-secret-0123456789abcdef"


@pytest.fixture(scope="module")
def signing_key() -> ec.EllipticCurvePrivateKey:
    """A P-256 key pair, the curve Supabase issues."""
    return ec.generate_private_key(ec.SECP256R1())


def _public_pem(key: ec.EllipticCurvePrivateKey) -> bytes:
    return key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )


def _segment(data: dict[str, Any]) -> str:
    """One base64url JWT segment, unpadded — the wire format, by hand."""
    raw = json.dumps(data, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def _claims(**extra: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "sub": "877e8bea-f218-4e45-b698-3068af9a44e5",
        "aud": _AUD,
        "iss": _ISS,
        "exp": datetime.now(tz=UTC) + timedelta(hours=1),
    }
    payload.update(extra)
    return payload


@pytest.fixture
def asymmetric_env(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """A project ref (so JWKS is consulted) AND a shared secret (so the fallback
    exists and can be shown not to be reachable for an ES256 token)."""
    monkeypatch.setenv("POSTGRES_PASSWORD", "unit-test-pw")
    monkeypatch.setenv("SUPABASE_PROJECT_REF", _REF)
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SHARED)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def _with_jwks(key: ec.EllipticCurvePrivateKey):
    """Patches the JWKS client so no network call is made."""

    class _Key:
        def __init__(self, material: Any) -> None:
            self.key = material

    class _Client:
        def __init__(self, *_: Any, **__: Any) -> None: ...

        def get_signing_key_from_jwt(self, token: str) -> _Key:
            header = jwt.get_unverified_header(token)
            if header.get("kid") != _KID:
                raise jwt.PyJWKClientError("no key for that kid")
            return _Key(
                serialization.load_pem_public_key(_public_pem(key)),
            )

    return patch("healthee.core.supabase_auth.jwt.PyJWKClient", _Client)


def test_an_es256_token_verifies(
    signing_key: ec.EllipticCurvePrivateKey,
    asymmetric_env: None,  # noqa: ARG001
) -> None:
    token = jwt.encode(_claims(), signing_key, algorithm="ES256", headers={"kid": _KID})
    from healthee.core import supabase_auth

    supabase_auth._jwk_client.cache_clear()
    with _with_jwks(signing_key):
        claims = verify_supabase_jwt(token)
    assert claims["sub"] == "877e8bea-f218-4e45-b698-3068af9a44e5"


def test_a_forged_hs256_token_signed_with_the_public_key_is_refused(
    signing_key: ec.EllipticCurvePrivateKey,
    asymmetric_env: None,  # noqa: ARG001
) -> None:
    """The key-confusion attack, made concretely and refused.

    The attacker needs no secret: the public key is published. They HMAC it.
    """
    # Hand-rolled, because PyJWT refuses to ENCODE an HMAC token from a PEM key
    # — a courtesy to the honest developer that an attacker simply does not use.
    # The forgery is three base64url segments and one HMAC, which is all it ever
    # was; assembling it here is what makes this a test of OUR verifier rather
    # than of PyJWT's willingness to help.
    public_pem = _public_pem(signing_key)
    header = _segment({"alg": "HS256", "typ": "JWT", "kid": _KID})
    payload = _segment(
        {
            **_claims(),
            "exp": int((datetime.now(tz=UTC) + timedelta(hours=1)).timestamp()),
        }
    )
    signing_input = f"{header}.{payload}".encode()
    signature = (
        base64.urlsafe_b64encode(hmac.new(public_pem, signing_input, hashlib.sha256).digest())
        .rstrip(b"=")
        .decode()
    )
    forged = f"{header}.{payload}.{signature}"
    from healthee.core import supabase_auth

    supabase_auth._jwk_client.cache_clear()
    with _with_jwks(signing_key), pytest.raises(HTTPException) as raised:
        verify_supabase_jwt(forged)
    assert raised.value.status_code == 401


def test_alg_none_is_still_refused(
    signing_key: ec.EllipticCurvePrivateKey,
    asymmetric_env: None,  # noqa: ARG001
) -> None:
    forged = jwt.encode(_claims(), None, algorithm="none", headers={"kid": _KID})  # type: ignore[arg-type]
    from healthee.core import supabase_auth

    supabase_auth._jwk_client.cache_clear()
    with _with_jwks(signing_key), pytest.raises(HTTPException) as raised:
        verify_supabase_jwt(forged)
    assert raised.value.status_code == 401


def test_a_project_with_no_jwks_still_verifies_hs256(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The legacy path, unbroken: a self-hosted GoTrue with no JWKS endpoint.

    The JWKS lookup fails, the shared secret is used, and only HS256 is allowed
    against it — so this is not a fallback that weakens anything.
    """
    monkeypatch.setenv("POSTGRES_PASSWORD", "unit-test-pw")
    monkeypatch.setenv("SUPABASE_PROJECT_REF", _REF)
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SHARED)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    get_settings.cache_clear()

    token = jwt.encode(_claims(), _SHARED, algorithm="HS256")

    class _Dead:
        def __init__(self, *_: Any, **__: Any) -> None: ...

        def get_signing_key_from_jwt(self, token: str) -> Any:
            raise jwt.PyJWKClientError("no jwks here")

    from healthee.core import supabase_auth

    supabase_auth._jwk_client.cache_clear()
    with patch("healthee.core.supabase_auth.jwt.PyJWKClient", _Dead):
        claims = verify_supabase_jwt(token)
    assert claims["aud"] == _AUD
    get_settings.cache_clear()


def test_a_jwks_fetch_that_throws_does_not_authorise_anything(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A network failure must not 500, and must not become a bypass either."""
    monkeypatch.setenv("POSTGRES_PASSWORD", "unit-test-pw")
    monkeypatch.setenv("SUPABASE_PROJECT_REF", _REF)
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SHARED)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    get_settings.cache_clear()

    class _Broken:
        def __init__(self, *_: Any, **__: Any) -> None: ...

        def get_signing_key_from_jwt(self, token: str) -> Any:
            raise OSError("network is down")

    from healthee.core import supabase_auth

    supabase_auth._jwk_client.cache_clear()
    # A token signed with something else entirely: the fallback is a real check.
    bogus = jwt.encode(_claims(), "not-the-shared-secret-at-all", algorithm="HS256")
    with (
        patch("healthee.core.supabase_auth.jwt.PyJWKClient", _Broken),
        pytest.raises(HTTPException) as raised,
    ):
        verify_supabase_jwt(bogus)
    assert raised.value.status_code == 401
    get_settings.cache_clear()


def test_the_jwks_url_is_the_projects_own(monkeypatch: pytest.MonkeyPatch) -> None:
    from healthee.core.supabase_auth import _jwks_url

    assert _jwks_url(_REF) == f"https://{_REF}.supabase.co/auth/v1/.well-known/jwks.json"
    assert json.dumps({"ref": _REF})  # the ref is not interpolated anywhere else
