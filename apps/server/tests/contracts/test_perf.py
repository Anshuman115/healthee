"""Performance guardrails for the aggregators: the read endpoints must NOT issue an
N+1 query fan-out, must each answer on ONE pooled connection, and must answer well
within the read budget on the seeded set.
"""

from __future__ import annotations

import time
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta

import psycopg
import pytest

from healthee.core import db as db_module
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_USER_ID

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

# /api/sleep: sessions + derived pivot + batched physiology + naps + findings. Like
# the Today bound this is a FIXED constant — the point of the sibling test is that it
# does not move with the number of nights stored.
_MAX_SLEEP_QUERIES = 15


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


def _count_statements(monkeypatch: pytest.MonkeyPatch) -> dict:
    """Count every statement the app executes, from the moment this is called."""
    counter = {"n": 0}
    original = psycopg.Cursor.execute

    def counting_execute(self, query, *args, **kwargs):  # noqa: ANN001, ANN202
        counter["n"] += 1
        return original(self, query, *args, **kwargs)

    monkeypatch.setattr(psycopg.Cursor, "execute", counting_execute)
    return counter


def _seed_extra_nights(nights: int) -> None:
    """Give the owner ``nights`` nights of main sleep sessions."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        for i in range(1, nights + 1):
            end = datetime.now(UTC) - timedelta(days=i)
            cur.execute(
                "INSERT INTO sleep_session (user_id, start_ts, end_ts, kind, "
                "  light_min, deep_min, rem_min, wake_min, score, stages) "
                "VALUES (%s, %s, %s, 'main', 200, 80, 60, 20, 80, '[]'::jsonb) "
                "ON CONFLICT DO NOTHING",
                (SENTINEL_USER_ID, end - timedelta(hours=7), end),
            )


def test_sleep_query_count_does_not_grow_with_history(
    seeded_client: tuple, monkeypatch: pytest.MonkeyPatch
) -> None:
    """/api/sleep must cost the same whether the owner has 10 nights or 200.

    The N+1 this pins was NOT proportional to the `days` PARAMETER — it was
    proportional to the nights actually stored, one physiology query per night. So a
    fixed-size assertion on the seeded set (7 nights) would have passed against the
    N+1 forever. This asserts the SHAPE instead: same statement count at 10 nights and
    at 200. Before the batching: 17 vs 207.
    """
    client, headers = seeded_client

    _seed_extra_nights(10)
    counter = _count_statements(monkeypatch)
    assert client.get("/api/sleep?days=365", headers=headers).status_code == 200
    at_10 = counter["n"]

    _seed_extra_nights(200)
    counter["n"] = 0
    resp = client.get("/api/sleep?days=365", headers=headers)
    assert resp.status_code == 200
    at_200 = counter["n"]

    assert len(resp.json()["nights"]) > 100, "fixture did not actually add nights"
    assert at_200 == at_10, (
        f"/api/sleep issued {at_10} statements over 10 nights but {at_200} over 200 — "
        "the cost is scaling with the owner's history (N+1)"
    )
    assert at_200 < _MAX_SLEEP_QUERIES, f"/api/sleep ran {at_200} statements"


def test_today_latency_under_budget(seeded_client: tuple) -> None:
    """Sanity latency check on the seeded set (real budget is p95 < 100 ms)."""
    client, headers = seeded_client
    client.get("/api/today", headers=headers)  # warm the pool
    start = time.perf_counter()
    resp = client.get("/api/today", headers=headers)
    elapsed_ms = (time.perf_counter() - start) * 1000
    assert resp.status_code == 200
    assert elapsed_ms < 500, f"/api/today took {elapsed_ms:.0f} ms on the seeded set"
