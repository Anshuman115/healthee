"""Fixtures for the contract + integration bed: a seeded FastAPI client bound to a
reachable TimescaleDB. Auto-skips when no DB is reachable (same policy as the other
integration tests), so ``pytest`` stays green on a laptop with no database.
"""

from __future__ import annotations

from collections.abc import Iterator

import psycopg
import pytest
from fastapi.testclient import TestClient
from tests._auth import SECRET, auth_header

from healthee.api.app import create_app
from healthee.core import db as db_module
from healthee.core.config import get_settings
from healthee.core.tenancy import SENTINEL_USER_ID


def _db_reachable() -> bool:
    try:
        settings = get_settings()
        with psycopg.connect(settings.admin_db_url, connect_timeout=3) as conn:
            conn.execute("SELECT 1")
    except Exception:
        return False
    return True


@pytest.fixture
def seeded_client(
    monkeypatch: pytest.MonkeyPatch,
    owner_sweep: None,  # noqa: ARG001 — `seed_owner_b` provisions an owner; sweep it (#119)
) -> Iterator[tuple[TestClient, dict]]:
    """Seed the known dataset and yield (client, auth-headers). Skips without a DB."""
    monkeypatch.setenv("SUPABASE_JWT_SECRET", SECRET)
    monkeypatch.delenv("SUPABASE_PROJECT_REF", raising=False)
    get_settings.cache_clear()
    db_module.close_pool()
    if not _db_reachable():
        pytest.skip("no reachable TimescaleDB — contract test skipped")
    from tests.contracts.seed import seed_all

    seed_all()
    client = TestClient(create_app())
    yield client, auth_header(SENTINEL_USER_ID, SECRET)
    db_module.close_pool()
    get_settings.cache_clear()
