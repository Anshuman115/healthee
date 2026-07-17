"""Guard: every ``[[id]]`` cited in the server source resolves to a manifest id.

Why this is a test and not a lint: the mobile ⓘ sheet renders the *note itself* for a
cited id (docs/INTELLIGENCE.md §1 — "one source of truth; no hardcoded card copy that
can drift from the research"). A citation that names nothing therefore renders nothing
— the user taps the ⓘ on a number and gets an empty sheet, silently. That is the same
failure the grounded-ask validator blocks in LLM output; it must not be tolerated in
our own source, where nothing was checking it at all.

The knowledge reconciliation renamed note ids and folded notes together. The *tests*
were fixed to resolve ids live from the manifest; the source docstrings were not, and
four ids rotted unnoticed. This guard is what makes that class of rot loud.

**Aliases deliberately do NOT count as resolving.** The alias list is retrieval
vocabulary — it is what a *query* may be phrased as, not what a *citation* may name.
Every consumer of a cited id looks it up by id: ``manifest.note_ids()`` (the validator's
allow-set), ``manifest.by_id`` / ``note_body`` (what the ⓘ sheet renders), and
``grade_of`` (the calibration floor). None of them consult ``aliases``. So a citation to
an alias resolves to nothing *in the behaviour that matters*, which is precisely how
``[[cardio_load_trimp]]`` — a live alias of ``training_stress_score`` — rendered a blank
sheet while looking perfectly healthy in a grep. Accepting aliases here would make the
guard agree with a reading of the corpus that no runtime code performs.
"""

from __future__ import annotations

import re
from pathlib import Path

import healthee
from healthee.insights.manifest import all_notes, note_ids

# A wiki-style citation: ``[[note_id]]``. Restricted to the manifest's id charset
# (lowercase snake_case) so ordinary Python subscripting can never look like one.
_CITATION = re.compile(r"\[\[([a-z][a-z0-9_]{2,})\]\]")


def _source_files() -> list[Path]:
    return sorted(Path(healthee.__file__).parent.rglob("*.py"))


def _citations(text: str) -> list[str]:
    """Every cited note id in a blob of source, in order (duplicates kept)."""
    return _CITATION.findall(text)


def test_every_cited_id_resolves_to_a_manifest_note() -> None:
    """No ``[[id]]`` anywhere in the server source names a note that doesn't exist.

    A failure here is one of two things, and both are real:
      * a rename the source missed (fix: cite the note's CURRENT id), or
      * a citation to a note that never existed (fix: DELETE it — inventing a note to
        satisfy a citation is the fabrication we refuse everywhere else).
    """
    known = note_ids()
    assert known, "manifest is empty — the guard would pass vacuously"
    offenders: list[str] = []
    for path in _source_files():
        for cited in dict.fromkeys(_citations(path.read_text())):
            if cited not in known:
                offenders.append(f"{path.name}: [[{cited}]] is not a manifest id")
    assert not offenders, (
        "citations that resolve to nothing (the ⓘ sheet renders these blank):\n"
        + "\n".join(offenders)
    )


def test_the_guard_actually_detects_a_dangling_citation() -> None:
    """The guard must FAIL on a planted violation — else it proves nothing.

    A scanner that silently matches nothing reports green forever while the source
    rots. This pins that the pattern really fires on the shape it is meant to catch.
    """
    planted = '"""Daily load. [[no_such_note_exists_anywhere]]."""'
    found = _citations(planted)
    assert found == ["no_such_note_exists_anywhere"], "the scanner failed to see a citation"
    assert found[0] not in note_ids()


def test_the_guard_sees_the_real_citation_styles_used_in_this_codebase() -> None:
    """No false negatives: the guard must find citations in every form the source uses.

    Comment-trailing, docstring-trailing, several-per-line, and a bare module-docstring
    "Knowledge:" list — if the scanner missed any of these, whole files would be
    silently unguarded.
    """
    sample = (
        "# Tanaka HRmax [[maximum_heart_rate]]\n"
        'def f():\n    """Load. [[training_stress_score]], [[heart_rate_zones]]."""\n'
        '"""Module. Knowledge: [[recovery_readiness]]."""\n'
    )
    assert _citations(sample) == [
        "maximum_heart_rate",
        "training_stress_score",
        "heart_rate_zones",
        "recovery_readiness",
    ]


def test_the_guard_rejects_an_alias_that_is_not_an_id() -> None:
    """An alias must NOT satisfy a citation — that is the whole point (see module docs).

    ``cardio_load_trimp`` is a live alias of ``training_stress_score``. It is a real
    string in the corpus, so a lenient guard would wave it through — and the ⓘ sheet,
    which looks up by id only, would still render nothing. Pin the strict reading.
    """
    aliases = {a for n in all_notes() for a in n.aliases}
    assert "cardio_load_trimp" in aliases, "fixture drifted: expected this alias to exist"
    assert "cardio_load_trimp" not in note_ids(), "an alias must not be an id"


def test_the_guard_scans_more_than_a_handful_of_files() -> None:
    """Sanity: the file walk must actually reach the source tree."""
    files = _source_files()
    assert len(files) > 40, f"only {len(files)} source files found — the walk is broken"
    assert any(p.name == "cardio_load.py" for p in files)
