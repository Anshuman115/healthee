"""The premium coach cap — 20 questions per rolling 30 local days (PRICING.md §0).

Until 2026-08-02 ``api/gate.py`` said "premium removes the limit", and it did: a premium
owner never touched a ledger. It cannot stay that way at a measured **$0.179** a coach
question against **$6.99** of price — 30 questions is $6.98 of cost, so the cap is the
product, not an implementation detail.

What is asserted here, and why each one is separate:

* the two TABLES, as the only executable copies of §0/§1a's numbers — a unit assertion, so
  changing a price without changing the doc that sells it fails the build;
* the cap over real HTTP, because the charge happens in a FastAPI dependency and calling
  ``run_coach`` directly would exercise the loop and none of the metering;
* the **refund**, in all three shapes a coach turn can deliver nothing — we do not bill a
  slot for an answer we did not deliver, and that sentence is only true if every path that
  can charge and return nothing gives it back;
* the ASYMMETRY between the tables: absent from ``FREE_ALLOWANCE`` is hard-locked, absent
  from ``PREMIUM_ALLOWANCE`` is unlimited, and a reader who assumes one for the other gets
  either a paywalled subscriber or an uncapped bill.

The HTTP cap tests run against a cap patched down to two. The real 20 is pinned by the
table test and exercised against the ledger; asking twenty-one questions through the
pipeline to prove an integer is passed correctly would buy nothing and cost a minute.
"""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from tests.insights._stub import StubLLM
from tests.premium.conftest import AUTH

from healthee.api import gate
from healthee.core import allowance
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID

pytestmark = pytest.mark.integration

QUESTION = {"messages": [{"role": "user", "content": "how am I doing?"}]}
MONDAY_EVENING = datetime(2026, 3, 2, 21, 0, tzinfo=UTC)


def _coach_uses() -> int:
    """How many coach questions the owner has on record in the PREMIUM window."""
    verdict = allowance.peek(
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        gate.COACH,
        gate.PREMIUM_COACH_QUESTIONS,
        window_days=gate.PREMIUM_WINDOW_DAYS,
    )
    return verdict.used


def _cap_at(monkeypatch: pytest.MonkeyPatch, questions: int) -> None:
    monkeypatch.setitem(gate.PREMIUM_ALLOWANCE, gate.COACH, questions)


# ── the priced numbers, against the docs that sell them ───────────────────────


def test_the_free_table_is_all_zero() -> None:
    """PRICING.md §1a: "no AI in the free tier — at all". Not one, not a taste. Zero.

    The dict survives at zero on purpose (§1a calls it "the executable table"), so this
    asserts the VALUES rather than the dict's absence, and asserts every feature is present
    so a feature quietly dropped from the table cannot be read as an unpriced one.
    """
    assert gate.FREE_ALLOWANCE == {
        gate.COACH: 0,
        gate.DAILY_ACTION: 0,
        gate.INSIGHT: 0,
        gate.NOTABLE: 0,
        gate.CHALLENGES: 0,
    }
    assert set(gate.FREE_ALLOWANCE) == set(gate.FEATURES), "a feature with no priced allowance"


def test_the_premium_table_caps_the_coach_and_nothing_else() -> None:
    """PRICING.md §0: 20 coach questions / 30 days, and nothing else capped.

    The second assertion is the load-bearing one: this table's default is UNLIMITED, so a
    feature appearing here is a new cap on a paying owner and must be a deliberate act.
    """
    assert gate.PREMIUM_ALLOWANCE == {gate.COACH: 20}
    assert gate.PREMIUM_COACH_QUESTIONS == 20
    assert gate.PREMIUM_WINDOW_DAYS == 30
    assert allowance.WINDOW_DAYS == 7, "the ledger's default window is still §1a's"


