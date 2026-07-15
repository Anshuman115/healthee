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


@pytest.fixture
def env(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """Minimal valid environment for constructing Settings in a unit test."""
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
