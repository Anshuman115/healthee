"""Coach control-flow — the honesty guarantees, no DB and no network.

The context builder is stubbed (these exercise the loop, refusal gate, blocking
validator inheritance, and the anti-hallucination guard — not the SQL). The crux:
the coach CANNOT ship unvalidated text or a fabricated action confirmation.
"""

from __future__ import annotations

import pytest
from tests.insights._coach_stub import CoachStub, NoCallStub, text_turn, tool_call, tool_turn
from tests.insights._ids import ESTABLISHED_ID, PROBABLE_ID
from tests.insights._stub import VALID_TEXT

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.insights import coach, coach_tools, prompts


@pytest.fixture(autouse=True)
def _stub_context(monkeypatch: pytest.MonkeyPatch) -> None:
    """Skip the DB-backed context/evidence build — these are control-flow tests."""
    monkeypatch.setattr(
        coach,
        "_initial_messages",
        lambda history, q, user_id, tz, days: [{"role": "user", "content": q}],
    )


def _ask(text: str) -> list[dict]:
    return [{"role": "user", "content": text}]


def _run(messages: list[dict], **kwargs) -> coach.CoachResult:
    """Run the coach as the sentinel owner — these are control-flow tests, not tenancy."""
    return coach.run_coach(messages, SENTINEL_USER_ID, SENTINEL_TZ, **kwargs)


def test_diagnosis_question_is_refused_before_any_tool_call() -> None:
    stub = NoCallStub()
    result = _run(_ask("do I have diabetes?"), client=stub)
    assert result.refused is True
    assert "physician" in result.reply  # the DIAGNOSIS refusal template
    assert stub.calls == 0  # the model (and its tools) never ran


def test_medication_question_is_refused_pre_llm() -> None:
    stub = NoCallStub()
    result = _run(_ask("should I increase my statin dose?"), client=stub)
    assert result.refused is True
    assert stub.calls == 0


def test_fabricated_citation_is_blocked_then_falls_back() -> None:
    bad = "Your recovery suggests overtraining [not_a_real_note]."
    stub = CoachStub([text_turn(bad), text_turn(bad)])
    result = _run(_ask("how's my recovery?"), client=stub)
    assert result.reply == prompts.FALLBACK  # never the unvalidated text
    assert result.validated is False
    assert "not_a_real_note" not in result.reply
    assert stub.calls == 2  # original + one nudged retry, then stop


def test_retry_after_a_nudge_can_succeed() -> None:
    stub = CoachStub([text_turn("This is great [not_a_real_note]."), text_turn(VALID_TEXT)])
    result = _run(_ask("how am I doing?"), client=stub)
    assert result.reply == VALID_TEXT
    assert result.validated is True


def test_claiming_an_action_with_no_tool_call_is_caught() -> None:
    """'I logged your coffee' with NO log_entry tool call must not ship as confirmed."""
    lie = "I logged your coffee for you."
    stub = CoachStub([text_turn(lie), text_turn(lie)])
    result = _run(_ask("log a coffee"), client=stub)
    assert result.reply == prompts.FALLBACK  # the fake confirmation is not echoed
    assert "logged your coffee" not in result.reply
    assert result.validated is False


def test_action_claim_allowed_after_a_successful_tool_call(monkeypatch: pytest.MonkeyPatch) -> None:
    """The same claim IS allowed once log_entry actually ran and returned ok."""
    monkeypatch.setattr(coach_tools, "execute_tool", lambda name, args, user_id, tz: {"ok": True})
    stub = CoachStub(
        [
            tool_turn(tool_call("c1", "log_entry", '{"type": "caffeine", "amount": 80}')),
            text_turn("Done — I logged your coffee (80 mg)."),
        ]
    )
    result = _run(_ask("log an 80mg coffee"), client=stub)
    assert result.reply == "Done — I logged your coffee (80 mg)."
    assert result.validated is True
    assert result.tool_calls[0]["tool"] == "log_entry"


