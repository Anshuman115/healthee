"""THE acceptance bar: a stage added to the choke point cannot silently miss the coach.

This file is the mechanism that replaced a rule people had to remember. Until the stages
were collapsed into ``insights/pipeline.py`` the coach was *enforced-equivalent* to the
choke point — it called the same primitives from its own loop — so INTELLIGENCE §4 and
ENGINEERING_STANDARDS §2 both carried a standing instruction to mirror every new rule by
hand. It had already been missed once (the hard output guardrail, written in two places).

Two independent tests hold the bar, and they need each other:

1. **Injection** — put a NEW stage into the shared registry and assert BOTH surfaces
   obey it. This proves the shared path actually reaches both, for all three kinds of
   stage (a question gate, a blocking answer gate, an issue-raising answer gate).
2. **The AST guard** — assert that no module except ``pipeline.py`` reaches a choke-point
   primitive directly. Injection proves a stage added *to the registry* propagates; this
   proves a stage cannot be added *outside* it without failing a test. Without (2)
   somebody could re-add ``check_output`` to one surface and (1) would stay green.

Mutation-verified both ways: making ``coach._loop`` call ``output_guard.check_output``
itself instead of driving the shared pipeline fails (2); making it skip a shared gate
fails (1).
"""

from __future__ import annotations

import ast
import re
from pathlib import Path

import pytest
from tests.insights._coach_stub import CoachStub, NoCallStub, text_turn
from tests.insights._stub import VALID_TEXT, StubLLM

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.insights import coach, grounded, pipeline, prompts
from healthee.insights.refusals import Domain

# ── 1 · a stage injected into the shared registry reaches BOTH surfaces ──────

_CANARY_WORD = "SENTINEL_CANARY"
_CANARY_BLOCK = "blocked by the canary stage"

# Deliberately an answer every EXISTING stage accepts: cited, calibrated, terminated,
# claiming no action. If it were rejectable on its own, these tests would pass whether
# or not the injected stage ran — which is how a canary test quietly becomes decorative.
_CANARY_ANSWER = f"{VALID_TEXT} {_CANARY_WORD}."


def _canary_block_gate(text: str, ctx: pipeline.AnswerContext) -> pipeline.GateOutcome:  # noqa: ARG001
    """A brand-new BLOCKING stage — the shape a future hard guardrail takes."""
    if _CANARY_WORD in text:
        return pipeline.GateOutcome(block=pipeline.Block("canary", _CANARY_BLOCK))
    return pipeline.GateOutcome()


def _canary_issue_gate(text: str, ctx: pipeline.AnswerContext) -> pipeline.GateOutcome:  # noqa: ARG001
    """A brand-new RETRYABLE stage — the shape a future validator rule takes."""
    if _CANARY_WORD in text:
        return pipeline.GateOutcome(issues=("the canary rule was broken",))
    return pipeline.GateOutcome()


_CANARY_DOMAIN = Domain(
    "canary", re.compile(_CANARY_WORD, re.IGNORECASE), "the canary question domain is refused"
)


def _add_answer_gate(monkeypatch: pytest.MonkeyPatch, gate: pipeline.AnswerGate) -> None:
    """Append one stage to the shared answer registry — the ONLY door a stage enters by."""
    existing = pipeline.answer_gates()
    monkeypatch.setattr(pipeline, "answer_gates", lambda: (*existing, gate))


def _stub_prompts(monkeypatch: pytest.MonkeyPatch) -> None:
    """Both surfaces' DB-backed message builders — these are control-flow tests."""
    monkeypatch.setattr(
        grounded, "_build_messages", lambda *a, **k: [{"role": "user", "content": "x"}]
    )
    monkeypatch.setattr(
        coach, "_initial_messages", lambda *a, **k: [{"role": "user", "content": "x"}]
    )


def _ask_grounded(client: object) -> str:
    result = grounded.grounded_ask("how am I doing?", SENTINEL_USER_ID, SENTINEL_TZ, client=client)  # type: ignore[arg-type]
    return result.text


def _ask_coach(client: object) -> str:
    result = coach.run_coach(
        [{"role": "user", "content": "how am I doing?"}],
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        client=client,  # type: ignore[arg-type]
    )
    return result.reply


