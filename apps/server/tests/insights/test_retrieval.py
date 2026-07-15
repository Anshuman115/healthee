"""Manifest-ranked retrieval — the fix for legacy dump-all (hole #3).

Proves a metric's own notes rank to the top and that the full-note count is
bounded (top-N), with the remainder present only as one-line summaries.
"""

from __future__ import annotations

from healthee.insights.retrieval import evidence_section, rank_notes


def test_metric_notes_rank_to_the_top() -> None:
    ranked = rank_notes("how are my steps", metrics=["steps_total"])
    top_ids = {n.id for n in ranked[:3]}
    # Every note that applies to steps_total should be among the highest-ranked.
    assert {"steps_mortality", "exercise_mortality"} & top_ids


def test_direct_id_mention_ranks_first() -> None:
    ranked = rank_notes("tell me about alcohol_sleep")
    assert ranked[0].id == "alcohol_sleep"


def test_evidence_section_bounds_full_notes() -> None:
    md, top_ids = evidence_section("steps and activity", metrics=["steps_total"], top_n=3)
    assert len(top_ids) == 3  # only N full notes embedded
    assert md.count("\n## `[") == 3  # exactly N full-note headers
    assert "Other citable notes (summaries only)" in md  # the rest are summaries


def test_evidence_section_is_empty_without_a_corpus_match_still_lists_notes() -> None:
    md, top_ids = evidence_section("anything", metrics=[])
    assert top_ids  # notes are always available to cite (ranker only reorders)
    assert "# EVIDENCE NOTES" in md