def test_tool_result_flows_back_and_a_valid_answer_ships(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list = []

    def fake_exec(name: str, args: dict, user_id: object, tz: str) -> dict:
        calls.append((name, args))
        return {"metric": "hrv_sleep_avg", "avg": 42.0, "n": 30}

    monkeypatch.setattr(coach_tools, "execute_tool", fake_exec)
    stub = CoachStub(
        [
            tool_turn(tool_call("c1", "query_metric", '{"metric": "hrv_sleep_avg"}')),
            text_turn(VALID_TEXT),
        ]
    )
    result = _run(_ask("what's my HRV?"), client=stub)
    assert result.reply == VALID_TEXT
    assert calls == [("query_metric", {"metric": "hrv_sleep_avg"})]
    assert result.tool_calls[0]["result"]["avg"] == 42.0


def test_the_model_is_offered_the_seven_live_tools() -> None:
    stub = CoachStub([text_turn(VALID_TEXT)])
    _run(_ask("how am I doing?"), client=stub)
    offered = {t["function"]["name"] for t in stub.tools_seen[0]}
    assert offered == {
        "query_metric",
        "compare_event",
        "sleep_consistency",
        "log_entry",
        "get_knowledge",
        # WP-C5 — deferred until the challenges subsystem existed, live now.
        "adopt_challenge",
        "create_challenge",
    }


def test_claiming_an_adoption_the_tool_refused_is_caught(monkeypatch: pytest.MonkeyPatch) -> None:
    """The tool RAN and said no. The coach may not report it as a yes (INTELLIGENCE §4)."""
    monkeypatch.setattr(
        coach_tools,
        "execute_tool",
        lambda name, args, user_id, tz: {"ok": False, "reason": "not_found"},
    )
    lie = "I've started your steps challenge — you're on 6,250 a day now."
    stub = CoachStub(
        [tool_turn(tool_call("c1", "adopt_challenge", '{"challenge_id": 9}')), text_turn(lie)]
    )
    result = _run(_ask("start the steps one"), client=stub)
    assert result.reply == prompts.FALLBACK
    assert "started your steps challenge" not in result.reply
    assert result.validated is False


def test_a_successful_log_does_not_license_an_adoption_claim(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The claim guard is per-TOOL: a logged coffee cannot vouch for a started challenge."""
    monkeypatch.setattr(coach_tools, "execute_tool", lambda name, args, user_id, tz: {"ok": True})
    lie = "Logged. I've also adopted the sleep challenge for you."
    stub = CoachStub(
        [tool_turn(tool_call("c1", "log_entry", '{"type": "caffeine"}')), text_turn(lie)]
    )
    result = _run(_ask("log a coffee"), client=stub)
    assert result.reply == prompts.FALLBACK
    assert result.validated is False


def test_an_adoption_claim_is_allowed_once_the_adopt_tool_returned_ok(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(coach_tools, "execute_tool", lambda name, args, user_id, tz: {"ok": True})
    said = "Done — I've started your steps challenge at the target we stored."
    stub = CoachStub(
        [tool_turn(tool_call("c1", "adopt_challenge", '{"challenge_id": 9}')), text_turn(said)]
    )
    result = _run(_ask("start the steps one"), client=stub)
    assert result.reply == said
    assert result.validated is True


def test_claiming_a_creation_the_tool_refused_is_caught(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        coach_tools,
        "execute_tool",
        lambda name, args, user_id, tz: {"ok": False, "reason": "not_trackable"},
    )
    lie = "I've created a sleep challenge for you."
    stub = CoachStub(
        [tool_turn(tool_call("c1", "create_challenge", '{"intent": "sleep"}')), text_turn(lie)]
    )
    result = _run(_ask("make me a sleep challenge"), client=stub)
    assert result.reply == prompts.FALLBACK
    assert result.validated is False


# ── #84 · the evidence floor reaches the caller ──────────────────────────────


def test_the_answers_grade_floor_is_carried_out_of_the_coach() -> None:
    """It was computed on every answer and thrown away — INTELLIGENCE §3 promises it."""
    result = _run(_ask("how am I doing?"), client=CoachStub([text_turn(VALID_TEXT)]))
    assert result.validated is True
    assert result.grade_floor == "Established"


def test_the_floor_is_the_weakest_cited_grade_not_the_strongest() -> None:
    """'Floor' is the whole point: one Probable note under an Established one lowers it."""
    mixed = (
        f"Your recent numbers look steady. Consistent activity may support fitness "
        f"[{ESTABLISHED_ID}]. Regular timing may also help recovery [{PROBABLE_ID}]."
    )
    result = _run(_ask("how am I doing?"), client=CoachStub([text_turn(mixed)]))
    assert result.validated is True
    assert set(result.citations) == {ESTABLISHED_ID, PROBABLE_ID}
    assert result.grade_floor == "Probable"


def test_a_refusal_carries_no_grade_floor() -> None:
    """Nothing was cited, so there is no floor — None, not a grade the answer never had."""
    result = _run(_ask("do I have diabetes?"), client=NoCallStub())
    assert result.refused is True
    assert result.grade_floor is None


def test_the_honest_fallback_carries_no_grade_floor() -> None:
    bad = "Your recovery suggests overtraining [not_a_real_note]."
    result = _run(_ask("how's my recovery?"), client=CoachStub([text_turn(bad), text_turn(bad)]))
    assert result.reply == prompts.FALLBACK
    assert result.grade_floor is None


def test_empty_conversation_greets_without_calling_the_model() -> None:
    stub = NoCallStub()
    result = _run([], client=stub)
    assert "Ask me anything" in result.reply
    assert stub.calls == 0
