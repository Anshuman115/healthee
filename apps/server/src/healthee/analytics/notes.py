"""Research-note matching for findings — v2-native, manifest-backed.

Findings and anomalies carry ``research_note_ids`` so the validity caveats travel
with the pattern. Legacy analytics resolved these through ``healthee.research``
(re-parsing the corpus tree on every call). v2 reads the generated retrieval
index ``packages/knowledge/manifest.json`` (WP4) instead: cached, deterministic,
and the same source the insights layer will rank against.

Matching preserves the legacy semantics of ``_matching_notes`` /
``research.for_metric``: a note applies when a metric is in its
``applies_to_metrics`` OR an intervention is in its ``applies_to_interventions``
OR its id begins with ``<intervention>_`` (e.g. ``alcohol_sleep`` for
``alcohol``). "★★★ only" becomes ``grade == "Established"`` under the unified
grade scale (legacy 3 → Established).
"""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

from healthee.core.logging import get_logger

log = get_logger(__name__)

# manifest.json lives at repo-root/packages/knowledge; this file sits at
# apps/server/src/healthee/analytics/notes.py → parents[5] is the repo root.
_MANIFEST_PATH = Path(__file__).resolve().parents[5] / "packages" / "knowledge" / "manifest.json"

# Unified evidence grade → legacy numeric rank, for the min-grade gate.
_GRADE_RANK: dict[str, int] = {
    "Established": 3,
    "Probable": 2,
    "Emerging": 1,
    "Contested": 1,
    "Myth": 0,
    "Refuted": 0,
}


@lru_cache(maxsize=1)
def _records() -> tuple[dict, ...]:
    """Load and cache the manifest records; empty (logged) if the file is absent.

    A missing manifest is a degraded state, not a crash: findings are still
    computed, just without citations. It is surfaced as a warning through the one
    logging path rather than swallowed silently (standards §Errors).
    """
    try:
        raw = _MANIFEST_PATH.read_text(encoding="utf-8")
    except OSError as exc:
        log.warning("knowledge manifest unreadable (%s) — findings will be uncited", exc)
        return ()
    return tuple(json.loads(raw).get("records", []))


def notes_for(
    metrics: list[str],
    interventions: list[str] | None = None,
    *,
    min_grade: int = 3,
) -> list[str]:
    """Sorted note ids applying to any given metric or intervention at ≥ min_grade.

    Verbatim behaviour of legacy ``_matching_notes`` (default ``min_grade=3`` =
    Established-only), just reading the manifest instead of the corpus tree.
    """
    interventions = interventions or []
    out: set[str] = set()
    for rec in _records():
        if _GRADE_RANK.get(rec.get("grade", ""), 0) < min_grade:
            continue
        note_id = rec.get("id", "")
        applies_metrics = rec.get("applies_to_metrics", [])
        applies_interventions = rec.get("applies_to_interventions", [])
        if any(m in applies_metrics for m in metrics):
            out.add(note_id)
        for e in interventions:
            if e in applies_interventions or note_id == e or note_id.startswith(e + "_"):
                out.add(note_id)
    return sorted(out)
