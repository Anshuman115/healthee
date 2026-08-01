"""The blocking validator — the crux of the honesty contract.

Uses the REAL manifest (so a fabricated id is genuinely unknown). Proves:
fabricated citations are blocked, real ones pass, uncited interpretation is blocked,
grade-calibrated phrasing is enforced, and personal findings are accepted yet kept
distinct from population note ids.
"""

from __future__ import annotations

import json

from tests.insights._ids import CONTESTED_ID, ESTABLISHED_ID, PROBABLE_ID, REFUTED_ID

from healthee.insights.validator import extract_citations, validate, validate_json

# Real manifest ids at known grades, resolved live (robust to reconciliation):
_ESTABLISHED = ESTABLISHED_ID
_PROBABLE = PROBABLE_ID
_CONTESTED = CONTESTED_ID
_REFUTED = REFUTED_ID


def _recs_json(**overrides: object) -> str:
    """A well-formed one-rec recs payload; overrides patch a single field."""
    rec = {
        "action": "Aim for a 30-minute brisk walk today.",
        "rationale": f"Consistent moderate activity may support recovery [{_ESTABLISHED}].",
        "expected_effect": "chips away at your weekly MVPA gap",
        "category": "activity",
        "evidence_grade": 3,
        "research_note_ids": [_ESTABLISHED],
        "signal_source": "mvpa_gap",
    }
    rec.update(overrides)
    return json.dumps({"recommendations": [rec]})


def test_json_valid_recs_with_real_id_passes() -> None:
    result = validate_json(_recs_json())
    assert result.ok is True
    assert _ESTABLISHED in result.citations
    assert result.grade_floor == "Established"


def test_json_fabricated_inline_citation_in_rationale_fails() -> None:
    payload = _recs_json(
        rationale="Intervals raise VO2max quickly [totally_made_up_note].",
        research_note_ids=["totally_made_up_note"],
    )
    result = validate_json(payload)
    assert result.ok is False
    assert any("do not exist" in i for i in result.issues)


def test_json_malformed_is_blocked() -> None:
    result = validate_json("{not valid json,,,")
    assert result.ok is False
    assert any("not valid JSON" in i for i in result.issues)


def test_json_interpretive_looking_keys_do_not_false_trip() -> None:
    # KEYS and constrained-vocab values contain interpretive/causal words ("suggests",
    # "is caused by", "always") but the rationale is properly cited → must PASS,
    # proving structure/keys are not validated as prose.
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
                    "signal_source": "this always suggests it is caused by low steps",
                }
            ]
        }
    )
    assert validate_json(payload).ok is True


def test_json_interpretive_rationale_without_citation_fails() -> None:
    payload = _recs_json(
        rationale="This suggests your recovery is impaired and getting worse.",
        research_note_ids=[_ESTABLISHED],
    )
    result = validate_json(payload)
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_fabricated_citation_is_blocked() -> None:
    result = validate("This suggests your recovery improved [not_a_real_note].")
    assert result.ok is False
    assert any("do not exist" in i for i in result.issues)


def test_real_citation_passes() -> None:
    result = validate(f"Your RHR was 55 bpm. Higher HRV may reflect recovery [{_ESTABLISHED}].")
    assert result.ok is True
    assert _ESTABLISHED in result.citations
    assert result.grade_floor == "Established"


def test_interpretive_sentence_without_citation_is_blocked() -> None:
    result = validate("This suggests your sleep is impaired and getting worse.")
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_honest_escape_phrase_passes() -> None:
    result = validate("This might matter, but no strong evidence in our base for this.")
    assert result.ok is True


def test_descriptive_sentence_needs_no_citation() -> None:
    assert validate("Your resting heart rate on 2026-07-14 was 55 bpm.").ok is True


def test_contested_claim_must_be_framed_as_debated() -> None:
    plain = validate(f"Your ACWR predicts injury risk [{_CONTESTED}].")
    assert plain.ok is False
    assert any("Contested" in i for i in plain.issues)
    hedged = validate(f"The science is mixed on whether ACWR predicts injury [{_CONTESTED}].")
    assert hedged.ok is True


def test_refuted_claim_must_be_framed_as_a_correction_not_hedged() -> None:
    """A Myth/Refuted note demands a CORRECTION, and a hedge is not one (#91).

    This is the whole point of the branch. Before #91, `Myth` and `Refuted` ranked 0
    and fell through the `strictest <= 1` branch shared with `Emerging`, so the word
    "may" — or "limited evidence" — satisfied the validator for a debunked claim.
    Hedging a myth is the wrong framing twice over: it softens a correction the
    evidence supports flatly, and it lends the claim the shape of thin-but-real
    evidence.
    """
    flat = validate(f"You should drink eight glasses of water a day [{_REFUTED}].")
    assert flat.ok is False
    assert any("Myth/Refuted" in i for i in flat.issues)

    # A HEDGE must not satisfy it — this is the exact bug, not merely a missing rule.
    hedged = validate(f"Eight glasses a day may not be necessary [{_REFUTED}].")
    assert hedged.ok is False
    assert any("Myth/Refuted" in i for i in hedged.issues)

    # Nor may an Emerging-style uncertainty flag, which used to be what it accepted.
    flagged = validate(f"There is limited evidence you should drink eight glasses [{_REFUTED}].")
    assert flagged.ok is False

    corrected = validate(
        f"Despite the popular belief, there is no scientific evidence for the "
        f"eight-glasses rule in healthy adults [{_REFUTED}]."
    )
    assert corrected.ok is True


def test_refuted_grade_is_the_answers_evidence_floor() -> None:
    """A refuted citation drives `grade_floor`, so callers can see what it rests on."""
    result = validate(
        f"That is a common misconception with no scientific basis [{_REFUTED}], and "
        f"consistent activity may support recovery [{_PROBABLE}]."
    )
    assert result.ok is True
    assert result.grade_floor == "Myth"


def test_probable_claim_must_be_hedged() -> None:
    flat = validate(f"Your cardio load predicts overtraining [{_PROBABLE}].")
    assert flat.ok is False
    assert any("Probable" in i for i in flat.issues)
    hedged = validate(f"Your cardio load may indicate overtraining [{_PROBABLE}].")
    assert hedged.ok is True


def test_banned_certainty_is_blocked() -> None:
    result = validate(f"Low HRV is caused by poor sleep [{_ESTABLISHED}].")
    assert result.ok is False
    assert any("certainty" in i for i in result.issues)


def test_personal_finding_is_accepted_and_distinguished() -> None:
    text = (
        "Your lower-HRV nights precede higher next-day RHR [personal_finding:hrv_sleep_avg], "
        f"consistent with autonomic recovery [{_ESTABLISHED}]."
    )
    result = validate(text)
    assert result.ok is True
    assert "hrv_sleep_avg" in result.personal_findings
    assert "hrv_sleep_avg" not in result.citations  # a finding is NOT a note id
    assert _ESTABLISHED in result.citations


def test_personal_finding_alone_does_not_ground_an_interpretation() -> None:
    result = validate(
        "Your low HRV likely explains the RHR spike [personal_finding:hrv_sleep_avg]."
    )
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_extract_citations_splits_notes_and_findings() -> None:
    ids, personal = extract_citations("a [alcohol_sleep, caffeine_sleep] b [personal_finding:rhr]")
    assert ids == {"alcohol_sleep", "caffeine_sleep"}
    assert personal == {"rhr"}
