"""/readyz reports the AI layer without ever paying for a completion.

The contract this file pins, in one sentence: **`/healthz` keeps meaning "restart me",
`/readyz` means "something I depend on is broken", and neither of them costs a token.**

The last clause is the one worth a test of its own. A health check that makes a paid LLM
call per probe is a worse bug than the outage it detects — it bills the account on a
timer, and hardest exactly when the account is the problem.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from healthee.api.routers import readiness
from healthee.core.config import get_settings
from healthee.insights import credits
from healthee.insights import transport_health as th


class _StatusError(Exception):
    def __init__(self, status_code: int) -> None:
        super().__init__(f"Error code: {status_code}")
        self.status_code = status_code


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    """A `/readyz` with the DB faked healthy, a key configured, and a fresh record."""
    monkeypatch.setattr(readiness, "db_ok", lambda: True)
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-key-not-a-secret")
    monkeypatch.setenv("DEFAULT_MODEL", "vendor/cheap")
    monkeypatch.setenv("COACH_MODEL", "vendor/strong")
    monkeypatch.setenv("POSTGRES_PASSWORD", "unit-test-pw")
    get_settings.cache_clear()
    th.reset()
    app = FastAPI()
    app.include_router(readiness.router)
    yield TestClient(app)
    th.reset()
    get_settings.cache_clear()


def _balance(monkeypatch: pytest.MonkeyPatch, reading: credits.CreditsReading) -> None:
    monkeypatch.setattr(readiness.credits, "read_balance", lambda **_kw: reading)


def _healthy(remaining: float = 150.0) -> credits.CreditsReading:
    return credits.CreditsReading(
        status=credits.OK,
        checked_at=datetime.now(tz=UTC),
        remaining_usd=remaining,
        total_credits_usd=200.0,
        total_usage_usd=200.0 - remaining,
    )


# ── the happy path, and the honest "we have not looked yet" ───────────────────


def test_a_healthy_deployment_is_200(monkeypatch: pytest.MonkeyPatch, client: TestClient) -> None:
    _balance(monkeypatch, _healthy())
    th.record_success()
    body = client.get("/readyz").json()
    assert body["status"] == "ok"
    assert body["llm"]["transport"] == "ok"
    assert body["llm"]["balance"] == "ok"


def test_a_process_with_no_llm_traffic_reports_unknown_and_is_still_ready(
    monkeypatch: pytest.MonkeyPatch, client: TestClient
) -> None:
    """`unknown` is not `ok`, and it is also not a reason to fail a readiness probe."""
    _balance(monkeypatch, _healthy())
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json()["llm"]["transport"] == "unknown"


# ── the incident: a dead AI layer is finally visible ──────────────────────────


def test_repeated_402s_make_readyz_503_while_healthz_would_still_be_green(
    monkeypatch: pytest.MonkeyPatch, client: TestClient
) -> None:
    _balance(monkeypatch, _healthy())
    for _ in range(th.OUTAGE_THRESHOLD):
        th.record_failure(_StatusError(402))
    response = client.get("/readyz")
    assert response.status_code == 503
    body = response.json()
    assert body["db"] == "ok", "the DB was fine — this is not a DB outage"
    assert body["llm"]["transport"] == "down"
    assert body["llm"]["last_error_kind"] == "credit"
    assert body["llm"]["last_status_code"] == 402


def test_an_exhausted_balance_alone_is_enough_for_503(
    monkeypatch: pytest.MonkeyPatch, client: TestClient
) -> None:
    """The api container may have made no failing call yet; the account is still empty."""
    _balance(monkeypatch, _healthy(remaining=0.0))
    th.record_success()
    response = client.get("/readyz")
    assert response.status_code == 503
    assert response.json()["llm"]["balance"] == "exhausted"


def test_a_single_blip_is_reported_but_does_not_fail_the_probe(
    monkeypatch: pytest.MonkeyPatch, client: TestClient
) -> None:
    _balance(monkeypatch, _healthy())
    th.record_failure(_StatusError(429))
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json()["llm"]["transport"] == "degraded"


def test_a_low_balance_warns_in_the_body_without_failing_the_probe(
    monkeypatch: pytest.MonkeyPatch, client: TestClient
) -> None:
    """The layer still works. A probe that 503s on a warning is a probe that gets ignored."""
    _balance(monkeypatch, _healthy(remaining=1.0))
    th.record_success()
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json()["llm"]["balance"] == "low"


def test_an_unmeasurable_balance_is_reported_as_unknown_and_not_as_an_outage(
    monkeypatch: pytest.MonkeyPatch, client: TestClient
) -> None:
    """Uncertainty is reported, never acted on as if it were evidence."""
    _balance(
        monkeypatch,
        credits.CreditsReading(
            status=credits.ERROR, checked_at=datetime.now(tz=UTC), error="HTTP 500"
        ),
    )
    th.record_success()
    response = client.get("/readyz")
    assert response.status_code == 200
    body = response.json()
    assert body["llm"]["balance"] == "unknown"
    assert body["llm"]["balance_checked"] is False
    assert body["llm"]["balance_error"] == "HTTP 500"


def test_a_deployment_without_a_key_is_ready_not_broken(
    monkeypatch: pytest.MonkeyPatch, client: TestClient
) -> None:
    """Running without the AI layer is supported; reporting it as an outage is noise."""
    monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)
    get_settings.cache_clear()
    _balance(
        monkeypatch,
        credits.CreditsReading(status=credits.UNCONFIGURED, checked_at=datetime.now(tz=UTC)),
    )
    for _ in range(th.OUTAGE_THRESHOLD):
        th.record_failure(_StatusError(402))
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json()["llm"]["configured"] is False


def test_a_down_db_still_fails_readyz(monkeypatch: pytest.MonkeyPatch, client: TestClient) -> None:
    monkeypatch.setattr(readiness, "db_ok", lambda: False)
    _balance(monkeypatch, _healthy())
    response = client.get("/readyz")
    assert response.status_code == 503
    assert response.json()["db"] == "fail"


# ── the two constraints the endpoint was designed around ──────────────────────


def test_the_probe_never_makes_an_llm_call(
    monkeypatch: pytest.MonkeyPatch, client: TestClient
) -> None:
    """The rule: a health check that costs money per request is worse than the bug it finds."""
    from healthee.insights import client as llm_client

    def forbidden() -> object:
        raise AssertionError("/readyz constructed the LLM transport")

    monkeypatch.setattr(llm_client.OpenRouterClient, "_client", lambda _self: forbidden())
    _balance(monkeypatch, _healthy())
    assert client.get("/readyz").status_code == 200


def test_the_body_carries_no_dollar_figures(
    monkeypatch: pytest.MonkeyPatch, client: TestClient
) -> None:
    """It is unauthenticated (nginx proxies `/` wholesale); the amounts go to Telegram."""
    _balance(monkeypatch, _healthy(remaining=137.42))
    th.record_success()
    raw = client.get("/readyz").text
    for figure in ("137.42", "62.58", "200.0"):  # remaining, usage, and the total
        assert figure not in raw, f"{figure} leaked onto an unauthenticated endpoint"
