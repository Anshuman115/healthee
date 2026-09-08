"""The coach body is bounded — the second half of `AUTH_AUDIT.md` E4.

`insights/coach.py` bounds the history it USES to the last 12 well-formed turns, so the
turn COUNT was bounded and the per-turn SIZE was not: `CoachMessage.content` had no
`max_length`, and the body was limited in practice only by nginx's
`client_max_body_size`, which was 600M. That is a denial-of-wallet against the surface
this project has actually measured at $0.179 a question — the same shape `read/logs.py`
names for manual-entry notes, and the same fix.

The accepting tests matter as much as the refusing ones: a bound below what a real
thread carries would truncate somebody's conversation with a 422 they cannot act on.
"""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from healthee.api.routers.coach import _MAX_CONTENT, _MAX_TURNS, CoachRequest
from healthee.insights import coach_thread

_TURN = {"role": "user", "content": "why is my HRV down?"}


def test_a_turn_longer_than_the_bound_is_refused() -> None:
    with pytest.raises(ValidationError):
        CoachRequest.model_validate(
            {"messages": [{"role": "user", "content": "x" * (_MAX_CONTENT + 1)}]}
        )


def test_a_long_but_human_question_is_accepted() -> None:
    """~700 words. Far more than anyone types into a chat box, and fatal to a paste."""
    body = CoachRequest.model_validate(
        {"messages": [{"role": "user", "content": "x" * _MAX_CONTENT}]}
    )
    assert len(body.messages[0].content) == _MAX_CONTENT


def test_a_conversation_longer_than_the_bound_is_refused() -> None:
    with pytest.raises(ValidationError):
        CoachRequest.model_validate({"messages": [_TURN] * (_MAX_TURNS + 1)})


def test_the_turn_cap_is_above_what_the_pipeline_actually_reads() -> None:
    """A cap below the history the coach uses would silently shorten a real thread.

    `coach_thread.recent` keeps the last `HISTORY_LIMIT` well-formed turns; this cap has
    to sit comfortably above it, or the boundary would refuse turns the answer needs.
    """
    assert _MAX_TURNS > coach_thread.HISTORY_LIMIT * 2


def test_a_full_thread_is_accepted() -> None:
    body = CoachRequest.model_validate({"messages": [_TURN] * _MAX_TURNS})
    assert len(body.messages) == _MAX_TURNS


def test_an_absurd_role_string_is_refused() -> None:
    """`role` is echoed into the prompt assembly like `content` is."""
    with pytest.raises(ValidationError):
        CoachRequest.model_validate({"messages": [{"role": "u" * 500, "content": "hi"}]})


def test_an_empty_body_is_still_valid() -> None:
    """Unchanged: the default was `[]` and the bound must not have made it required."""
    assert CoachRequest.model_validate({}).messages == []
