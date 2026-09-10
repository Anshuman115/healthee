"""Gathering is bounded by the CLOCK as well as by rounds.

## The failure this closes

`coach.py` allows 20 gathering rounds and nothing bounded how long they take. On
2026-09-10 production rounds were measured at ~103 s each — about 30,000 input
tokens re-sent every round — so the worst case was over half an hour while the app
hangs up at 360 s. **Zero coach requests had ever completed on that deployment.**
The server kept working, produced an answer, and wrote it to a closed socket.

A round ceiling cannot express that, because the thing that ran out was not rounds.

## Why the deadline stops GATHERING rather than the run

Aborting would give the owner nothing, which is what already happened. Stopping
gathering forces the next turn to answer with what has been collected — the same
shape the stall guard already uses, and the same rule this product follows
everywhere else it runs short: say what you have and say it is partial.
"""

from __future__ import annotations

from collections.abc import Iterator

import pytest

from healthee.core.config import get_settings
from healthee.insights import pipeline
from healthee.insights.pipeline import Loop, Turn


@pytest.fixture
def _fast_deadline(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """A deadline of zero: the first round is already late."""
    monkeypatch.setenv("GATHERING_DEADLINE_S", "0")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def _recording_loop(answers: list[str | None]) -> tuple[Loop, list[bool]]:
    """A loop that yields `answers` in order and records the `tools_allowed` it saw."""
    seen: list[bool] = []
    queue = list(answers)

    def next_turn(tools_allowed: bool) -> Turn:
        seen.append(tools_allowed)
        return Turn(text=queue.pop(0) if queue else "done [note]")

    return (
        Loop(
            next_turn=next_turn,
            nudge=lambda _text, _ids: None,
            label="test-loop",
            max_gathering_turns=20,
        ),
        seen,
    )


def test_the_deadline_setting_is_read_live_not_at_import() -> None:
    """A deployment must be able to change it, and a test to set it, without a reload."""
    assert pipeline.gathering_deadline_s() == get_settings().gathering_deadline_s


def test_a_run_past_its_deadline_is_NOT_offered_tools(_fast_deadline: None) -> None:  # noqa: PT019, N802
    """The whole point: gathering stops even though 20 rounds remain unspent."""
    loop, seen = _recording_loop([None, None])

    pipeline.drive(loop)

    assert seen, "the loop never ran"
    assert seen[0] is False, "an over-deadline run was still offered tools"


def test_WITHIN_the_deadline_tools_are_offered(monkeypatch: pytest.MonkeyPatch) -> None:  # noqa: N802
    """The premise of the test above — without this it could pass against a loop
    that never offers tools at all, which is the shape of gate that protects nothing."""
    monkeypatch.setenv("GATHERING_DEADLINE_S", "600")
    get_settings.cache_clear()
    loop, seen = _recording_loop([None, "an answer [note]"])

    pipeline.drive(loop)

    assert seen[0] is True
    get_settings.cache_clear()


def test_the_deadline_still_produces_an_ANSWER(_fast_deadline: None) -> None:  # noqa: PT019, N802
    """An abort would hand the owner exactly what the timeout already handed them."""
    loop, _seen = _recording_loop(["what I have so far [note]"])

    outcome = pipeline.drive(loop)

    assert outcome.text
    assert outcome.text != ""
