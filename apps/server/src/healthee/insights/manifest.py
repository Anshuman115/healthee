"""The retrieval index for the insights layer — the generated knowledge manifest.

``packages/knowledge/manifest.json`` (built by ``make knowledge``) is the single
source of citable note ids, their unified evidence grade, and the metric/alias
metadata retrieval ranks against. This module loads it once (cached) and exposes:

  * ``all_notes()``   — every ``ManifestNote`` record,
  * ``note_ids()``    — the set the validator checks citations against,
  * ``by_id(id)``     — one record, or None,
  * ``grade_of(id)``  — the unified grade string for a cited id,
  * ``note_body(n)``  — the note's markdown body (frontmatter stripped), for
                        embedding top-ranked full notes in the LLM context.

``analytics.notes`` reads the same file for the *findings* citation-matching path;
this is the parallel accessor for the *insights* retrieval + validation path (both
are thin readers of one generated index — no second definition of the corpus).
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache

from healthee.core.knowledge import knowledge_dir
from healthee.core.logging import get_logger

log = get_logger(__name__)

_KNOWLEDGE_DIR = knowledge_dir()
_MANIFEST_PATH = _KNOWLEDGE_DIR / "manifest.json"

# Unified evidence grade → numeric rank (legacy 3/2/1 scale). Used for the
# "grade floor" of a response and to order calibration strictness.
GRADE_RANK: dict[str, int] = {
    "Established": 3,
    "Probable": 2,
    "Emerging": 1,
    "Contested": 1,
    "Myth": 0,
    "Refuted": 0,
}


@dataclass(frozen=True)
class ManifestNote:
    """One citable note as the retrieval index sees it (not the full body)."""

    id: str
    name: str
    grade: str
    summary: str
    path: str
    category: str
    aliases: tuple[str, ...] = ()
    applies_to_metrics: tuple[str, ...] = ()
    applies_to_interventions: tuple[str, ...] = ()
    population: str = ""


@lru_cache(maxsize=1)
def all_notes() -> tuple[ManifestNote, ...]:
    """Every manifest record, cached. Empty (logged) if the file is unreadable.

    A missing manifest is a degraded state, not a crash — surfaced through the one
    logging path so the caller can still refuse honestly instead of inventing ids.
    """
    try:
        raw = _MANIFEST_PATH.read_text(encoding="utf-8")
    except OSError as exc:
        log.warning("knowledge manifest unreadable (%s) — no notes are citable", exc)
        return ()
    records = json.loads(raw).get("records", [])
    return tuple(_to_note(r) for r in records)


def _to_note(rec: dict) -> ManifestNote:
    return ManifestNote(
        id=rec.get("id", ""),
        name=rec.get("name", ""),
        grade=rec.get("grade", ""),
        summary=rec.get("summary", ""),
        path=rec.get("path", ""),
        category=rec.get("category", ""),
        aliases=tuple(rec.get("aliases", [])),
        applies_to_metrics=tuple(rec.get("applies_to_metrics", [])),
        applies_to_interventions=tuple(rec.get("applies_to_interventions", [])),
        population=rec.get("population", ""),
    )


@lru_cache(maxsize=1)
def _by_id() -> dict[str, ManifestNote]:
    return {n.id: n for n in all_notes() if n.id}


def note_ids() -> set[str]:
    """The set of citable ids — what the validator checks every citation against."""
    return set(_by_id())


def by_id(note_id: str) -> ManifestNote | None:
    return _by_id().get(note_id)


def grade_of(note_id: str) -> str | None:
    """The unified grade string of a cited id, or None if the id is unknown."""
    note = _by_id().get(note_id)
    return note.grade if note else None


@lru_cache(maxsize=256)
def note_body(note_id: str) -> str:
    """The markdown body of a note (YAML frontmatter stripped), for full-note context.

    Cached per id. Returns the manifest ``summary`` as a fallback when the source
    file can't be read (degraded, logged) so the note is still usably described.
    """
    note = _by_id().get(note_id)
    if note is None or not note.path:
        return ""
    try:
        raw = (_KNOWLEDGE_DIR / note.path).read_text(encoding="utf-8")
    except OSError as exc:
        log.warning("note body unreadable for %s (%s) — using summary", note_id, exc)
        return note.summary
    return _strip_frontmatter(raw).strip()


def _strip_frontmatter(text: str) -> str:
    """Drop a leading ``---`` YAML frontmatter block if present."""
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            return text[text.find("\n", end + 1) + 1 :]
    return text
