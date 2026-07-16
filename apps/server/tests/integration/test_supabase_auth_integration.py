"""Integration tests for Supabase identity against a real TimescaleDB.

Covers JIT-provisioning via `current_user`, device-token mint/resolve round-trips
(hash-only storage), and the GET /api/me + POST /api/device endpoints via
TestClient with a self-signed HS256 test token. Auto-skips when no DB is reachable.
"""

from __future__ import annotations

import hashlib
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

import jwt
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from healthee.api.routers import auth
from healthee.core.config import get_settings
from healthee.core.db import transaction
from healthee.core.supabase_auth import mint_device_token, resolve_device_token
from healthee.db import migrate

pytestmark = pytest.mark.integration

# >= 32 bytes: PyJWT warns (InsecureKeyLengthWarning) on shorter HMAC keys.
_SECRET = "integration-supabase-secret-0123456789abcdef"
_AUD = "authenticated"


def _make_token(sub: str, email: str | None = None) -> str:
    payload: dict[str, Any] = {
        "sub": sub,
        "aud": _AUD,
        "exp": datetime.now(tz=UTC) + timedelta(hours=1),
    }
    if email is not None:
        payload["email"] = email
    return jwt.encode(payload, _SECRET, algorithm="HS256")


def _bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def supabase_secret(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """Set only the Supabase secret/aud — leave the ambient POSTGRES_* (real DB)."""
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    monkeypatch.delenv("SUPABASE_PROJECT_REF", raising=False)
    # These tests are about what happens AFTER an account exists (provisioning,
    # device tokens, /api/me). Signups are open so the gate isn't the thing under
    # test here — the gate itself is owned by `tests/test_signup_gate.py`.
    monkeypatch.setenv("SIGNUPS_OPEN", "true")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def _client() -> TestClient:
    app = FastAPI()
    app.include_router(auth.router)
    return TestClient(app)


def _user_count(user_id: UUID) -> int:
    with transaction() as cur:
        cur.execute("SELECT count(*) FROM app_user WHERE id = %s", (str(user_id),))
        row = cur.fetchone()
    assert row is not None
    return int(row[0])


def test_current_user_jit_provisions_then_reuses(
    db: None,  # noqa: ARG001 — gates on a reachable DB
    supabase_secret: None,  # noqa: ARG001 — sets the signing secret
) -> None:
    migrate.apply_migrations()
    uid = uuid4()
    token = _make_token(str(uid), email="jit@example.com")
    client = _client()

    first = client.get("/api/me", headers=_bearer(token))
    assert first.status_code == 200
    assert first.json() == {"id": str(uid), "timezone": "UTC"}
    assert _user_count(uid) == 1

    second = client.get("/api/me", headers=_bearer(token))
    assert second.status_code == 200
    assert _user_count(uid) == 1  # reused, not duplicated


def test_me_without_token_is_401(
    db: None,  # noqa: ARG001
    supabase_secret: None,  # noqa: ARG001
) -> None:
    migrate.apply_migrations()
    assert _client().get("/api/me").status_code == 401


def test_device_token_mint_resolve_roundtrip_stores_only_hash(
    db: None,  # noqa: ARG001
    supabase_secret: None,  # noqa: ARG001
) -> None:
    migrate.apply_migrations()
    uid = uuid4()
    with transaction() as cur:  # FK requires the owner to exist
        cur.execute("INSERT INTO app_user (id) VALUES (%s)", (str(uid),))

    raw = mint_device_token(uid, label="test strap")
    assert resolve_device_token(raw) == uid
    assert resolve_device_token("not-a-real-token") is None

    with transaction() as cur:
        cur.execute("SELECT token_hash FROM device_token WHERE user_id = %s", (str(uid),))
        row = cur.fetchone()
    assert row is not None
    stored = row[0]
    assert stored != raw  # the raw token is never stored
    assert stored == hashlib.sha256(raw.encode("utf-8")).hexdigest()


def test_post_device_endpoint_mints_resolvable_token(
    db: None,  # noqa: ARG001
    supabase_secret: None,  # noqa: ARG001
) -> None:
    migrate.apply_migrations()
    uid = uuid4()
    token = _make_token(str(uid))
    resp = _client().post("/api/device", headers=_bearer(token))
    assert resp.status_code == 200
    body = resp.json()
    assert body["id"] == str(uid)
    assert resolve_device_token(body["device_token"]) == uid
