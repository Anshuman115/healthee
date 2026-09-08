"""The coach's TWO budgets — gathering rounds and validation retries — must not compete.

They used to be one counter (``Loop.max_turns=5``), and the measured consequence was two
defects rather than one tight bound. Scripted against the stub client, the OLD sequence
was:

    | tool rounds | LLM calls made                  | result                          |
    |-------------|---------------------------------|---------------------------------|
    | 3           | tool,tool,tool,prose            | validated                       |
    | 4           | tool,tool,tool,tool,prose       | validated, ZERO retries left    |
    | 5           | tool,tool,tool,tool,tool        | fallback — prose never REQUESTED |

(a) at the ceiling the loop exited having never asked for an answer: the model had
gathered everything correctly and was denied the chance to use it, and the owner saw the
honest fallback to a question the system could answer. (b) a data-heavy question arrived
at its single answer attempt with no validation retries while a trivial question kept the
full :func:`pipeline.validation_retries` allowance — the questions needing the most data
got the LEAST grounding tolerance.

The shape is what changed, not the number: gathering has its own allowance, the retries
are reserved on top of it, and the last round withdraws ``tools=`` so the model is always
asked for an answer with what it has. These tests assert the SEQUENCE of calls, because
the defect was invisible in the reply and only legible in the call log.
"""

from __future__ import annotations

import pytest
from tests.insights._coach_stub import (
    VALID_REPLY,
    CoachStub,
    claim_turn,
    opening_turn,
    tool_call,
    tool_turn,
    valid_turn,
)

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.insights import (
    coach,
    coach_loop,
    coach_thread,
    coach_tools,
    output_guard,
    pipeline,
    prompts,
)

# A candidate that fails its gates: a claim citing an id the manifest does not know.
# Written through the answer contract (#128) so what is being measured is the RETRY
# BUDGET rather than the shape check — a raw-prose candidate would fail for two reasons
# at once and the call counts below would stop meaning what they say.
_BAD = claim_turn("Your recovery suggests overtraining", ["not_a_real_note"])
_RETRIES = 2  # `LLM_VALIDATION_RETRIES`' default; asserted against the setting below


@pytest.fixture(autouse=True)
def _stub_context(monkeypatch: pytest.MonkeyPatch) -> None:
    """No DB, no network: these are call-sequence tests, not SQL or grounding tests."""
    monkeypatch.setattr(
        coach,
        "_initial_messages",
        # Keeps the LAYOUT (a `system` turn, then the whole conversation) while
        # skipping the DB-backed context/evidence build. It used to return only the
        # last question, which discarded `history` — so no coach test exercised a
        # multi-turn context, and the thread-wide refusal screen could not have been
        # caught here however it behaved. The topic block rides along so a test can
        # assert what a topic does and does not put in front of the model.
        lambda history, q, user_id, tz, days, topic=None: [
            {"role": "system", "content": f"CONTEXT{coach_thread.topic_block(topic)}"},
            *history,
        ],
    )
    monkeypatch.setattr(coach_tools, "execute_tool", lambda name, args, user_id, tz: {"ok": True})


def _tool(n: int) -> object:
    """A tool round asking for a DISTINCT metric — distinct so the stall guard stays out."""
    return tool_turn(tool_call(f"c{n}", "query_metric", f'{{"metric": "m{n}"}}'))


def _run(script: list) -> tuple[CoachStub, coach.CoachResult]:
    stub = CoachStub(script)
    result = coach.run_coach(
        [{"role": "user", "content": "how am I doing?"}],
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        client=stub,  # type: ignore[arg-type]
    )
    return stub, result


def _gather(rounds: int) -> list:
    return [_tool(i) for i in range(rounds)]


def _offered_tools(stub: CoachStub) -> list[bool]:
    """Which calls were made WITH tools — the sequence the defect actually lived in."""
    return [tools is not None for tools in stub.tools_seen]


# ── the sequence table, re-measured ──────────────────────────────────────────


