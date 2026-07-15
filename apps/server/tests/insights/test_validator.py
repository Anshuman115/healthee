"""The blocking validator — the crux of the honesty contract.

Uses the REAL manifest (so a fabricated id is genuinely unknown). Proves:
fabricated citations are blocked, real ones pass, uncited interpretation is blocked,
grade-calibrated phrasing is enforced, and personal findings are accepted yet kept
distinct from population note ids.
"""

from __future__ import annotations

from healthee.insights.validator import extract_citations, validate

# Real manifest ids at known grades (confirmed in the generated manifest):
_ESTABLISHED = "hrv_recovery_marker"
_PROBABLE = "cardio_load_trimp"
_CONTESTED = "training_load_acwr"


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
