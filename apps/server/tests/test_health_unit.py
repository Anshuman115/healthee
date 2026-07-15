"""Unit test for the /healthz response shaping — DB up vs down — with the DB
call faked, so it runs without a database.
"""

from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from healthee.api.routers import health


def test_healthz_200_when_db_ok(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(health, "_db_ok", lambda: True)
    app = FastAPI()
    app.include_router(health.router)
    resp = TestClient(app).get("/healthz")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok", "db": "ok"}


def test_healthz_503_when_db_down(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(health, "_db_ok", lambda: False)
    app = FastAPI()
    app.include_router(health.router)
    resp = TestClient(app).get("/healthz")
    assert resp.status_code == 503
    assert resp.json()["db"] == "fail"


def test_db_ok_logs_and_returns_false_on_error(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    def _boom() -> object:
        raise RuntimeError("pool down")

    monkeypatch.setattr(health, "transaction", _boom)
    assert health._db_ok() is False
    assert any("db check failed" in r.message for r in caplog.records)
