"""Locate the knowledge corpus (``packages/knowledge``), and rank its one grade.

In the dev tree it sits at ``<repo>/packages/knowledge``; the Docker image copies
it to ``/app/packages/knowledge`` and sets ``HEALTHEE_KNOWLEDGE_DIR``. Resolving by
walking up from ``__file__`` breaks in the image (the corpus isn't a parent of the
installed package), so callers must use this helper rather than a fixed
``parents[n]`` offset.

The grade→rank map lives here for a layering reason, explained at
:data:`GRADE_RANK`.
"""

from __future__ import annotations

import os
from pathlib import Path

# ── The ONE grade → numeric rank map (legacy 3/2/1 scale) ────────────────────
# Unified evidence grade → numeric rank. Used for the "grade floor" of a response,
# to order calibration strictness, to gate which findings may cite a note, and to
# decide what may drive an action.
#
# ## Why it lives in `core` and not in `insights/manifest.py` (#88, 2026-08-01)
#
# It used to live in TWO places: `insights/manifest.py::GRADE_RANK` and a private
# `analytics/notes.py::_GRADE_RANK`. They agreed — which is exactly the state the two
# grade FIELDS were in before they started publishing `Myth` as `Established` (#83).
# "They agree today" is not a property, it is a coincidence with a maintenance
# schedule, and seven docs meanwhile called `insights/manifest.py` the one definition
# while a second copy sat one layer down.
#
# The merge could not simply delete the analytics copy: `insights/` imports
# `analytics/` (5 modules do), never the reverse, so `analytics.notes` importing
# `insights.manifest` would invert the layering — a real MUST in Engineering
# Standards §1, not a preference. Hoisting it *below both* is the move that costs
# nothing: `core.knowledge` is already imported by both readers (each builds its own
# manifest path from `knowledge_dir()`), it depends on nothing, and no layer is
# crossed in either direction.
#
# `insights.manifest` re-exports it under the documented name `GRADE_RANK`, so every
# existing call site and every doc reference stays correct.
GRADE_RANK: dict[str, int] = {
    "Established": 3,
    "Probable": 2,
    "Emerging": 1,
    "Contested": 1,
    "Myth": 0,
    "Refuted": 0,
}


def knowledge_dir() -> Path:
    """Directory holding ``manifest.json`` + the ``notes/`` and ``sports-science/``
    trees. Prefers ``HEALTHEE_KNOWLEDGE_DIR``, then an upward search from this file,
    then the image default."""
    env = os.environ.get("HEALTHEE_KNOWLEDGE_DIR")
    if env:
        return Path(env)
    for parent in Path(__file__).resolve().parents:
        candidate = parent / "packages" / "knowledge"
        if (candidate / "manifest.json").is_file():
            return candidate
    return Path("/app/packages/knowledge")
