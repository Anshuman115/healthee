#!/usr/bin/env python3
"""Regenerate ``lib/shared/format/note_names.dart`` from the corpus manifest.

The app has to name a research note on screen — a citation chip reading
``sleep_score_implementation_plan`` is an internal identifier, and no owner
should ever be shown one. The name it uses is the corpus's OWN name, so this is
a transcription rather than a second opinion: ``packages/knowledge/manifest.json``
is itself generated (``packages/knowledge/tools/gen_manifest.py``) and is the
single source for every id → name pair.

Hand-writing the table was the alternative and was rejected for the reason
``metric_names.dart`` states about a different table: a name invented in the UI
layer is a name nobody in the corpus agreed to. Prettifying the id mechanically
was rejected for the same reason — ``Sleep score implementation plan`` looks like
a name and is not one.

``test/shared/note_names_test.dart`` reads the manifest out of the repo and fails
when this file drifts, naming this script in the failure. Run it from
``apps/mobile``::

    python3 tool/gen_note_names.py
"""

from __future__ import annotations

import json
import re
from pathlib import Path

MANIFEST = Path("../../packages/knowledge/manifest.json")
OUTPUT = Path("lib/shared/format/note_names.dart")
GRADES_OUTPUT = Path("lib/shared/format/note_grades.dart")

HEADER = """/// The owner-facing name for a research-note id. **Generated — do not hand-edit.**
///
/// Run `python3 tool/gen_note_names.py` from `apps/mobile` after any change to
/// `packages/knowledge`; `test/shared/note_names_test.dart` reads the manifest
/// out of the repo and fails when this file has drifted from it.
///
/// ## Why the app carries the corpus's names at all
///
/// A citation reaches the screen as an id — `/api/today` sends
/// `research_note_ids: ["mvpa_minutes_mortality"]` and nothing else — and an id
/// is an internal identifier. The chips rendered `recovery_readiness` under the
/// gauge and `cardio_load_trimp` on Activity, which is a log line where a source
/// should be.
///
/// The names here are the corpus's own `name` field, transcribed. Two other
/// designs were rejected:
///
///   * **Prettify the id** (`sleep_score_implementation_plan` → "Sleep score
///     implementation plan"). `metric_names.dart` already argues this one down
///     for metric ids: it invents an owner-facing name for something nobody
///     named, and it looks like a name, so nothing about it reads as a gap.
///   * **Have the server send the name.** This is the right long-term fix and it
///     is a wire change, so it belongs in a server PR with a contract snapshot.
///     Until then the app resolves offline, which it must do anyway — the
///     citations are on cached payloads and the phone is often on no network.
///
/// An id with no entry keeps its id (see [noteName]), which is the same stance
/// `metric_names.dart` takes and is now a corpus-ahead-of-app condition rather
/// than a routine one.
///
/// ## Aliases are here because the SERVER cites them
///
/// `/api/today` does not only send note ids. `read/activity.py` cites
/// `cardio_load_trimp` and `read/vo2max.py` cites `vo2max_fitness_mortality`,
/// and neither is a note id — both are **aliases**, of `training_stress_score`
/// and `vo2max` respectively. An ids-only table left those two chips reading as
/// raw snake_case on the Activity screen, which is the defect this file exists
/// to fix, so [kNoteAliases] resolves them.
///
/// Only aliases **shaped like an id** are here (`^[a-z0-9_]+$`) — those are the
/// only ones that can arrive in a `research_notes` array — and any alias claimed
/// by two or more notes is dropped rather than guessed at. `methodology` belongs
/// to seven notes; naming one of them would be picking a source for the reader.
library;

/// The readable source name for [cited], or null when this build cannot resolve
/// it to a note.
///
/// [cited] is whatever the payload carried: a note id, or one of the aliases the
/// server's read layer cites. Null rather than a manufactured phrase — an app
/// older than the corpus should show the id and be visibly behind, not invent a
/// title for a note it does not have. `CitationRow` renders the id then, and
/// logs it.
String? noteName(String cited) => kNoteNames[canonicalNoteId(cited)];

/// The note id [cited] refers to — itself, or the note it is an alias of.
String canonicalNoteId(String cited) =>
    kNoteNames.containsKey(cited) ? cited : (kNoteAliases[cited] ?? cited);

/// Every note in the corpus, id → the corpus's own name.
const Map<String, String> kNoteNames = <String, String>{
"""

ALIAS_HEADER = """
/// Id-shaped aliases the corpus declares, → the note they belong to.
///
/// See the library docstring: the server cites some of these directly. Ambiguous
/// aliases are omitted, so a lookup here is never a guess.
const Map<String, String> kNoteAliases = <String, String>{
"""