def test_the_canary_answer_is_otherwise_clean_on_both_surfaces(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The control the three tests below rest on: with NO new stage, this answer ships.

    Every later assertion says "the injected stage rejected it". That only means anything
    if nothing else would have.
    """
    _stub_prompts(monkeypatch)
    assert _ask_grounded(StubLLM([_CANARY_ANSWER])) == _CANARY_ANSWER
    assert _ask_coach(CoachStub([text_turn(_CANARY_ANSWER)])) == _CANARY_ANSWER


def test_a_new_blocking_stage_reaches_the_choke_point(monkeypatch: pytest.MonkeyPatch) -> None:
    _stub_prompts(monkeypatch)
    _add_answer_gate(monkeypatch, _canary_block_gate)
    stub = StubLLM([_CANARY_ANSWER])
    assert _ask_grounded(stub) == _CANARY_BLOCK
    assert stub.calls == 1, "a blocking stage must not be nudged/retried"


def test_a_new_blocking_stage_reaches_the_coach_too(monkeypatch: pytest.MonkeyPatch) -> None:
    """The bar itself: nobody edited coach.py, and the coach obeys the new stage."""
    _stub_prompts(monkeypatch)
    _add_answer_gate(monkeypatch, _canary_block_gate)
    stub = CoachStub([text_turn(_CANARY_ANSWER)])
    assert _ask_coach(stub) == _CANARY_BLOCK
    assert stub.calls == 1


def test_a_new_retryable_stage_reaches_both_surfaces(monkeypatch: pytest.MonkeyPatch) -> None:
    """An issue-raising stage must nudge once and then ship the honest fallback — on both."""
    _stub_prompts(monkeypatch)
    _add_answer_gate(monkeypatch, _canary_issue_gate)

    grounded_stub = StubLLM([_CANARY_ANSWER, _CANARY_ANSWER])
    assert _ask_grounded(grounded_stub) == prompts.FALLBACK
    assert grounded_stub.calls == 2, "one nudged retry, then the fallback"

    coach_stub = CoachStub([text_turn(_CANARY_ANSWER), text_turn(_CANARY_ANSWER)])
    assert _ask_coach(coach_stub) == prompts.FALLBACK
    assert coach_stub.calls == 2


def test_a_new_question_gate_reaches_both_surfaces(monkeypatch: pytest.MonkeyPatch) -> None:
    """A pre-LLM stage must short-circuit BOTH surfaces before the model is ever called."""
    _stub_prompts(monkeypatch)
    existing = pipeline.question_gates()
    monkeypatch.setattr(
        pipeline,
        "question_gates",
        lambda: (*existing, lambda q: _CANARY_DOMAIN if _CANARY_WORD in q else None),
    )
    question = f"tell me about {_CANARY_WORD}"

    grounded_result = grounded.grounded_ask(
        question, SENTINEL_USER_ID, SENTINEL_TZ, client=NoCallStub()
    )
    assert grounded_result.refused is True
    assert grounded_result.text == _CANARY_DOMAIN.template

    coach_result = coach.run_coach(
        [{"role": "user", "content": question}],
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        client=NoCallStub(),
    )
    assert coach_result.refused is True
    assert coach_result.reply == _CANARY_DOMAIN.template


def test_the_shared_registry_keeps_the_floor_under_the_validator() -> None:
    """Order is load-bearing: the hard guardrail runs BEFORE the validator (§3)."""
    names = [gate.__name__ for gate in pipeline.answer_gates()]
    assert names.index("_output_guard_gate") < names.index("_validator_gate")


# ── 2 · no surface may reach a choke-point primitive directly ────────────────

_SRC = Path(__file__).resolve().parents[2] / "src" / "healthee"

# name → the module that owns it. Reaching any of these from anywhere but the pipeline
# is how a stage gets re-added to ONE surface, which is the whole failure being fixed.
_PRIMITIVES: dict[str, str] = {
    "classify_refusal": "healthee.insights.refusals",
    "check_output": "healthee.insights.output_guard",
    "validate": "healthee.insights.validator",
    "validate_json": "healthee.insights.validator",
    "evidence_section": "healthee.insights.retrieval",
    "build_context": "healthee.insights.context",
}
_OWNER_MODULES = {"refusals", "output_guard", "validator", "retrieval", "context"}

# The pipeline is the one place they may be reached; each owner module defines its own.
_ALLOWED = {"insights/pipeline.py"} | {f"insights/{m}.py" for m in _OWNER_MODULES}


def _python_files() -> list[Path]:
    return sorted(p for p in _SRC.rglob("*.py") if "__pycache__" not in p.parts)


def _reaches_a_primitive(tree: ast.AST) -> set[str]:
    """Every choke-point primitive this module imports by name or calls as an attribute."""
    found: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and node.module in _PRIMITIVES.values():
            found |= {alias.name for alias in node.names if alias.name in _PRIMITIVES}
        elif isinstance(node, ast.Attribute) and node.attr in _PRIMITIVES:
            owner = node.value
            if isinstance(owner, ast.Name) and owner.id in _OWNER_MODULES:
                found.add(node.attr)
    return found


def test_only_the_pipeline_reaches_the_choke_point_primitives() -> None:
    """The structural half of the bar — a stage cannot be re-added to one surface only.

    Without this, ``coach.py`` could quietly grow its own ``check_output`` call again and
    every injection test above would stay green (the shared gate would still run; a
    SECOND copy would just have appeared). That is exactly how the guardrail came to be
    written twice.
    """
    offenders: dict[str, set[str]] = {}
    for path in _python_files():
        relative = path.relative_to(_SRC).as_posix()
        if relative in _ALLOWED:
            continue
        reached = _reaches_a_primitive(ast.parse(path.read_text(encoding="utf-8")))
        if reached:
            offenders[relative] = reached
    assert not offenders, (
        "these modules reach a choke-point primitive directly instead of going through "
        f"insights/pipeline.py: {offenders}"
    )


def test_the_guard_would_catch_a_surface_that_reached_a_primitive() -> None:
    """Mutation-proof the guard itself: a detector that detects nothing proves nothing."""
    source = "from healthee.insights.output_guard import check_output\ncheck_output('x')\n"
    assert _reaches_a_primitive(ast.parse(source)) == {"check_output"}
    attribute = "from healthee.insights import validator\nvalidator.validate('x')\n"
    assert _reaches_a_primitive(ast.parse(attribute)) == {"validate"}