@pytest.mark.parametrize("rounds", [0, 1, 2, 3, 4, 5, 6, 19])
def test_n_tool_rounds_then_an_answer_turn_all_ship(rounds: int) -> None:
    """Under the ceiling the sequence is exactly N tool calls + one answer call."""
    stub, result = _run([*_gather(rounds), valid_turn()])
    assert result.reply == VALID_REPLY
    assert result.validated is True
    assert stub.calls == rounds + 1
    assert _offered_tools(stub) == [True] * (rounds + 1)


def test_the_old_five_round_cliff_is_gone() -> None:
    """The exact row that used to fall back: five tool rounds, then an answer."""
    stub, result = _run([*_gather(5), valid_turn()])
    assert result.reply == VALID_REPLY  # was prompts.FALLBACK
    assert stub.calls == 6  # was 5 — the answer turn was never even requested


@pytest.mark.parametrize("rounds", [0, 4, 19, coach.GATHERING_ROUNDS])
def test_gathering_never_eats_the_validation_retry_budget(rounds: int) -> None:
    """Defect (b): after ANY amount of gathering, a bad answer still gets its nudge.

    Four tool rounds used to leave zero retries — the same first-attempt failure that a
    trivial question recovers from shipped the fallback instead.
    """
    stub, result = _run([*_gather(rounds), _BAD, valid_turn()])
    assert result.reply == VALID_REPLY
    assert result.validated is True
    assert stub.calls == rounds + 2


def test_the_worst_case_call_count_is_the_declared_ceiling() -> None:
    """Full gathering + a failed answer + its retries — and that is the maximum."""
    rounds = coach.GATHERING_ROUNDS
    script = [*_gather(rounds), *([_BAD] * _RETRIES), valid_turn()]
    stub, result = _run(script)
    assert stub.calls == rounds + pipeline.validation_retries() + 1 == 23
    assert result.validated is True


# ── the loop is never left without asking for an answer ──────────────────────


def test_at_the_ceiling_the_tools_are_withdrawn_and_an_answer_is_requested() -> None:
    """Defect (a): the last round drops ``tools=`` instead of exiting empty-handed."""
    rounds = coach.GATHERING_ROUNDS
    stub, result = _run([*_gather(rounds), valid_turn()])
    assert result.reply == VALID_REPLY
    assert stub.calls == rounds + 1
    assert _offered_tools(stub) == [True] * rounds + [False]


def test_the_model_is_told_why_its_tools_disappeared_exactly_once() -> None:
    """A silent loss of tools is a worse prompt than an explained one — and said twice is noise."""
    rounds = coach.GATHERING_ROUNDS
    stub, _ = _run([*_gather(rounds), _BAD, valid_turn()])
    final_convo = stub.messages_seen[-1]
    said = [m for m in final_convo if m.get("content") == coach_loop._ANSWER_NOW]
    assert len(said) == 1


@pytest.mark.parametrize("rounds", [coach.GATHERING_ROUNDS, coach.GATHERING_ROUNDS + 5])
def test_a_model_that_only_ever_calls_tools_is_still_asked_for_an_answer(rounds: int) -> None:
    """The invariant defect (a) broke: the loop never gives up without requesting prose."""
    stub, result = _run(_gather(rounds))
    assert stub.tools_seen[-1] is None, "the last call must be an ANSWER request"
    assert result.reply == prompts.FALLBACK  # it was asked and produced none — honest fallback


# ── the honesty floor is untouched ───────────────────────────────────────────


def test_the_fallback_still_ships_when_grounding_genuinely_fails() -> None:
    """Every attempt bad: the fallback, after exactly the budget — no extra attempts."""
    stub, result = _run([_BAD] * (_RETRIES + 2))
    assert result.reply == prompts.FALLBACK
    assert result.validated is False
    assert stub.calls == _RETRIES + 1


