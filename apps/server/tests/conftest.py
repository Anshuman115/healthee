"""Shared test fixtures.

Unit tests set a minimal valid environment via the `env` fixture. Integration
tests depend on `db` (or `db_env`), which auto-skips when no TimescaleDB is
reachable — so `pytest` is green on a laptop with no database and exercises the
real DB in CI, where the service container sets POSTGRES_*.

## The whole suite runs as the LEAST-PRIVILEGE app role (6.5b-2)

`app_role_pool` below is autouse and session-scoped: it provisions the real
least-privilege role and points the **app pool** at it for the entire run, while
migrations / `TRUNCATE` / re-keying keep using the admin (`admin_connection`).

This is not tidiness — it is the acceptance bar for RLS. `POSTGRES_APP_*` is unset
in dev and CI, so without this fixture the app pool falls back to the admin
**superuser**, which `rolbypassrls` — every `0008` policy would be inert, every RLS
test would pass while protecting nothing, and any tenant query left on plain
`transaction()` would silently keep working here and return zero rows in prod. That
is the exact illusion 6.5b-1 exists to prevent, and it has bitten this project
before. `tests/db/test_rls.py::test_the_app_pool_is_never_privileged` asserts the
premise so a future env change cannot quietly undo it.
"""

from __future__ import annotations

import secrets
from collections.abc import Iterator

import psycopg
import pytest
from psycopg import sql

from healthee.core import db as db_module
from healthee.core.config import get_settings
from healthee.db import migrate, provision_app_role

# The suite's own app role. Named `_test` so it can never be confused with (or drop)
# a real deployment's `healthee_app`.
TEST_APP_ROLE = "healthee_app_test"

# Vars with defaults that the defaults tests assert on — cleared so the unit
# environment is hermetic (a dev shell that exports e.g. POSTGRES_PORT must not
# leak into a test asserting the default value).
_DEFAULTED_ENV_VARS = (
    "POSTGRES_HOST",
    "POSTGRES_PORT",
    "POSTGRES_DB",
    "POSTGRES_USER",
    "POSTGRES_APP_USER",
    "POSTGRES_APP_PASSWORD",
    "LOG_LEVEL",
    "API_HOST",
    "API_PORT",
    "OPENROUTER_API_KEY",
    "DEFAULT_MODEL",
    "COACH_MODEL",
    "TELEGRAM_BOT_TOKEN",
    "TELEGRAM_CHAT_ID",
    "SUPABASE_JWT_SECRET",
    "SUPABASE_SERVICE_ROLE_KEY",
    "SUPABASE_PROJECT_REF",
    "SUPABASE_JWT_AUD",
    "SIGNUPS_OPEN",
    "SIGNUP_ALLOWLIST",
)


@pytest.fixture
def env(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """Minimal, hermetic environment for constructing Settings in a unit test.

    Only the two effectively-required vars are set; every var that has a default
    is cleared so a test of the defaults sees the code's defaults, not whatever
    the ambient shell exported.
    """
    for var in _DEFAULTED_ENV_VARS:
        monkeypatch.delenv(var, raising=False)
    monkeypatch.setenv("POSTGRES_PASSWORD", "unit-test-pw")
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", "unit-test-token")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def _db_reachable() -> bool:
    """True if the configured DB accepts a trivial query within a short timeout."""
    try:
        settings = get_settings()
    except Exception:  # Settings can't even be built (e.g. no password) → skip
        return False
    try:
        with psycopg.connect(settings.admin_db_url, connect_timeout=3) as conn:
            conn.execute("SELECT 1")
    except Exception:
        return False
    return True


def drop_test_role(role: str) -> None:
    """Remove the role and every privilege granted to it, so the DB is left as found.

    `DROP OWNED BY` is what revokes the grants and the `ALTER DEFAULT PRIVILEGES`
    entries; a plain `DROP ROLE` would fail while they exist.
    """
    with db_module.admin_connection() as conn, conn.cursor() as cur:
        cur.execute(sql.SQL("DROP OWNED BY {}").format(sql.Identifier(role)))
        cur.execute(sql.SQL("DROP ROLE IF EXISTS {}").format(sql.Identifier(role)))


@pytest.fixture(scope="session", autouse=True)
def app_role_pool() -> Iterator[str | None]:
    """Point the app pool at the real least-privilege role for the whole session.

    Yields the role name, or None when no DB is reachable (unit-only runs stay green
    on a laptop with no database — the integration tests skip themselves anyway).

    Migrations run FIRST because `provision_app_role` grants table-by-table from an
    explicit list: on an empty database those GRANTs have nothing to grant on.

    A fresh random password per run — a fixed one in git is a credential in git even
    on a throwaway database. Torn down with `DROP OWNED BY` + `DROP ROLE` so neither
    the local DB nor CI's accumulates roles across runs.
    """
    if not _db_reachable():
        yield None
        return
    monkeypatch = pytest.MonkeyPatch()
    migrate.apply_migrations()
    monkeypatch.setenv("POSTGRES_APP_USER", TEST_APP_ROLE)
    monkeypatch.setenv("POSTGRES_APP_PASSWORD", secrets.token_urlsafe(24))
    get_settings.cache_clear()
    db_module.close_pool()  # so the next get_pool() connects as the app role
    provision_app_role.provision()
    yield TEST_APP_ROLE
    db_module.close_pool()
    drop_test_role(TEST_APP_ROLE)
    monkeypatch.undo()
    get_settings.cache_clear()


@pytest.fixture(scope="session")
def db_env(app_role_pool: str | None) -> None:
    """Skip the test unless a TimescaleDB is reachable from the current env."""
    if app_role_pool is None:
        pytest.skip("no reachable TimescaleDB — integration test skipped")


@pytest.fixture
def db(db_env: None) -> Iterator[None]:  # noqa: ARG001 — gates on reachability
    """Fresh DB pool for an integration test; closes it afterwards so the next
    test rebuilds against current config."""
    db_module.close_pool()
    yield
    db_module.close_pool()
