"""``GET /api/history`` metric-name validation (contract gap #59).

An unknown metric must be a 422, not a 200 with a confident-looking empty series
("that isn't a metric" ≠ "you have no data"). Every name the server recognizes —
the canonical v2 registry, data-bearing or a legitimate empty case — stays
non-422; a retired v1 name is just an unknown metric now (the v2 app sends
canonical names). The accepted set is asserted here by parametrizing over the
whole registry, so a future metric is auto-covered.
"""

from __future__ import annotations

import sys
from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from healthee.analytics.metrics import KNOWN_METRICS
from healthee.api.app import create_app
from healthee.core.config import get_settings
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.db import migrate

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analytics"))
import _seed_db as sd  # type: ignore[import-not-found]  # noqa: E402 — shared v2 seed helpers

pytestmark = pytest.mark.integration

_TOKEN = "history-test-token"
_AUTH = {"Authorization": f"Bearer {_TOKEN}"}


@pytest.fixture
def api(monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    """A seeded client whose bearer token maps to the sentinel owner."""
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", _TOKEN)
    get_settings.cache_clear()
    migrate.apply_migrations()
    sd.clean()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        days = sd.recent_days(10)
        sd.seed_daily(cur, "rhr_daily", {d: 55.0 + i for i, d in enumerate(days)})
    client = TestClient(create_app())
    yield client
    get_settings.cache_clear()


def test_known_metric_with_data_returns_series(db: None, api: TestClient) -> None:  # noqa: ARG001
    resp = api.get("/api/history", params={"metric": "rhr_daily"}, headers=_AUTH)
    assert resp.status_code == 200
    body = resp.json()
    assert body["metric"] == "rhr_daily"
    assert len(body["series"]) == 10


def test_known_metric_without_data_returns_empty_200(db: None, api: TestClient) -> None:  # noqa: ARG001
    # A real metric with no rows must STILL be 200-empty — the legitimate
    # "no data" case, which the 422 gate must not touch.
    resp = api.get("/api/history", params={"metric": "vo2max_estimate"}, headers=_AUTH)
    assert resp.status_code == 200
    assert resp.json() == {"metric": "vo2max_estimate", "series": []}


def test_retired_v1_name_is_422(db: None, api: TestClient) -> None:  # noqa: ARG001
    # We are not backward-compatible with the v1 mobile app: the canonical name is
    # hrv_sleep_avg (in V2_DAILY_METRICS). The retired v1 alias is now unknown → 422.
    resp = api.get("/api/history", params={"metric": "hrv_sleep_avg_ms"}, headers=_AUTH)
    assert resp.status_code == 422


def test_unknown_metric_is_422(db: None, api: TestClient) -> None:  # noqa: ARG001
    resp = api.get("/api/history", params={"metric": "bogus"}, headers=_AUTH)
    assert resp.status_code == 422
    assert "bogus" in resp.json()["detail"]


@pytest.mark.parametrize("metric", sorted(KNOWN_METRICS))
def test_every_known_metric_is_not_422(db: None, api: TestClient, metric: str) -> None:  # noqa: ARG001
    # Parametrized over the whole registry: any name the server recognizes must
    # pass validation (200, data-bearing or empty). Adding a metric auto-covers it.
    resp = api.get("/api/history", params={"metric": metric}, headers=_AUTH)
    assert resp.status_code != 422