def test_the_included_questions_run_out_at_exactly_the_cap(db: None) -> None:  # noqa: ARG001
    """The real 20, against the real ledger: twenty go through and the twenty-first does not."""
    from tests.contracts.seed import seed_all

    seed_all()
    for i in range(gate.PREMIUM_COACH_QUESTIONS):
        verdict = allowance.spend(
            SENTINEL_USER_ID,
            SENTINEL_TZ,
            gate.COACH,
            gate.PREMIUM_COACH_QUESTIONS,
            now=MONDAY_EVENING + timedelta(hours=i),
            window_days=gate.PREMIUM_WINDOW_DAYS,
        )
        assert verdict.allowed is True, f"question {i + 1} of the included 20 was refused"
    over = allowance.spend(
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        gate.COACH,
        gate.PREMIUM_COACH_QUESTIONS,
        now=MONDAY_EVENING + timedelta(hours=gate.PREMIUM_COACH_QUESTIONS),
        window_days=gate.PREMIUM_WINDOW_DAYS,
    )
    assert over.allowed is False, "the 21st question was included too"
    assert over.used == gate.PREMIUM_COACH_QUESTIONS


# ── the cap at the HTTP edge ──────────────────────────────────────────────────


def test_a_premium_owner_is_refused_402_past_the_cap(
    bed: TestClient,
    stub: StubLLM,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """ "premium removes the limit" is no longer true, and this is where that is enforced."""
    _cap_at(monkeypatch, 2)
    for _ in range(2):
        assert bed.post("/api/coach", json=QUESTION, headers=AUTH).status_code == 200
    spent = stub.calls
    assert spent > 0, "the included questions never reached the model"

    refused = bed.post("/api/coach", json=QUESTION, headers=AUTH)
    assert refused.status_code == 402, "a capped premium owner was served a third question"
    assert stub.calls == spent, "the refused question still cost tokens"


def test_the_refusal_tells_a_paying_owner_when_it_comes_back_and_sells_them_nothing(
    bed: TestClient,
    stub: StubLLM,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The body is the whole point: this owner already paid, so it must not be an upsell.

    ``upgrade`` is asserted ABSENT rather than merely unused, because the app renders an
    upgrade button from its presence — a capped subscriber offered a subscription is the
    locked card lying about what happened.
    """
    _cap_at(monkeypatch, 1)
    assert bed.post("/api/coach", json=QUESTION, headers=AUTH).status_code == 200
    refused = bed.post("/api/coach", json=QUESTION, headers=AUTH)

    detail = refused.json()["detail"]
    assert detail["locked"] is True
    assert detail["feature"] == gate.COACH
    assert detail["limit"] == 1
    assert detail["used"] == 1
    assert detail["resets_at"], "a refusal that cannot say when is the vague one (§Errors)"
    assert int(refused.headers["Retry-After"]) > 0
    assert "upgrade" not in detail, "a paying owner was shown an upgrade link"
    assert "premium" in detail["error"] and "subscription" in detail["error"]
    assert detail["resets_at"][:10] in detail["error"], "the sentence never names the day"


def test_the_charge_lands_in_the_thirty_day_row_not_the_seven_day_one(
    bed: TestClient,
    stub: StubLLM,  # noqa: ARG001
) -> None:
    """The gate must pass the PREMIUM window, or the cap would roll every week instead."""
    from healthee.core.db import tenant_transaction

    assert bed.post("/api/coach", json=QUESTION, headers=AUTH).status_code == 200
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "SELECT key FROM kv WHERE user_id = %s AND key LIKE 'allowance%%'",
            (SENTINEL_USER_ID,),
        )
        keys = sorted(row[0] for row in cur.fetchall())
    assert keys == [f"allowance:{gate.COACH}:{gate.PREMIUM_WINDOW_DAYS}d"], keys


# ── the refund contract, now that premium actually charges ────────────────────


def test_a_refused_question_does_not_consume_an_included_one(
    bed: TestClient,
    stub: StubLLM,
) -> None:
    """A pre-LLM refusal costs no tokens and must cost no slot either.

    "Do I have diabetes?" is classified out of scope before any model runs
    (``insights.refusals``), so the owner got the product working correctly and no answer.
    Billing one of twenty for that is billing for an answer we did not deliver.
    """
    refusal = bed.post(
        "/api/coach",
        json={"messages": [{"role": "user", "content": "do I have diabetes?"}]},
        headers=AUTH,
    )
    assert refusal.status_code == 200
    assert refusal.json()["refused"] is True
    assert stub.calls == 0
    assert _coach_uses() == 0, "the refusal was billed as one of the included questions"


def test_an_unvalidatable_answer_does_not_consume_an_included_one(
    bed: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The honest fallback is the product working — and it is still not an answer."""
    from healthee.insights import coach as coach_module
    from healthee.insights import grounded

    broken = StubLLM(["Your recovery suggests overtraining [not_a_real_note]."])
    monkeypatch.setattr(grounded, "get_client", lambda: broken)
    monkeypatch.setattr(coach_module, "get_client", lambda: broken)

    fallback = bed.post("/api/coach", json=QUESTION, headers=AUTH)
    assert fallback.status_code == 200
    assert fallback.json()["validated"] is False
    assert _coach_uses() == 0, "the honest fallback was billed as an answer"


def test_a_transport_failure_does_not_consume_an_included_one(
    bed: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The ``except`` branch of ``routers/coach.py``: refund on the way out, then re-raise."""
    from healthee.api.routers import coach as coach_router

    def explode(*_args: object, **_kwargs: object) -> None:
        raise RuntimeError("the provider hung up")

    monkeypatch.setattr(coach_router, "run_coach", explode)
    with pytest.raises(RuntimeError, match="hung up"):
        bed.post("/api/coach", json=QUESTION, headers=AUTH)
    assert _coach_uses() == 0, "a request that raised kept the owner's question"


def test_a_delivered_answer_really_is_billed(bed: TestClient, stub: StubLLM) -> None:
    """The other side of the refund: a working answer must actually cost a slot.

    Without this, a refund bug that gave everything back would look like a passing suite.
    """
    reply = bed.post("/api/coach", json=QUESTION, headers=AUTH)
    assert reply.status_code == 200
    assert reply.json()["validated"] is True
    assert stub.calls > 0
    assert _coach_uses() == 1


def test_a_tool_calling_question_charges_once_not_once_per_model_call(
    bed: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The metered UNIT is the question, and the coach's gathering allowance is 20 deep.

    ``routers/coach.py`` says so in prose; this measures it, because the two numbers differ
    by more than an order of magnitude. A question that spends ten tool rounds makes eleven
    model calls and must still cost ONE of the twenty — otherwise a generous gathering
    budget quietly became a 20× pricing change.
    """
    from tests.insights._coach_stub import CoachStub, text_turn, tool_call, tool_turn
    from tests.insights._stub import VALID_TEXT

    from healthee.insights import coach as coach_module
    from healthee.insights import coach_tools

    rounds = 10
    script = [
        tool_turn(tool_call(f"c{i}", "query_metric", f'{{"metric": "m{i}"}}'))
        for i in range(rounds)
    ]
    stub = CoachStub([*script, text_turn(VALID_TEXT)])
    monkeypatch.setattr(coach_module, "get_client", lambda: stub)
    monkeypatch.setattr(coach_tools, "execute_tool", lambda name, args, uid, tz: {"ok": True})

    reply = bed.post("/api/coach", json=QUESTION, headers=AUTH)
    assert reply.status_code == 200
    assert reply.json()["validated"] is True
    assert stub.calls == rounds + 1, "the loop did not actually make many model calls"
    assert _coach_uses() == 1, f"eleven model calls billed {_coach_uses()} included questions"


# ── absent from the premium table means UNLIMITED ─────────────────────────────


@pytest.mark.parametrize("path", ["/api/sleep/insight", "/api/notable", "/api/challenges"])
def test_a_premium_feature_that_is_not_in_the_table_is_never_capped(
    bed: TestClient,
    stub: StubLLM,  # noqa: ARG001
    path: str,
) -> None:
    """The asymmetry, measured: the cards are $0.0084 and stay uncapped by decision.

    Ten calls is well past any plausible cap somebody might add by accident, and the ledger
    assertion is what distinguishes "uncapped" from "capped at eleven".
    """
    for _ in range(10):
        assert bed.get(path, headers=AUTH).status_code != 402, path
    from healthee.core.db import tenant_transaction

    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "SELECT count(*) FROM kv WHERE user_id = %s AND key LIKE 'allowance%%'",
            (SENTINEL_USER_ID,),
        )
        row = cur.fetchone()
    assert row is not None and row[0] == 0, "an uncapped feature wrote to the ledger"


# ── the free side: zero is a hard lock, and re-granting is a number ───────────


def test_a_free_owner_is_refused_the_coach_on_the_very_first_call(
    bed: TestClient,
    make_free: Callable[[], None],
    stub: StubLLM,
) -> None:
    """§1a since 2026-08-02: not a smaller taste — none. The FIRST call is 402.

    Asserted on the model's call count as well as the status, because a gate that ran after
    generation would produce an identical 402 while spending exactly the tokens the change
    was made to stop spending.
    """
    make_free()
    refused = bed.post("/api/coach", json=QUESTION, headers=AUTH)
    assert refused.status_code == 402
    detail = refused.json()["detail"]
    assert detail["locked"] is True
    assert detail["feature"] == gate.COACH
    assert "upgrade" in detail, "a free owner IS being sold something"
    assert "resets_at" not in detail, "a hard lock must not imply that waiting helps"
    assert stub.calls == 0
    assert _coach_uses() == 0, "a hard-locked feature wrote to the ledger"


def test_re_granting_a_free_taste_is_a_number_and_it_refuses_with_the_free_sentence(
    bed: TestClient,
    make_free: Callable[[], None],
    stub: StubLLM,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The reason the zeroed table and ``_spent_body``'s free branch are not dead code.

    §1a keeps ``FREE_ALLOWANCE`` as "the executable table" so that re-granting a taste is a
    NUMBER rather than a rewrite. If that is true, patching one entry must give a free owner
    exactly one question — and the refusal after it must be the FREE sentence, with the
    upgrade link a free owner actually needs, not the paid-cap one.
    """
    make_free()
    monkeypatch.setitem(gate.FREE_ALLOWANCE, gate.COACH, 1)

    assert bed.post("/api/coach", json=QUESTION, headers=AUTH).status_code == 200
    refused = bed.post("/api/coach", json=QUESTION, headers=AUTH)
    assert refused.status_code == 402

    detail = refused.json()["detail"]
    assert detail["limit"] == 1
    assert detail["resets_at"]
    assert "upgrade" in detail, "a free owner's spent taste must still point at the upgrade"
    assert "free tier" in detail["error"]
    assert f"{allowance.WINDOW_DAYS} days" in detail["error"], "the free window is 7 days"


def test_a_lapsed_owners_free_row_and_their_paid_row_are_different_rows(
    bed: TestClient,
    make_free: Callable[[], None],
    stub: StubLLM,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The collision, at the gate rather than in the ledger: same owner, same feature.

    One key for both windows would let this owner's paid question be read as their free
    week (or the reverse), which is the failure the window-in-the-key exists to prevent —
    so it is asserted here in the only sequence that can actually produce both rows.
    """
    assert bed.post("/api/coach", json=QUESTION, headers=AUTH).status_code == 200  # paid
    make_free()
    monkeypatch.setitem(gate.FREE_ALLOWANCE, gate.COACH, 1)
    assert bed.post("/api/coach", json=QUESTION, headers=AUTH).status_code == 200  # free

    from healthee.core.db import tenant_transaction

    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "SELECT key FROM kv WHERE user_id = %s AND key LIKE 'allowance%%' ORDER BY key",
            (SENTINEL_USER_ID,),
        )
        keys = [row[0] for row in cur.fetchall()]
    assert keys == [f"allowance:{gate.COACH}:30d", f"allowance:{gate.COACH}:7d"], keys
    assert _coach_uses() == 1, "the free question was billed against the paid window"
