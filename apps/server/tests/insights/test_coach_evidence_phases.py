"""#105 — the notes ride on the round that USES them, and on no other.

A coach question is ~3 model calls and the EVIDENCE NOTES block — six full research notes
— used to be on every one of them: 65–83% of each prompt (task #23). Only the last call
writes prose or cites anything, so the gathering rounds were paying to ship a library to
a call that produces a function name.

What replaced it is two phases distinguished by what each round is GIVEN, not by any
guess about which round is which (the loop cannot know: the model simply stops calling
tools). These tests pin both halves, because either one alone is a defect:

  * a gathering round must carry NO note body — that is the saving;
  * an answering round, INCLUDING every validation retry, must carry them all — an
    answer written without the notes it cites is the cheaper-but-less-grounded outcome
    this change exists not to ship.

The non-tool surfaces (``grounded_ask``) have no gathering rounds and must be untouched;
the last test here says so against the shared retrieval stage.
"""

from __future__ import annotations

import pytest
from tests.insights._coach_stub import CoachStub, text_turn, tool_call, tool_turn
from tests.insights._stub import VALID_TEXT

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.insights import coach, coach_messages, coach_tools, grounded, pipeline

# The heading `evidence_section` puts above the embedded note BODIES, and the one
# `index_section` puts above the one-line list. Matching on the headings rather than on a
# note's prose keeps the assertions readable and still fails if either block moves.
_BODIES = "# EVIDENCE NOTES"
_INDEX = "# EVIDENCE INDEX"

_QUESTION = "how has my sleep been lately?"
_BAD = "Your recovery suggests overtraining [not_a_real_note]."


@pytest.fixture(autouse=True)
def _no_db(monkeypatch: pytest.MonkeyPatch) -> None:
    """Stub the DB-backed CONTEXT and nothing else — the message LAYOUT stays real.

    Deliberately not a stub of ``initial_messages`` (which is what the other coach
    control-flow files do, because they are testing the loop and not the prompt): a test
    that rebuilds the layout it is checking cannot fail when the layout changes, and the
    layout is exactly what this file exists to pin.
    """
    monkeypatch.setattr(coach_messages, "build_coach_context", lambda *a, **k: "OWNER CONTEXT")
    monkeypatch.setattr(coach_tools, "execute_tool", lambda name, args, user_id, tz: {"ok": True})


def _run(script: list) -> tuple[CoachStub, coach.CoachResult]:
    stub = CoachStub(script)
    result = coach.run_coach(
        [{"role": "user", "content": _QUESTION}],
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        client=stub,  # type: ignore[arg-type]
    )
    return stub, result


def _prompt(stub: CoachStub, call: int) -> str:
    """Everything the model was asked on one call, as one string."""
    return "\n".join(str(m.get("content", "")) for m in stub.messages_seen[call])


def _tool(n: int) -> object:
    return tool_turn(tool_call(f"c{n}", "query_metric", f'{{"metric": "m{n}"}}'))


# ── the saving: no note body on a round that cites nothing ───────────────────


def test_no_gathering_round_carries_a_note_body() -> None:
    """The measured waste: three calls, one of which needed the notes."""
    stub, result = _run([_tool(0), _tool(1), text_turn("READY"), text_turn(VALID_TEXT)])
    assert result.validated is True
    gathering = [_prompt(stub, i) for i in range(3)]
    assert all(_BODIES not in prompt for prompt in gathering)
    assert all(_INDEX in prompt for prompt in gathering), "the corpus INDEX still reaches them"


def test_a_gathering_prompt_is_strictly_smaller_than_the_answering_one() -> None:
    """The claim is a size claim, so measure it rather than trusting the marker strings."""
    stub, _ = _run([_tool(0), text_turn("READY"), text_turn(VALID_TEXT)])
    gathering, answering = len(_prompt(stub, 0)), len(_prompt(stub, 2))
    assert answering > gathering
    # The notes are the biggest thing in the product's prompts; a few hundred characters
    # would mean the block did not actually move.
    assert answering - gathering > 10_000


def test_the_index_names_every_note_the_full_block_would_embed() -> None:
    """The risk this design had to respect: the model may need the corpus to know what to
    look UP. It still sees every note's id, grade and summary — the index is a strict
    subset of the old block, which already listed its un-embedded notes in that form."""
    index = pipeline.evidence_index(_QUESTION)
    _bodies, embedded_ids = pipeline.evidence(_QUESTION)
    assert embedded_ids, "the fixture needs a corpus"
    assert all(f"`[{note_id}]`" in index for note_id in embedded_ids)
    assert _BODIES not in index


# ── the floor: the answer, and every retry, gets the notes ───────────────────


def test_the_answering_round_gets_the_full_notes_and_no_tools() -> None:
    stub, result = _run([_tool(0), text_turn("READY"), text_turn(VALID_TEXT)])
    assert result.validated is True
    assert _BODIES in _prompt(stub, 2)
    assert stub.tools_seen[2] is None, "an answering round offers no tools"


def test_a_validation_retry_still_has_the_full_notes() -> None:
    """A retry IS an answering round — it must not be cheaper than the attempt it fixes."""
    stub, result = _run([text_turn("READY"), text_turn(_BAD), text_turn(VALID_TEXT)])
    assert result.reply == VALID_TEXT
    assert _BODIES in _prompt(stub, 2)


def test_the_notes_are_sent_exactly_once_however_many_answer_attempts_there_are() -> None:
    """Appending them per attempt would spend the saving on the questions that fail."""
    stub, _ = _run([text_turn("READY"), text_turn(_BAD), text_turn(VALID_TEXT)])
    assert _prompt(stub, 2).count(_BODIES) == 1


def test_the_answer_gets_the_notes_when_the_gathering_allowance_runs_out_instead() -> None:
    """The other way into the answering round: the budget ends the phase, not the model."""
    stub, _ = _run([_tool(n) for n in range(coach.GATHERING_ROUNDS)] + [text_turn(VALID_TEXT)])
    last = _prompt(stub, coach.GATHERING_ROUNDS)
    assert _BODIES in last
    assert coach_messages.ANSWER_NOW in last


# ── the non-tool surfaces must not have moved at all ─────────────────────────


def test_grounded_ask_still_embeds_the_full_notes_in_its_one_and_only_prompt(
    db: None,  # noqa: ARG001 — its context builder is the real, DB-backed one
) -> None:
    """``grounded_ask`` has no gathering rounds, so it has nothing to defer and must not.

    Asserted through the surface's own message builder rather than the retrieval stage, so
    a change that left ``pipeline.evidence`` alone but stopped USING it would still fail.
    """
    messages = grounded._build_messages(_QUESTION, SENTINEL_USER_ID, SENTINEL_TZ, [], 14)
    body = "\n".join(str(m["content"]) for m in messages)
    assert _BODIES in body
    assert _INDEX not in body
    assert coach_messages.GATHERING_NOTICE not in body
