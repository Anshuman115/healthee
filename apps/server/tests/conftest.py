"""Shared test fixtures.

Unit tests set a minimal valid environment via the `env` fixture. Integration
tests depend on `db` (or `db_env`), which auto-skips when no TimescaleDB is
reachable — so `pytest` is green on a laptop with no database and exercises the
real DB in CI, where the service container sets POSTGRES_*.
"""

from __future__ import annotations

from collections.abc import Iterator

import psycopg
import pytest

from healthee.core import db as db_module
from healthee.core.config import get_settings

# Vars with defaults that the defaults tests assert on — cleared so the unit
# environment is hermetic (a dev shell that exports e.g. POSTGRES_PORT must not
# leak into a test asserting the default value).
_DEFAULTED_ENV_VARS = (
    "POSTGRES_HOST",
    "POSTGRES_PORT",
    "POSTGRES_DB",
    "POSTGRES_USER",
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
        with psycopg.connect(settings.db_url, connect_timeout=3) as conn:
            conn.execute("SELECT 1")
    except Exception:
        return False
    return True


@pytest.fixture(scope="session")
def db_env() -> None:
    """Skip the test unless a TimescaleDB is reachable from the current env."""
    if not _db_reachable():
        pytest.skip("no reachable TimescaleDB — integration test skipped")


@pytest.fixture
def db(db_env: None) -> Iterator[None]:  # noqa: ARG001 — gates on reachability
    """Fresh DB pool for an integration test; closes it afterwards so the next
    test rebuilds against current config."""
    db_module.close_pool()
    yield
    db_module.close_pool()
