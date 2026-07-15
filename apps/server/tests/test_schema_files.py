"""Drift guard — db/schema.sql (the reference) must declare the same tables and
indexes as the migrations that actually build the DB. Keeps the two from lying
to each other as migrations accumulate.
"""

from __future__ import annotations

import re
from pathlib import Path

_DB_DIR = Path(__file__).resolve().parents[1] / "src" / "healthee" / "db"
_SCHEMA = _DB_DIR / "schema.sql"
_MIGRATIONS = _DB_DIR / "migrations"

_TABLE_RE = re.compile(r"CREATE TABLE IF NOT EXISTS (\w+)", re.IGNORECASE)
_INDEX_RE = re.compile(r"CREATE INDEX IF NOT EXISTS (\w+)", re.IGNORECASE)


def _objects(sql: str) -> tuple[set[str], set[str]]:
    return set(_TABLE_RE.findall(sql)), set(_INDEX_RE.findall(sql))


def _migrations_sql() -> str:
    return "\n".join(p.read_text() for p in sorted(_MIGRATIONS.glob("*.sql")))


def test_schema_reference_matches_migrations() -> None:
    schema_tables, schema_indexes = _objects(_SCHEMA.read_text())
    mig_tables, mig_indexes = _objects(_migrations_sql())
    assert schema_tables == mig_tables
    assert schema_indexes == mig_indexes


def test_v1_compat_objects_are_absent() -> None:
    tables, _ = _objects(_SCHEMA.read_text())
    # The v1 compat views / v1-only tables must not reappear (INTELLIGENCE.md §6).
    assert "metric_sample" not in tables
    assert "session" not in tables
    assert "sync_run" not in tables


def test_recommendation_has_audit_columns() -> None:
    schema = _SCHEMA.read_text()
    assert "raw_llm_prompt" in schema
    assert "raw_llm_response" in schema
