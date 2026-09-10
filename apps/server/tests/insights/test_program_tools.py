"""The coach can design a ladder — and cannot design one itself.

`challenges/program_generate.py` has been able to build a multi-week ladder since
WP-C4b, and nothing but `POST /api/programs/generate` could ask it to. So an owner
could tell the coach "build me a twelve-week plan" and the coach could only
describe one — the machinery existed and the conversation could not reach it.

What these pin is the rail, not the plumbing: the coach passes INTENT and the
generator computes every number. A model that wrote "add 10% a week for twelve
weeks" would be inventing a training load for a person whose data it had not read,
and it would read exactly as confident as a computed one.
"""

from __future__ import annotations

from typing import Any
from unittest.mock import patch
from uuid import uuid4

import pytest

from healthee.insights import coach_tools, program_tools

_TZ = "Asia/Kolkata"


def test_both_tools_are_offered_to_the_model() -> None:
    names = {t["function"]["name"] for t in coach_tools.COACH_TOOLS}
    assert {"create_program", "adopt_program"} <= names


def test_both_are_action_tools() -> None:
    """So the anti-hallucination gate covers them.

    `coach_loop` only lets the coach claim it did something when an ACTION tool
    returned ok this turn. A write tool missing from that set is a tool the coach
    can claim to have called without calling it.
    """
    assert {"create_program", "adopt_program"} <= coach_tools.ACTION_TOOLS


def test_an_empty_intent_is_refused_without_spending_anything() -> None:
    """The budget is the owner's; a blank intent must not cost one."""
    with patch.object(program_tools.budget, "spend_then_run") as spend:
        result = program_tools.create_program(uuid4(), _TZ, "   ")
    assert result["ok"] is False
    assert result["reason"] == "no_intent"
    spend.assert_not_called()


def test_the_intent_reaches_the_generator_and_nothing_else_does() -> None:
    """The coach supplies words. It supplies no metric, target, rate or horizon."""
    captured: dict[str, Any] = {}

    def _fake_spend(user_id, tz, run, pre_llm):  # noqa: ANN001, ARG001
        return run()

    def _fake_generate(user_id, tz, **kwargs):  # noqa: ANN001, ARG001
        captured.update(kwargs)
        return {"ok": True, "generated": 1, "rejected": [], "program": {"id": 7}}

    with (
        patch.object(program_tools.budget, "spend_then_run", _fake_spend),
        patch.object(program_tools.program_generate, "generate_program", _fake_generate),
    ):
        result = program_tools.create_program(uuid4(), _TZ, "get me to a 10k")

    assert captured == {"intent": "get me to a 10k"}
    assert result["created"] is True
    assert result["program"] == {"id": 7}
    # Designed, not started — two consents.
    assert result["status"] == "suggested"


def test_a_design_the_gates_threw_out_is_an_answer_not_a_silence() -> None:
    """`generated: 0` with reasons is the pipeline working and the ladder failing.

    Reported as an empty success the coach would have nothing to say and would be
    free to offer a ladder of its own, which is the one thing it must not do.
    """

    def _fake_spend(user_id, tz, run, pre_llm):  # noqa: ANN001, ARG001
        return run()

    def _fake_generate(user_id, tz, **kwargs):  # noqa: ANN001, ARG001
        return {"ok": True, "generated": 0, "rejected": ["ungrounded_rung"], "program": None}

    with (
        patch.object(program_tools.budget, "spend_then_run", _fake_spend),
        patch.object(program_tools.program_generate, "generate_program", _fake_generate),
    ):
        result = program_tools.create_program(uuid4(), _TZ, "something we cannot ground")

    assert result["ok"] is True
    assert result["created"] is False
    assert result["rejected"] == ["ungrounded_rung"]
    assert "Do not offer a ladder of your own" in result["note"]


def test_adopt_without_an_id_is_refused_rather_than_guessed() -> None:
    result = program_tools.adopt_program(uuid4(), _TZ, None)
    assert result["ok"] is False
    assert result["reason"] == "no_program_id"


def test_an_unknown_name_raises_rather_than_looking_like_a_refusal() -> None:
    """A routing bug is not a model mistake, and must not read like one."""
    with pytest.raises(ValueError, match="not a program tool"):
        program_tools.execute("create_universe", {}, uuid4(), _TZ)
