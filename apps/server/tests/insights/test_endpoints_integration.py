"""Seeded-DB endpoint tests with a stubbed LLM — grounded text + per-day caching.

Each insight endpoint runs through the choke point (stubbed, offline) and caches
its result: a second same-day call is served from ``kv`` with NO second LLM call.
Proves the wiring end-to-end and the caching contract (standards §Performance).
"""

from __future__ import annotations

import sys
from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from tests.conftest import entitle
from tests.insights._stub import VALID_TEXT, StubLLM

from healthee.api.app import create_app
from healthee.core.config import get_settings
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.db import migrate
from healthee.insights import grounded

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analytics"))
import _seed_db as sd  # type: ignore[import-not-found]  # noqa: E402 — shared v2 seed helpers

pytestmark = pytest.mark.integration

_TOKEN = "insights-test-token"
_AUTH = {"Authorization": f"Bearer {_TOKEN}"}


@pytest.fixture
def stub(monkeypatch: pytest.MonkeyPatch) -> Iterator[StubLLM]:
    """One shared stub client the choke point uses, plus the auth token in env."""
    client = StubLLM()
    monkeypatch.setattr(grounded, "get_client", lambda: client)
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", _TOKEN)
    get_settings.cache_clear()
    yield client
    get_settings.cache_clear()


def _seed() -> None:
    migrate.apply_migrations()
    # Every endpoint below is premium (6.6a) — without this the whole file 402s, and
    # would pass ONLY when some earlier test file happened to entitle the sentinel.
    entitle(SENTINEL_USER_ID)
    days = sd.recent_days(30)
    sd.clean("kv")
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, "rhr_daily", {d: 54.0 + (i % 3) for i, d in enumerate(days)})
        sd.seed_daily(cur, "hrv_sleep_avg", {d: 42.0 + (i % 4) for i, d in enumerate(days)})
        sd.seed_daily(cur, "steps_total", {d: 6000.0 + 80 * i for i, d in enumerate(days)})
        sd.seed_daily(cur, "vo2max_estimate", {d: 38.0 for d in days})
        sd.seed_daily(
            cur, "sleep_health_score_4dim", {d: 2.0 + (i % 2) for i, d in enumerate(days)}
        )


def test_sleep_insight_returns_grounded_text_and_caches(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    _seed()
    api = TestClient(create_app())
    first = api.get("/api/sleep/insight", headers=_AUTH)
    assert first.status_code == 200
    assert first.json()["insight"] == VALID_TEXT
    assert first.json()["validated"] is True
    assert stub.calls == 1
    second = api.get("/api/sleep/insight", headers=_AUTH)
    assert second.status_code == 200
    assert second.json() == first.json()
    assert stub.calls == 1  # served from cache — no second LLM call


def test_activity_insight_caches(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    _seed()
    api = TestClient(create_app())
    assert api.get("/api/activity/insight", headers=_AUTH).status_code == 200
    api.get("/api/activity/insight", headers=_AUTH)
    assert stub.calls == 1


def test_metric_insight_returns_text(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    _seed()
    api = TestClient(create_app())
    resp = api.get("/api/metric/insight", params={"metric": "rhr_daily"}, headers=_AUTH)
    assert resp.status_code == 200
    assert resp.json()["insight"] == VALID_TEXT
    assert stub.calls == 1


def test_metric_insight_rejects_unknown_metric(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    _seed()
    api = TestClient(create_app())
    resp = api.get("/api/metric/insight", params={"metric": "bogus"}, headers=_AUTH)
    assert resp.status_code == 422
    assert stub.calls == 0  # rejected before any LLM work


def test_metric_insight_rejects_retired_v1_name(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    # Not backward-compatible with the v1 app: the canonical name is hrv_sleep_avg.
    # The retired v1 alias is unknown → 422, before any LLM work.
    _seed()
    api = TestClient(create_app())
    resp = api.get("/api/metric/insight", params={"metric": "hrv_sleep_avg_ms"}, headers=_AUTH)
    assert resp.status_code == 422
    assert stub.calls == 0


def test_notable_returns_items(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    days = sd.recent_days(30)
    values = {d: 54.0 + (i % 3) for i, d in enumerate(days)}
    values[days[-2]] = 95.0  # a clear recent anomaly to surface
    sd.clean("kv")
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, "rhr_daily", values)
    api = TestClient(create_app())
    resp = api.get("/api/notable", headers=_AUTH)
    assert resp.status_code == 200
    body = resp.json()
    assert body["items"]  # the seeded spike surfaces as a notable shift
    assert body["items"][0]["metric"] == "rhr_daily"


def test_insight_requires_auth(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    _seed()
    api = TestClient(create_app())
    assert api.get("/api/sleep/insight").status_code == 401
