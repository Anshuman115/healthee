"""The metered free allowance — the rolling window itself (6.6a-2, PRICING.md §1a).

``test_ai_gate.py`` proves the gate lets exactly one metered call through over HTTP.
This file proves the thing underneath it is a *rolling seven days* and not a calendar
period wearing its name, which is the whole difference between the promise §1a makes and
the one ``core.rate_limit`` would have made. It also pins §1a's UNIT — a question, not an
LLM call — which stopped being self-evident when the coach's gathering allowance went to
20 and one question could make 22 calls.

Every window assertion drives the injectable ``now``, because a rule that can only be
exercised by waiting a week is one nobody exercises (``core.entitlement.evaluate``
records the same reason).

The ledger is per owner, so the two-owner case runs against a real database with RLS
underneath rather than being argued from the SQL.
"""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from uuid import UUID

import pytest
from fastapi.testclient import TestClient
from tests.conftest import entitle
from tests.premium.conftest import AUTH

from healthee.api import gate
from healthee.core import allowance
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID

pytestmark = pytest.mark.integration

FEATURE = "coach"

# A fixed, unremarkable instant to anchor every window assertion: 21:00 on a Monday, in
# the middle of the week and nowhere near a midnight, so a rule that secretly reset on a
# calendar boundary cannot pass by coincidence.
MONDAY_EVENING = datetime(2026, 3, 2, 21, 0, tzinfo=UTC)


@pytest.fixture
def owner(db: None) -> UUID:  # noqa: ARG001 — the fixture is the database
    """The sentinel owner with an empty ledger (``seed_all``'s reset truncates ``kv``)."""
    from tests.contracts.seed import seed_all

    seed_all()
    entitle(SENTINEL_USER_ID, premium=False)
    return SENTINEL_USER_ID


def spend(owner: UUID, now: datetime, *, limit: int = 1) -> allowance.Verdict:
    return allowance.spend(owner, SENTINEL_TZ, FEATURE, limit, now=now)


# ── the window rolls with the USE, not with the calendar ──────────────────────


def test_the_first_use_is_granted_and_the_second_is_not(owner: UUID) -> None:
    assert spend(owner, MONDAY_EVENING).allowed is True
    refused = spend(owner, MONDAY_EVENING + timedelta(minutes=1))
    assert refused.allowed is False
    assert refused.used == 1
    assert refused.limit == 1


def test_it_is_still_refused_six_days_and_23_hours_later(owner: UUID) -> None:
    """The hard edge. A window that quietly meant "six days" would pass every other test."""
    spend(owner, MONDAY_EVENING)
    assert spend(owner, MONDAY_EVENING + timedelta(days=6, hours=23)).allowed is False


def test_it_is_granted_again_exactly_seven_days_later(owner: UUID) -> None:
    spend(owner, MONDAY_EVENING)
    assert spend(owner, MONDAY_EVENING + timedelta(days=7)).allowed is True


def test_a_midnight_does_not_reset_it_the_way_a_daily_counter_would(owner: UUID) -> None:
    """THE distinction this module exists for, pinned rather than described.

    ``core.rate_limit`` resets at the owner's local midnight, so a use at 21:00 would be
    free again three hours later. If this ledger ever became that one, this is the test
    that would say so — and it is the exact case a real owner hits, because people ask
    their one question in the evening.
    """
    spend(owner, MONDAY_EVENING)
    local_midnight_after = MONDAY_EVENING + timedelta(hours=3)  # 00:00 UTC, 05:30 in IST
    assert spend(owner, local_midnight_after).allowed is False
    assert spend(owner, MONDAY_EVENING + timedelta(days=1)).allowed is False


