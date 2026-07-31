"""Integration tests for `0009_outcome_ledger` — the ledger's honesty in the schema.

The point of 0009 is that the caveat lives in the DDL, not in prose a future reader
(or a future prompt) can skip. So these assert against the DATABASE's own catalog
rather than the file: a column that exists only in `schema.sql` protects nobody.

Auto-skips without a reachable TimescaleDB (same policy as the other integration
tests).
"""

from __future__ import annotations

from collections.abc import Iterator

import psycopg
import pytest

from healthee.core.db import admin_connection, tenant_transaction, transaction
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.db import migrate

pytestmark = pytest.mark.integration


@pytest.fixture(autouse=True)
def clean_challenges(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on reachability
    """Leave `challenge` as found, across every owner.

    ADMIN + TRUNCATE for the same two reasons the other seeds give: the app role
    deliberately has no TRUNCATE, and a reset must clear rows an RLS-scoped
    connection cannot even see. CASCADE takes `challenge_outcome` with it via the FK.
    """
    yield
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("TRUNCATE challenge CASCADE")


def _columns(table: str) -> dict[str, str]:
    """{column: data_type} straight from `information_schema` — the DB's own answer."""
    with transaction() as cur:
        cur.execute(
            "SELECT column_name, data_type FROM information_schema.columns "
            "WHERE table_schema = 'public' AND table_name = %s",
            (table,),
        )
        return {row[0]: row[1] for row in cur.fetchall()}


def test_the_ledger_carries_the_confound_columns(db: None) -> None:  # noqa: ARG001
    """`confounds`, `data_confidence` and a direction-aware `improvement_pct` exist."""
    migrate.apply_migrations()
    columns = _columns("challenge_outcome")
    assert columns["confounds"] == "jsonb"
    assert columns["data_confidence"] == "text"
    assert columns["improvement_pct"] == "double precision"
    assert "delta_pct" not in columns, "the ambiguous name must be gone, not duplicated"


def test_downstream_is_gone_and_co_occurring_is_structured(db: None) -> None:  # noqa: ARG001
    """The rename IS the fix (§7.1) — and JSONB is what carries the caveat alongside.

    A TEXT `downstream` invites a sentence, and a sentence about another metric
    moving during the window is an attribution claim we cannot support with 2–4
    challenges running at once.
    """
    migrate.apply_migrations()
    columns = _columns("challenge_outcome")
    assert "downstream" not in columns
    assert columns["co_occurring"] == "jsonb"


def test_adherence_and_improvement_are_documented_as_different_numbers(
    db: None,  # noqa: ARG001
) -> None:
    """The DDL comments are the fix for §2.6, so they are part of the migration's job.

    Legacy's one `adherence` answered "did they show up" AND "did the metric move".
    `\\d+` must now be able to tell them apart without anyone reading a doc.
    """
    migrate.apply_migrations()
    with transaction() as cur:
        cur.execute(
            "SELECT c.column_name, col_description(%s::regclass, c.ordinal_position) "
            "FROM information_schema.columns c "
            "WHERE c.table_schema = 'public' AND c.table_name = 'challenge_outcome' "
            "  AND c.column_name IN ('adherence', 'improvement_pct', 'co_occurring')",
            ("challenge_outcome",),
        )
        comments = {row[0]: (row[1] or "") for row in cur.fetchall()}
    assert "Behaviour rate" in comments["adherence"]
    assert "NOT whether the metric moved" in comments["adherence"]
    assert "baseline -> final" in comments["improvement_pct"]
    assert "UNATTRIBUTED" in comments["co_occurring"]


def test_an_unknown_data_confidence_is_rejected(db: None) -> None:  # noqa: ARG001
    """The gate is only a gate if the database enforces its vocabulary.

    'insufficient_data' has to be a value the ledger can hold and a typo has to be a
    loud failure — a mislabelled confidence is worse than none, because it reads as
    a verified result.
    """
    migrate.apply_migrations()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "INSERT INTO challenge (user_id, title, why, category, metric, comparator, "
            "  target_value, cadence, window_days) "
            "VALUES (%s, 't', 'w', 'sleep', 'steps_total', '>=', 1, 'daily', 7) RETURNING id",
            (SENTINEL_USER_ID,),
        )
        challenge_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO challenge_outcome (user_id, challenge_id, data_confidence) "
            "VALUES (%s, %s, 'insufficient_data')",
            (SENTINEL_USER_ID, challenge_id),
        )
        with pytest.raises(psycopg.errors.CheckViolation):
            cur.execute(
                "UPDATE challenge_outcome SET data_confidence = 'probably_fine' "
                "WHERE user_id = %s AND challenge_id = %s",
                (SENTINEL_USER_ID, challenge_id),
            )


def test_a_challenge_cannot_hold_an_unknown_status(db: None) -> None:  # noqa: ARG001
    """`expired` is a real state; anything outside the vocabulary is refused.

    A challenge in a status no reader filters on is invisible — it stops being
    tracked and nobody is told. `expired` exists so a window that ran out unmet is
    never recorded as "completed" (§2.3).
    """
    migrate.apply_migrations()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "INSERT INTO challenge (user_id, title, why, category, metric, comparator, "
            "  target_value, cadence, window_days, status) "
            "VALUES (%s, 't', 'w', 'sleep', 'steps_total', '>=', 1, 'daily', 7, 'expired')",
            (SENTINEL_USER_ID,),
        )
        with pytest.raises(psycopg.errors.CheckViolation):
            cur.execute(
                "INSERT INTO challenge (user_id, title, why, category, metric, comparator, "
                "  target_value, cadence, window_days, status) "
                "VALUES (%s, 't', 'w', 'sleep', 'steps_total', '>=', 1, 'daily', 7, 'donezo')",
                (SENTINEL_USER_ID,),
            )


def test_the_app_role_can_write_the_new_columns(db: None) -> None:  # noqa: ARG001
    """A table-level GRANT covers columns added by a LATER migration — proved, not assumed.

    If it did not, the ledger would be unwritable in production while every unit test
    stayed green, and the fastest 2am "fix" for that is handing back superuser
    (`provision_app_role`'s docstring makes the same argument).
    """
    migrate.apply_migrations()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute(
            "INSERT INTO challenge (user_id, title, why, category, metric, comparator, "
            "  target_value, cadence, window_days) "
            "VALUES (%s, 't', 'w', 'sleep', 'steps_total', '>=', 1, 'daily', 7) RETURNING id",
            (SENTINEL_USER_ID,),
        )
        challenge_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO challenge_outcome "
            "  (user_id, challenge_id, improvement_pct, confounds, co_occurring, data_confidence) "
            "VALUES (%s, %s, 12.5, %s, %s, 'ok')",
            (SENTINEL_USER_ID, challenge_id, '{"illness_days": 2}', '{"hrv_sleep_avg": 3.0}'),
        )
        cur.execute(
            "SELECT improvement_pct, confounds, co_occurring FROM challenge_outcome "
            "WHERE user_id = %s AND challenge_id = %s",
            (SENTINEL_USER_ID, challenge_id),
        )
        row = cur.fetchone()
    assert row is not None
    assert (row[0], row[1], row[2]) == (12.5, {"illness_days": 2}, {"hrv_sleep_avg": 3.0})
