"""The harness's own machinery, offline: metering, classification, and its premises.

No network and no database — everything here is either arithmetic over fake responses or
a deterministic check the shipped code can answer for free. The most valuable test in the
file is the last one: the safety questions must be refused BEFORE any model call, which
is both the eval's floor and the reason those two questions cost nothing to run.
"""

from __future__ import annotations

import pytest
from tests.grounding_eval import questions as qs
from tests.grounding_eval.meter import MeteredClient
from tests.grounding_eval.records import (
    FALLBACK,
    GROUNDED,
    REFUSED,
    question_set_fingerprint,
)
from tests.grounding_eval.runner import _is_success, _outcome

from healthee.insights import morning
from healthee.insights.client import ChatResponse, Usage
from healthee.insights.coach import CoachResult
from healthee.insights.refusals import classify_refusal


class _FakeInner:
    """An LLM that returns a scripted list of responses (usage included)."""

    def __init__(self, responses: list[ChatResponse]) -> None:
        self._responses = responses
        self.calls = 0

    def complete(  # noqa: ARG002
        self, messages: list[dict], *, tools=None, model=None, response_format=None
    ) -> ChatResponse:
        response = self._responses[min(self.calls, len(self._responses) - 1)]
        self.calls += 1
        return response


def _result(*, refused: bool = False, validated: bool = True) -> CoachResult:
    """A real surface result — the two flags ``_outcome`` reads, on the shipped type."""
    return CoachResult(reply="x", refused=refused, validated=validated)


# ── metering ─────────────────────────────────────────────────────────────────


def test_the_meter_totals_provider_counts_across_every_call_of_one_question() -> None:
    inner = _FakeInner(
        [
            ChatResponse(text="", tool_calls=[object()], usage=Usage(30_000, 100, 80)),
            ChatResponse(text="answer", usage=Usage(33_000, 400, 300)),
        ]
    )
    client = MeteredClient(inner)
    client.complete([])
    client.complete([])
    assert client.meter.llm_calls == 2
    assert client.meter.tool_rounds == 1  # only the turn that asked for tools
    assert client.meter.prompt_tokens == 63_000
    assert client.meter.completion_tokens == 500
    assert client.meter.reasoning_tokens == 380


def test_reset_separates_one_question_from_the_next() -> None:
    client = MeteredClient(_FakeInner([ChatResponse(text="x", usage=Usage(10, 2, 0))]))
    client.complete([])
    client.reset()
    client.complete([])
    assert client.meter.llm_calls == 1
    assert client.meter.prompt_tokens == 10


def test_a_call_the_provider_did_not_meter_is_counted_as_unknown_not_free() -> None:
    """Silently treating an unmetered call as zero would understate every cost figure."""
    client = MeteredClient(_FakeInner([ChatResponse(text="x")]))
    client.complete([])
    assert client.meter.unmetered_calls == 1
    assert client.meter.prompt_tokens == 0


def test_the_metered_client_returns_the_inner_response_untouched() -> None:
    """It observes; it must never become a second place that shapes an answer."""
    original = ChatResponse(text="verbatim", usage=Usage(1, 1, 0))
    client = MeteredClient(_FakeInner([original]))
    assert client.complete([]) is original


# ── classification ───────────────────────────────────────────────────────────


def test_a_validated_answer_is_the_only_thing_that_counts_as_shipped() -> None:
    assert _outcome(_result()) == GROUNDED
    assert _outcome(_result(validated=False)) == FALLBACK
    assert _outcome(_result(refused=True, validated=False)) == REFUSED


def test_success_is_measured_against_what_the_question_asked_for() -> None:
    answer_q = qs.QUESTIONS[0]
    refusal_q = next(q for q in qs.QUESTIONS if q.expect == qs.REFUSAL)
    assert _is_success(answer_q, GROUNDED) is True
    assert _is_success(answer_q, FALLBACK) is False
    assert _is_success(answer_q, REFUSED) is False  # a refused knowledge question is a failure
    assert _is_success(refusal_q, REFUSED) is True
    assert _is_success(refusal_q, GROUNDED) is False  # answering it is the worst outcome


# ── the question set's own premises ──────────────────────────────────────────


def test_the_safety_questions_are_refused_before_any_model_call() -> None:
    """The eval's floor, checkable for free: these two never reach the network."""
    safety = [q for q in qs.QUESTIONS if q.kind == qs.SAFETY]
    assert safety
    for question in safety:
        assert classify_refusal(question.text) is not None, question.id
        assert question.expect == qs.REFUSAL


def test_no_answer_expecting_question_trips_the_refusal_classifier() -> None:
    """A question that always refuses would silently score 0 forever and mean nothing."""
    for question in qs.QUESTIONS:
        if question.expect == qs.ANSWER:
            assert classify_refusal(question.text) is None, question.id


def test_the_question_set_spans_every_kind_it_claims_to() -> None:
    assert {q.kind for q in qs.QUESTIONS} >= {
        qs.KNOWLEDGE,
        qs.DATA,
        qs.COMPOUND,
        qs.OUT_OF_DOMAIN,
        qs.SAFETY,
    }


def test_question_ids_are_unique_because_pairing_keys_on_them() -> None:
    ids = [q.id for q in qs.QUESTIONS]
    assert len(ids) == len(set(ids))


def test_the_fingerprint_moves_when_a_prompt_is_edited() -> None:
    """Comparing two arms whose prompts differ is not a comparison; ``compare`` refuses."""
    original = question_set_fingerprint(qs.QUESTIONS)
    replacement = qs.EvalQuestion(id="x", kind="knowledge", surface="coach", text="?")
    edited = (*qs.QUESTIONS[:-1], replacement)
    assert original != question_set_fingerprint(edited)


def test_narrowing_by_kind_returns_only_that_kind() -> None:
    assert {q.kind for q in qs.by_kind({qs.DATA})} == {qs.DATA}
    assert qs.by_kind(None) == qs.QUESTIONS


def test_narrowing_by_id_returns_exactly_those_questions_in_the_sets_order() -> None:
    """Kind is too coarse to aim a paid run — the five shipped surfaces are one kind."""
    picked = qs.by_ids(["g_morning", "k_alcohol"])
    assert [q.id for q in picked] == ["k_alcohol", "g_morning"]


def test_an_unknown_question_id_raises_rather_than_running_a_smaller_set() -> None:
    """A typo must not spend money and then report a rate over a set nobody chose."""
    with pytest.raises(KeyError, match="g_mornning"):
        qs.by_ids(["g_morning", "g_mornning"])


def test_the_merged_morning_prompt_and_both_prompts_it_replaced_are_measurable() -> None:
    """#95 asks 'as reliably as the two separate ones' — all three must be in the set.

    And each must be the SHIPPED constant, not a copy: a paraphrase here would measure a
    prompt the product does not send, which is the drift the set exists to prevent.
    """
    texts = {q.id: q.text for q in qs.QUESTIONS}
    assert texts["g_morning"] == morning.MORNING_TASK
    assert texts["g_briefing"] == morning.BRIEFING_TASK
    assert texts["g_daily_action"] == morning.DAILY_ACTION_PROMPT