def test_the_fallback_still_ships_after_a_full_gather_that_cannot_be_grounded() -> None:
    rounds = coach.GATHERING_ROUNDS
    stub, result = _run([*_gather(rounds), *([_BAD] * (_RETRIES + 2))])
    assert result.reply == prompts.FALLBACK
    assert result.validated is False
    assert stub.calls == rounds + _RETRIES + 1


def test_a_blocked_answer_still_returns_without_a_retry() -> None:
    """A hard guardrail is a floor, not a grounding problem to nudge the model out of."""
    forbidden = "At this activity level your life expectancy is around 79."
    assert output_guard.check_output(forbidden) is not None, "the fixture must be blocked"
    stub, result = _run([*_gather(3), opening_turn(forbidden)])
    assert result.refused is True
    assert result.validated is False
    assert stub.calls == 4  # three tool rounds + the blocked answer. No retry.


# ── the no-progress guard ────────────────────────────────────────────────────


def test_a_repeated_identical_call_stops_the_gathering_early() -> None:
    """Same tool, same arguments = the same answer. Stop and answer with what is there."""
    same = _tool(0)
    stub, result = _run([same, same, valid_turn()])
    assert result.reply == VALID_REPLY
    assert stub.calls == 3  # not 20 rounds of the same question
    assert _offered_tools(stub) == [True, True, False]


def test_the_stall_guard_does_not_fire_on_the_same_tool_with_different_arguments() -> None:
    """Two reads of two different metrics is progress, not a loop."""
    stub, result = _run([_tool(0), _tool(1), _tool(2), valid_turn()])
    assert stub.calls == 4
    assert _offered_tools(stub) == [True] * 4


def test_a_round_that_repeats_one_call_but_makes_another_still_counts_as_progress() -> None:
    """A parallel round is stalled only when EVERY call in it was already made."""
    mixed = tool_turn(
        tool_call("a", "query_metric", '{"metric": "m0"}'),
        tool_call("b", "query_metric", '{"metric": "m9"}'),
    )
    stub, result = _run([_tool(0), mixed, _tool(1), valid_turn()])
    assert stub.calls == 4
    assert _offered_tools(stub) == [True] * 4


def test_a_stalled_loop_that_still_refuses_to_answer_falls_back_rather_than_spinning() -> None:
    """The pathological model: it keeps calling tools even after they were withdrawn."""
    same = _tool(0)
    stub, result = _run([same] * 40)
    assert result.reply == prompts.FALLBACK
    assert result.validated is False
    assert stub.calls == 3  # new call, repeat (stall), one tool-less attempt, then stop


# ── the budgets themselves ───────────────────────────────────────────────────


def test_a_tool_less_surface_has_no_gathering_allowance() -> None:
    """``grounded_ask``'s budget is unchanged: one attempt plus its one nudged retry."""
    loop = pipeline.Loop(
        next_turn=lambda _: pipeline.Turn(text=""), nudge=lambda t, i: None, label="x"
    )
    assert loop.max_gathering_turns == 0
    assert pipeline.turn_budget(loop) == pipeline.validation_retries() + 1


def test_the_coach_budget_is_gathering_plus_the_reserved_answers() -> None:
    loop = pipeline.Loop(
        next_turn=lambda _: pipeline.Turn(text=""),
        nudge=lambda t, i: None,
        label="coach",
        max_gathering_turns=coach.GATHERING_ROUNDS,
    )
    assert pipeline.turn_budget(loop) == coach.GATHERING_ROUNDS + _RETRIES + 1


def test_the_retry_budget_is_the_configured_one_and_defaults_to_two() -> None:
    """The number moved out of the source and into `LLM_VALIDATION_RETRIES` (#128).

    Two, not one, because the failures it recovers are citation/format wording (§9.1's
    ~80 %) and a nudge naming the exact issue is what repairs them; on a flash tier the
    third attempt costs a fraction of one attempt on the tier above. The counts asserted
    throughout this file are that default, so this is the line that fails first if it
    changes — which is the point of pinning it here rather than in prose.
    """
    assert pipeline.validation_retries() == _RETRIES == 2
