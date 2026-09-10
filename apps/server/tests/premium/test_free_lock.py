"""The FREE side of the paywall: zero is a hard lock, and re-granting is a number.

Split from `test_premium_cap.py` at the 400-line gate. That file is about what a
PAYING owner gets and what it costs them; this one is about the owner who has not
paid — a different question, and the one where a mistake gives the AI layer away.

The asymmetry these two files sit either side of is `api/gate.py`'s: a feature
absent from `FREE_ALLOWANCE` is hard-locked (fail closed — nobody paid), and a
feature absent from `PREMIUM_ALLOWANCE` is unlimited (fail open — they did).
"""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime

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
