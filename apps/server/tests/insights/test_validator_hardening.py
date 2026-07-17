"""H1 + #24 · the validator's blind spots — verbs, markdown, brackets, truncation.

Each test reproduces a way an ungrounded interpretive claim could ship: an advice verb
the interpretive regex could not see, a claim hidden in markdown structure the sentence
splitter dropped, a citation that silently parsed to nothing, or a truncated answer that
validated clean by containing nothing checkable.

Just as important here is the false-positive boundary: an over-eager validator fires the
honest fallback on good answers, which degrades the product a different way. Every
widening below is pinned on BOTH sides.
"""

from __future__ import annotations

import json

from tests.insights._ids import ESTABLISHED_ID, PROBABLE_ID

from healthee.insights.validator import extract_citations, validate, validate_json

_ESTABLISHED = ESTABLISHED_ID
_PROBABLE = PROBABLE_ID


# ── H1 · interpretive verbs the validator could not see ──────────────────────


def test_should_advice_without_citation_is_blocked() -> None:
    result = validate("You should sleep 8 hours to fix your recovery.")
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_aim_for_advice_without_citation_is_blocked() -> None:
    result = validate("Aim for 8 hours in bed tonight.")
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_shows_claim_without_citation_is_blocked() -> None:
    result = validate("Your data shows your recovery is being held back by late caffeine.")
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_cited_advice_using_the_new_verbs_passes() -> None:
    """THE false-positive boundary: honest, cited advice using should/aim for/shows must ship."""
    assert validate(f"You should aim for 7-9 hours in bed [{_ESTABLISHED}].").ok is True
    assert validate(f"Research shows consistent timing supports sleep [{_ESTABLISHED}].").ok is True


def test_new_verbs_still_respect_the_honest_escape() -> None:
    result = validate("You should try an earlier bedtime, though no strong evidence in our base.")
    assert result.ok is True


def test_new_verbs_still_respect_grade_calibration() -> None:
    """A Probable-graded 'shows' claim must still be hedged — the verbs join the same rules."""
    flat = validate(f"Your cardio load shows overtraining [{_PROBABLE}].")
    assert flat.ok is False
    assert any("Probable" in i for i in flat.issues)


def test_descriptive_sentence_with_new_verbs_absent_still_needs_no_citation() -> None:
    assert validate("Your resting heart rate on 2026-07-14 was 55 bpm.").ok is True


# ── H1 · markdown structure was skipped entirely ─────────────────────────────
# `_sentences` dropped every line starting with # | or >, so an LLM answering in a
# table or a blockquote bypassed the whole contract.


def test_interpretive_claim_inside_a_markdown_table_is_blocked() -> None:
    text = (
        "Here is your week.\n\n"
        "| Metric | Reading | What it means |\n"
        "|---|---|---|\n"
        "| HRV | 42 ms | This suggests your recovery is impaired. |\n"
    )
    result = validate(text)
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_fabricated_citation_inside_a_markdown_table_is_blocked() -> None:
    text = "| HRV | 42 ms | Low HRV may reflect fatigue [not_a_real_note]. |\n"
    result = validate(text)
    assert result.ok is False
    assert any("do not exist" in i for i in result.issues)


def test_interpretive_claim_inside_a_blockquote_is_blocked() -> None:
    result = validate("> Your low HRV suggests you are overtraining.")
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_interpretive_claim_in_a_heading_is_blocked() -> None:
    result = validate("## Your recovery is low because of sleep debt\n\nNumbers below.")
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_cited_heading_passes() -> None:
    text = f"## Your recovery may be limited by sleep debt [{_ESTABLISHED}]\n\nNumbers below."
    assert validate(text).ok is True


def test_well_cited_markdown_table_passes() -> None:
    """False-positive boundary for tables: a properly cited table must still ship."""
    text = (
        "Here is your week.\n\n"
        "| Metric | Reading | What it means |\n"
        "|---|---|---|\n"
        f"| HRV | 42 ms | Lower HRV may reflect fatigue [{_ESTABLISHED}]. |\n"
        "| Steps | 8,200 | Above your 30-day median. |\n"
    )
    assert validate(text).ok is True


def test_table_separator_and_empty_cells_do_not_false_trip() -> None:
    assert validate("| Metric | Reading |\n|:---|---:|\n| RHR | 55 bpm |\n").ok is True


