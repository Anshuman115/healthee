"""Real, current note ids per evidence grade, resolved from the manifest.

Reconciliation renames and consolidates notes, so tests must NOT hardcode a
specific citable id (it may become an alias). Anything that needs "a real
Established / Probable / Contested note to cite" uses these, resolved live.
"""

from __future__ import annotations

from healthee.insights import manifest as _manifest


def _first_of_grade(grade: str) -> str:
    for note_id in sorted(_manifest.note_ids()):
        if _manifest.grade_of(note_id) == grade:
            return note_id
    raise AssertionError(f"no note of grade {grade!r} in the manifest")


def _first_mortality_note() -> str:
    """A real note whose subject IS population mortality evidence.

    The output guardrails must block a *personal* death-risk projection while letting
    honest population science through, so the false-positive tests need a genuine
    mortality note to cite. Resolved live for the same reason as the grades above:
    reconciliation folded `vo2max_fitness_mortality` into `vo2max`, and a hardcoded id
    would have rotted silently.
    """
    for note_id in sorted(_manifest.note_ids()):
        if note_id.endswith("_mortality"):
            return note_id
    raise AssertionError("no mortality note in the manifest")


ESTABLISHED_ID = _first_of_grade("Established")
PROBABLE_ID = _first_of_grade("Probable")
CONTESTED_ID = _first_of_grade("Contested")
MORTALITY_ID = _first_mortality_note()
