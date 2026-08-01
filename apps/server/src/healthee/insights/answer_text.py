"""Reading a generated answer: citations, sentences, and truncation.

The mechanical half of the honesty core — *what the answer says*, not *whether it is
allowed to say it*. ``validator.py`` owns the rules and imports these primitives; keeping
them apart is what got the rule engine back under the size gate, and each half now has
one reason to change (a new markdown shape here, a new rule there).

Everything here exists because the validator can only enforce what it can SEE. Each
function's docstring names the bypass it closes.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

# ── Citations ────────────────────────────────────────────────────────────────
# Parsed bracket-first, then part-by-part, so a bracket MIXING kinds
# (`[personal_finding:x, note_id]`) yields both. The previous pair of whole-bracket
# regexes matched such a bracket only partially: the note id parsed to nothing (a real
# citation silently lost, so a grounded claim read as ungrounded — or a fabricated id
# rode along unchecked) and the finding name came back as the garbage "x, note_id".
_BRACKET_RE = re.compile(r"\[([^\[\]]+)\]")
_NOTE_ID_RE = re.compile(r"^[a-z0-9_]+$")
_PERSONAL_PREFIX = "personal_finding:"

# ── Markdown structure the sentence splitter must see INTO rather than skip ──
_BLOCKQUOTE_RE = re.compile(r"^\s*>+\s?")
_LIST_MARKER_RE = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
_TABLE_SEPARATOR_RE = re.compile(r"^\|?[\s:|-]+\|?$")
_SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?])\s+")

# ── Headings ─────────────────────────────────────────────────────────────────
# Two shapes, because models write both: a real ATX heading (`## What the data shows`)
# and — far more often, since these answers are 4–6 lines — a whole line in bold with
# nothing after it (`**What the data shows**`). A trailing colon is part of the label.
#
# A line with bold at the FRONT and prose after it (`**Physiology:** your HRV is 45 ms`)
# is deliberately NOT a heading: it is a sentence that happens to start with a label, and
# it makes its claim in the same breath.
_ATX_HEADING_RE = re.compile(r"^\s{0,3}#{1,6}\s*")
_BOLD_ONLY_RE = re.compile(r"^\s*(\*\*|__)(?P<text>[^\s*_].*?)\1\s*:?\s*$")

# ── Truncation ───────────────────────────────────────────────────────────────
# A complete prose answer ends in a sentence terminator, optionally behind closing
# quotes/emphasis. Structural last lines (table rows, headings, list items) legitimately
# carry no terminator and are exempt, so the check stays conservative — it must never
# fire the honest fallback on a good answer.
_SENTENCE_TERMINATORS = ".!?"
_CLOSING_WRAPPER_CHARS = " \t\r\n\"')`*"


def extract_citations(text: str) -> tuple[set[str], set[str]]:
    """(note_ids, personal_finding_names) cited in ``text``.

    Every bracket is split on commas and each part classified independently, so the two
    kinds are never confused and a bracket mixing them parses correctly in either order.
    Parts that are neither (prose, markdown link text, a malformed id) are ignored — they
    cannot ground anything, so an interpretive sentence carrying only those still fails
    the citation check.
    """
    ids: set[str] = set()
    personal: set[str] = set()
    for match in _BRACKET_RE.finditer(text):
        for raw in match.group(1).split(","):
            part = raw.strip()
            if part.lower().startswith(_PERSONAL_PREFIX):
                name = part[len(_PERSONAL_PREFIX) :].strip()
                if name:
                    personal.add(name)
            elif _NOTE_ID_RE.match(part):
                ids.add(part)
    return ids, personal


@dataclass(frozen=True)
class Unit:
    """One validatable piece of an answer, and whether it is a section HEADING.

    ``heading`` is the only distinction the splitter draws, and it exists because a
    heading is a LABEL for the text beneath it, not a claim of its own: an answer that
    writes ``**What the data shows**`` above a fully cited paragraph was failing the
    interpretive-citation rule on the word "shows", i.e. on its own table of contents
    (#99, measured — grade/citation language was ~80% of every fallback).

    Marking a unit is NOT excusing it. This module only says where the text came from;
    ``validator._sentence_issues`` decides what that buys, and it buys very little — a
    heading still has to be a report rather than an assertion. The guardrails take the
    distinction not at all: ``sentences()`` returns every unit flat and ``output_guard``
    reads that, so a forbidden output written as a heading is blocked exactly as in prose.
    """

    text: str
    heading: bool = False


def _split_prose(blob: str, *, heading: bool = False) -> list[Unit]:
    """Sentence-split one prose blob (already joined across its wrapped lines)."""
    parts = _SENTENCE_SPLIT_RE.split(blob.strip())
    return [Unit(s.strip(), heading) for s in parts if s.strip()]


def _structural_units(line: str) -> list[Unit] | None:
    """A markdown-structural line → the units to validate. None for ordinary prose.

    Table rows yield one unit per cell (each cell is its own claim); separator rows yield
    nothing; headings yield their text, marked. These lines were DROPPED entirely, so an
    answer written as a table or under a heading bypassed the whole honesty contract.
    """
    stripped = line.strip()
    if stripped.startswith("|"):
        if _TABLE_SEPARATOR_RE.match(stripped):
            return []
        cells = [cell.strip() for cell in stripped.strip("|").split("|") if cell.strip()]
        return [unit for cell in cells for unit in _split_prose(cell)]
    if stripped.startswith("#"):
        return _split_prose(_ATX_HEADING_RE.sub("", stripped), heading=True)
    bold = _BOLD_ONLY_RE.match(stripped)
    if bold:
        return _split_prose(bold.group("text"), heading=True)
    return None


def sentence_units(text: str) -> list[Unit]:
    """Split an answer into validatable units, seeing INTO markdown structure.

    Prose is buffered across lines before splitting, because LLMs hard-wrap: a sentence
    and the ``[note_id]`` grounding it routinely land on different lines, and splitting
    per line would tear the citation off its own claim — a false positive that fires the
    honest fallback on good answers. Blank lines, list markers and headings end a blob,
    so one bullet's citation can never ground a neighbouring bullet's claim.
    """
    out: list[Unit] = []
    prose: list[str] = []

    def flush() -> None:
        blob = " ".join(prose).strip()
        prose.clear()
        out.extend(_split_prose(blob))

    for line in text.splitlines():
        # A blockquote is prose that happens to be quoted — unwrap it, don't skip it.
        content = _BLOCKQUOTE_RE.sub("", line, count=1)
        if not content.strip() or _LIST_MARKER_RE.match(content):
            flush()
            content = _LIST_MARKER_RE.sub("", content, count=1)
        units = _structural_units(content)
        if units is None:
            prose.append(content)
            continue
        flush()
        out.extend(units)
    flush()
    return out


def sentences(text: str) -> list[str]:
    """Every validatable unit of ``text``, flat — headings included, unmarked.

    This is what the hard output guardrails read: a forbidden output does not become
    allowed by being written as a heading, so the guard deliberately sees the same units
    the validator does with no distinction drawn between them.
    """
    return [unit.text for unit in sentence_units(text)]


def _looks_structural(line: str) -> bool:
    """True for a markdown line that legitimately ends without sentence punctuation."""
    stripped = line.strip()
    return stripped.startswith(("|", "#")) or bool(_LIST_MARKER_RE.match(stripped))


def truncation_issue(text: str) -> str | None:
    """The issue when an answer was cut off mid-generation (or is empty); None if complete.

    A truncated answer is not a validated answer — it is an accident that happened to
    contain nothing checkable, and it validated CLEAN precisely because its interpretive
    sentence never completed. Only the prose path calls this: on the JSON path
    ``json.loads`` already rejects a truncated answer, and rec fields (e.g.
    ``expected_effect``) are fragments that legitimately carry no terminator.
    """
    stripped = text.strip()
    if not stripped:
        return "Response was empty — nothing to validate."
    if stripped.count("[") != stripped.count("]"):
        return "Response appears truncated mid-citation (unclosed '[')."
    last_line = next(ln for ln in reversed(stripped.splitlines()) if ln.strip())
    if _looks_structural(last_line):
        return None
    if not last_line.rstrip(_CLOSING_WRAPPER_CHARS).endswith(tuple(_SENTENCE_TERMINATORS)):
        return f"Response appears truncated (no sentence terminator): '{last_line[-60:]}'"
    return None
