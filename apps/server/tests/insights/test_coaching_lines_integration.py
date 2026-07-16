"""The WP5-deferred coaching one-liners: /api/today action + /api/sleep tonight.

Both are generated through the choke point (stubbed) and cached per day; the read
endpoints carry the cached text (and ``None`` when cold — the read path never
generates, standards §Performance).
"""

from __future__ import annotations

import sys
from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from tests.insights._stub import VALID_TEXT, StubLLM

from healthee.api.app import create_app
from healthee.core.config import get_settings
from healthee.core.db import transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.insights import coaching, grounded

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analytics"))
import _seed_db as sd  # type: ignore[import-not-found]  # noqa: E402 — shared v2 seed helpers

pytestmark = pytest.mark.integration

_TOKEN = "coaching-test-token"
_AUTH = {"Authorization": f"Bearer {_TOKEN}"}


@pytest.fixture
def stub(monkeypatch: pytest.MonkeyPatch) -> Iterator[StubLLM]:
    client = StubLLM()
    monkeypatch.setattr(grounded, "get_client", lambda: client)
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", _TOKEN)
    get_settings.cache_clear()
    yield client
    get_settings.cache_clear()


def _seed() -> None:
    migrate.apply_migrations()
    days = sd.recent_days(30)
    with transaction() as cur:
        cur.execute("DELETE FROM kv")
        sd.clean(cur)
        sd.seed_daily(cur, "recovery_score", {d: 70.0 for d in days})
        sd.seed_daily(cur, "sleep_regularity_index", {d: 74.0 for d in days})


def test_today_action_is_none_when_cold_then_filled_after_warming(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    _seed()
    api = TestClient(create_app())
    assert api.get("/api/today", headers=_AUTH).json()["action"] is None  # cold: no LLM
    assert stub.calls == 0
    warmed = coaching.warm_daily_action(
        SENTINEL_USER_ID, SENTINEL_TZ
    )  # off the read path, through the choke point
    assert warmed["text"] == VALID_TEXT
    assert api.get("/api/today", headers=_AUTH).json()["action"] == VALID_TEXT
    assert stub.calls == 1  # generated once; the read served it from cache


def test_sleep_tonight_line_fills_after_warming(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    _seed()
    api = TestClient(create_app())
    consistency = api.get("/api/sleep/consistency", headers=_AUTH)
    assert consistency.json()["tonight"] is None
    coaching.warm_sleep_tonight(SENTINEL_USER_ID, SENTINEL_TZ)
    again = api.get("/api/sleep/consistency", headers=_AUTH)
    assert again.json()["tonight"] == VALID_TEXT