def test_wrapped_prose_keeps_its_citation_on_the_next_line() -> None:
    """False-positive boundary: LLMs hard-wrap prose — a wrapped sentence is ONE sentence."""
    text = "Your lower HRV this week may reflect accumulated fatigue\nrather than illness "
    text += f"[{_ESTABLISHED}]."
    assert validate(text).ok is True


def test_wrapped_blockquote_keeps_its_citation_on_the_next_line() -> None:
    text = f"> Your lower HRV may reflect accumulated\n> fatigue [{_ESTABLISHED}]."
    assert validate(text).ok is True


# ── #24.1 · mixed-bracket citations mis-parsed ───────────────────────────────
# `[personal_finding:x, note_id]` matched neither regex cleanly: the note id was
# dropped (a real citation silently parsing to nothing) and the finding name came
# back as the garbage string "x, note_id".


def test_mixed_bracket_extracts_both_the_finding_and_the_note_id() -> None:
    ids, personal = extract_citations(f"[personal_finding:hrv_sleep_avg, {_ESTABLISHED}]")
    assert ids == {_ESTABLISHED}
    assert personal == {"hrv_sleep_avg"}


def test_mixed_bracket_extracts_both_in_either_order() -> None:
    ids, personal = extract_citations(f"[{_ESTABLISHED}, personal_finding:hrv_sleep_avg]")
    assert ids == {_ESTABLISHED}
    assert personal == {"hrv_sleep_avg"}


def test_mixed_bracket_citation_grounds_an_interpretive_sentence() -> None:
    text = (
        "Your lower-HRV nights may precede a higher next-day RHR "
        f"[personal_finding:hrv_sleep_avg, {_ESTABLISHED}]."
    )
    result = validate(text)
    assert result.ok is True
    assert _ESTABLISHED in result.citations
    assert "hrv_sleep_avg" in result.personal_findings
    assert "hrv_sleep_avg" not in result.citations


def test_mixed_bracket_fabricated_id_is_blocked() -> None:
    """The real hole: a fabricated id hid inside a mixed bracket on a descriptive sentence."""
    result = validate("Your RHR was 55 bpm [personal_finding:rhr_trend, not_a_real_note].")
    assert result.ok is False
    assert any("do not exist" in i for i in result.issues)


def test_mixed_bracket_does_not_smuggle_a_bogus_finding_name() -> None:
    _, personal = extract_citations(f"[personal_finding:rhr_trend, {_ESTABLISHED}]")
    assert personal == {"rhr_trend"}
    assert not any("," in name for name in personal)


# ── #24.2 · a truncated answer is not a validated answer ─────────────────────


def test_truncated_answer_is_blocked() -> None:
    """Cut off at max_tokens: nothing checkable completed, so nothing was checked."""
    result = validate("Your HRV has been trending down over the past week, which may")
    assert result.ok is False
    assert any("truncated" in i for i in result.issues)


def test_answer_truncated_mid_citation_is_blocked() -> None:
    result = validate("Lower HRV may reflect fatigue [sleep_")
    assert result.ok is False
    assert any("truncated" in i for i in result.issues)


def test_empty_answer_is_blocked() -> None:
    for text in ("", "   \n  "):
        result = validate(text)
        assert result.ok is False
        assert any("empty" in i for i in result.issues)


def test_complete_answers_are_not_flagged_as_truncated() -> None:
    """False-positive boundary for truncation — every legitimate ending must pass."""
    for text in (
        "Your resting heart rate was 55 bpm.",
        "Was your sleep disrupted?",
        f"Lower HRV may reflect fatigue [{_ESTABLISHED}].",
        "| Metric | Reading |\n|---|---|\n| RHR | 55 bpm |",
        "Your steps are on track (8,200 today).",
        f'You should aim for 7-9 hours [{_ESTABLISHED}]. "Rest" is the goal!',
    ):
        assert validate(text).ok is True, text


def test_truncation_is_not_applied_to_the_json_path() -> None:
    """JSON truncation is already caught by the parser; fields need no terminal punctuation."""
    payload = json.dumps(
        {
            "recommendations": [
                {
                    "action": "Aim for a 30-minute brisk walk today.",
                    "rationale": f"Moderate activity may support recovery [{_ESTABLISHED}].",
                    "expected_effect": "chips away at your weekly MVPA gap",
                    "category": "activity",
                    "evidence_grade": 3,
                    "research_note_ids": [_ESTABLISHED],
                    "signal_source": "mvpa_gap",
                }
            ]
        }
    )
    assert validate_json(payload).ok is True
