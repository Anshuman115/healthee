"""ONE generation budget, both doors (#78) — the coach can no longer spend for free.

Before 6.6a the daily generation budget lived in the router, so ``POST /api/challenges/
generate`` paid and the coach's ``create_challenge`` did not: an owner could exhaust
three refreshes in the app and then keep authoring challenges in chat, unbounded.

The load-bearing test is the CROSS one — exhaust the budget through the HTTP endpoint,
then watch the chat path refuse. Two tests that each only checked their own door would
pass against two separate counters, which is precisely the bug.
"""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from tests.challenges import _gen
from tests.insights import _challenge_bed as bed

from healthee.challenges import budget
from healthee.core import rate_limit
from healthee.insights import challenge_tools

pytestmark = pytest.mark.integration


@pytest.fixture
def spent_budget() -> Iterator[None]:
    """Charge the owner's whole daily budget the way the ENDPOINT does."""
    for _ in range(budget.GENERATIONS_PER_DAY):
        rate_limit.spend(bed.OWNER, bed.TZ, budget.FEATURE, budget.GENERATIONS_PER_DAY)
    yield


def test_the_coach_charges_the_same_counter_as_the_endpoint(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """One chat-created challenge costs one unit of the SAME per-owner budget."""
    bed.scripted_llm(monkeypatch, [_gen.response()])

    before = _used()
    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "make me a walking challenge")

    assert result["ok"] is True
    assert _used() == before + 1


def test_exhausting_the_budget_through_the_endpoint_blocks_the_chat_path(
    challenge_owner_with_history: None,  # noqa: ARG001
    spent_budget: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The cross-door assertion — the one two separate counters would fail.

    The stub is scripted with a valid response on purpose: if the budget were not
    shared, the pipeline would happily author a challenge and this would pass a
    different way.
    """
    stub = bed.scripted_llm(monkeypatch, [_gen.response()])

    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "make me a walking challenge")

    assert result["ok"] is False
    assert result["reason"] == budget.BUDGET_SPENT
    assert stub.calls == 0, "the model was asked despite the budget being gone"
    assert bed.suggested_ids() == []  # and nothing was written


def test_the_refusal_tells_the_person_when_it_resets(
    challenge_owner_with_history: None,  # noqa: ARG001
    spent_budget: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """ "Try again later" without a when is the vague refusal standards §Errors forbids."""
    bed.scripted_llm(monkeypatch, [_gen.response()])
    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "walking challenge")
    assert result["limit"] == budget.GENERATIONS_PER_DAY
    assert result["resets_at"]
    assert "share this budget" in result["error"]


def test_a_no_cost_refusal_is_refunded_on_the_chat_path_too(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The endpoint's refund rule applies to the coach, because it is the same function.

    ``too_many_active`` is decided before the model is reached, so it must not cost an
    owner a refresh. Charging for it would take the day's budget for a state they can
    fix in one tap.
    """
    bed.scripted_llm(monkeypatch, [_gen.response()])
    monkeypatch.setattr(
        challenge_tools.generate,
        "generate_challenges",
        lambda *_a, **_kw: {"ok": False, "reason": "too_many_active", "error": "full"},
    )

    before = _used()
    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "walking challenge")

    assert result["reason"] == "too_many_active"
    assert _used() == before, "a pre-LLM refusal cost the owner a generation"


def test_a_clock_shaped_intent_is_refused_before_it_costs_anything(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The tool's own deterministic refusal runs FIRST, so it never charges.

    "no screens after 22:00" names a clock on something the registry cannot put one on;
    we know that without asking a model, so it must not cost a refresh.
    """
    bed.scripted_llm(monkeypatch, [_gen.response()])
    before = _used()

    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "no screens after 22:00")

    assert result["reason"] == "no_time_of_day_predicate"
    assert _used() == before


def _used() -> int:
    """The stored counter for today, read straight from ``kv``.

    Read rather than inferred from a Verdict, because the thing under test is that BOTH
    doors write the same row — an inference from either door's return value could not
    tell one counter from two.
    """
    from healthee.core.db import tenant_transaction

    with tenant_transaction(bed.OWNER) as cur:
        cur.execute(
            "SELECT split_part(value, ':', 2)::int FROM kv WHERE user_id = %s AND key = %s",
            (bed.OWNER, f"ratelimit:{budget.FEATURE}"),
        )
        row = cur.fetchone()
    return int(row[0]) if row else 0
