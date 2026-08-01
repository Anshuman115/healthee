"""The 6.6a bed: one seeded owner whose entitlement a test can flip, over real HTTP.

Owner A is the sentinel (``seed_all``), reached with the legacy shared token exactly as
today's live app reaches the server — which makes this bed the one that would have
caught the deployment trap: a gate shipped with no entitlement row takes the live
owner's whole AI layer away, and every test here that asks for a 402 is the same call
path that would have produced it silently in production.

``free``/``premium`` flip the SERVER's state (the ``subscription`` row), never a header
or a client flag. §12.7's threat model is that the client is adversarial, so a test that
simulated "not premium" by asking nicely would be testing nothing.
"""

from __future__ import annotations

from collections.abc import Callable, Iterator

import pytest
from fastapi.testclient import TestClient
from tests.conftest import entitle
from tests.insights._stub import StubLLM

# Re-exported so pytest discovers it for this package too: `challenge_owner_with_history`
# is defined in `tests/insights/conftest.py`, and a conftest's fixtures are visible only
# to its own directory tree. Importing the function here re-registers it by name rather
# than duplicating a seven-day seed in two places.
from tests.insights.conftest import (  # noqa: E402, F401 — re-exported fixture
    challenge_owner_with_history,
)

from healthee.api.app import create_app
from healthee.core.config import get_settings
from healthee.core.db import close_pool
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.insights import coach, grounded

TOKEN = "premium-test-token"
AUTH = {"Authorization": f"Bearer {TOKEN}"}


@pytest.fixture
def bed(db: None, monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:  # noqa: ARG001
    """A seeded, authenticated client. The owner starts PREMIUM (``seed_all`` entitles)."""
    from tests.contracts.seed import seed_all

    monkeypatch.setenv("REALTIME_INGEST_TOKEN", TOKEN)
    get_settings.cache_clear()
    close_pool()
    seed_all()
    yield TestClient(create_app())
    close_pool()
    get_settings.cache_clear()


@pytest.fixture
def make_free() -> Callable[[], None]:
    """Revoke the seeded owner's entitlement — server-side, mid-test."""

    def revoke() -> None:
        entitle(SENTINEL_USER_ID, premium=False)

    return revoke


@pytest.fixture
def stub(monkeypatch: pytest.MonkeyPatch) -> StubLLM:
    """One offline LLM stub behind BOTH entry points into the shared choke point.

    The two surfaces run one pipeline (#46) but they still construct their own client —
    ``get_client`` is resolved per entry point, so both are patched. A test that measures
    LLM spend has to see every call, and patching one would leave the other on the network.
    """
    client = StubLLM()
    monkeypatch.setattr(grounded, "get_client", lambda: client)
    monkeypatch.setattr(coach, "get_client", lambda: client)
    return client