def test_the_reset_instant_is_the_use_plus_seven_local_days(owner: UUID) -> None:
    """What the 402 tells the owner has to be the instant the window actually opens."""
    spend(owner, MONDAY_EVENING)
    refused = spend(owner, MONDAY_EVENING + timedelta(hours=1))
    assert refused.resets_at == MONDAY_EVENING + timedelta(days=7)
    # …and waiting exactly that long really does work, which is what makes it not a guess.
    assert spend(owner, refused.resets_at).allowed is True


def test_the_window_keeps_rolling_after_it_reopens(owner: UUID) -> None:
    """A second use starts its own seven days — the ledger is not one-shot-then-open."""
    spend(owner, MONDAY_EVENING)
    later = MONDAY_EVENING + timedelta(days=7)
    assert spend(owner, later).allowed is True
    assert spend(owner, later + timedelta(days=6)).allowed is False
    assert spend(owner, later + timedelta(days=7)).allowed is True


# ── a refusal is not a use ────────────────────────────────────────────────────


def test_a_refused_attempt_does_not_push_the_window_forward(owner: UUID) -> None:
    """The bug this shape exists to avoid: recording refusals would lock an owner out
    forever, because every rejected tap would re-arm the seven days."""
    spend(owner, MONDAY_EVENING)
    for hours in (1, 24, 100, 160):
        spend(owner, MONDAY_EVENING + timedelta(hours=hours))
    assert spend(owner, MONDAY_EVENING + timedelta(days=7)).allowed is True


# ── refunds ───────────────────────────────────────────────────────────────────


def test_a_refund_gives_the_use_back(owner: UUID) -> None:
    spend(owner, MONDAY_EVENING)
    allowance.refund(owner, SENTINEL_TZ, FEATURE, now=MONDAY_EVENING)
    assert spend(owner, MONDAY_EVENING + timedelta(minutes=1)).allowed is True


def test_a_refund_can_never_mint_allowance(owner: UUID) -> None:
    """Refunding more than was spent must leave the owner with one use, not five."""
    spend(owner, MONDAY_EVENING)
    for _ in range(5):
        allowance.refund(owner, SENTINEL_TZ, FEATURE, now=MONDAY_EVENING)
    assert spend(owner, MONDAY_EVENING).allowed is True
    assert spend(owner, MONDAY_EVENING).allowed is False


def test_a_refund_cannot_reach_into_a_window_that_has_already_rolled(owner: UUID) -> None:
    """A late refund of an expired use is a no-op, not a credit against the new window."""
    spend(owner, MONDAY_EVENING)
    much_later = MONDAY_EVENING + timedelta(days=8)
    assert spend(owner, much_later).allowed is True  # the new week's use
    allowance.refund(owner, SENTINEL_TZ, FEATURE, now=much_later)
    assert spend(owner, much_later).allowed is True  # refunded the NEW one, which is right
    assert spend(owner, much_later).allowed is False


# ── peek reports, it does not spend ───────────────────────────────────────────


def test_peek_never_records_anything(owner: UUID) -> None:
    for _ in range(10):
        assert allowance.peek(owner, SENTINEL_TZ, FEATURE, 1, now=MONDAY_EVENING).allowed is True
    assert spend(owner, MONDAY_EVENING).allowed is True
    assert allowance.peek(owner, SENTINEL_TZ, FEATURE, 1, now=MONDAY_EVENING).allowed is False


# ── the ledger's own shape ────────────────────────────────────────────────────


def test_the_ledger_is_one_row_per_owner_per_feature_with_no_date_in_the_key(
    owner: UUID,
) -> None:
    """The #77 leak, not reintroduced: a date in the KEY would grow a row per period.

    Asserted against the table rather than the docstring, because the docstring is what
    was wrong last time.
    """
    from healthee.core.db import tenant_transaction

    for day in range(0, 40, 7):  # six weeks of legitimate weekly use
        spend(owner, MONDAY_EVENING + timedelta(days=day))
    with tenant_transaction(owner) as cur:
        cur.execute(
            "SELECT key, value FROM kv WHERE user_id = %s AND key LIKE 'allowance%%'", (owner,)
        )
        rows = cur.fetchall()
    assert len(rows) == 1, f"the ledger grew a row per period: {rows}"
    key, value = rows[0]
    assert key == f"allowance:{FEATURE}"
    assert value.count(",") == 0, f"the stored window is not bounded to the limit: {value!r}"


