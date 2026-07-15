"""Integration tests against a real TimescaleDB (CI service container; auto-skips
locally). Cover the migration runner, the hypertable, idempotency, healthz, and a
sample round-trip.
"""

from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from healthee.api.routers import health
from healthee.core.db import transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration


def _table_exists(name: str) -> bool:
    with transaction() as cur:
        cur.execute("SELECT to_regclass(%s)", (name,))
        row = cur.fetchone()
    return row is not None and row[0] is not None


def test_apply_migrations_creates_schema(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    for table in ("sample", "sleep_session", "derived_daily", "finding", "gps_point"):
        assert _table_exists(table), f"missing table {table}"
    assert _table_exists("schema_migrations")


def test_sample_is_a_hypertable(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    with transaction() as cur:
        cur.execute(
            "SELECT 1 FROM timescaledb_information.hypertables WHERE hypertable_name = 'sample'"
        )
        assert cur.fetchone() is not None


def test_second_migrate_run_is_a_no_op(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()  # ensure applied
    assert migrate.apply_migrations() == []  # nothing pending the second time


def test_sample_insert_and_read_roundtrip(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    with transaction() as cur:
        cur.execute(
            "INSERT INTO sample (ts, metric, value) VALUES "
            "('2026-01-01T00:00:00+00', 'hr', 61.0) "
            "ON CONFLICT (metric, ts) DO UPDATE SET value = EXCLUDED.value"
        )
    with transaction() as cur:
        cur.execute(
            "SELECT value FROM sample WHERE metric = 'hr' AND ts = '2026-01-01T00:00:00+00'"
        )
        row = cur.fetchone()
    assert row is not None
    assert row[0] == 61.0


def test_healthz_returns_200_with_db_ok(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    app = FastAPI()
    app.include_router(health.router)
    resp = TestClient(app).get("/healthz")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok", "db": "ok"}
