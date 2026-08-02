"""``POST /api/today/action`` — the reveal that GENERATES rather than reading the cache.

Built for ``PRICING.md`` §1a's weekly free teaser, which no longer exists; its real user
turned out to be the premium owner on a day the nightly chain has not warmed the line yet.
The 402 for everyone else is ``test_ai_gate.py``'s. What is asserted here is what happens
*after* the gate: a cold day generates, a warm one does not, a degraded line ships an
honest ``null``, and the retry loop that degraded line opens is bounded — that last one
by ``core.rate_limit``, which applies to a paying owner exactly as it did to a free one.

The daily action is absent from ``gate.PREMIUM_ALLOWANCE``, i.e. **uncapped for premium**,
so the refunds on these paths are no-ops today. They are asserted through their observable
consequence (no ledger row exists at all) rather than removed — see the router docstring.
"""

from __future__ import annotations

from collections.abc import Callable

import pytest
from fastapi.testclient import TestClient
from tests.insights._stub import StubLLM
from tests.premium.conftest import AUTH

from healthee.api import gate

pytestmark = pytest.mark.integration


def test_a_free_owner_cannot_reveal_it_at_all_and_costs_nothing_trying(
    bed: TestClient, make_free: Callable[[], None], stub: StubLLM
) -> None:
    """No AI in the free tier means the door does not open, not that it opens once."""
    make_free()
    response = bed.post("/api/today/action", headers=AUTH)
    assert response.status_code == 402
    assert response.json()["detail"]["feature"] == gate.DAILY_ACTION
    assert stub.calls == 0, "a refused reveal reached the model"


def test_the_today_read_still_omits_the_action_for_a_free_owner(
    bed: TestClient, make_free: Callable[[], None], stub: StubLLM
) -> None:
    """The read path never meters and never generates — the reveal is a door, not a page.

    If ``/api/today`` served the line it would be calling a model on a read path, which the
    standards forbid, and it would be serving a premium field to a free owner besides.
    """
    make_free()
    payload = bed.get("/api/today", headers=AUTH)
    assert '"action"' not in payload.text
    assert stub.calls == 0
    assert bed.post("/api/today/action", headers=AUTH).status_code == 402


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


def test_a_degraded_reveal_ships_an_honest_null_and_charges_nobody(
    bed: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """An ungroundable line ships nothing, and nothing is billed for shipping nothing.

    The model is scripted to answer with text the validator cannot accept, which is the
    real degraded path (``coaching._warm`` caches only a validated, unrefused line).
    """
    from healthee.insights import grounded

    broken = StubLLM(["Sleep eight hours and you will feel amazing."])
    monkeypatch.setattr(grounded, "get_client", lambda: broken)
    response = bed.post("/api/today/action", headers=AUTH)
    assert response.status_code == 200
    assert response.json()["action"] is None
    assert response.json()["degraded"] is True
    assert _allowance_rows() == 0, "a degraded reveal left a charge on the ledger"


def test_the_degraded_retry_loop_is_bounded_by_the_daily_cost_limiter(
    bed: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """An always-refunded allowance would be an unbounded LLM door without this.

    ``core.rate_limit`` composes with entitlement rather than replacing it: entitlement
    asks *may this person*, the budget asks *how often may anyone*. It binds a PAYING owner
    too — the daily action is uncapped for premium, so this limiter is the only thing
    standing between a degraded line and an unbounded retry loop.
    """
    from healthee.api.routers.daily_action import REVEAL_ATTEMPTS_PER_DAY
    from healthee.insights import grounded

    # The bound has to be a SMALL number, not merely a number: a test that only looped
    # `REVEAL_ATTEMPTS_PER_DAY` times and then expected a 429 would pass with the cap set
    # to 500, which is the unbounded door this exists to close. (A mutation to 500 did
    # exactly that until this line was added.)
    assert REVEAL_ATTEMPTS_PER_DAY <= 5, "the retry loop must stay cheap (#48)"
    broken = StubLLM(["Sleep eight hours and you will feel amazing."])
    monkeypatch.setattr(grounded, "get_client", lambda: broken)
    for _ in range(REVEAL_ATTEMPTS_PER_DAY):
        assert bed.post("/api/today/action", headers=AUTH).status_code == 200
    spent = broken.calls
    refused = bed.post("/api/today/action", headers=AUTH)
    assert refused.status_code == 429
    assert refused.json()["detail"]["reason"] == "reveal_attempts_spent"
    assert broken.calls == spent, "a 429'd attempt still reached the model"


def test_a_premium_owner_is_never_metered_by_it(bed: TestClient, stub: StubLLM) -> None:
    """Ten reveals, no 402, no ledger row: absent from `PREMIUM_ALLOWANCE` means uncapped.

    The ledger assertion is what distinguishes "uncapped" from "capped at eleven", and it
    is the observable form of ``gate.PREMIUM_ALLOWANCE``'s fail-open default.
    """
    for _ in range(10):
        assert bed.post("/api/today/action", headers=AUTH).status_code == 200
    assert stub.calls == 1, "the per-day cache stopped working for a premium owner"
    assert _allowance_rows() == 0


def _allowance_rows() -> int:
    """How many allowance ledger rows the seeded owner has — zero, for an uncapped path."""
    from healthee.core.db import tenant_transaction
    from healthee.core.tenancy import SENTINEL_USER_ID

    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "SELECT count(*) FROM kv WHERE user_id = %s AND key LIKE 'allowance%%'",
            (SENTINEL_USER_ID,),
        )
        row = cur.fetchone()
    return int(row[0]) if row else -1