GRADE_HEADER = """/// The evidence grade for a research-note id. **Generated — do not hand-edit.**
///
/// Emitted by `python3 tool/gen_note_names.py` in the same pass as
/// `note_names.dart`, from the same read of `packages/knowledge/manifest.json`,
/// so the two cannot describe different corpus versions. A separate file only
/// because one file of both would clear 400 lines (Standards §1).
///
/// `test/shared/note_names_test.dart` reads the manifest out of the repo and
/// fails when this file has drifted from it.
library;

import 'package:healthee/shared/format/note_names.dart';

/// Every note in the corpus, id → the corpus's own `grade` field.
///
/// ## Why the app may hold grades at all, when `CitationRow` may not infer them
///
/// `CitationRow` never derives a grade from an id it was handed, and that rule
/// stands: a `research_notes` array arriving on a payload says which notes back
/// a sentence the SERVER composed, and the server is the only party that knows
/// what that sentence claims. Guessing a grade there would rebuild the
/// `evidence_grade`-vs-`grade` split that once published a `Myth` note as
/// `Established` (#83).
///
/// The explainers in `shared/metric_info/` are the opposite case. Their prose is
/// written **in this repo, against these notes**, by a person who read them —
/// the citation is authored, not received. So the grade is not inferred from the
/// id; it is looked up from the corpus's own field, and this table is a
/// transcription of that field exactly as [kNoteNames] is a transcription of
/// `name`. The generator emits both from the same manifest read, so they cannot
/// describe different corpus versions.
const Map<String, String> kNoteGrades = <String, String>{
"""

RANK_BLOCK = """
/// Grade → numeric rank. **The server's `core/knowledge.py::GRADE_RANK`,
/// transcribed** — one scale, so "weakest" means the same thing on both sides of
/// the wire. `Contested` and `Emerging` share rank 1 and `Myth`/`Refuted` share
/// 0, which is the server's map and not a simplification made here.
const Map<String, int> kGradeRank = <String, int>{
  'Established': 3,
  'Probable': 2,
  'Emerging': 1,
  'Contested': 1,
  'Myth': 0,
  'Refuted': 0,
};

/// The grade a claim citing [noteIds] may honestly wear: **the weakest one**.
///
/// The same rule `jobs/recs.py::_provable_grade` applies server-side — "the
/// strictest (weakest) grade among the cited notes is the ceiling" — so a claim
/// resting on an `Established` note and a `Probable` one ships as `Probable`.
/// Averaging or taking the strongest would let one solid citation launder a weak
/// one, which is the whole failure mode.
///
/// An id this build cannot resolve returns null rather than a grade: an app
/// older than the corpus must be visibly behind, never confidently wrong. Same
/// for an empty list — a claim with no citations has no grade to show, and
/// `MetricInfo` says so in words instead.
String? weakestGrade(Iterable<String> noteIds) {
  String? weakest;
  var lowest = 1 << 30;
  for (final id in noteIds) {
    final grade = kNoteGrades[canonicalNoteId(id)];
    final rank = grade == null ? null : kGradeRank[grade];
    if (grade == null || rank == null) {
      return null;
    }
    if (rank < lowest) {
      lowest = rank;
      weakest = grade;
    }
  }
  return weakest;
}
"""

FOOTER = "};\n"

ID_SHAPED = re.compile(r"^[a-z0-9_]+$")


def _check(value: str, what: str) -> str:
    if "'" in value or "$" in value or "\\" in value:
        raise SystemExit(f"{what}: needs escaping this generator does not do")
    return value


def _aliases(records: list[dict]) -> dict[str, str]:
    """Id-shaped aliases owned by exactly one note, excluding real ids."""
    ids = {record["id"] for record in records}
    owners: dict[str, set[str]] = {}
    for record in records:
        for alias in record.get("aliases", []):
            if ID_SHAPED.match(alias) and alias not in ids:
                owners.setdefault(alias, set()).add(record["id"])
    return {alias: next(iter(o)) for alias, o in owners.items() if len(o) == 1}


def main() -> None:
    records = json.loads(MANIFEST.read_text())["records"]
    lines = [HEADER]
    for record in sorted(records, key=lambda r: r["id"]):
        note_id = record["id"]
        name = _check(record["name"], note_id)
        lines.append(f"  '{note_id}': '{name}',\n")
    lines.append(FOOTER)

    aliases = _aliases(records)
    lines.append(ALIAS_HEADER)
    for alias in sorted(aliases):
        lines.append(f"  '{_check(alias, alias)}': '{aliases[alias]}',\n")
    lines.append(FOOTER)

    OUTPUT.write_text("".join(lines))

    grades = [GRADE_HEADER]
    for record in sorted(records, key=lambda r: r["id"]):
        grade = _check(str(record["grade"]), record["id"])
        grades.append(f"  '{record['id']}': '{grade}',\n")
    grades.append(FOOTER)
    grades.append(RANK_BLOCK)
    GRADES_OUTPUT.write_text("".join(grades))

    print(f"{OUTPUT}: {len(records)} notes, {len(aliases)} aliases")
    print(f"{GRADES_OUTPUT}: {len(records)} grades")


if __name__ == "__main__":
    main()
