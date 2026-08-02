"""The deterministic refusal pre-classifier — each of the 5 domains bypasses the LLM.

Proves hole-#1 groundwork: a safety-critical query is refused by *code*, before any
model runs (INTELLIGENCE §5.5). The stub LLM asserts it is never called.
"""

from __future__ import annotations

import pytest
from tests.insights._stub import StubLLM

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.insights import red_flags, refusals
from healthee.insights.grounded import grounded_ask

_CASES = [
    ("emergency", "I have chest pain right now, what does my data say?", refusals.EMERGENCY),
    (
        "exertional_emergency",
        "I collapsed at the end of my long run yesterday and was vomiting afterwards.",
        refusals.EMERGENCY,
    ),
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
    result = grounded_ask(question, SENTINEL_USER_ID, SENTINEL_TZ, client=stub)
    assert result.refused is True
    assert result.text == template
    assert stub.calls == 0  # the model is never called on a refusal


def test_ordinary_question_is_not_refused() -> None:
    assert refusals.classify_refusal("How has my resting heart rate trended this month?") is None


# ── #110 · the word "stroke" has a metric sense, and the legacy port ate it ───
# The fragment was a bare, unanchored `stroke`. Below, one case per alternative of the
# exclusion lookahead with the frame held constant, so a deleted alternative has exactly
# one test that can fail for it — the discipline #100's own agent found it had missed.

_METRIC_SENSES: list[tuple[str, str]] = [
    ("rate", "My stroke rate was 24 spm on the erg."),
    ("volume", "Does my training improve my stroke volume?"),
    ("count", "My stroke count dropped this month."),
    ("length", "How does stroke length affect swim pace?"),
    ("index", "What does my stroke index look like at threshold?"),
    ("per", "I averaged 28 strokes per minute."),
    # Not the lookahead — the word boundary. Bare `stroke` matched the inside of these.
    ("word boundary: breaststroke", "My breaststroke is slower than my freestyle."),
    ("word boundary: backstroke", "Backstroke intervals wrecked my shoulders."),
]


@pytest.mark.parametrize(("alternative", "question"), _METRIC_SENSES)
def test_the_metric_sense_of_stroke_reaches_the_coach(alternative: str, question: str) -> None:
    """Rowing, swimming and cardiac physiology all use this word and none of them is 911.

    "stroke volume" is taught by four of our own notes — the corpus and the safety screen
    disagreed about the same word.
    """
    assert refusals.classify_refusal(question) is None, (
        f"the `{alternative}` exclusion is gone: an ordinary training question is being "
        f"refused as a medical emergency"
    )


# The medical senses, one case per alternative that carries it. Every one of these is a
# question the product refuses today; none of them may stop refusing. Note what is NOT
# here: a case that `exertional_emergency` could rescue. Each of these fails that screen's
# owner-attribution test, so `emergency` is the only thing standing between it and the
# model — which is why the domain NAME is asserted, not merely that something refused.

_MEDICAL_SENSES: list[tuple[str, str]] = [
    ("the plain word", "I think I'm having a stroke."),
    # `strokes?` — plural is how people report someone else's history.
    ("plural", "My mother had two strokes."),
    # The exclusion is ADJACENCY (`\s*`), not presence anywhere in the message. Loosen it
    # to `.*` and this sentence stops escalating because it says "rate" eight words later
    # — which is how an emergency report from someone quoting their watch actually reads.
    ("adjacency, not presence", "I think I'm having a stroke and my heart rate is 180."),
    # The three below are why #110 did NOT hand heat stroke to `exertional_emergency`
    # (see the refusals module docstring). Each one that screen reads as a topic, not a
    # report, so removing them here removes them from the product entirely.
    ("third-party heat stroke", "My friend collapsed with heat stroke, what do I do?"),
    ("first-person gerund", "I think I'm having heat stroke right now."),
    ("sun stroke", "I got sun stroke yesterday."),
    ("closed compound", "I got sunstroke yesterday."),
    ("hyphenated compound", "He has heat-stroke symptoms."),
]


@pytest.mark.parametrize(("alternative", "question"), _MEDICAL_SENSES)
def test_the_medical_sense_of_stroke_still_escalates(alternative: str, question: str) -> None:
    domain = refusals.classify_refusal(question)
    assert domain is not None, f"the `{alternative}` case stopped escalating — a real gap"
    assert domain.name == "emergency"
    assert domain.template == refusals.EMERGENCY


@pytest.mark.parametrize(
    "question",
    [
        "My friend collapsed with heat stroke, what do I do?",
        "I think I'm having heat stroke right now.",
        "I got sun stroke yesterday.",
    ],
)
def test_the_cases_the_exertional_screen_cannot_hold(question: str) -> None:
    """The measurement the #110 decision rests on, pinned so it cannot rot silently.

    If ``owner_reports_emergency`` is ever widened to cover these, the docstring's reason
    for keeping heat stroke in ``emergency`` expires and this test says so out loud.
    """
    assert red_flags.owner_reports_emergency(question) is False


def test_the_learning_question_about_heat_stroke_is_still_over_refused() -> None:
    """The stated COST of #110's decision, pinned so it is visible rather than assumed.

    ``exertional_emergency`` reads this correctly as asking-to-learn. It never gets asked,
    because ``emergency`` is checked first and its pattern has no attribution test — which
    is the same property that lets it hold the third-party and gerund cases above. A known
    over-refusal, not an oversight: closing it means widening ``owner_reports_emergency``
    to third-party reports, which is its own diff. When that lands, this test is what says
    so out loud instead of the behaviour changing quietly.
    """
    question = "What are the signs of heat stroke?"
    domain = refusals.classify_refusal(question)
    assert domain is not None
    assert domain.name == "emergency"
    assert red_flags.owner_reports_emergency(question) is False


def test_owner_reported_heat_stroke_is_refused_by_the_first_domain_that_hits() -> None:
    """Both mechanisms hold this one; ``emergency`` is checked first, so it wins the name.

    Same template either way. Pinned because the obvious reading of #106 is that this
    question belongs to ``exertional_emergency``, and it does not.
    """
    domain = refusals.classify_refusal("I got heat stroke on my run yesterday.")
    assert domain is not None
    assert domain.name == "emergency"
    assert domain.template == refusals.EMERGENCY
    assert red_flags.owner_reports_emergency("I got heat stroke on my run yesterday.") is True
