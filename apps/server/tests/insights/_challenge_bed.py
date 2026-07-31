"""Shared bed for the two coach-challenge-tool suites: one owner, one scripted model.

Not a pytest module (underscore-prefixed); the fixture the suites gate on lives in
``conftest.py`` where pytest can find it by name.
"""

from __future__ import annotations

import pytest
from tests.challenges import _seed
from tests.insights._stub import StubLLM

from healthee.challenges import store
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.insights import grounded

OWNER = _seed.OWNER
TZ = SENTINEL_TZ


def scripted_llm(monkeypatch: pytest.MonkeyPatch, responses: list[str]) -> StubLLM:
    """Point the choke point at a scripted client — no network, in either direction."""
    stub = StubLLM(responses)
    monkeypatch.setattr(grounded, "get_client", lambda: stub)
    return stub


def suggest(**overrides) -> int:
    """One seeded suggestion of the owner's; returns its id."""
    with tenant_transaction(OWNER) as cur:
        return _seed.seed_challenge(cur, OWNER, **overrides)


def stored(challenge_id: int) -> dict:
    """The row as the database actually holds it — what the tool must report."""
    with tenant_transaction(OWNER) as cur:
        return _seed.stored(cur, OWNER, challenge_id)


def suggested_ids() -> list[int]:
    with tenant_transaction(OWNER) as cur:
        return [int(row["id"]) for row in store.list_by_status(cur, OWNER, ("suggested",))]
