"""``POST /api/today/action`` — what a free owner's ONE weekly reveal buys, and costs.

The second teaser in ``PRICING.md`` §1a. Its interesting property is not the 402 (that is
``test_ai_gate.py``'s) but what counts as a *use*: the jobs chain never warms a free
owner's line, so revealing it means generating it, and three outcomes have to be told
apart — a generation that shipped (charged), a re-read of today's line (free), and a
degraded line (refunded, because the owner got nothing).
"""

from __future__ import annotations

from collections.abc import Callable

import pytest
from fastapi.testclient import TestClient
from tests.insights._stub import StubLLM
from tests.premium.conftest import AUTH

from healthee.api import gate

pytestmark = pytest.mark.integration


def test_a_free_owner_reveals_a_real_line_and_it_costs_one_model_call(
    bed: TestClient, make_free: Callable[[], None], stub: StubLLM
) -> None:
    """§1a's budget for the whole teaser is "~1–2 extra LLM calls / free user / week"."""
    make_free()
    response = bed.post("/api/today/action", headers=AUTH)
    assert response.status_code == 200
    body = response.json()
    assert body["action"], "the reveal revealed nothing"
    assert body["degraded"] is False
    assert stub.calls == 1


def test_the_today_read_still_omits_the_action_for_a_free_owner(
    bed: TestClient, make_free: Callable[[], None], stub: StubLLM
) -> None:
    """The read path never meters and never generates — the reveal is a door, not a page.

    If ``/api/today`` served the line, opening the app would spend the week's taste
    without the owner ever choosing to, and a read would be calling a model.
    """
    make_free()
    payload = bed.get("/api/today", headers=AUTH)
    assert '"action"' not in payload.text
    assert stub.calls == 0
    # …and the reveal is still available afterwards, i.e. the read charged nothing.
    assert bed.post("/api/today/action", headers=AUTH).status_code == 200


def test_a_free_owners_second_reveal_in_the_window_is_refused_not_re_served(
    bed: TestClient, make_free: Callable[[], None], stub: StubLLM
) -> None:
    """One reveal means ONE. The gate charges in the dependency, before the handler can
    see that today's line is cached — which is deliberate, because a gate that peeked and
    charged afterwards would let concurrent requests all pass the peek before any of them
    recorded a use. The response is where the line lives; the client holds it."""
    make_free()
    assert bed.post("/api/today/action", headers=AUTH).status_code == 200
    second = bed.post("/api/today/action", headers=AUTH)
    assert second.status_code == 402
    assert second.json()["detail"]["resets_at"]
    assert stub.calls == 1, "the refused reveal still cost tokens"


def test_a_premium_owner_re_reads_the_warmed_line_without_regenerating(
    bed: TestClient, stub: StubLLM
) -> None:
    """The cached branch's real user: the chain warmed it overnight, so nothing is
    generated and every call answers from ``kv`` (standards §Performance)."""
    first = bed.post("/api/today/action", headers=AUTH).json()
    again = bed.post("/api/today/action", headers=AUTH)
    assert again.status_code == 200
    assert again.json()["action"] == first["action"]
    assert stub.calls == 1, "the cached line was regenerated"


def test_a_degraded_reveal_does_not_consume_the_week(
    bed: TestClient, make_free: Callable[[], None], monkeypatch: pytest.MonkeyPatch
) -> None:
    """An ungroundable line ships nothing; charging a week for an apology would be a bait.

    The model is scripted to answer with text the validator cannot accept, which is the
    real degraded path (``coaching._warm`` caches only a validated, unrefused line).
    """
    from healthee.insights import grounded

    broken = StubLLM(["Sleep eight hours and you will feel amazing."])
    monkeypatch.setattr(grounded, "get_client", lambda: broken)
    make_free()
    response = bed.post("/api/today/action", headers=AUTH)
    assert response.status_code == 200
    assert response.json()["action"] is None
    assert response.json()["degraded"] is True
    # The taste is still in hand — the entitlement endpoint is the owner-visible proof.
    assert gate.DAILY_ACTION not in bed.get("/api/entitlement", headers=AUTH).json()["locked"]


def test_the_degraded_retry_loop_is_bounded_by_the_daily_cost_limiter(
    bed: TestClient, make_free: Callable[[], None], monkeypatch: pytest.MonkeyPatch
) -> None:
    """An always-refunded allowance would be an unbounded free LLM door without this.

    ``core.rate_limit`` composes with the allowance rather than replacing it: entitlement
    asks *may this person*, the budget asks *how often may anyone*.
    """
    from healthee.api.routers.daily_action import REVEAL_ATTEMPTS_PER_DAY
    from healthee.insights import grounded

    # The bound has to be a SMALL number, not merely a number: a test that only looped
    # `REVEAL_ATTEMPTS_PER_DAY` times and then expected a 429 would pass with the cap set
    # to 500, which is the unbounded door this exists to close. (A mutation to 500 did
    # exactly that until this line was added.) Five is the ceiling PRICING.md §6.3's
    # "free-tier cost control is existential" will tolerate on a free surface.
    assert REVEAL_ATTEMPTS_PER_DAY <= 5, "a free owner's retry loop must stay cheap (#48)"
    broken = StubLLM(["Sleep eight hours and you will feel amazing."])
    monkeypatch.setattr(grounded, "get_client", lambda: broken)
    make_free()
    for _ in range(REVEAL_ATTEMPTS_PER_DAY):
        assert bed.post("/api/today/action", headers=AUTH).status_code == 200
    spent = broken.calls
    refused = bed.post("/api/today/action", headers=AUTH)
    assert refused.status_code == 429
    assert refused.json()["detail"]["reason"] == "reveal_attempts_spent"
    assert broken.calls == spent, "a 429'd attempt still reached the model"
    # …and the 429 did not quietly eat the weekly reveal on its way out.
    assert gate.DAILY_ACTION not in bed.get("/api/entitlement", headers=AUTH).json()["locked"]


def test_a_premium_owner_is_never_metered_by_it(bed: TestClient, stub: StubLLM) -> None:
    """Ten reveals, no 402, and no ledger row — a premium owner never touches the table."""
    from healthee.core.db import tenant_transaction
    from healthee.core.tenancy import SENTINEL_USER_ID

    for _ in range(10):
        assert bed.post("/api/today/action", headers=AUTH).status_code == 200
    assert stub.calls == 1, "the per-day cache stopped working for a premium owner"
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "SELECT count(*) FROM kv WHERE user_id = %s AND key LIKE 'allowance%%'",
            (SENTINEL_USER_ID,),
        )
        row = cur.fetchone()
    assert row is not None and row[0] == 0
