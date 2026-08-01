"""#99 · the validator refusing answers it should accept — and still refusing the rest.

``tests/grounding_eval`` measured, over two paid arms on 2026-08-01, that ~80% of the
answers this product generated and never shipped failed on grade-calibration WORDING, not
on missing evidence. Three of those causes were the validator being wrong. Every sentence
in the "was a false positive" half below is copied from an arm's own failure log, so this
file is a record of measured waste rather than of imagined cases.

The other half is the part that matters more: each widening is pinned on BOTH sides, and
the "must still fail" cases are the exact shapes the widening could have opened —
a judgement dressed as a report, a population claim laundered through the owner's number,
an advice sentence wearing a reporting verb. A validator that stopped catching those
would be a worse defect than the one this fixes.
"""

from __future__ import annotations

from tests.insights._ids import CONTESTED_ID, ESTABLISHED_ID, PROBABLE_ID

from healthee.insights.answer_text import sentence_units
from healthee.insights.validator import validate

_ESTABLISHED = ESTABLISHED_ID
_PROBABLE = PROBABLE_ID
_CONTESTED = CONTESTED_ID


# ── 1 · "probably" is a hedge ────────────────────────────────────────────────


def test_probably_hedges_a_probable_claim() -> None:
    """From an arm's log: rejected for having no hedge, while saying 'probably'."""
    result = validate(
        "You should probably take it easy today, though the lack of historical data "
        f"prevents a highly confident call [{_PROBABLE}]."
    )
    assert result.ok is True, result.issues


def test_probable_as_an_adjective_hedges_too() -> None:
    result = validate(
        "Because your wake time is anchored at 06:30, shifting your bedtime earlier is a "
        f"probable method to reduce the debt [{_PROBABLE}]."
    )
    assert result.ok is True, result.issues


def test_participle_forms_of_existing_hedges_are_hedges() -> None:
    """`suggests?` never matched 'suggesting'; `tends?` never matched 'tending'."""
    assert (
        validate(f"An illness signal is flagged, suggesting you keep today light [{_PROBABLE}].").ok
        is True
    )
    assert validate(f"Your load appearing high tends to precede a dip [{_PROBABLE}].").ok is True


def test_frequency_hedges_are_hedges() -> None:
    result = validate(
        f"An illness flag usually indicates a need for lighter training [{_PROBABLE}]."
    )
    assert result.ok is True, result.issues


def test_a_flat_probable_claim_is_still_blocked() -> None:
    """THE boundary: no hedge word anywhere means the calibration rule still fires."""
    result = validate(f"Caffeine after noon reduces deep sleep and impacts recovery [{_PROBABLE}].")
    assert result.ok is False
    assert any("without a hedge" in i for i in result.issues)


def test_a_contested_claim_is_not_hedged_by_probably() -> None:
    """Contested demands a 'mixed' framing; the widened hedge list must not satisfy it."""
    result = validate(f"Cold exposure probably affects overnight recovery [{_CONTESTED}].")
    assert result.ok is False
    assert any("not framed as debated" in i for i in result.issues)


def test_a_sentence_that_declines_to_claim_is_not_an_overclaim() -> None:
    """From an arm's log: the product refusing to ship its own admission of uncertainty."""
    result = validate(
        "However, the data does not support a confident coaching call because your "
        f"30-day history is completely static [{_PROBABLE}]."
    )
    assert result.ok is True, result.issues


def test_cannot_confidently_verify_is_a_disclaimer() -> None:
    result = validate(
        "Because the underlying metrics show no deviation, we cannot confidently verify "
        f"this illness flag [{_PROBABLE}]."
    )
    assert result.ok is True, result.issues


def test_advice_containing_not_enough_still_needs_its_hedge() -> None:
    """THE boundary: the rule is anchored on epistemic words, not on any negation."""
    result = validate(f"You should not train hard without enough recovery [{_PROBABLE}].")
    assert result.ok is False
    assert any("without a hedge" in i for i in result.issues)


