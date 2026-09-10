"""A device token can be listed, revoked, and refused past a cap (auth audit C2).

Before this, a token was valid from the moment it was minted until somebody deleted
the row by hand — and nothing in the codebase deleted one. A lost phone kept write
access to that owner's health data permanently, with no user- or operator-facing way
to stop it.

Every case here is written against the property that matters rather than the call
that implements it: a revoked token must stop RESOLVING, a listing must never carry
a credential, and one owner's revoke must not reach another owner's token. The
storage side (hash-only, returned once) is owned by
`test_supabase_auth_integration.py` and is not re-asserted.
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
from healthee.core.device_token import (
    _MAX_LIVE_DEVICE_TOKENS,
    list_device_tokens,
    mint_device_token,
    resolve_device_token,
    revoke_device_token,
)
from healthee.db import migrate

pytestmark = [
    pytest.mark.integration,
    # Every test here provisions an owner and removes none; `--user`-less ops tooling
    # walks every active owner it finds, so the strays are not free (#119).
    pytest.mark.usefixtures("owner_sweep"),
]

_SECRET = "device-token-lifecycle-secret-0123456789abcdef"
_AUD = "authenticated"
# The transitional shared secret, for the one case that asserts it is refused.
_SHARED = "the-legacy-shared-ingest-token-0123456789"


def _make_token(sub: str) -> str:
    payload: dict[str, Any] = {
        "sub": sub,
        "aud": _AUD,
        "exp": datetime.now(tz=UTC) + timedelta(hours=1),
    }
    return jwt.encode(payload, _SECRET, algorithm="HS256")


def _bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def supabase_secret(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """The Supabase secret/aud, open signups, and NO legacy shared token."""
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    monkeypatch.delenv("SUPABASE_PROJECT_REF", raising=False)
    monkeypatch.setenv("SIGNUPS_OPEN", "true")
    # `core.config` refuses open signups beside a shared token, and so it should.
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", "")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def _client() -> TestClient:
    app = FastAPI()
    app.include_router(auth.router)
    return TestClient(app)


def _seed_owner() -> UUID:
    """An owner with an `app_user` row, so a device token has something to hang off."""
    uid = uuid4()
    with transaction() as cur:
        cur.execute("INSERT INTO app_user (id, email) VALUES (%s, %s)", (str(uid), None))
    return uid


def test_a_revoked_token_stops_resolving(
    db: None,  # noqa: ARG001 — gates on a reachable DB
    supabase_secret: None,  # noqa: ARG001
) -> None:
    migrate.apply_migrations()
    uid = _seed_owner()
    raw, token_id = mint_device_token(uid, label="the phone")

    assert resolve_device_token(raw) == uid
    assert revoke_device_token(uid, token_id) is True
    # The property, not the column: what must change is whether `/ingest/*` will
    # attribute a push to this owner.
    assert resolve_device_token(raw) is None


def test_revoking_twice_does_not_move_the_timestamp(
    db: None,  # noqa: ARG001
    supabase_secret: None,  # noqa: ARG001
) -> None:
    """`revoked_at` keeps saying when the credential actually stopped working."""
    migrate.apply_migrations()
    uid = _seed_owner()
    _, token_id = mint_device_token(uid, label=None)

    assert revoke_device_token(uid, token_id) is True
    with transaction() as cur:
        cur.execute("SELECT revoked_at FROM device_token WHERE id = %s", (str(token_id),))
        first = cur.fetchone()
    assert first is not None and first[0] is not None

    assert revoke_device_token(uid, token_id) is False
    with transaction() as cur:
        cur.execute("SELECT revoked_at FROM device_token WHERE id = %s", (str(token_id),))
        second = cur.fetchone()
    assert second is not None
    assert second[0] == first[0]


def test_a_revoked_token_does_not_touch_last_seen(
    db: None,  # noqa: ARG001
    supabase_secret: None,  # noqa: ARG001
) -> None:
    """Otherwise the column that answers "was it used after I revoked it?" lies.

    `resolve_device_token` is an UPDATE, so a filter applied after the write would
    still have stamped `last_seen` on every attempt with a revoked token — turning
    the audit trail into a log of refusals indistinguishable from uses.
    """
    migrate.apply_migrations()
    uid = _seed_owner()
    raw, token_id = mint_device_token(uid, label=None)
    assert resolve_device_token(raw) == uid  # one real use, so last_seen is set

    with transaction() as cur:
        cur.execute("SELECT last_seen FROM device_token WHERE id = %s", (str(token_id),))
        used = cur.fetchone()
    assert used is not None and used[0] is not None

    revoke_device_token(uid, token_id)
    assert resolve_device_token(raw) is None

    with transaction() as cur:
        cur.execute("SELECT last_seen FROM device_token WHERE id = %s", (str(token_id),))
        after = cur.fetchone()
    assert after is not None
    assert after[0] == used[0]


def test_one_owner_cannot_revoke_anothers_token(
    db: None,  # noqa: ARG001
    supabase_secret: None,  # noqa: ARG001
) -> None:
    """The owner is a predicate on the UPDATE, so this matches no row at all."""
    migrate.apply_migrations()
    mine = _seed_owner()
    theirs = _seed_owner()
    raw, token_id = mint_device_token(theirs, label="their phone")

    assert revoke_device_token(mine, token_id) is False
    # And the token they own still works, which is the half that would be missed by
    # asserting only that the call returned False.
    assert resolve_device_token(raw) == theirs


def test_the_listing_carries_no_credential(
    db: None,  # noqa: ARG001
    supabase_secret: None,  # noqa: ARG001
) -> None:
    """Not the raw token, and not its hash either — both are secrets on the wire."""
    migrate.apply_migrations()
    uid = _seed_owner()
    token = _make_token(str(uid))
    minted = _client().post("/api/device", json={"label": "Pixel 8"}, headers=_bearer(token))
    assert minted.status_code == 200
    raw = minted.json()["device_token"]

    resp = _client().get("/api/device", headers=_bearer(token))
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 1
    assert body[0]["label"] == "Pixel 8"
    printed = resp.text
    assert raw not in printed
    assert hashlib.sha256(raw.encode("utf-8")).hexdigest() not in printed


def test_a_listing_shows_only_this_owners_live_tokens(
    db: None,  # noqa: ARG001
    supabase_secret: None,  # noqa: ARG001
) -> None:
    migrate.apply_migrations()
    mine = _seed_owner()
    theirs = _seed_owner()
    _, kept = mint_device_token(mine, label="kept")
    _, dropped = mint_device_token(mine, label="dropped")
    mint_device_token(theirs, label="theirs")

    revoke_device_token(mine, dropped)
    rows = list_device_tokens(mine)

    # Revoked rows are excluded rather than flagged: this list answers "what can
    # currently write to my account?", and a revoked token is not an answer to it.
    assert [row.id for row in rows] == [kept]
    assert [row.label for row in rows] == ["kept"]


def test_the_cap_refuses_the_eleventh_and_a_revoke_frees_a_slot(
    db: None,  # noqa: ARG001
    supabase_secret: None,  # noqa: ARG001
) -> None:
    """A refusal an owner can act on, which is why the cap counts LIVE tokens."""
    migrate.apply_migrations()
    uid = _seed_owner()
    token = _make_token(str(uid))
    client = _client()

    ids: list[str] = []
    for _ in range(_MAX_LIVE_DEVICE_TOKENS):
        resp = client.post("/api/device", headers=_bearer(token))
        assert resp.status_code == 200
        ids.append(resp.json()["id"])

    refused = client.post("/api/device", headers=_bearer(token))
    assert refused.status_code == 409
    # The body IS the remedy — the mobile client prints a 409 verbatim.
    assert "revoke" in refused.json()["detail"].lower()

    assert client.delete(f"/api/device/{ids[0]}", headers=_bearer(token)).status_code == 204
    assert client.post("/api/device", headers=_bearer(token)).status_code == 200


def test_revoking_someone_elses_token_over_http_is_a_404(
    db: None,  # noqa: ARG001
    supabase_secret: None,  # noqa: ARG001
) -> None:
    """The same answer as an id that never existed, and deliberately so.

    Confirming that an id exists but is not yours tells a caller something about an
    account that is not theirs — a revocation endpoint that enumerated other owners'
    token ids would be a worse leak than the one it was built to close.
    """
    migrate.apply_migrations()
    mine = _seed_owner()
    theirs = _seed_owner()
    _, theirs_token = mint_device_token(theirs, label=None)

    client = _client()
    token = _make_token(str(mine))
    not_mine = client.delete(f"/api/device/{theirs_token}", headers=_bearer(token))
    never_existed = client.delete(f"/api/device/{uuid4()}", headers=_bearer(token))

    assert not_mine.status_code == 404
    assert never_existed.status_code == 404
    assert not_mine.json() == never_existed.json()


@pytest.fixture
def shared_token_configured(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """A deployment that still has the transitional shared token set.

    Signups must be CLOSED for this to be a legal configuration — `core.config`
    refuses one never-expiring secret that authenticates as a real tenant beside a
    deployment strangers can join — so this fixture is the honest shape of the
    transition, not a contrived one.
    """
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    monkeypatch.delenv("SUPABASE_PROJECT_REF", raising=False)
    monkeypatch.setenv("SIGNUPS_OPEN", "false")
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", _SHARED)
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def test_the_shared_token_cannot_mint_or_list_a_device_token(
    db: None,  # noqa: ARG001
    shared_token_configured: None,  # noqa: ARG001
) -> None:
    """The escalation these two endpoints are excluded from dual auth to prevent.

    Everywhere else on `/api/*`, the transitional shared secret resolves to the
    sentinel owner — which grants exactly what that secret already granted, and no
    more. Here it would grant something new: a permanent per-owner ingest token,
    forged by anyone holding the shared secret, that goes on OUTLIVING the shared
    token's removal. Listing is the same leak read backwards.

    This was a paragraph in `api/routers/auth.py` and nothing else. A dependency
    swapped from `current_user` to the dual-auth `request_user` would have been a
    one-word diff that broke it silently.
    """
    migrate.apply_migrations()
    client = _client()
    minted = client.post("/api/device", headers=_bearer(_SHARED))
    listed = client.get("/api/device", headers=_bearer(_SHARED))
    revoked = client.delete(f"/api/device/{uuid4()}", headers=_bearer(_SHARED))

    assert minted.status_code == 401
    assert listed.status_code == 401
    assert revoked.status_code == 401


def test_device_endpoints_refuse_an_unauthenticated_caller(
    db: None,  # noqa: ARG001
    supabase_secret: None,  # noqa: ARG001
) -> None:
    migrate.apply_migrations()
    client = _client()
    assert client.get("/api/device").status_code == 401
    assert client.delete(f"/api/device/{uuid4()}").status_code == 401
