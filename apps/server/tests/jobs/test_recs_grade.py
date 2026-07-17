"""A rec's evidence grade must be PROVABLE from the manifest, never merely claimed.

``_rec_ok`` used to check only that the model's *self-declared* ``evidence_grade``
was 2 or 3 — it was never compared against ``manifest.grade_of()`` of the notes the
rec actually cites. So a rec citing a Contested note could self-declare 3 and reach
the user labelled *Established*: the honesty contract's rule 2 ("confidence is part
of the answer") broken by the one field the prose validator does not police.

These tests pin the resolution rule from both sides:
  * overclaiming never ships (the grade is corrected down to what the notes prove);
  * evidence weaker than Probable never ships at all (§5.6's grade>=2 whitelist,
    now enforced on the PROVABLE floor rather than on the model's claim);
  * an honestly-graded rec still ships, unchanged — the false-positive boundary. A
    gate that drops every rec ships an empty card daily, which is its own failure.

Ids resolve live from the manifest (``tests.insights._ids``) — reconciliation renames
notes, and a hardcoded id would rot silently.
"""

from __future__ import annotations

import pytest
from tests.insights._ids import CONTESTED_ID, ESTABLISHED_ID, PROBABLE_ID

from healthee.insights import manifest
from healthee.jobs.recs import _parse_and_validate


def _rec(
    note_ids: list[str], declared: int, action: str = "Take a 30-minute brisk walk today."
) -> dict:
    """A structurally valid rec citing ``note_ids`` and declaring ``declared``."""
    return {
        "action": action,
        "rationale": f"Moderate activity may support recovery [{note_ids[0]}].",
        "expected_effect": "chips away at your weekly MVPA gap",
        "category": "activity",
        "evidence_grade": declared,
        "research_note_ids": list(note_ids),
        "signal_source": "mvpa_gap",
    }


def _ship(rec: dict) -> list[dict]:
    clean, _dropped = _parse_and_validate({"recommendations": [rec]})
    return clean


# ── the premise: the fixture ids really are the grades we think ─────────────


def test_fixture_ids_have_the_expected_grades() -> None:
    """Guards the tests below: if these drift, every assertion here is vacuous."""
    assert manifest.grade_of(ESTABLISHED_ID) == "Established"
    assert manifest.grade_of(PROBABLE_ID) == "Probable"
    assert manifest.grade_of(CONTESTED_ID) == "Contested"


# ── overclaiming must not ship as claimed ──────────────────────────────────


def test_probable_note_declared_established_is_corrected_down() -> None:
    """Cites Probable, claims 3 -> ships as 2. The action is fine; only the label lied."""
    shipped = _ship(_rec([PROBABLE_ID], declared=3))
    assert len(shipped) == 1, "an honest rec was thrown away with the dishonest label"
    assert shipped[0]["evidence_grade"] == 2


def test_contested_note_declared_established_is_dropped() -> None:
    """Cites Contested (rank 1), claims 3 -> below the Probable floor -> dropped.

    This is the headline defect: pre-fix this rec shipped, labelled Established.
    """
    assert _ship(_rec([CONTESTED_ID], declared=3)) == []


def test_mixed_citation_takes_the_strictest_cited_note() -> None:
    """[Established, Contested] -> the weakest cited note governs -> dropped.

    Same "strictest grade among cited notes" rule the prose validator already
    applies per sentence (``validator._grade_issue``) — one semantic, not two.
    """
    assert _ship(_rec([ESTABLISHED_ID, CONTESTED_ID], declared=3)) == []


def test_mixed_established_and_probable_ships_at_probable() -> None:
    shipped = _ship(_rec([ESTABLISHED_ID, PROBABLE_ID], declared=3))
    assert len(shipped) == 1
    assert shipped[0]["evidence_grade"] == 2


# ── the false-positive boundary: honest recs still ship ────────────────────


def test_honest_established_rec_ships_unchanged() -> None:
    """The value case. A correctly-graded rec must survive the gate untouched."""
    rec = _rec([ESTABLISHED_ID], declared=3)
    shipped = _ship(rec)
    assert len(shipped) == 1
    assert shipped[0]["evidence_grade"] == 3
    assert shipped[0]["action"] == rec["action"]
    assert shipped[0]["research_note_ids"] == [ESTABLISHED_ID]


def test_honest_probable_rec_ships_unchanged() -> None:
    shipped = _ship(_rec([PROBABLE_ID], declared=2))
    assert len(shipped) == 1
    assert shipped[0]["evidence_grade"] == 2


def test_underclaiming_is_never_inflated() -> None:
    """Cites Established but claims 2 -> ships as 2. We never talk the model UP."""
    shipped = _ship(_rec([ESTABLISHED_ID], declared=2))
    assert len(shipped) == 1
    assert shipped[0]["evidence_grade"] == 2


def test_a_full_batch_of_honest_recs_all_ship() -> None:
    """The over-correction guard: a normal day's payload must not come back empty."""
    payload = {
        "recommendations": [
            _rec([ESTABLISHED_ID], 3, action="Take a 30-minute brisk walk today."),
            _rec([PROBABLE_ID], 2, action="Wind down 30 minutes earlier tonight."),
            _rec([ESTABLISHED_ID], 3, action="Add a 10-minute mobility block."),
        ]
    }
    clean, dropped = _parse_and_validate(payload)
    assert len(clean) == 3
    assert dropped == 0


# ── the pre-existing gate still holds ─────────────────────────────────────


@pytest.mark.parametrize("declared", [0, 1, 4, "3", None])
def test_a_grade_outside_the_shippable_band_is_dropped(declared: object) -> None:
    assert _ship(_rec([ESTABLISHED_ID], declared=declared)) == []  # type: ignore[arg-type]


def test_unknown_note_is_still_dropped() -> None:
    assert _ship(_rec(["not_a_real_note"], declared=3)) == []


def test_an_unrecognized_grade_fails_closed(monkeypatch: pytest.MonkeyPatch) -> None:
    """A citable note whose grade is not in GRADE_RANK must DROP the rec, never ship it.

    Unreachable with today's corpus (every record grades to a known string), which is
    exactly why it is pinned here: a mutation flipping the ``GRADE_RANK.get(..., 0)``
    default to a lenient 3 survived the rest of this file. `_to_note` defaults a missing
    grade to ``""``, and a future note carrying a new or typo'd grade name would rank
    the same way — fail-open would then ship it labelled *Established*, the precise bug
    this module exists to kill. The default is the guard; this is its test.
    """
    monkeypatch.setattr(manifest, "grade_of", lambda _id: "Speculative")
    assert _ship(_rec([ESTABLISHED_ID], declared=3)) == []
