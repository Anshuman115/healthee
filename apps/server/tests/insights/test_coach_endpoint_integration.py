"""POST /api/coach end-to-end with a stubbed LLM — seeded DB, no network.

The endpoint runs the whole coach loop (real context build over the seeded DB, the
stubbed model returns a validated answer) and returns the reply; and it 401s
without auth. The deeper honesty guarantees are unit-tested in ``test_coach.py``.
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
from healthee.db import migrate
from healthee.insights import coach

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analytics"))
import _seed_db as sd  # type: ignore[import-not-found]  # noqa: E402 — shared v2 seed helpers

pytestmark = pytest.mark.integration

_TOKEN = "coach-test-token"
_AUTH = {"Authorization": f"Bearer {_TOKEN}"}


@pytest.fixture
def stub(monkeypatch: pytest.MonkeyPatch) -> Iterator[StubLLM]:
    client = StubLLM()
    monkeypatch.setattr(coach, "get_client", lambda: client)
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", _TOKEN)
    get_settings.cache_clear()
    yield client
    get_settings.cache_clear()


def _seed() -> None:
    migrate.apply_migrations()
    days = sd.recent_days(30)
    with transaction() as cur:
        sd.clean(cur)
        sd.seed_daily(cur, "rhr_daily", {d: 54.0 for d in days})
        sd.seed_daily(cur, "hrv_sleep_avg", {d: 45.0 for d in days})


def test_coach_returns_a_reply_on_a_seeded_conversation(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    _seed()
    api = TestClient(create_app())
    resp = api.post(
        "/api/coach",
        headers=_AUTH,
        json={"messages": [{"role": "user", "content": "how is my recovery trending?"}]},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["reply"] == VALID_TEXT
    assert body["validated"] is True
    assert body["refused"] is False
    assert stub.calls == 1


def test_coach_refuses_a_diagnosis_question_without_calling_the_model(
    db: None, stub: StubLLM
) -> None:  # noqa: ARG001
    _seed()
    api = TestClient(create_app())
    resp = api.post(
        "/api/coach",
        headers=_AUTH,
        json={"messages": [{"role": "user", "content": "do I have sleep apnea?"}]},
    )
    assert resp.status_code == 200
    assert resp.json()["refused"] is True
    assert stub.calls == 0  # refused before any LLM/tool call


def test_coach_requires_auth(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    api = TestClient(create_app())
    assert api.post("/api/coach", json={"messages": []}).status_code == 401
