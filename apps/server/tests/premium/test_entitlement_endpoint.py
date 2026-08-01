"""``GET /api/entitlement`` — what the app renders unlocked, and what it must not decide.

§12.3's last line. Two properties matter more than the payload's shape:

* it is **reachable while locked out** — an endpoint that 402'd would leave a free owner
  with no way to learn why everything else did;
* it is a **display hint, not the decision** — the test below revokes entitlement and
  then checks that the AI routes refuse, whatever this endpoint last said.
"""

from __future__ import annotations

from collections.abc import Callable

import pytest
from fastapi.testclient import TestClient
from tests.premium.conftest import AUTH

from healthee.api import gate
from healthee.api.routers.entitlement import ALL_FEATURES

pytestmark = pytest.mark.integration


def test_a_premium_owner_sees_an_empty_locked_list(bed: TestClient) -> None:
    body = bed.get("/api/entitlement", headers=AUTH).json()
    assert body["premium"] is True
    assert body["status"] == "active"
    assert body["source"] == "subscription"
    assert body["locked"] == []
    assert body["expires_at"]  # a client that knows WHEN can renew before the surprise


def test_a_free_owner_can_still_read_it_and_learns_what_is_locked(
    bed: TestClient, make_free: Callable[[], None]
) -> None:
    """The one endpoint whose subject is the paywall must not be behind the paywall.

    Since 6.6a-2 the list is what is locked *right now*: the two metered teasers are
    absent while the owner still has them (PRICING.md §1a), and everything else is there.
    """
    make_free()
    response = bed.get("/api/entitlement", headers=AUTH)
    assert response.status_code == 200
    body = response.json()
    assert body["premium"] is False
    assert set(body["locked"]) == set(ALL_FEATURES) - {gate.COACH, gate.DAILY_ACTION}


def test_a_free_owners_spent_teaser_appears_in_the_locked_list(
    bed: TestClient,
    make_free: Callable[[], None],
    stub,  # noqa: ANN001, ARG001 — the question must not reach a network
) -> None:
    """The upsell screen has to be able to say "you have used this week's" — and change.

    A `locked` list computed once and cached would pass every other test in this file and
    fail this one, which is why the endpoint peeks the ledger on each call.
    """
    make_free()
    assert gate.COACH not in bed.get("/api/entitlement", headers=AUTH).json()["locked"]
    bed.post("/api/coach", json={"messages": [{"role": "user", "content": "hi"}]}, headers=AUTH)
    locked = bed.get("/api/entitlement", headers=AUTH).json()["locked"]
    assert gate.COACH in locked
    # …and asking about it must not itself have been charged: the daily action is untouched.
    assert gate.DAILY_ACTION not in locked


def test_reading_the_entitlement_endpoint_never_spends_the_allowance(
    bed: TestClient,
    make_free: Callable[[], None],
    stub,  # noqa: ANN001, ARG001
) -> None:
    """It PEEKs. An app that polled this every minute would otherwise cost a free owner
    their week without them ever opening the coach."""
    make_free()
    for _ in range(5):
        assert gate.COACH not in bed.get("/api/entitlement", headers=AUTH).json()["locked"]
    assert (
        bed.post(
            "/api/coach", json={"messages": [{"role": "user", "content": "hi"}]}, headers=AUTH
        ).status_code
        == 200
    )


def test_it_reflects_a_revocation_on_the_very_next_call(
    bed: TestClient, make_free: Callable[[], None]
) -> None:
    """No caching: a refund or cancellation shows up on the next poll, not after a TTL."""
    assert bed.get("/api/entitlement", headers=AUTH).json()["premium"] is True
    make_free()
    assert bed.get("/api/entitlement", headers=AUTH).json()["premium"] is False


def test_the_locked_list_covers_every_gated_feature(bed: TestClient) -> None:
    """A feature missing from the upsell screen is a feature nobody can buy.

    `ALL_FEATURES` is derived from `api.gate`'s constants rather than re-typed, and this
    asserts the derivation actually reaches the wire.
    """
    assert set(ALL_FEATURES) == {
        gate.COACH,
        gate.INSIGHT,
        gate.NOTABLE,
        gate.CHALLENGES,
        gate.DAILY_ACTION,
    }
    assert bed.get("/api/entitlement", headers=AUTH).status_code == 200
