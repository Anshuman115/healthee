"""A5 · what the refusal gate is asked about. B1 · a greeting is not an answer. The topic.

Three properties of the INPUT to a coach turn, in one file because they are one question
asked three ways — *what exactly reaches the model, and what did it cost?*

**A5.** ``check_question``'s guarantee is that "the model is never called, so it cannot be
prompted, jailbroken or cajoled past a hard guardrail". It was asked about
``_last_user(history)`` — one message — while ``_initial_messages`` sent the whole bounded
history. So a refused emergency re-entered the model's context on the very next turn,
unscreened, one turn after ``refusals.exertional_emergency`` was written to stop exactly
that. The one coach test that could have caught it monkeypatched ``_initial_messages`` to
discard the history, so the suite could not have failed however the gate behaved; that
stub now preserves the layout, which is what makes the first two tests below possible.

**B1.** ``CoachResult``'s defaults are ``refused=False, validated=True``, so the canned
greeting matched none of the router's refund branches and charged one of twenty for a
sentence no model wrote.

**The topic.** It is CONTEXT, not evidence. These tests pin both halves: it must reach
retrieval (otherwise it does nothing) and it must not arrive as a claim, must not skip the
refusal gate, and must not exempt the answer from anything.
"""

from __future__ import annotations

import pytest
from tests.insights._coach_stub import CoachStub, NoCallStub, valid_turn

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.insights import coach, coach_thread

# The domain #106 was built for, in the owner's own words.
COLLAPSE = "During my long run yesterday I got confused and started vomiting, then collapsed."
BENIGN = "What should I eat before an easy run?"


@pytest.fixture(autouse=True)
def _stub_context(monkeypatch: pytest.MonkeyPatch) -> None:
    """The layout without the DB — system turn, then the WHOLE conversation."""
    monkeypatch.setattr(
        coach,
        "_initial_messages",
        lambda history, q, user_id, tz, days, topic=None: [
            {"role": "system", "content": f"CONTEXT{coach_thread.topic_block(topic)}"},
            *history,
        ],
    )


def _run(messages: list[dict], client: object, **kwargs) -> coach.CoachResult:
    return coach.run_coach(
        messages,
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        client=client,  # type: ignore[arg-type]
        **kwargs,
    )


# ── A5 · screen what is SENT ─────────────────────────────────────────────────


def test_an_emergency_two_turns_back_still_refuses_the_current_turn() -> None:
    """THE finding. The ordinary flow, with no bad actor in it anywhere."""
    stub = NoCallStub()
    result = _run(
        [
            {"role": "user", "content": COLLAPSE},
            {"role": "assistant", "content": "Please seek care now."},
            {"role": "user", "content": BENIGN},
        ],
        stub,
    )

    assert result.refused is True
    assert stub.calls == 0, (
        "the collapse report re-entered the model's context on the next turn — the hole "
        "refusals.exertional_emergency exists to close, reopened one turn later"
    )


def test_the_refusal_is_attributed_to_the_domain_that_actually_fired() -> None:
    """Oldest first, so the reply is the emergency's template, not the newest hit's."""
    result = _run(
        [
            {"role": "user", "content": COLLAPSE},
            {"role": "user", "content": BENIGN},
        ],
        NoCallStub(),
    )
    domain = coach_thread.screen([{"role": "user", "content": COLLAPSE}])
    assert domain is not None
    assert result.reply == domain.template


def test_a_clean_thread_of_several_turns_still_reaches_the_model() -> None:
    """The guard must not be a blanket refusal on any multi-turn conversation."""
    stub = CoachStub([valid_turn()])
    result = _run(
        [
            {"role": "user", "content": "How did I sleep last week?"},
            {"role": "assistant", "content": "Steadily."},
            {"role": "user", "content": BENIGN},
        ],
        stub,
    )

    assert result.refused is False
    assert stub.calls == 1
    # And the whole conversation genuinely went — otherwise the screen above is
    # screening something the model never sees, which is a different guarantee.
    sent = stub.messages_seen[0]
    assert [m["role"] for m in sent] == ["system", "user", "assistant", "user"]


