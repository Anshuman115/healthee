"""Unit tests for core.auth — the Bearer-token dependency (valid/invalid/missing).

Uses a throwaway FastAPI app with one guarded route so no DB or real router is
needed.
"""

from __future__ import annotations

import pytest
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from healthee.core.auth import require_token
from healthee.core.config import get_settings

_TOKEN = "unit-test-token"


@pytest.fixture
def client(env: None) -> TestClient:  # noqa: ARG001 — env sets the token
    app = FastAPI()

    @app.get("/guarded", dependencies=[Depends(require_token)])
    def _guarded() -> dict[str, bool]:
        return {"ok": True}

    return TestClient(app)


def test_valid_token_passes(client: TestClient) -> None:
    resp = client.get("/guarded", headers={"Authorization": f"Bearer {_TOKEN}"})
    assert resp.status_code == 200
    assert resp.json() == {"ok": True}


def test_wrong_token_is_401(client: TestClient) -> None:
    resp = client.get("/guarded", headers={"Authorization": "Bearer nope"})
    assert resp.status_code == 401
    assert resp.json()["detail"] == "Invalid token"


def test_missing_header_is_401(client: TestClient) -> None:
    resp = client.get("/guarded")
    assert resp.status_code == 401
    assert "Missing" in resp.json()["detail"]


def test_malformed_header_is_401(client: TestClient) -> None:
    resp = client.get("/guarded", headers={"Authorization": _TOKEN})  # no "Bearer "
    assert resp.status_code == 401


def test_unconfigured_token_fails_closed(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("POSTGRES_PASSWORD", "pw")
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", "")  # not configured
    get_settings.cache_clear()
    app = FastAPI()

    @app.get("/guarded", dependencies=[Depends(require_token)])
    def _guarded() -> dict[str, bool]:
        return {"ok": True}

    resp = TestClient(app).get("/guarded", headers={"Authorization": "Bearer x"})
    assert resp.status_code == 401
    assert "not configured" in resp.json()["detail"]
    get_settings.cache_clear()
