"""C2 · a refusal template must BE the answer, never a substring of it.

The bypass this pins: ``is_refusal`` substring-matched, so ANY answer merely
*containing* a hard-refusal template skipped every citation, tone, calibration and
certainty check — a total validation bypass of the honesty contract (ARCHITECTURE,
"The honesty contract" #1). It was reachable organically, not just adversarially:
refusal templates sit in coach conversation history for a model to echo.

The other half of the contract is pinned here too: a REAL refusal must still bypass
citation checks — that is INTELLIGENCE §5.5 by design, not a hole.
"""

from __future__ import annotations

from tests.insights._ids import ESTABLISHED_ID

from healthee.insights import refusals
from healthee.insights.validator import is_refusal, validate

_ESTABLISHED = ESTABLISHED_ID


# ── C2 · a refusal template must BE the answer, never a substring of it ───────
# The bypass: `is_refusal` substring-matched, so ANY answer containing a template
# skipped every citation/tone/certainty check. Refusal templates live in coach
# conversation history, so a model can echo one into an ungrounded answer.


def test_embedded_refusal_template_does_not_bypass_validation() -> None:
    """The reviewer's exact shape: confident, uncited prose wrapped around a template."""
    text = (
        "Your HRV definitely indicates overtraining, so train harder to push through it. "
        f"{refusals.MEDICATION} "
        "This is caused by your low sleep and always resolves within a week."
    )
    result = validate(text)
    assert result.ok is False
    assert any("certainty" in i for i in result.issues)
    assert any("lacks a citation" in i for i in result.issues)


def test_refusal_template_prefixed_with_prose_is_not_a_refusal() -> None:
    """The gate itself: prose + a template is not a hard refusal, so validation RUNS.

    This text happens to carry no ungrounded interpretive claim, so the rules then pass
    it — that is correct. What must never happen is the rules being SKIPPED.
    """
    assert is_refusal(f"Sure, here's my take. {refusals.DIAGNOSIS}") is False


def test_refusal_template_suffixed_with_uncited_claim_does_not_bypass() -> None:
    result = validate(f"{refusals.EMERGENCY} Separately, your low HRV suggests overtraining.")
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_every_real_refusal_template_still_passes() -> None:
    """§5.5 by design: a hard refusal is safe by construction and bypasses citation checks."""
    for template in refusals.REFUSAL_TEMPLATES:
        assert is_refusal(template) is True
        assert validate(template).ok is True


def test_refusal_tolerates_surrounding_whitespace_and_wrapping() -> None:
    """A real refusal echoed with padding / re-wrapped newlines is still a refusal."""
    assert is_refusal(f"\n  {refusals.MENTAL_HEALTH}  \n") is True
    assert is_refusal(refusals.MENTAL_HEALTH.replace(" ", "\n  ")) is True


def test_refusal_tolerates_trailing_markdown_emphasis_and_quotes() -> None:
    assert is_refusal(f'"{refusals.DIAGNOSIS}"') is True
    assert is_refusal(f"**{refusals.MEDICATION}**") is True


def test_near_miss_refusal_is_not_treated_as_one() -> None:
    """A template with an extra claim spliced INSIDE it is not the template."""
    tampered = refusals.MEDICATION.replace(
        "belong with your physician", "belong with your physician, but your data suggests a change"
    )
    assert is_refusal(tampered) is False
