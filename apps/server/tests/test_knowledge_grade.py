"""ONE grade per note — the corpus cannot write down a grade disagreement (#83).

Notes used to carry TWO grades: the authored ``grade`` string and a numeric
``evidence_grade`` mirror. They could disagree, and WHICH ONE WON DEPENDED ON THE
NOTE'S DIRECTORY — ``notes/`` was built from ``evidence_grade`` (ignoring ``grade``)
and ``sports-science/`` did the exact reverse. So a note could ship under a grade
nobody wrote, and the severe case is not hypothetical arithmetic: ``grade: Myth``
with ``evidence_grade: 3`` published as **Established**.

That string is load-bearing. ``insights/validator.py::_grade_issue`` reads it to
decide whether a sentence may be stated plainly or must be hedged, flagged, or framed
as debated; ``_grade_floor`` reports it as an answer's evidence floor; and
``MIN_ACTIONABLE_RANK`` consults it before letting a note drive a recommendation or a
multi-week challenge. Established means "state it plainly" — so the corpus could have
instructed the product to assert a debunked claim as fact.

These tests are that missing failure. They live here rather than in
``test_knowledge_manifest.py`` because "a note has exactly one grade" is its own
reason to change, and that file was at the 400-line gate.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from tests.test_knowledge_manifest import LEGACY_NOTE, _point_at, _write, gen


@pytest.mark.parametrize(
    "grade", ["Established", "Probable", "Emerging", "Contested", "Myth", "Refuted"]
)
def test_authored_grade_is_what_ships_for_a_legacy_note(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, grade: str
) -> None:
    """The whole unified vocabulary survives a `notes/` note — including Myth.

    The retired numeric field spanned 3/2/1 only, so Contested and Myth had no
    numeric at all and a `notes/` note could not express them.
    """
    _point_at(monkeypatch, tmp_path)
    _write(
        tmp_path / "notes" / "m" / "n.md",
        LEGACY_NOTE.format(id="n", topic="A topic", grade=grade),
    )
    records, _ = gen.build_records()
    assert records[0]["grade"] == grade
    assert records[0]["name"] == "A topic"  # topic -> name


def test_a_myth_note_can_never_ship_as_established(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """THE defect, from both directions: the split is now unrepresentable.

    Authoring the retired numeric mirror is a hard generation failure, so there is no
    way to write the disagreement down at all — not merely a way for it to lose.
    """
    _point_at(monkeypatch, tmp_path)
    _write(
        tmp_path / "notes" / "m" / "debunked.md",
        "---\nid: debunked\ngrade: Myth\nevidence_grade: 3\ntopic: T\ntags: [t]\n---\n\nBody.\n",
    )
    with pytest.raises(gen.CorpusError, match="evidence_grade.* was removed"):
        gen.build_records()

    # ...and with the mirror gone, the authored grade is simply what ships.
    _write(
        tmp_path / "notes" / "m" / "debunked.md",
        "---\nid: debunked\ngrade: Myth\ntopic: T\ntags: [t]\n---\n\nBody.\n",
    )
    (record,), _ = gen.build_records()
    assert record["grade"] == "Myth"


def test_reintroduced_evidence_grade_fails_in_either_collection(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """A note that re-opens the split fails the build wherever it lives."""
    _point_at(monkeypatch, tmp_path)
    _write(
        tmp_path / "notes" / "m" / "l.md",
        "---\nid: leg\ngrade: Probable\nevidence_grade: 2\ntopic: T\ntags: [t]\n---\n\nBody.\n",
    )
    _write(
        tmp_path / "sports-science" / "metrics" / "s.md",
        '---\nid: ss\nname: "S"\ncategory: metrics\ngrade: Probable\nevidence_grade: 2\n'
        'summary: "x"\naliases: ["s"]\napplies_to_metrics: []\napplies_to_interventions: []\n'
        "---\n\nBody.\n",
    )
    with pytest.raises(gen.CorpusError) as exc:
        gen.build_records()
    # BOTH are named — the rule is not per-collection.
    assert "notes/m/l.md" in str(exc.value)
    assert "sports-science/metrics/s.md" in str(exc.value)


def test_both_collections_read_grade_the_same_way(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """The old defect was directory-dependent authority. One authored grade, one answer."""
    _point_at(monkeypatch, tmp_path)
    _write(
        tmp_path / "notes" / "m" / "l.md",
        "---\nid: leg\ngrade: Contested\ntopic: T\ntags: [t]\n---\n\nBody.\n",
    )
    _write(
        tmp_path / "sports-science" / "metrics" / "s.md",
        '---\nid: ss\nname: "S"\ncategory: metrics\ngrade: Contested\nsummary: "x"\n'
        'aliases: ["s"]\napplies_to_metrics: []\napplies_to_interventions: []\n---\n\nBody.\n',
    )
    records, _ = gen.build_records()
    assert {r["grade"] for r in records} == {"Contested"}


def test_legacy_note_without_a_grade_fails(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """`grade` is required now that it is the only grade — silence must not mean a default."""
    _point_at(monkeypatch, tmp_path)
    _write(tmp_path / "notes" / "m" / "n.md", "---\nid: n\ntopic: T\ntags: [t]\n---\n\nBody.\n")
    with pytest.raises(gen.CorpusError, match="missing required field `grade`"):
        gen.build_records()


def test_real_corpus_carries_no_numeric_grade_mirror() -> None:
    """Over the committed corpus: every note has exactly one grade, and it is `grade`."""
    records, _ = gen.build_records()
    for record in records:
        fm, _body = gen._parse_frontmatter((gen.KNOWLEDGE_ROOT / record["path"]).read_text())
        assert gen.RETIRED_GRADE_FIELD not in fm, record["id"]
        assert record["grade"] == fm["grade"], record["id"]
        assert record["grade"] in gen.UNIFIED_GRADES, record["id"]