def test_an_assistant_turn_is_not_screened() -> None:
    """Our own validated output is not a question, and the vocabulary is for questions."""
    stub = CoachStub([valid_turn()])
    result = _run(
        [
            {"role": "assistant", "content": COLLAPSE},
            {"role": "user", "content": BENIGN},
        ],
        stub,
    )
    assert result.refused is False
    assert stub.calls == 1


# ── B1 · a greeting delivered nothing, so nothing may be charged ─────────────


@pytest.mark.parametrize(
    "messages",
    [
        pytest.param([], id="empty"),
        pytest.param([{"role": "assistant", "content": "hello"}], id="assistant-only"),
        pytest.param([{"role": "user", "content": ""}], id="empty-user-turn"),
    ],
)
def test_a_request_with_no_question_is_not_an_answered_turn(messages: list[dict]) -> None:
    """The router's fourth refund branch reads this flag; the other three miss it."""
    result = _run(messages, NoCallStub())

    assert result.answered is False, (
        "a canned greeting matched no refund branch and charged one of the owner's twenty"
    )
    assert result.refused is False
    assert result.validated is True


def test_an_answered_turn_says_so() -> None:
    """The flag must not be inert in the direction that always refunds."""
    result = _run([{"role": "user", "content": BENIGN}], CoachStub([valid_turn()]))
    assert result.answered is True


# ── the topic · context, never evidence ──────────────────────────────────────


def test_the_topic_reaches_retrieval() -> None:
    """Otherwise it is a field that does nothing, which is the gap being closed."""
    assert coach_thread.retrieval_key("How am I doing?", "my VO2max trend") == (
        "my VO2max trend\nHow am I doing?"
    )
    assert coach_thread.retrieval_key("How am I doing?", None) == "How am I doing?"
    assert coach_thread.retrieval_key("How am I doing?", "   ") == "How am I doing?"


def test_the_topic_arrives_fenced_as_a_label_and_not_as_a_finding() -> None:
    """It says what it is NOT, in the prompt, beside the subject itself."""
    stub = CoachStub([valid_turn()])
    _run([{"role": "user", "content": BENIGN}], stub, topic="my VO2max trend")
    system = stub.messages_seen[0][0]["content"]

    assert "my VO2max trend" in system
    assert "not a claim" in system
    assert "do not restate it as fact" in system
    assert "do not cite anything to it" in system


def test_no_topic_puts_no_block_in_the_prompt() -> None:
    """Absent is absent — an empty heading would be a subject nobody chose."""
    stub = CoachStub([valid_turn()])
    _run([{"role": "user", "content": BENIGN}], stub)
    assert "WHAT THIS CONVERSATION IS ABOUT" not in stub.messages_seen[0][0]["content"]


def test_a_topic_is_screened_by_the_refusal_gate_like_any_other_input() -> None:
    """It is text the app puts in the prompt, so "screen what is sent" has to cover it."""
    stub = NoCallStub()
    result = _run([{"role": "user", "content": BENIGN}], stub, topic=COLLAPSE)

    assert result.refused is True
    assert stub.calls == 0


def test_the_owners_own_emergency_names_the_domain_over_a_topics() -> None:
    """A thread carrying a real emergency is named by it, not by the screen it opened from."""
    owner_domain = coach_thread.screen([{"role": "user", "content": COLLAPSE}])
    both = coach_thread.screen(
        [{"role": "user", "content": COLLAPSE}], "should I increase my statin dose?"
    )
    assert both is owner_domain


def test_a_topic_is_bounded_and_flattened() -> None:
    """One line, capped. A newline would end the fence and free the rest of the string."""
    assert coach_thread.normalized_topic("a\nb  c") == "a b c"
    assert coach_thread.normalized_topic("   ") is None
    assert coach_thread.normalized_topic(None) is None
    assert len(coach_thread.normalized_topic("x" * 5000) or "") == coach_thread.TOPIC_MAX_CHARS


def test_the_history_is_still_bounded() -> None:
    """The topic did not become a way around the context-window discipline."""
    turns = [{"role": "user", "content": f"q{i}"} for i in range(40)]
    kept = coach_thread.recent(turns)
    assert len(kept) == coach_thread.HISTORY_LIMIT
    assert kept[-1]["content"] == "q39"
