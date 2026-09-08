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

from healthee.core.knowledge import GRADE_RANK, knowledge_dir
from healthee.core.logging import get_logger

log = get_logger(__name__)

_MANIFEST_PATH = knowledge_dir() / "manifest.json"


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

    MEMOISED on its arguments, because ``correlate`` calls it once per finding — 774
    times a night for an owner — and the answer depends on nothing but the manifest,
    which :func:`_records` already caches for the process's whole life. So this adds no
    staleness that was not already there: the two caches expire together, on restart.
    Profiled at 0.055 s of the step's 1.044 s before (`PERF_AUDIT.md` B3).

    A fresh ``list`` is returned every call. The cache holds a tuple, so a caller that
    mutates what it gets back cannot reach into the cache and change what the next
    caller sees — the failure that makes a shared mutable cache worse than no cache.
    """
    return list(_notes_for(tuple(metrics), tuple(interventions or ()), min_grade))


# Bounded by the metric registry, not by traffic: the key is a metric list, and
# `CORRELATED_METRICS` is 24 long, so the reachable key space is a few hundred pairs.
_NOTES_CACHE_SIZE = 2048


@lru_cache(maxsize=_NOTES_CACHE_SIZE)
def _notes_for(
    metrics: tuple[str, ...],
    interventions: tuple[str, ...],
    min_grade: int,
) -> tuple[str, ...]:
    """:func:`notes_for`'s body, keyed on hashable arguments. Never called directly."""
    out: set[str] = set()
    for rec in _records():
        if GRADE_RANK.get(rec.get("grade", ""), 0) < min_grade:
            continue
        note_id = rec.get("id", "")
        applies_metrics = rec.get("applies_to_metrics", [])
        applies_interventions = rec.get("applies_to_interventions", [])
        if any(m in applies_metrics for m in metrics):
            out.add(note_id)
        for e in interventions:
            if e in applies_interventions or note_id == e or note_id.startswith(e + "_"):
                out.add(note_id)
    return tuple(sorted(out))
