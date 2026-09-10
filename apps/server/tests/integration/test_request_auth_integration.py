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

pytestmark = [
    pytest.mark.integration,
    # This module provisions owners — explicitly, JIT on the first authenticated
    # request, or via `seed_owner_b` — and removed none of them. `--user`-less ops
    # tooling walks every active owner it finds, so the strays are not free (#119).
    pytest.mark.usefixtures("owner_sweep"),
]

_SECRET = "request-auth-int-supabase-secret-0123456789abcdef"
_AUD = "authenticated"


def _token(sub: UUID) -> str:
    return jwt.encode(
        {"sub": str(sub), "aud": _AUD, "exp": datetime.now(tz=UTC) + timedelta(hours=1)},
        _SECRET,
        algorithm="HS256",
    )


def _db_reachable() -> bool:
    try:
        with psycopg.connect(get_settings().admin_db_url, connect_timeout=3) as conn:
            conn.execute("SELECT 1")
    except Exception:
        return False
    return True


def _serving_app() -> FastAPI:
    """One endpoint behind the real `CurrentUser` dependency, echoing who it resolved."""
    app = FastAPI()

    @app.get("/whoami")
    def _whoami(user: CurrentUser) -> dict[str, str]:
        return {"id": str(user.id), "timezone": user.timezone}

    return app


@pytest.fixture
def _auth_env(monkeypatch: pytest.MonkeyPatch) -> Iterator[pytest.MonkeyPatch]:
    """Supabase verification configured against a real DB; the rest is per-deployment."""
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    monkeypatch.delenv("SUPABASE_PROJECT_REF", raising=False)
    yield monkeypatch
    db_module.close_pool()
    get_settings.cache_clear()


def _built(monkeypatch: pytest.MonkeyPatch) -> TestClient:
    get_settings.cache_clear()
    db_module.close_pool()
    if not _db_reachable():
        pytest.skip("no reachable TimescaleDB — auth integration test skipped")
    migrate.apply_migrations()
    return TestClient(_serving_app())


# ── One deployment now, because there is only one credential ─────────────────
#
# This file used to carry TWO client fixtures — one for the post-transition
# deployment and one for the transitional deployment where the shared
# `REALTIME_INGEST_TOKEN` still resolved to the sentinel. That branch is gone from
# `core.request_auth` (2026-09-10), so there is one deployment and one way in, and
# the tests that described the other one are below as a single negative: an opaque
# bearer is a 401, whatever it is.


@pytest.fixture
def signup_client(_auth_env: pytest.MonkeyPatch) -> TestClient:
    """The only deployment there is: real Supabase logins."""
    # This file asks *who* a token resolves to, not *whether* a stranger may sign up
    # (that is `tests/test_signup_gate.py`), so signups are open here.
    _auth_env.setenv("SIGNUPS_OPEN", "true")
    return _built(_auth_env)


def _whoami(client: TestClient, token: str) -> dict:
    resp = client.get("/whoami", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200, f"{resp.status_code}: {resp.text[:200]}"
    return resp.json()


def _set_timezone(user_id: UUID, tz: str) -> None:
    with transaction() as cur:
        cur.execute("UPDATE app_user SET timezone = %s WHERE id = %s", (tz, str(user_id)))


def test_a_valid_jwt_resolves_to_that_user(signup_client: TestClient) -> None:
    uid = uuid4()
    body = _whoami(signup_client, _token(uid))
    assert body["id"] == str(uid)  # the real user, not the sentinel
    assert body["id"] != str(SENTINEL_USER_ID)


def test_a_valid_jwt_jit_provisions_the_user(signup_client: TestClient) -> None:
    uid = uuid4()
    _whoami(signup_client, _token(uid))
    with transaction() as cur:
        cur.execute("SELECT count(*) FROM app_user WHERE id = %s", (str(uid),))
        row = cur.fetchone()
    assert row is not None and row[0] == 1


def test_AN_OPAQUE_BEARER_IS_401_AND_RESOLVES_TO_NOBODY(  # noqa: N802
    signup_client: TestClient,
) -> None:
    """The removed transition, asserted as an absence.

    Until 2026-09-10 a single shared string in this header resolved to the sentinel
    owner on every `/api/*` route. Deleting code cannot be proved by the code that is
    left, so the guarantee is written down as its consequence: a bearer that is not a
    verifiable JWT is refused, and no old secret is a special case of that.
    """
    for presented in ("request-auth-int-legacy-token", "", "Bearer", "a" * 64):
        resp = signup_client.get("/whoami", headers={"Authorization": f"Bearer {presented}"})
        assert resp.status_code == 401, f"{presented!r} was not refused"
        assert str(SENTINEL_USER_ID) not in resp.text


def test_the_sentinels_timezone_comes_from_its_row_not_the_constant(
    signup_client: TestClient,
) -> None:
    """Per-user timezone is real for the sentinel too — the `app_user` row is the source.

    Returning `SENTINEL_TZ` from the constant would make this owner's zone unchangeable
    and silently disagree with every query below, which threads the row's value. Reached
    through a JWT now rather than the shared token, because that is the only door left;
    the claim it makes about the row is unchanged.
    """
    _whoami(signup_client, _token(SENTINEL_USER_ID))  # provisions the row if absent
    _set_timezone(SENTINEL_USER_ID, "Pacific/Auckland")
    try:
        body = _whoami(signup_client, _token(SENTINEL_USER_ID))
        assert body["timezone"] == "Pacific/Auckland"
    finally:
        _set_timezone(SENTINEL_USER_ID, SENTINEL_TZ)
    assert _whoami(signup_client, _token(SENTINEL_USER_ID))["timezone"] == SENTINEL_TZ


def test_a_users_timezone_comes_from_their_own_row(signup_client: TestClient) -> None:
    """Two owners, two zones, one dependency — neither sees the other's boundary.

    The sentinel half of the original assertion moved to
    `test_the_sentinels_timezone_comes_from_its_row_not_the_constant`, which owns it and
    runs on the deployment where the legacy token exists. What is left here is the claim
    this test was named for: an owner's zone is THEIR row's, and setting it moves only
    theirs.
    """
    uid, other = uuid4(), uuid4()
    _whoami(signup_client, _token(uid))  # JIT-provisions at the column default
    _whoami(signup_client, _token(other))
    _set_timezone(uid, "America/Chicago")
    assert _whoami(signup_client, _token(uid))["timezone"] == "America/Chicago"
    assert _whoami(signup_client, _token(other))["timezone"] == "UTC"  # unaffected
