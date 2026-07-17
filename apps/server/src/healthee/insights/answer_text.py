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


def _split_prose(blob: str) -> list[str]:
    """Sentence-split one prose blob (already joined across its wrapped lines)."""
    return [s.strip() for s in _SENTENCE_SPLIT_RE.split(blob.strip()) if s.strip()]


def _structural_units(line: str) -> list[str] | None:
    """A markdown-structural line → the text units to validate. None for ordinary prose.

    Table rows yield one unit per cell (each cell is its own claim); separator rows yield
    nothing; headings yield their text. These lines were DROPPED entirely, so an answer
    written as a table or under a heading bypassed the whole honesty contract.
    """
    stripped = line.strip()
    if stripped.startswith("|"):
        if _TABLE_SEPARATOR_RE.match(stripped):
            return []
        return [cell.strip() for cell in stripped.strip("|").split("|") if cell.strip()]
    if stripped.startswith("#"):
        return [stripped.lstrip("#").strip()]
    return None


def sentences(text: str) -> list[str]:
    """Split an answer into validatable sentences, seeing INTO markdown structure.

    Prose is buffered across lines before splitting, because LLMs hard-wrap: a sentence
    and the ``[note_id]`` grounding it routinely land on different lines, and splitting
    per line would tear the citation off its own claim — a false positive that fires the
    honest fallback on good answers. Blank lines and list markers end a blob, so one
    bullet's citation can never ground a neighbouring bullet's claim.
    """
    out: list[str] = []
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
        for unit in units:
            out.extend(_split_prose(unit))
    flush()
    return out


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
