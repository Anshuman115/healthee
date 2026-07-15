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


ESTABLISHED_ID = _first_of_grade("Established")
PROBABLE_ID = _first_of_grade("Probable")
CONTESTED_ID = _first_of_grade("Contested")