# ── 2 · a heading labels the claims beneath it; it makes none ────────────────


def test_bold_only_line_is_a_heading_not_a_claim() -> None:
    """'**What the data shows**' was an uncited interpretive sentence, on the word 'shows'."""
    answer = "**What the data shows**\n\nYour RHR averaged 55.1 bpm last week."
    assert validate(answer).ok is True


def test_atx_heading_is_a_heading_not_a_claim() -> None:
    answer = "## What the data shows\n\nYour RHR averaged 55.1 bpm last week."
    assert validate(answer).ok is True


def test_a_bold_lead_in_followed_by_prose_is_still_a_sentence() -> None:
    """THE boundary: bold at the front of a line that keeps talking is not a heading."""
    result = validate("**Physiology:** Your low HRV is likely due to accumulated load.")
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_a_heading_that_asserts_is_still_a_claim() -> None:
    """THE boundary: the exemption is for LABELS, not for claims typed after a `**`.

    ``test_validator_hardening`` pins the same line for an ATX heading; this pins it for
    the bold-line shape the heading rule newly recognises, so the widening cannot be
    walked through by changing the markdown.
    """
    result = validate("**Your recovery is low because of sleep debt**\n\nNumbers below.")
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_a_heading_still_faces_banned_tone_and_the_output_guard_units() -> None:
    """Headings are excused from GROUNDING wording only — tone still applies."""
    result = validate("**Your recovery is dangerous**\n\nRHR was 55 bpm.")
    assert result.ok is False
    assert any("Alarmist" in i for i in result.issues)


def test_sentences_stays_flat_so_the_output_guard_sees_headings() -> None:
    units = sentence_units("## Your risk of dying is 22% higher\n\nRHR was 55 bpm.")
    assert units[0].heading is True
    assert units[0].text == "Your risk of dying is 22% higher"


# ── 3 · stating a measurement is not making a claim ──────────────────────────


def test_a_self_comparison_needs_no_research_citation() -> None:
    """From an arm's log — arithmetic on the owner's own data, with no note that grounds it."""
    result = validate(
        "**Architecture:** Your sleep stages (90m Deep, 90m REM) are consistent with your "
        "personal baseline."
    )
    assert result.ok is True, result.issues


def test_reporting_a_measured_pattern_needs_no_citation() -> None:
    result = validate(
        "Over the last two weeks, your logged sleep sessions show a consistent pattern of "
        "6 hours and 20 minutes of actual sleep."
    )
    assert result.ok is True, result.issues


def test_a_qualitative_judgement_is_not_a_report() -> None:
    """THE boundary 1: no number quoted means it is an opinion about the data, not the data."""
    result = validate("Your data shows poor sleep consistency.")
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_a_population_claim_laundered_through_a_number_is_not_a_report() -> None:
    """THE boundary 2: the moment it reaches for the world it is a claim about the world."""
    result = validate("Your VO2max of 32 shows you are 3 years older than your actual age.")
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_advice_wearing_a_reporting_verb_is_not_a_report() -> None:
    """THE boundary 3: one 'should' and the sentence is making an argument, not a report."""
    result = validate(
        f"Your sleep debt of 120 minutes shows you should extend sleep [{_PROBABLE}]."
    )
    assert result.ok is False
    assert any("without a hedge" in i for i in result.issues)


def test_a_report_does_not_excuse_a_fabricated_id() -> None:
    result = validate("Your HRV of 45 ms is consistent with your baseline [not_a_real_note].")
    assert result.ok is False
    assert any("do not exist" in i for i in result.issues)


def test_an_established_cited_report_still_ships() -> None:
    """The exemption must not have made cited descriptive text worse."""
    assert validate(f"Your HRV of 45 ms sits at your 30-day median [{_ESTABLISHED}].").ok is True
