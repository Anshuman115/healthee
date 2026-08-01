"""Manifest-ranked retrieval — the fix for legacy dump-all (hole #3).

Proves a metric's own notes rank to the top and that the full-note count is
bounded (top-N), with the remainder present only as one-line summaries.

The alias tests below are the guard on task #23's finding: an alias was matched as a
bare SUBSTRING, so ``critical_speed``'s aliases ``W`` and ``D`` put a 6,707-token note
about running critical power into the top-6 of 6 of 11 representative prompts — 16% of
the daily-action prompt, bought by two letters. Word boundaries are the fix, and these
pin both halves of it: the letter no longer matches, the acronym still does.
"""

from __future__ import annotations

from healthee.insights.coaching import _DAILY_ACTION_PROMPT, DAILY_ACTION_METRICS
from healthee.insights.manifest import all_notes
from healthee.insights.retrieval import _score, _tokens, evidence_section, rank_notes


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


def _relevance(note_id: str, question: str, metrics: tuple[str, ...] = ()) -> int:
    note = next(n for n in all_notes() if n.id == note_id)
    return _score(note, _tokens(question), question.lower(), set(metrics))


def test_a_single_letter_alias_does_not_match_inside_a_word() -> None:
    """``critical_speed`` aliases ``W``/``D``; "this week … today" is not critical power.

    Asserted on the SCORE rather than the ranking, because a note can still surface in a
    top-6 on the alphabetical tie-break that breaks all-zero scores — a separate ranking
    weakness this change does not claim to fix. What is claimed is that the note stops
    being scored as *relevant*, and that is what this reads.

    The premise is asserted first: if the corpus ever drops those one-letter aliases the
    test stops proving anything, and it should say so rather than pass vacuously.
    """
    note = next(n for n in all_notes() if n.id == "critical_speed")
    assert any(len(a) == 1 for a in note.aliases), note.aliases
    assert _relevance("critical_speed", "How has my sleep been this week? One move today.") == 0


def test_the_daily_action_prompt_no_longer_embeds_a_critical_power_note() -> None:
    """The end-to-end version of the same fact, on a real shipped prompt.

    Measured before the fix: ``critical_speed`` was ranked into this prompt's top-6 and
    embedded IN FULL — 6,707 tokens, 16% of a ~42k prompt, every owner, every night.
    """
    top = [n.id for n in rank_notes(_DAILY_ACTION_PROMPT, DAILY_ACTION_METRICS)[:6]]
    assert "critical_speed" not in top


def test_an_acronym_alias_still_matches_its_own_word() -> None:
    """The fix must not cost real matches: HRV is how people ask about HRV."""
    assert _relevance("heart_rate_variability", "why is my hrv low lately?") > 0
    top = [n.id for n in rank_notes("why is my hrv low lately?")[:5]]
    assert "heart_rate_variability" in top


def test_a_phrase_alias_still_matches_its_phrase() -> None:
    ranked = rank_notes("how does alcohol before bed affect sleep?")
    assert ranked[0].id == "alcohol_sleep"
