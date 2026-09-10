"""`GET /api/auth-config` — the one endpoint that cannot require a credential.

It is the call a client makes in order to learn HOW to authenticate, so requiring
authentication would be circular. That makes it the one place where "what does this
return, and to whom" has to be reasoned about rather than assumed, which is what
these tests are.
"""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from healthee.api.routers import auth
from healthee.core.config import get_settings

_ANON = "anon-key-that-is-published-on-purpose"
# Deliberately word-shaped and low-entropy. A realistic-looking fixture here trips
# gitleaks' `generic-api-key` on the `SUPABASE_JWT_SECRET=` keyword, and the honest
# fix is a fixture that could not be mistaken for a key rather than an allowlist
# entry teaching the scanner to ignore that name.
_JWT_SECRET = "not-a-real-signing-secret-only-a-fixture"


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    """The router alone — no DB, because this endpoint touches none."""
    monkeypatch.setenv("POSTGRES_PASSWORD", "unit-test-pw")
    app = FastAPI()
    app.include_router(auth.router)
    yield TestClient(app)
    get_settings.cache_clear()


def _configure(monkeypatch: pytest.MonkeyPatch, **env: str) -> None:
    for key, value in env.items():
        monkeypatch.setenv(key, value)
    get_settings.cache_clear()


def test_IT_TAKES_NO_CREDENTIAL(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:  # noqa: N802
    """The load-bearing one. Every other `/api/*` route 401s without a bearer."""
    _configure(monkeypatch, SUPABASE_PROJECT_REF="abcdef", SUPABASE_ANON_KEY=_ANON)

    response = client.get("/api/auth-config")

    assert response.status_code == 200
    assert response.json()["supabase_anon_key"] == _ANON


def test_the_url_is_derived_from_the_project_ref(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A deployment that configured the ref for JWT verification does not repeat itself."""
    _configure(monkeypatch, SUPABASE_PROJECT_REF="abcdef", SUPABASE_ANON_KEY=_ANON)

    assert client.get("/api/auth-config").json()["supabase_url"] == "https://abcdef.supabase.co"


def test_an_explicit_url_wins_for_a_self_hosted_gotrue(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A self-hosted GoTrue has no project ref, so the derived form cannot serve it."""
    _configure(
        monkeypatch,
        SUPABASE_URL="https://auth.example.test/",
        SUPABASE_PROJECT_REF="abcdef",
        SUPABASE_ANON_KEY=_ANON,
    )

    # And the trailing slash is dropped: the client joins paths onto this.
    assert client.get("/api/auth-config").json()["supabase_url"] == "https://auth.example.test"


class TestHalfAConfigurationIsNoConfiguration:
    """Both values or neither — half of them is a form that submits into a 400."""

    def test_a_url_with_no_key_answers_nulls(
        self, client: TestClient, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        _configure(monkeypatch, SUPABASE_PROJECT_REF="abcdef", SUPABASE_ANON_KEY="")

        body = client.get("/api/auth-config").json()

        assert body == {"supabase_url": None, "supabase_anon_key": None}

    def test_a_key_with_no_url_answers_nulls(
        self, client: TestClient, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        _configure(monkeypatch, SUPABASE_PROJECT_REF="", SUPABASE_URL="", SUPABASE_ANON_KEY=_ANON)

        body = client.get("/api/auth-config").json()

        assert body == {"supabase_url": None, "supabase_anon_key": None}


def test_NULLS_ARE_A_200_AND_NOT_A_404(  # noqa: N802
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A box with no login configured is a real state, and a DIFFERENT one from a
    server too old to have this endpoint. Collapsing them would leave the app unable
    to tell "no login here" from "this server predates the question", and those need
    different sentences on a screen."""
    _configure(monkeypatch, SUPABASE_PROJECT_REF="", SUPABASE_URL="", SUPABASE_ANON_KEY="")

    response = client.get("/api/auth-config")

    assert response.status_code == 200
    assert response.json() == {"supabase_url": None, "supabase_anon_key": None}


def test_THE_SERVICE_ROLE_KEY_IS_NEVER_SERVED(  # noqa: N802
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The one that bypasses every policy. It is configured on the same object and
    it must never leave the server — least of all through the endpoint that
    deliberately takes no credential."""
    secret = "service-role-key-that-bypasses-every-policy"
    _configure(
        monkeypatch,
        SUPABASE_PROJECT_REF="abcdef",
        SUPABASE_ANON_KEY=_ANON,
        SUPABASE_SERVICE_ROLE_KEY=secret,
        SUPABASE_JWT_SECRET=_JWT_SECRET,
    )

    body = client.get("/api/auth-config").text

    assert secret not in body
    assert _JWT_SECRET not in body
    assert set(client.get("/api/auth-config").json()) == {"supabase_url", "supabase_anon_key"}


@pytest.mark.integration
def test_it_is_unauthenticated_IN_THE_SHIPPED_APP(monkeypatch: pytest.MonkeyPatch) -> None:  # noqa: N802
    """The test above mounts the router alone, which cannot see app-wide auth.

    That is exactly the shape of test that passes while the real thing is broken: a
    dependency added to `create_app` later, or a middleware, would 401 the one call
    a client has to be able to make before it has anything to present. So this one
    asks the app the deployment actually runs.
    """
    from healthee.api.app import create_app

    _configure(monkeypatch, SUPABASE_PROJECT_REF="abcdef", SUPABASE_ANON_KEY=_ANON)
    client = TestClient(create_app())

    response = client.get("/api/auth-config")

    assert response.status_code == 200, response.text
    assert response.json()["supabase_url"] == "https://abcdef.supabase.co"
    # And the premise: a neighbouring /api/* route DOES refuse the same bare call.
    assert client.get("/api/me").status_code == 401
