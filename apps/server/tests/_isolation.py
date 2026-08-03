"""Per-run isolation for the integration suite: a private database AND a private role.

## Why a separate DATABASE is not enough — the sentence that saves the hour (#119)

`tests/conftest.py::app_role_pool` provisions a login role with a **fresh random
password** and `DROP ROLE`s it at the end of the run. A role is a **cluster-level**
object: two suites against one PostgreSQL *instance* meet the same role even when
they are pointed at different databases. So the obvious mitigation — give each run
its own database — does not work, and fails in a way that reads like a code bug:

* the second run's `provision_app_role` ALTERs the password out from under the first
  run's already-open pool, so its next connection fails to authenticate;
* whichever run finishes first `DROP OWNED BY` + `DROP ROLE`s the role the other is
  still connecting as, and every subsequent test in the survivor dies on a role that
  no longer exists.

Measured on 2026-08-03, two full suites started together against one container: one
finished `2205 passed` in 3m44s, the other produced 14 errors and a growing wall of
failures and had gone through 64 of 2205 tests when the 15-minute timeout killed it.
The failures land in **unrelated code, in both directions**, which is the dangerous
part: the noise is indistinguishable from a real regression, so the natural reaction
is to go debug an innocent diff. With this module in place the same pair both finish
`2205 passed`, in 3m10s and 3m12s.

Isolation therefore needs both halves, and this module owns both:

* a private **database**, because the seed fixtures `TRUNCATE` shared tables;
* a private **role**, because the database does not cover a cluster-scoped object.

## The run id

`<pid>_<random>`. The PID is there for humans — an orphaned `healthee_test_…` left
by a `kill -9` names the process that leaked it. The random half is what makes
collision impossible: PIDs are recycled, and a recycled PID would let a later run
`DROP` a live run's role, which is the exact failure being fixed here. Every process
gets its own id, so `pytest-xdist` workers are covered without a special case.

A run killed hard (SIGKILL, or a pulled container) skips the teardown and leaves its
database and role behind. That is why the documented recipe is a **throwaway
container** — see CONTRIBUTING.md "Running the server suite" for the drop one-liner
when a long-lived local container has collected some.
"""

from __future__ import annotations

import os
import secrets

import psycopg
from psycopg import sql

# One id per PROCESS, fixed at import. Everything cluster- or database-scoped that
# this suite creates carries it.
RUN_ID = f"{os.getpid()}_{secrets.token_hex(3)}"

# The suite's own app role. Named `_test` so it can never be confused with (or drop)
# a real deployment's `healthee_app`; suffixed so two runs cannot share one.
TEST_APP_ROLE = f"healthee_app_test_{RUN_ID}"

# The suite's own database, created from the configured one and dropped afterwards.
TEST_DATABASE = f"healthee_test_{RUN_ID}"


def create_database(admin_url: str) -> None:
    """Create this run's private database. `admin_url` points at the CONFIGURED one.

    Autocommit because `CREATE DATABASE` is refused inside a transaction block, and
    psycopg3 opens one before the first statement otherwise.
    """
    with psycopg.connect(admin_url, autocommit=True) as conn:
        conn.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(TEST_DATABASE)))


def drop_database(admin_url: str) -> None:
    """Drop this run's database, taking any lingering connection with it.

    `WITH (FORCE)` terminates backends still attached (PG13+). Without it a single
    leaked connection — a pool a test forgot to close — turns teardown into a hard
    error and leaves the database behind for good.
    """
    with psycopg.connect(admin_url, autocommit=True) as conn:
        conn.execute(
            sql.SQL("DROP DATABASE IF EXISTS {} WITH (FORCE)").format(sql.Identifier(TEST_DATABASE))
        )
