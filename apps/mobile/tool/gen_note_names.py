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
from pathlib import Path

MANIFEST = Path("../../packages/knowledge/manifest.json")
OUTPUT = Path("lib/shared/format/note_names.dart")

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
library;

/// The readable source name for [noteId], or null when this build has never
/// heard of it.
///
/// Null rather than a manufactured phrase: an app older than the corpus should
/// show the id and be visibly behind, not invent a title for a note it does not
/// have. `CitationRow` renders the id in that case and logs it.
String? noteName(String noteId) => kNoteNames[noteId];

/// Every note in the corpus, id → the corpus's own name.
const Map<String, String> kNoteNames = <String, String>{
"""

FOOTER = "};\n"


def main() -> None:
    records = json.loads(MANIFEST.read_text())["records"]
    lines = [HEADER]
    for record in sorted(records, key=lambda r: r["id"]):
        note_id = record["id"]
        name = record["name"]
        if "'" in name or "$" in name or "\\" in name:
            raise SystemExit(f"{note_id}: name needs escaping this generator does not do")
        lines.append(f"  '{note_id}': '{name}',\n")
    lines.append(FOOTER)
    OUTPUT.write_text("".join(lines))
    print(f"{OUTPUT}: {len(records)} notes")


if __name__ == "__main__":
    main()
