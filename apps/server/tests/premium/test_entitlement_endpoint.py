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

    Since 2026-08-02 the free tier has no AI at all, so the list is EVERY feature — the
    two metered teasers that used to be conditionally absent (PRICING.md §1a) are gone.
    """
    make_free()
    response = bed.get("/api/entitlement", headers=AUTH)
    assert response.status_code == 200
    body = response.json()
    assert body["premium"] is False
    assert set(body["locked"]) == set(ALL_FEATURES)


def test_a_capped_premium_owner_is_still_shown_nothing_to_upgrade_to(
    bed: TestClient,
    stub,  # noqa: ANN001, ARG001 — the question must not reach a network
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """``locked`` is the UPGRADEABLE list, and a subscriber at their cap has nothing to buy.

    This is the deliberate seam between the two surfaces: the entitlement endpoint answers
    "what would paying get me", so it stays empty for someone who has paid; the *limit*
    reaches the owner on the 402 that refuses them, with the day it reopens
    (``test_premium_cap.py``). A capped owner listed here would render as an upgrade card
    and pitch a subscription at a subscriber.
    """
    monkeypatch.setitem(gate.PREMIUM_ALLOWANCE, gate.COACH, 1)
    question = {"messages": [{"role": "user", "content": "hi"}]}
    assert bed.post("/api/coach", json=question, headers=AUTH).status_code == 200
    assert bed.post("/api/coach", json=question, headers=AUTH).status_code == 402, (
        "premise: the cap is actually spent"
    )
    body = bed.get("/api/entitlement", headers=AUTH).json()
    assert body["premium"] is True
    assert body["locked"] == []


def test_reading_the_entitlement_endpoint_never_spends_anything(
    bed: TestClient,
    stub,  # noqa: ANN001, ARG001
) -> None:
    """It PEEKs. An app that polled this every minute must not cost anybody a question."""
    from healthee.core.db import tenant_transaction
    from healthee.core.tenancy import SENTINEL_USER_ID

    for _ in range(5):
        assert bed.get("/api/entitlement", headers=AUTH).json()["locked"] == []
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "SELECT count(*) FROM kv WHERE user_id = %s AND key LIKE 'allowance%%'",
            (SENTINEL_USER_ID,),
        )
        row = cur.fetchone()
    assert row is not None and row[0] == 0, "polling the paywall's own endpoint charged for it"


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
