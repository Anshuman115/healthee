"""The dual-auth ACCEPT paths against a real DB (6.4b) — who each token resolves to.

`tests/test_request_auth.py` owns the rejection matrix (DB-free). This file owns the
half that needs a database: what an accepted token actually resolves to, and — the
point of per-user timezones — that the timezone comes from the owner's `app_user`
row rather than a compiled-in constant.

Auto-skips without a reachable TimescaleDB (same policy as the other DB tests).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import jwt
import psycopg
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from healthee.core import db as db_module
from healthee.core.config import get_settings
from healthee.core.db import transaction
from healthee.core.request_auth import CurrentUser
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate

pytestmark = pytest.mark.integration

_SECRET = "request-auth-int-supabase-secret-0123456789abcdef"
_AUD = "authenticated"
_LEGACY_TOKEN = "request-auth-int-legacy-token"


def _token(sub: UUID) -> str:
    return jwt.encode(
        {"sub": str(sub), "aud": _AUD, "exp": datetime.now(tz=UTC) + timedelta(hours=1)},
        _SECRET,
        algorithm="HS256",
    )


def _db_reachable() -> bool:
    try:
        with psycopg.connect(get_settings().db_url, connect_timeout=3) as conn:
            conn.execute("SELECT 1")
    except Exception:
        return False
    return True


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    """One endpoint behind the real `CurrentUser` dependency, echoing who it resolved."""
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", _LEGACY_TOKEN)
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    monkeypatch.delenv("SUPABASE_PROJECT_REF", raising=False)
    # This file asks *who* a token resolves to, not *whether* a stranger may sign up
    # (that is `tests/test_signup_gate.py`), so signups are open for its fixtures.
    monkeypatch.setenv("SIGNUPS_OPEN", "true")
    get_settings.cache_clear()
    db_module.close_pool()
    if not _db_reachable():
        pytest.skip("no reachable TimescaleDB — auth integration test skipped")
    migrate.apply_migrations()
    app = FastAPI()

    @app.get("/whoami")
    def _whoami(user: CurrentUser) -> dict[str, str]:
        return {"id": str(user.id), "timezone": user.timezone}

    yield TestClient(app)
    db_module.close_pool()
    get_settings.cache_clear()


def _whoami(client: TestClient, token: str) -> dict:
    resp = client.get("/whoami", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200, f"{resp.status_code}: {resp.text[:200]}"
    return resp.json()


def _set_timezone(user_id: UUID, tz: str) -> None:
    with transaction() as cur:
        cur.execute("UPDATE app_user SET timezone = %s WHERE id = %s", (tz, str(user_id)))


def test_a_valid_jwt_resolves_to_that_user(client: TestClient) -> None:
    uid = uuid4()
    body = _whoami(client, _token(uid))
    assert body["id"] == str(uid)  # the real user, not the sentinel
    assert body["id"] != str(SENTINEL_USER_ID)


def test_a_valid_jwt_jit_provisions_the_user(client: TestClient) -> None:
    uid = uuid4()
    _whoami(client, _token(uid))
    with transaction() as cur:
        cur.execute("SELECT count(*) FROM app_user WHERE id = %s", (str(uid),))
        row = cur.fetchone()
    assert row is not None and row[0] == 1


def test_the_legacy_shared_token_resolves_to_the_sentinel(client: TestClient) -> None:
    """The transition: today's app token keeps resolving exactly today's one tenant."""
    body = _whoami(client, _LEGACY_TOKEN)
    assert body["id"] == str(SENTINEL_USER_ID)
    assert body["timezone"] == SENTINEL_TZ  # the row 0003 seeds


def test_the_sentinels_timezone_comes_from_its_row_not_the_constant(client: TestClient) -> None:
    """Per-user timezone is real for the sentinel too — the `app_user` row is the source.

    Returning `SENTINEL_TZ` from the constant would make this owner's zone unchangeable
    and silently disagree with every query below, which threads the row's value.
    """
    _set_timezone(SENTINEL_USER_ID, "Pacific/Auckland")
    try:
        assert _whoami(client, _LEGACY_TOKEN)["timezone"] == "Pacific/Auckland"
    finally:
        _set_timezone(SENTINEL_USER_ID, SENTINEL_TZ)
    assert _whoami(client, _LEGACY_TOKEN)["timezone"] == SENTINEL_TZ


def test_a_users_timezone_comes_from_their_own_row(client: TestClient) -> None:
    """Two owners, two zones, one dependency — neither sees the other's boundary."""
    uid = uuid4()
    _whoami(client, _token(uid))  # JIT-provisions at the column default
    _set_timezone(uid, "America/Chicago")
    assert _whoami(client, _token(uid))["timezone"] == "America/Chicago"
    assert _whoami(client, _LEGACY_TOKEN)["timezone"] == SENTINEL_TZ  # unaffected
