"""Tests for the knowledge manifest generator.

The generator lives at packages/knowledge/tools/gen_manifest.py (outside the
server src tree) so it is loaded by path. Corpus-shape tests point the module's
directory constants at a synthetic tmp corpus; two tests exercise the real
committed corpus.
"""

from __future__ import annotations

import importlib.util
import types
from pathlib import Path

import pytest

_GEN_PATH = (
    Path(__file__).resolve().parents[3] / "packages" / "knowledge" / "tools" / "gen_manifest.py"
)


def _load_module() -> types.ModuleType:
    spec = importlib.util.spec_from_file_location("gen_manifest", _GEN_PATH)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


gen = _load_module()


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def _point_at(monkeypatch: pytest.MonkeyPatch, root: Path) -> None:
    """Redirect the module's corpus constants at a synthetic tmp root."""
    monkeypatch.setattr(gen, "KNOWLEDGE_ROOT", root)
    monkeypatch.setattr(gen, "NOTES_DIR", root / "notes")
    monkeypatch.setattr(gen, "SS_DIR", root / "sports-science")


LEGACY_NOTE = """---
id: {id}
topic: {topic}
evidence_grade: {grade}
applies_to_metrics: [rhr_daily]
tags: [a, b]
last_reviewed: 2026-01-01
---

## Finding
Body prose here.
"""

SS_NOTE = """---
id: {id}
name: "{name}"
category: metrics
grade: {grade}
summary: "One line."
aliases: ["{id}", "an alias"]
applies_to_metrics: [cardio_load]
applies_to_interventions: []
---

# Body
Untouched.
"""


# ── real corpus ──────────────────────────────────────────────────────────


def test_parses_both_formats_over_real_corpus() -> None:
    records, skipped = gen.build_records()
    collections = {r["collection"] for r in records}
    assert collections == {"legacy", "sports_science"}
    assert len(records) == len({r["id"] for r in records})  # ids unique
    # protocol/engineering notes are surfaced as skipped, not dropped silently
    assert any("protocol" in s for s in skipped)


def test_real_corpus_grades_and_ids() -> None:
    records, _ = gen.build_records()
    by_id = {r["id"]: r for r in records}
    # legacy evidence_grade 3 -> Established
    assert by_id["hrv_recovery_marker"]["grade"] == "Established"
    # sports-science id is snake_case and keeps its own grade
    assert by_id["heart_rate_zones"]["grade"] == "Probable"
    assert by_id["heart_rate_zones"]["applies_to_metrics"] == ["cardio_load"]
    assert all(gen.ID_RE.fullmatch(r["id"]) for r in records)


# ── grade mapping ──────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    ("grade_num", "expected"),
    [(3, "Established"), (2, "Probable"), (1, "Emerging")],
)
def test_legacy_grade_mapping(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, grade_num: int, expected: str
) -> None:
    _point_at(monkeypatch, tmp_path)
    _write(
        tmp_path / "notes" / "m" / "n.md",
        LEGACY_NOTE.format(id="n", topic="A topic", grade=grade_num),
    )
    records, _ = gen.build_records()
    assert records[0]["grade"] == expected
    assert records[0]["name"] == "A topic"  # topic -> name


# ── validation failures ─────────────────────────────────────────────────────


def test_duplicate_id_across_collections_fails(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _point_at(monkeypatch, tmp_path)
    _write(tmp_path / "notes" / "a.md", LEGACY_NOTE.format(id="dup", topic="T", grade=3))
    _write(
        tmp_path / "sports-science" / "metrics" / "b.md",
        SS_NOTE.format(id="dup", name="Dup", grade="Established"),
    )
    with pytest.raises(gen.CorpusError, match="duplicate id 'dup'"):
        gen.build_records()


def test_malformed_frontmatter_reports_filename(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _point_at(monkeypatch, tmp_path)
    # An unquoted % inside a flow list is invalid YAML (the real bug this catches).
    _write(
        tmp_path / "sports-science" / "metrics" / "broken.md",
        "---\nid: broken\naliases: [%bad]\n---\n\nBody.\n",
    )
    with pytest.raises(gen.CorpusError, match="broken.md"):
        gen.build_records()


def test_missing_required_field_fails_listing_file(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _point_at(monkeypatch, tmp_path)
    _write(
        tmp_path / "sports-science" / "metrics" / "partial.md",
        '---\nid: partial\nname: "P"\ncategory: metrics\ngrade: Established\n'
        'summary: "x"\naliases: ["partial"]\napplies_to_metrics: []\n---\n\nBody.\n',
    )
    with pytest.raises(gen.CorpusError, match="partial.md.*applies_to_interventions"):
        gen.build_records()


def test_unknown_grade_fails(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    _point_at(monkeypatch, tmp_path)
    _write(
        tmp_path / "sports-science" / "metrics" / "g.md",
        SS_NOTE.format(id="g", name="G", grade="Wobbly"),
    )
    with pytest.raises(gen.CorpusError, match="unknown grade"):
        gen.build_records()


def test_non_snake_case_id_fails(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    _point_at(monkeypatch, tmp_path)
    _write(
        tmp_path / "sports-science" / "metrics" / "h.md",
        SS_NOTE.format(id="Not-Snake", name="H", grade="Probable"),
    )
    with pytest.raises(gen.CorpusError, match="not snake_case"):
        gen.build_records()


def test_protocol_note_skipped_not_failed(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    _point_at(monkeypatch, tmp_path)
    # No id and no evidence_grade -> engineering doc, skipped (not an error).
    _write(tmp_path / "notes" / "protocol" / "p.md", "---\ntitle: X\nstatus: draft\n---\n\nBody.\n")
    _write(tmp_path / "notes" / "a.md", LEGACY_NOTE.format(id="real", topic="T", grade=2))
    records, skipped = gen.build_records()
    assert [r["id"] for r in records] == ["real"]
    assert skipped == ["notes/protocol/p.md"]


# ── determinism ─────────────────────────────────────────────────────────────


def test_output_is_deterministic() -> None:
    records, _ = gen.build_records()
    assert gen.render_manifest(records) == gen.render_manifest(records)
    assert gen.render_summaries(records) == gen.render_summaries(records)


def test_summaries_shape() -> None:
    records, _ = gen.build_records()
    import json

    summaries = json.loads(gen.render_summaries(records))["summaries"]
    assert set(summaries[0]) == {"id", "name", "grade", "summary", "applies_to_metrics"}
