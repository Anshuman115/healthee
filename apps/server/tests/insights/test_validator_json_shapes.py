"""The JSON path's shape dispatch — and the bypass it closes.

``validate_json`` used to extract segments for exactly one payload shape (recs) and
return zero segments for anything else. Zero segments means no text, no text means no
citations to check, and ``_run_rules`` returned **ok=True** — so any future JSON surface
that forgot to register its shape would have shipped uncited, unvalidated text through
the "blocking" validator. These tests pin the fail-closed behaviour and the challenges
shape that WP-C3 registered.
"""

from __future__ import annotations

import json

from tests.insights._ids import CONTESTED_ID, ESTABLISHED_ID, PROBABLE_ID

from healthee.insights.validator import validate_json


def _challenge(**overrides) -> str:
    challenge = {
        "title": "Walk a little more",
        "why": f"A modest step increase may support cardiovascular fitness [{ESTABLISHED_ID}].",
        "expected_outcome": f"More daily movement may add up over the window [{ESTABLISHED_ID}].",
        "how_to": "Two 15-minute walks, one after lunch and one after dinner.",
        "category": "activity",
        "difficulty": "standard",
        "metric": "steps_total",
        "comparator": ">=",
        "target_value": 3500,
        "cadence": "daily",
        "window_days": 14,
        "research_note_ids": [ESTABLISHED_ID],
    }
    challenge.update(overrides)
    return json.dumps({"challenges": [challenge]})


def test_an_unknown_payload_shape_fails_closed() -> None:
    result = validate_json(json.dumps({"widgets": [{"why": "no citation anywhere at all"}]}))
    assert result.ok is False
    assert any("none of the known payload keys" in i for i in result.issues)


def test_a_bare_json_value_is_not_an_answer() -> None:
    assert validate_json('"just a string"').ok is False


def test_an_empty_challenges_array_is_a_valid_honest_answer() -> None:
    assert validate_json(json.dumps({"challenges": []})).ok is True


def test_a_well_formed_challenge_validates() -> None:
    result = validate_json(_challenge())
    assert result.ok is True
    assert ESTABLISHED_ID in result.citations


def test_a_fabricated_id_in_a_challenge_why_is_blocked() -> None:
    result = validate_json(_challenge(why="Steps raise VO2max fast [totally_made_up_note]."))
    assert result.ok is False
    assert any("do not exist" in i for i in result.issues)


def test_an_uncited_interpretive_why_is_blocked() -> None:
    result = validate_json(why_uncited := _challenge(why="This suggests your fitness is low."))
    assert why_uncited  # the payload really did carry the sentence
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_a_personal_finding_alone_cannot_ground_a_challenge() -> None:
    result = validate_json(
        _challenge(why="Steps may lift your recovery [personal_finding:steps_total].")
    )
    assert result.ok is False
    assert any("lacks a citation" in i for i in result.issues)


def test_challenge_wording_must_match_the_cited_grade() -> None:
    """A Contested note stated flatly fails, exactly as it does on the prose path."""
    result = validate_json(
        _challenge(
            why=f"More steps is linked to better recovery [{CONTESTED_ID}].",
            research_note_ids=[CONTESTED_ID],
        )
    )
    assert result.ok is False
    assert any("Contested" in i for i in result.issues)


def test_a_probable_claim_needs_a_hedge_in_a_challenge_too() -> None:
    result = validate_json(
        _challenge(
            why=f"More steps is linked to better recovery [{PROBABLE_ID}].",
            research_note_ids=[PROBABLE_ID],
        )
    )
    assert result.ok is False
    assert any("without a hedge" in i for i in result.issues)


def test_the_directive_fields_are_not_required_to_carry_citations() -> None:
    """`title`/`how_to` are directives grounded at the challenge level, like a rec's
    `action` — an imperative cannot be grade-calibrated without absurdity."""
    result = validate_json(
        _challenge(
            title="Walk more each day",
            how_to="Aim for a walk after lunch; you should keep it brisk.",
        )
    )
    assert result.ok is True
