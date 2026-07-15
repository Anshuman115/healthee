"""Fixtures for the contract + integration bed: a seeded FastAPI client bound to a
reachable TimescaleDB. Auto-skips when no DB is reachable (same policy as the other
integration tests), so ``pytest`` stays green on a laptop with no database.
"""

from __future__ import annotations

from collections.abc import Iterator

import psycopg
import pytest
from fastapi.testclient import TestClient

from healthee.api.app import create_app
from healthee.core import db as db_module
from healthee.core.config import get_settings

_TOKEN = "contract-token"


def _db_reachable() -> bool:
    try:
        settings = get_settings()
        with psycopg.connect(settings.db_url, connect_timeout=3) as conn:
            conn.execute("SELECT 1")
    except Exception:
        return False
    return True


@pytest.fixture
def seeded_client(monkeypatch: pytest.MonkeyPatch) -> Iterator[tuple[TestClient, dict]]:
    """Seed the known dataset and yield (client, auth-headers). Skips without a DB."""
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", _TOKEN)
    get_settings.cache_clear()
    db_module.close_pool()
    if not _db_reachable():
        pytest.skip("no reachable TimescaleDB — contract test skipped")
    from tests.contracts.seed import seed_all

    seed_all()
    client = TestClient(create_app())
    yield client, {"Authorization": f"Bearer {_TOKEN}"}
    db_module.close_pool()
    get_settings.cache_clear()
