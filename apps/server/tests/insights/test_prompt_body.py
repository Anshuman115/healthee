"""``manifest.prompt_body`` — the note as a PROMPT sees it, minus its bibliography.

Task #23's measurement: the evidence section is 65–83% of every prompt the product
sends, and 14.4% of the corpus's tokens are author/year/journal/DOI lines the model
can never cite (the validator's grammar is ``[note_id]``, checked against the
manifest). These tests pin three things:

  * the bibliography is gone from the prompt copy — in EVERY note, not the one sampled;
  * nothing else is: a section that follows the references survives, and so does every
    other heading in the corpus;
  * ``note_body`` is untouched — the human-facing ⓘ reader keeps the receipts, which is
    the whole reason this is a second accessor rather than an edit to the first.
"""

from __future__ import annotations

import re

from healthee.insights.manifest import all_notes, note_body, prompt_body

_BIBLIOGRAPHY_HEADING = re.compile(r"^##\s+(?:key\s+)?references\b", re.I | re.M)
_HEADINGS = re.compile(r"^##\s+(.+)$", re.M)


def test_no_note_carries_a_bibliography_into_a_prompt() -> None:
    offenders = [n.id for n in all_notes() if _BIBLIOGRAPHY_HEADING.search(prompt_body(n.id))]
    assert offenders == []


def test_every_note_body_still_has_its_bibliography() -> None:
    """The ⓘ reader gets the sources — PRICING §1a keeps reading the evidence free."""
    missing = [n.id for n in all_notes() if not _BIBLIOGRAPHY_HEADING.search(note_body(n.id))]
    assert missing == []


def test_only_the_bibliography_is_dropped() -> None:
    """Every OTHER section survives — in all 71 notes, not a sampled one.

    The bibliography is never the last section in this corpus (Healthee implementation
    & honesty policy follows it), so a regex that ran to the end of the file would
    silently eat the honesty policy. That is exactly the loss this asserts against.
    """
    for note in all_notes():
        kept = set(_HEADINGS.findall(prompt_body(note.id)))
        dropped = set(_HEADINGS.findall(note_body(note.id))) - kept
        assert all(h.lower().startswith(("references", "key references")) for h in dropped), (
            note.id,
            dropped,
        )
        assert kept, note.id


def test_the_saving_is_real_and_stays_real() -> None:
    """A regression guard on the measured number, not a tautology.

    Measured 2026-08-01: 1,228,863 → 1,084,571 characters (−11.7%), which is −14.4% of
    tokens (reference lines are URL-dense and tokenize badly). Pinned loosely at 8% so
    corpus growth doesn't fail the build, but a change that quietly stopped stripping
    would.
    """
    full = sum(len(note_body(n.id)) for n in all_notes())
    stripped = sum(len(prompt_body(n.id)) for n in all_notes())
    assert full > 0
    assert (full - stripped) / full > 0.08
