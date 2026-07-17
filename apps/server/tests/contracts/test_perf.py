"""Performance guardrails for the aggregators: the read endpoints must NOT issue an
N+1 query fan-out, must each answer on ONE pooled connection, and must answer well
within the read budget on the seeded set.
"""

from __future__ import annotations

import time
from collections.abc import Iterator

import psycopg
import pytest

from healthee.core import db as db_module

pytestmark = pytest.mark.integration

# How long a starved borrow waits before the pool gives up. Only reached when a
# request needs a SECOND connection, so it is pure test latency on a passing run —
# short enough that the regression fails fast, long enough not to flake on a busy box.
_POOL_WAIT_S = 3.0


@pytest.fixture
def pool_of_one(seeded_client: tuple, monkeypatch: pytest.MonkeyPatch) -> Iterator[tuple]:
    """The seeded client, but the whole app shares a pool of exactly ONE connection.

    This is what makes the self-deadlock DETERMINISTIC instead of a concurrency race.
    A request that borrows a second connection while holding the first cannot be
    served by a one-connection pool at any concurrency — it simply blocks until
    `_POOL_WAIT_S` and raises `PoolTimeout`. So a nested borrow fails this fixture's
    tests on a single, serial request, with no threads and no timing luck involved.
    """
    client, headers = seeded_client
    real_pool = db_module.ConnectionPool

    def one_connection_pool(**kwargs):  # noqa: ANN003, ANN202
        return real_pool(**{**kwargs, "min_size": 1, "max_size": 1, "timeout": _POOL_WAIT_S})

    monkeypatch.setattr(db_module, "ConnectionPool", one_connection_pool)
    db_module.close_pool()  # force the next get_pool() to rebuild at size 1
    yield client, headers
    db_module.close_pool()


def test_today_is_served_on_one_connection(pool_of_one: tuple) -> None:
    """/api/today must complete on a single pooled connection.

    Fails on the pre-fix code: `today_snapshot` held the request's connection while
    `build_today_reads` -> `compute_baselines` and `top_findings` ->
    `get_significant_findings` each opened their own `tenant_transaction`. At
    `_POOL_MAX_SIZE` = 10 that made ~10 concurrent requests deadlock the pool against
    itself — an outage, not a slowdown (standards §1: "no per-item connections").
    """
    client, headers = pool_of_one
    resp = client.get("/api/today", headers=headers)
    assert resp.status_code == 200, "/api/today needs >1 pooled connection (nested borrow?)"


def test_sleep_is_served_on_one_connection(pool_of_one: tuple) -> None:
    """/api/sleep must complete on a single pooled connection (see the Today twin)."""
    client, headers = pool_of_one
    resp = client.get("/api/sleep", headers=headers)
    assert resp.status_code == 200, "/api/sleep needs >1 pooled connection (nested borrow?)"


# /api/today aggregates ~30 blocks. The seeded snapshot issues 46 statements today:
# the per-metric latest-value fan-out is one DISTINCT ON, the ~8 per-metric baselines
# are one grouped CTE, the sparklines are one batched read, and data-health is six
# targeted last-seen probes. The count is a small FIXED constant, NOT proportional to
# days/rows — that is the property this bound protects. It catches both an accidental
# N+1 and a regression of the consolidation.
#
# Raised 45 -> 50 when data-health went from one grouped scan to six probes. Raising a
# ratchet deserves suspicion, so: the five extra statements are a measured trade, not a
# slip. The grouped `GROUP BY metric, max(ts)` cost 10,481 buffers against a year of
# data because GROUP BY defeats the min/max index rewrite; the six probes cost 18 total
# and, unlike the scan, do not grow with history. Statement count is the proxy; buffers
# are the budget (read/recovery.py::_last_seen).
#
# The claim this comment used to make — that the baselines ran "on ONE connection,
# not 8" — was true of the STATEMENT count and false of the CONNECTION count: the
# grouped CTE ran on a second pooled connection borrowed under the request's own.
# Counting statements never could have caught that; `pool_of_one` above does.
_MAX_TODAY_QUERIES = 50


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
