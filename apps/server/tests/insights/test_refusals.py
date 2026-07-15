"""The deterministic refusal pre-classifier — each of the 5 domains bypasses the LLM.

Proves hole-#1 groundwork: a safety-critical query is refused by *code*, before any
model runs (INTELLIGENCE §5.5). The stub LLM asserts it is never called.
"""

from __future__ import annotations

import pytest
from tests.insights._stub import StubLLM

from healthee.insights import refusals
from healthee.insights.grounded import grounded_ask

_CASES = [
    ("emergency", "I have chest pain right now, what does my data say?", refusals.EMERGENCY),
    ("diagnosis", "Do I have sleep apnea based on my SpO2?", refusals.DIAGNOSIS),
    ("medication", "Should I increase my dose of my statin medication?", refusals.MEDICATION),
    ("pregnancy_pediatric", "I'm pregnant — is my HRV okay?", refusals.PREGNANCY_PEDIATRIC),
    ("mental_health", "I've felt so depressed and hopeless lately.", refusals.MENTAL_HEALTH),
]


@pytest.mark.parametrize(("name", "question", "template"), _CASES)
def test_domain_classifier_hits(name: str, question: str, template: str) -> None:
    domain = refusals.classify_refusal(question)
    assert domain is not None
    assert domain.name == name
    assert domain.template == template


@pytest.mark.parametrize(("name", "question", "template"), _CASES)
def test_refusal_bypasses_the_llm(name: str, question: str, template: str) -> None:  # noqa: ARG001
    stub = StubLLM()
    result = grounded_ask(question, client=stub)
    assert result.refused is True
    assert result.text == template
    assert stub.calls == 0  # the model is never called on a refusal


def test_ordinary_question_is_not_refused() -> None:
    assert refusals.classify_refusal("How has my resting heart rate trended this month?") is None
