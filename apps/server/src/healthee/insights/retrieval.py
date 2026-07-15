"""Manifest-ranked retrieval — the fix for legacy's dump-all context (hole #3).

Legacy stuffed EVERY ★★★ note in full on every call (``_research_notes_md``,
INTELLIGENCE §5.1) — unbounded, and it grew with the corpus. Here we rank the
manifest by relevance to the question + the metrics in play and embed only the
**top-N full note bodies**, listing the remainder as one-line summaries. Token
cost is bounded at any corpus size; the model still knows every citable id exists.
"""

from __future__ import annotations

import re

from healthee.insights.manifest import GRADE_RANK, ManifestNote, all_notes, note_body

DEFAULT_TOP_N = 6

_DIRECT_ID = 100  # the note's id literally named in the question
_METRIC_HIT = 10  # a metric in play is in the note's applies_to_metrics
_INTERVENTION_HIT = 10
_ALIAS_HIT = 5  # an alias phrase appears in the question
_WORD = re.compile(r"[a-z0-9_]+")


def _tokens(text: str) -> set[str]:
    return set(_WORD.findall(text.lower()))


def _score(note: ManifestNote, q_tokens: set[str], q_text: str, metrics: set[str]) -> int:
    """Relevance of one note to the question + active metrics (higher = better)."""
    score = 0
    if note.id and note.id in q_tokens:
        score += _DIRECT_ID
    score += _METRIC_HIT * len(metrics.intersection(note.applies_to_metrics))
    score += _INTERVENTION_HIT * sum(1 for iv in note.applies_to_interventions if iv in q_tokens)
    score += _ALIAS_HIT * sum(1 for alias in note.aliases if alias.lower() in q_text)
    return score


def rank_notes(question: str, metrics: list[str] | None = None) -> list[ManifestNote]:
    """All notes, most relevant first; ties break toward stronger evidence grades.

    A pure reorder (legacy semantics) — bounding to top-N happens in
    ``evidence_section``. Deterministic: equal scores fall back to grade then id.
    """
    q_text = question.lower()
    q_tokens = _tokens(question)
    metric_set = set(metrics or [])
    return sorted(
        all_notes(),
        key=lambda n: (
            -_score(n, q_tokens, q_text, metric_set),
            -GRADE_RANK.get(n.grade, 0),
            n.id,
        ),
    )


def evidence_section(
    question: str, metrics: list[str] | None = None, *, top_n: int = DEFAULT_TOP_N
) -> tuple[str, list[str]]:
    """The EVIDENCE NOTES markdown + the ids embedded in full.

    Top-N notes appear with their full body and grade tag; the rest are one-line
    ``[id] (Grade): summary`` entries so the model knows they exist and are citable
    without paying their full token cost.
    """
    ranked = rank_notes(question, metrics)
    if not ranked:
        return ("", [])
    top, rest = ranked[:top_n], ranked[top_n:]
    parts = [
        "# EVIDENCE NOTES",
        "Cite ONLY by id: `[note_id]`. Each note shows its evidence grade — match "
        "your wording to it. If no note covers a claim, write "
        "`No strong evidence in our base for this.`",
    ]
    for n in top:
        parts.append(f"\n## `[{n.id}]` ({n.grade}) — {n.name}\n{note_body(n.id)}")
    if rest:
        parts.append("\n## Other citable notes (summaries only)")
        parts.extend(f"- `[{n.id}]` ({n.grade}): {n.summary}" for n in rest)
    return ("\n".join(parts), [n.id for n in top])
