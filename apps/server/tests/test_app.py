"""Wiring smoke test — create_app mounts the health router. Inspects the OpenAPI
schema (the reliable path index; include_router uses a lazy wrapper route) so no
lifespan/DB is started.
"""

from __future__ import annotations

from healthee.api.app import create_app


def test_create_app_mounts_healthz() -> None:
    app = create_app()
    assert "/healthz" in app.openapi()["paths"]
    assert app.title == "Healthee"


def test_create_app_mounts_readyz_beside_it() -> None:
    """The dependency probe is a separate path on purpose — /healthz's contract is
    "restart me", and a provider outage must never mean that."""
    assert "/readyz" in create_app().openapi()["paths"]
