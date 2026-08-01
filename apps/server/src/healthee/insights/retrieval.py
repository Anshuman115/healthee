"""Manifest-ranked retrieval — the fix for legacy's dump-all context (hole #3).

Legacy stuffed EVERY ★★★ note in full on every call (``_research_notes_md``,
INTELLIGENCE §5.1) — unbounded, and it grew with the corpus. Here we rank the
manifest by relevance to the question + the metrics in play and embed only the
**top-N full note bodies**, listing the remainder as one-line summaries. The note
COUNT is bounded at any corpus size; the token count is not — a note runs 1.2k–8.8k
tokens, so the same "top 6" measured between 18k and 41k tokens across our surfaces
(task #23). That is why *which* six notes rank matters for cost as well as grounding:
this section is 65–83% of every prompt the product sends.
"""

from __future__ import annotations

import re
from functools import lru_cache

from healthee.insights.manifest import GRADE_RANK, ManifestNote, all_notes, prompt_body

DEFAULT_TOP_N = 6

_DIRECT_ID = 100  # the note's id literally named in the question
_METRIC_HIT = 10  # a metric in play is in the note's applies_to_metrics
_INTERVENTION_HIT = 10
_ALIAS_HIT = 5  # an alias phrase appears in the question
_WORD = re.compile(r"[a-z0-9_]+")


def _tokens(text: str) -> set[str]:
    return set(_WORD.findall(text.lower()))


def _alias_hits(note: ManifestNote, q_text: str) -> int:
    """How many of ``note``'s aliases appear in the question AS WORDS.

    This used to be a bare substring test (``alias.lower() in q_text``), which is not a
    topical signal at all once an alias is short: ``critical_speed`` carries the aliases
    ``W`` and ``D``, so it matched any question containing the letter w or d — i.e. very
    nearly every question in English. Measured (task #23), that note was ranked into the
    top-6 and embedded IN FULL — 6,707 tokens — on **6 of 11** representative surface
    prompts, including "how has my sleep been this week?". A note about running critical
    power was 16% of the daily-action prompt, bought by two letters.

    That is a grounding defect first and a cost defect second: those tokens displaced a
    note that could have grounded the answer, and the coach then spent a whole extra
    round on ``get_knowledge`` fetching the note retrieval should have supplied (each
    round is another ~37k input tokens).

    Word boundaries are the fix and nothing more: an acronym alias still matches its own
    word (``HRV`` in "why is my hrv low"), a phrase alias still matches its phrase, and a
    letter no longer matches the inside of an unrelated word. It does give up matching
    inflections (alias ``sleep`` no longer hits "sleeping"), which is a real but small
    loss — measured across those 11 prompts, every note this rule stopped matching had
    been matched by a substring that was not a topical signal.
    """
    return sum(1 for alias in note.aliases if _alias_re(alias).search(q_text))


@lru_cache(maxsize=1024)
def _alias_re(alias: str) -> re.Pattern[str]:
    """``alias`` as a word-bounded pattern, compiled once (ranking runs over 71 notes)."""
    return re.compile(rf"(?<!\w){re.escape(alias.lower())}(?!\w)")


def _score(note: ManifestNote, q_tokens: set[str], q_text: str, metrics: set[str]) -> int:
    """Relevance of one note to the question + active metrics (higher = better)."""
    score = 0
    if note.id and note.id in q_tokens:
        score += _DIRECT_ID
    score += _METRIC_HIT * len(metrics.intersection(note.applies_to_metrics))
    score += _INTERVENTION_HIT * sum(1 for iv in note.applies_to_interventions if iv in q_tokens)
    score += _ALIAS_HIT * _alias_hits(note, q_text)
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

    Top-N notes appear with their body and grade tag; the rest are one-line
    ``[id] (Grade): summary`` entries so the model knows they exist and are citable
    without paying their full token cost.

    The embedded body is ``prompt_body`` — the note minus its bibliography, which the
    model cannot cite (see that function). ``note_body`` remains the whole note for the
    human-facing reader.
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
        parts.append(f"\n## `[{n.id}]` ({n.grade}) — {n.name}\n{prompt_body(n.id)}")
    if rest:
        parts.append("\n## Other citable notes (summaries only)")
        parts.extend(f"- `[{n.id}]` ({n.grade}): {n.summary}" for n in rest)
    return ("\n".join(parts), [n.id for n in top])
