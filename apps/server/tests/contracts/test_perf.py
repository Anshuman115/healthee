"""Performance guardrails for the aggregators: /api/today must NOT issue an N+1
query fan-out, and it must answer well within the read budget on the seeded set.
"""

from __future__ import annotations

import time

import psycopg
import pytest

pytestmark = pytest.mark.integration

# /api/today aggregates ~30 blocks. After the fan-out consolidation the seeded
# snapshot issues ~37 statements — the per-metric latest-value fan-out is one
# DISTINCT ON, the ~8 per-metric baselines are one grouped CTE (on ONE connection,
# not 8), data-health is one grouped scan, and the sparklines are one batched read.
# The count is a small fixed constant, NOT proportional to days/rows. This bound
# catches both an accidental N+1 AND a regression of the consolidation.
_MAX_TODAY_QUERIES = 45


def test_today_query_count_is_bounded(seeded_client: tuple, monkeypatch) -> None:
    client, headers = seeded_client
    counter = {"n": 0}
    original = psycopg.Cursor.execute

    def counting_execute(self, query, *args, **kwargs):  # noqa: ANN001, ANN202
        counter["n"] += 1
        return original(self, query, *args, **kwargs)

    monkeypatch.setattr(psycopg.Cursor, "execute", counting_execute)
    resp = client.get("/api/today", headers=headers)
    assert resp.status_code == 200
    assert counter["n"] < _MAX_TODAY_QUERIES, f"/api/today ran {counter['n']} queries (N+1?)"


def test_today_latency_under_budget(seeded_client: tuple) -> None:
    """Sanity latency check on the seeded set (real budget is p95 < 100 ms)."""
    client, headers = seeded_client
    client.get("/api/today", headers=headers)  # warm the pool
    start = time.perf_counter()
    resp = client.get("/api/today", headers=headers)
    elapsed_ms = (time.perf_counter() - start) * 1000
    assert resp.status_code == 200
    assert elapsed_ms < 500, f"/api/today took {elapsed_ms:.0f} ms on the seeded set"