def test_a_corrupt_ledger_row_is_dropped_rather_than_raising(owner: UUID) -> None:
    """A row somebody hand-edited must not 500 every AI request that owner makes."""
    from healthee.core.db import tenant_transaction

    with tenant_transaction(owner) as cur:
        cur.execute(
            "INSERT INTO kv (user_id, key, value) VALUES (%s, %s, %s)",
            (owner, f"allowance:{FEATURE}", "not-an-instant"),
        )
    assert spend(owner, MONDAY_EVENING).allowed is True


# ── per-owner isolation ───────────────────────────────────────────────────────


def test_one_owners_spent_week_does_not_touch_another(owner: UUID) -> None:
    """Two owners, one ledger table, RLS underneath — measured, not argued."""
    from tests.contracts.seed_owner_b import OWNER_B, OWNER_B_TZ, seed_owner_b

    seed_owner_b()
    entitle(OWNER_B, premium=False)
    assert spend(owner, MONDAY_EVENING).allowed is True
    assert spend(owner, MONDAY_EVENING).allowed is False
    assert allowance.spend(OWNER_B, OWNER_B_TZ, FEATURE, 1, now=MONDAY_EVENING).allowed is True


# ── the METERED UNIT: a question, not an LLM call ─────────────────────────────


def test_a_tool_calling_coach_question_charges_the_allowance_once_not_per_call(
    bed: TestClient,
    make_free: Callable[[], None],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """§1a's unit is the QUESTION, and the coach's gathering allowance is now 20 deep.

    ``routers/coach.py`` says so in prose; this measures it, because the two numbers now
    differ by more than an order of magnitude. A question that spends ten tool rounds
    makes eleven model calls and must still cost a free owner exactly one of §1a's weekly
    questions — otherwise a generous gathering budget quietly became a pricing change,
    and the cost gate that took a whole work package to close would be a regression.

    Over real HTTP, because the charge happens in the FastAPI dependency: calling
    ``run_coach`` directly would exercise the loop and none of the metering.
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
    make_free()

    reply = bed.post(
        "/api/coach",
        json={"messages": [{"role": "user", "content": "how am I doing?"}]},
        headers=AUTH,
    )
    assert reply.status_code == 200
    assert reply.json()["validated"] is True
    assert stub.calls == rounds + 1, "the loop did not actually make many model calls"

    verdict = allowance.peek(SENTINEL_USER_ID, SENTINEL_TZ, FEATURE, limit=1)
    assert verdict.used == 1, f"eleven model calls billed {verdict.used} weekly questions"


# ── the features, against PRICING.md §1a ──────────────────────────────────────


def test_the_allowance_table_is_exactly_what_pricing_1a_says() -> None:
    """§1a is the authoritative tier table and this dict is its only executable copy.

    A unit test, deliberately: the numbers are the product decision, and they should fail
    the build the moment somebody changes one without changing the doc that sells it.
    """
    assert gate.FREE_ALLOWANCE == {
        gate.COACH: 1,  # "teaser: 1 question / 7 days"
        gate.DAILY_ACTION: 1,  # "teaser: revealed 1× / 7 days"
        gate.INSIGHT: 0,  # "— (locked card)" — AI insight cards
        gate.NOTABLE: 0,  # "— (premium)" — the notable-shift feed
        gate.CHALLENGES: 0,  # "— (premium)" — challenges/programs in full
    }
    assert allowance.WINDOW_DAYS == 7
    assert set(gate.FREE_ALLOWANCE) == set(gate.FEATURES), "a feature with no priced allowance"
