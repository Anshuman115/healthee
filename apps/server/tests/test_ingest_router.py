"""Router wiring for POST /ingest/helio — the route is mounted and Bearer-guarded.

No DB: an unauthorized request is rejected by the auth dependency before any
ingest work runs, so these assert the HTTP contract without a database.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from healthee.api.app import create_app


def test_route_is_registered() -> None:
    app = create_app()
    assert "/ingest/helio" in app.openapi()["paths"]


def test_ingest_requires_bearer_token(env: None) -> None:  # noqa: ARG001 — sets token
    client = TestClient(create_app())
    resp = client.post("/ingest/helio", json={})  # valid empty payload, no auth
    assert resp.status_code == 401
