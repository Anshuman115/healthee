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
grade: {grade}
applies_to_metrics: [rhr_daily]
tags: [a, b]
last_reviewed: 2026-01-01
---

## Finding
Body prose here.
"""

# A legacy note as the unified TEMPLATE specifies it: its own `name`, `summary`
# and `aliases` alongside the older `topic`/`tags`. The authored fields must win.
AUTHORED_LEGACY_NOTE = """---
id: alcohol_sleep
name: "Alcohol, sleep architecture, and overnight autonomics"
topic: Alcohol disrupts second-half sleep architecture and acutely lowers HRV
category: intake
grade: Established
summary: "Alcohol before bed front-loads slow-wave sleep then fragments the second half."
aliases: ["nightcap", "alcohol before bed", "alcohol and hrv"]
applies_to_metrics: [hrv_sleep_avg]
tags: [alcohol, sleep, hrv, autonomic]
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
    ids = [r["id"] for r in records]
    # every id is snake_case (citable) and unique — robust to reconciliation, which
    # consolidates/renames notes; assert invariants, not specific consolidatable ids.
    assert all(gen.ID_RE.fullmatch(i) for i in ids)
    assert len(set(ids)) == len(ids)
    # one grade vocabulary across the real corpus, both collections (#83)
    grades = {r["grade"] for r in records}
    assert grades <= gen.UNIFIED_GRADES
    assert {"Established", "Probable", "Contested"} <= grades
    # a stable sports-science note keeps its snake_case id + a v2 metric mapping
    by_id = {r["id"]: r for r in records}
    assert by_id["heart_rate_zones"]["grade"] == "Probable"
    assert "cardio_load" in by_id["heart_rate_zones"]["applies_to_metrics"]


# ── authored fields survive into the manifest ───────────────────────────────
#
# The manifest is the retrieval index AND the one-line description the model is
# shown for every note it did NOT pull in full (INTELLIGENCE §3). A generator
# that publishes the terse `topic:` in place of the authored `summary:`, or the
# classifying `tags:` in place of the findable `aliases:`, silently degrades
# grounding without failing anything. These tests are that missing failure.


def test_legacy_note_authored_summary_and_aliases_survive(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _point_at(monkeypatch, tmp_path)
    _write(tmp_path / "notes" / "intake" / "alcohol_sleep.md", AUTHORED_LEGACY_NOTE)
    (record,), _ = gen.build_records()
    assert record["name"] == "Alcohol, sleep architecture, and overnight autonomics"
    assert record["summary"].startswith("Alcohol before bed front-loads slow-wave sleep")
    # findability phrases, not the classifying tags
    assert record["aliases"] == ["nightcap", "alcohol before bed", "alcohol and hrv"]
    assert "alcohol" not in record["aliases"] and "autonomic" not in record["aliases"]
    # and none of the three is the one-line `topic:`
    topic = "Alcohol disrupts second-half sleep architecture and acutely lowers HRV"
    assert topic not in (record["name"], record["summary"])


def test_legacy_note_without_authored_fields_falls_back(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """A pre-TEMPLATE note (topic/tags only) still gets a usable record."""
    _point_at(monkeypatch, tmp_path)
    _write(
        tmp_path / "notes" / "m" / "old.md",
        LEGACY_NOTE.format(id="old", topic="A topic", grade="Established"),
    )
    (record,), _ = gen.build_records()
    assert record["name"] == "A topic"
    assert record["summary"] == "A topic"
    assert record["aliases"] == ["a", "b"]  # tags, only because aliases is absent


def test_both_builders_read_the_same_authored_fields(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """Identical authored frontmatter must produce identical records in either collection."""
    _point_at(monkeypatch, tmp_path)
    authored = 'name: "Shared Name"\nsummary: "Shared summary line."\naliases: ["shared-alias"]\n'
    _write(
        tmp_path / "notes" / "m" / "l.md",
        f"---\nid: leg\n{authored}topic: terse\ngrade: Established\ntags: [t]\n---\n\nBody.\n",
    )
    _write(
        tmp_path / "sports-science" / "metrics" / "s.md",
        f"---\nid: ss\n{authored}category: m\ngrade: Established\n"
        "applies_to_metrics: []\napplies_to_interventions: []\n---\n\nBody.\n",
    )
    records, _ = gen.build_records()
    fields = [{k: r[k] for k in ("name", "summary", "aliases")} for r in records]
    assert fields[0] == fields[1]
    assert fields[0] == {
        "name": "Shared Name",
        "summary": "Shared summary line.",
        "aliases": ["shared-alias"],
    }


def test_real_corpus_publishes_the_authored_summary_and_aliases() -> None:
    """Over the committed corpus: no record substitutes a derived value for an authored one."""
    records, _ = gen.build_records()
    for record in records:
        fm, _body = gen._parse_frontmatter((gen.KNOWLEDGE_ROOT / record["path"]).read_text())
        if fm.get("summary"):
            assert record["summary"] == str(fm["summary"]).strip(), record["id"]
        if fm.get("name"):
            assert record["name"] == str(fm["name"]).strip(), record["id"]
        if fm.get("aliases"):
            assert record["aliases"] == [str(a) for a in fm["aliases"]], record["id"]
        # the terse `topic:` never stands in for the authored summary
        if fm.get("topic") and fm.get("summary"):
            assert record["summary"] != str(fm["topic"]).strip(), record["id"]


# ── validation failures ─────────────────────────────────────────────────────


def test_duplicate_id_across_collections_fails(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _point_at(monkeypatch, tmp_path)
    _write(
        tmp_path / "notes" / "a.md", LEGACY_NOTE.format(id="dup", topic="T", grade="Established")
    )
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
    _write(tmp_path / "notes" / "a.md", LEGACY_NOTE.format(id="real", topic="T", grade="Probable"))
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
