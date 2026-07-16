"""The one database connection pool — every query in the app goes through here.

Decision (handed down): **sync** psycopg3 + `psycopg_pool.ConnectionPool`. The
science layer ports verbatim as synchronous code; FastAPI sync endpoints run in
the threadpool; single-tenant scale doesn't need async. No other module may open
a connection (standards §2: "DB access only via core/db … No module-local
`_connect()`").

Usage — the transaction helper commits on a clean exit and rolls back on any
exception (the pool's own connection context manager does this; we wrap it so
callers get a cursor directly):

    from healthee.core.db import transaction

    with transaction() as cur:
        cur.execute("INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, %s, %s)",
                    (user_id, ts, metric, value))
    # committed here; on exception the whole block is rolled back

Every tenant table needs the owner named explicitly: `0007` dropped the transitional
`user_id` DEFAULT, so a write that omits it now raises NotNullViolation rather than
silently attributing someone's health data to the sentinel.
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager

from psycopg import Connection, Cursor
from psycopg.rows import TupleRow
from psycopg_pool import ConnectionPool

from healthee.core.config import get_settings
from healthee.core.logging import get_logger

log = get_logger(__name__)

# Single-tenant scale: a small pool is plenty. Sync FastAPI endpoints run in the
# threadpool (default ~40 workers), so cap well below that to bound DB load.
_POOL_MIN_SIZE = 1
_POOL_MAX_SIZE = 10

_Pool = ConnectionPool[Connection[TupleRow]]
_pool: _Pool | None = None


def get_pool() -> _Pool:
    """Return the process-wide connection pool, opening it on first use.

    Lazy so importing this module never touches the network or requires config —
    the pool opens the first time a query is actually run.
    """
    global _pool
    if _pool is None:
        settings = get_settings()
        pool: _Pool = ConnectionPool(
            conninfo=settings.db_url,
            min_size=_POOL_MIN_SIZE,
            max_size=_POOL_MAX_SIZE,
            name="healthee",
            open=False,  # explicit open() avoids the constructor-open deprecation
        )
        pool.open()
        log.info(
            "opened db pool: %s:%s/%s (min=%d max=%d)",
            settings.postgres_host,
            settings.postgres_port,
            settings.postgres_db,
            _POOL_MIN_SIZE,
            _POOL_MAX_SIZE,
        )
        _pool = pool
    return _pool


@contextmanager
def connection() -> Iterator[Connection[TupleRow]]:
    """Borrow a pooled connection as a transaction scope.

    Commits on a clean exit, rolls back on any exception, and returns the
    connection to the pool either way. Use this when a unit of work needs several
    cursors; use `transaction()` for the common single-cursor case.
    """
    with get_pool().connection() as conn:
        yield conn


@contextmanager
def transaction() -> Iterator[Cursor[TupleRow]]:
    """Borrow a connection and yield a cursor in one transaction.

    Commit-on-success / rollback-on-exception is handled by the underlying
    connection context manager. The most ergonomic entry point for a single
    statement or a small batch.
    """
    with get_pool().connection() as conn, conn.cursor() as cur:
        yield cur


def close_pool() -> None:
    """Close the pool and drop the singleton. Called at app shutdown and between
    tests so the next `get_pool()` rebuilds against fresh config."""
    global _pool
    if _pool is not None:
        _pool.close()
        _pool = None
        log.info("closed db pool")
