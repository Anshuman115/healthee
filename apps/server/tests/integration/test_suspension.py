"""Suspending an owner actually suspends them — `AUTH_AUDIT.md` B2, and F3 beside it.

## What was true before

`app_user.status` existed (`0002_identity.sql`, `NOT NULL DEFAULT 'active'`), was
documented as the kill switch, and was read by EXACTLY ONE thing: `core.tenancy
.active_users`, the scheduler sweep. Setting `status='suspended'` stopped that owner's
nightly LLM chain and left **full `/api/*` read/write and full `/ingest/*` write access
intact** — so the only working kill switch was deleting the `app_user` row, and every FK
to it is `ON DELETE CASCADE`. Stopping an owner meant destroying their entire health
history, which is not a kill switch.

## Why the assertions here are per-PATH and not per-function

A suspension that only some entry points consult is not a suspension, and the two
request paths resolve an owner in two different modules (`core.request_auth` for the
device/legacy token, `core.supabase_auth._provision_user` for a JWT). Asserting the
helper would prove the helper. These drive the real dependencies, once each, so a future
lookup that forgets `status` fails here.

F3's assertion sits in the same file because it is the same read: a legacy shared token
whose sentinel row is ABSENT used to authenticate an owner who does not exist — the
documented post-condition of `db/claim_sentinel.py` — and now 401s like `ingest_user`
already did.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import jwt
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from healthee.core import db as db_module
from healthee.core.config import get_settings
from healthee.core.db import transaction
from healthee.core.device_token import mint_device_token
from healthee.core.request_auth import CurrentUser, IngestUser
from healthee.db import migrate

pytestmark = [
    pytest.mark.integration,
    pytest.mark.usefixtures("owner_sweep"),
]

_SECRET = "suspension-supabase-secret-0123456789abcdef"
_AUD = "authenticated"


def _jwt(sub: UUID) -> str:
    return jwt.encode(
        {"sub": str(sub), "aud": _AUD, "exp": datetime.now(tz=UTC) + timedelta(hours=1)},
        _SECRET,
        algorithm="HS256",
    )


def _app() -> FastAPI:
    """One route per identity path, each echoing the owner it resolved."""
    app = FastAPI()

    @app.get("/api/whoami")
    def _api(user: CurrentUser) -> dict[str, str]:
        return {"id": str(user.id)}

    @app.post("/ingest/whoami")
    def _ingest(user: IngestUser) -> dict[str, str]:
        return {"id": str(user.id)}

    return app


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch, db: None) -> Iterator[TestClient]:  # noqa: ARG001
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    monkeypatch.delenv("SUPABASE_PROJECT_REF", raising=False)
    monkeypatch.setenv("SIGNUPS_OPEN", "false")
    monkeypatch.setenv("SIGNUP_ALLOWLIST", "")
    get_settings.cache_clear()
    migrate.apply_migrations()
    yield TestClient(_app())
    get_settings.cache_clear()
    db_module.close_pool()


def _owner(status: str = "active") -> UUID:
    """An `app_user` row in a known state. Removed by `owner_sweep`."""
    uid = uuid4()
    with transaction() as cur:
        cur.execute("INSERT INTO app_user (id, status) VALUES (%s, %s)", (str(uid), status))
    return uid


def _set_status(user_id: UUID, status: str) -> None:
    with transaction() as cur:
        cur.execute("UPDATE app_user SET status = %s WHERE id = %s", (status, str(user_id)))


# ── the premise, asserted first ──────────────────────────────────────────────


def test_an_active_owner_reaches_both_paths(client: TestClient) -> None:
    """Without this, every refusal below could be passing for the wrong reason."""
    uid = _owner()
    token, _ = mint_device_token(uid, label="strap")
    assert client.get("/api/whoami", headers=_bearer(_jwt(uid))).json() == {"id": str(uid)}
    assert client.post("/ingest/whoami", headers=_bearer(token)).json() == {"id": str(uid)}


def _bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


# ── B2: suspension reaches every request path ────────────────────────────────


def test_a_suspended_owner_is_refused_on_the_api_path(client: TestClient) -> None:
    uid = _owner()
    assert client.get("/api/whoami", headers=_bearer(_jwt(uid))).status_code == 200
    _set_status(uid, "suspended")
    resp = client.get("/api/whoami", headers=_bearer(_jwt(uid)))
    assert resp.status_code == 403, "a suspended owner still had full /api/* access"


def test_a_suspended_owner_is_refused_on_the_ingest_path(client: TestClient) -> None:
    """The sharper half: `/ingest/*` is a WRITE into that owner's health history."""
    uid = _owner()
    token, _ = mint_device_token(uid, label="strap")
    assert client.post("/ingest/whoami", headers=_bearer(token)).status_code == 200
    _set_status(uid, "suspended")
    resp = client.post("/ingest/whoami", headers=_bearer(token))
    assert resp.status_code == 403, "a suspended owner's device could still write"


def test_the_refusal_is_403_and_not_401(client: TestClient) -> None:
    """The credential is valid and we know exactly who it is; what they lack is access.

    401 would tell the client its login failed and invite it to retry the login it just
    completed successfully — the same argument `supabase_auth.forbidden` already makes
    for a refused signup.
    """
    uid = _owner(status="suspended")
    resp = client.get("/api/whoami", headers=_bearer(_jwt(uid)))
    assert resp.status_code == 403
    assert resp.status_code != 401


def test_any_status_that_is_not_active_is_refused(client: TestClient) -> None:
    """Fail closed on an unknown word.

    `status` is free text (`TEXT NOT NULL DEFAULT 'active'`), so a future value —
    'deleted', 'pending', a typo — must refuse rather than be interpreted. An allowlist
    of one is the only reading that cannot be widened by accident.
    """
    for status in ("suspended", "deleted", "pending_deletion", "ACTIVE"):
        uid = _owner(status=status)
        resp = client.get("/api/whoami", headers=_bearer(_jwt(uid)))
        assert resp.status_code == 403, f"status={status!r} was let through"


def test_reactivating_an_owner_restores_access(client: TestClient) -> None:
    """Suspension is reversible; that is the whole point of not deleting the data."""
    uid = _owner(status="suspended")
    assert client.get("/api/whoami", headers=_bearer(_jwt(uid))).status_code == 403
    _set_status(uid, "active")
    assert client.get("/api/whoami", headers=_bearer(_jwt(uid))).status_code == 200


def test_one_owners_suspension_does_not_touch_another(client: TestClient) -> None:
    """The multi-tenant assertion: a status is a property of a ROW, not of the server."""
    suspended, active = _owner(status="suspended"), _owner()
    assert client.get("/api/whoami", headers=_bearer(_jwt(suspended))).status_code == 403
    assert client.get("/api/whoami", headers=_bearer(_jwt(active))).status_code == 200
