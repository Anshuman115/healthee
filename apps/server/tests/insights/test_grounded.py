"""The choke point's control flow — proves the honesty guarantees (holes #1, #2).

No DB: the message-builder is stubbed so these are pure control-flow tests. The
crux is that after two validation failures the pipeline returns the honest
FALLBACK — never the unvalidated model text (legacy shipped it anyway, §5.2).
"""

from __future__ import annotations

import json

import pytest
from tests.insights._ids import ESTABLISHED_ID
from tests.insights._stub import VALID_TEXT, StubLLM

from healthee.insights import grounded, prompts


@pytest.fixture(autouse=True)
def _stub_messages(monkeypatch: pytest.MonkeyPatch) -> None:
    """Skip the DB-backed context build; the LLM step is what these tests exercise."""
    monkeypatch.setattr(
        grounded, "_build_messages", lambda *a, **k: [{"role": "user", "content": "x"}]
    )


def test_two_failures_return_the_honest_fallback_not_the_raw_text() -> None:
    bad = "This suggests a serious problem [not_a_real_note]."
    stub = StubLLM([bad, bad])  # fails validation both times
    result = grounded.grounded_ask("why is my rhr high?", client=stub)
    assert result.text == prompts.FALLBACK
    assert result.validated is False
    assert "not_a_real_note" not in result.text  # the unvalidated text never ships
    assert stub.calls == 2  # original + one nudged retry, then stop


def test_retry_succeeds_after_a_nudge() -> None:
    stub = StubLLM(["This is great [not_a_real_note].", VALID_TEXT])
    result = grounded.grounded_ask("how am I doing?", client=stub)
    assert result.text == VALID_TEXT
    assert result.validated is True
    assert ESTABLISHED_ID in result.citations
    assert stub.calls == 2


def test_first_pass_success_does_not_retry() -> None:
    stub = StubLLM([VALID_TEXT])
    result = grounded.grounded_ask("how am I doing?", client=stub)
    assert result.validated is True
    assert stub.calls == 1


def test_json_mode_returns_the_parsed_object_on_data() -> None:
    payload = json.dumps(
        {
            "recommendations": [
                {
                    "action": "Walk 30 min today.",
                    "rationale": f"Activity may support recovery [{ESTABLISHED_ID}].",
                    "category": "activity",
                    "evidence_grade": 3,
                    "research_note_ids": [ESTABLISHED_ID],
                }
            ]
        }
    )
    stub = StubLLM([payload])
    result = grounded.grounded_ask("recommend", client=stub, response_format="json")
    assert result.validated is True
    assert isinstance(result.data, dict)
    assert result.data["recommendations"][0]["action"] == "Walk 30 min today."
    assert ESTABLISHED_ID in result.citations
    assert stub.calls == 1


def test_json_mode_fabricated_cite_falls_back_with_no_data() -> None:
    bad = json.dumps(
        {"recommendations": [{"action": "x", "rationale": "This suggests gains [made_up_note]."}]}
    )
    stub = StubLLM([bad, bad])
    result = grounded.grounded_ask("recommend", client=stub, response_format="json")
    assert result.validated is False
    assert result.data is None
    assert result.text == prompts.FALLBACK
    assert stub.calls == 2


def test_json_mode_malformed_json_falls_back_with_no_data() -> None:
    stub = StubLLM(["not json at all", "still not json"])
    result = grounded.grounded_ask("recommend", client=stub, response_format="json")
    assert result.validated is False
    assert result.data is None
    assert stub.calls == 2
