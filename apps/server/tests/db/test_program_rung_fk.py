"""Integration tests for `0013` — a rung belongs to its ladder in the DATABASE.

`challenge.program_id` shipped as a bare `BIGINT` (legacy's shape, ported in `0001`),
so the only thing tying a rung to its program was `program_store` remembering to
delete both. These assert against the live catalog and live rows rather than the
file: a constraint that exists only in `schema.sql` protects nobody, and the whole
point of `0013` is that the guarantee stops depending on anyone remembering it.

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
def clean_ladders(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on reachability
    """Leave `challenge` and `program` as found, across every owner.

    ADMIN + TRUNCATE for the reasons the other seeds give: the app role deliberately
    has no TRUNCATE, and a reset must clear rows an RLS-scoped connection cannot see.
    """
    migrate.apply_migrations()
    yield
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("TRUNCATE challenge, program CASCADE")


def _insert_program(cur: psycopg.Cursor) -> int:
    cur.execute(
        "INSERT INTO program (user_id, title, why, status) "
        "VALUES (%s, 'ladder', 'because', 'suggested') RETURNING id",
        (SENTINEL_USER_ID,),
    )
    row = cur.fetchone()
    assert row is not None
    return int(row[0])


def _insert_rung(cur: psycopg.Cursor, program_id: int | None, rung_index: int = 0) -> int:
    cur.execute(
        "INSERT INTO challenge (user_id, title, why, category, metric, comparator, "
        "  target_value, cadence, window_days, status, program_id, rung_index) "
        "VALUES (%s, 'rung', 'w', 'activity', 'steps_total', '>=', 8000, 'daily', 7, "
        "  'locked', %s, %s) RETURNING id",
        (SENTINEL_USER_ID, program_id, rung_index),
    )
    row = cur.fetchone()
    assert row is not None
    return int(row[0])


def test_a_rung_cannot_reference_a_program_that_does_not_exist(db: None) -> None:  # noqa: ARG001
    """The gap `0013` closes: `program_id` used to accept any integer at all.

    A rung pointing at nothing is not a recoverable state — `program_store.rungs`
    returns it to no ladder, the feed never lists a `locked` row, and `lifecycle.adopt`
    refuses it. It would simply sit there.
    """
    with (
        tenant_transaction(SENTINEL_USER_ID) as cur,
        pytest.raises(psycopg.errors.ForeignKeyViolation),
    ):
        _insert_rung(cur, 987654321)


def test_a_standalone_challenge_still_needs_no_program(db: None) -> None:  # noqa: ARG001
    """NULL means "not a rung" and must stay unconstrained — most challenges are that."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        challenge_id = _insert_rung(cur, None)
        cur.execute(
            "SELECT program_id FROM challenge WHERE user_id = %s AND id = %s",
            (SENTINEL_USER_ID, challenge_id),
        )
        row = cur.fetchone()
    assert row is not None
    assert row[0] is None


def test_deleting_a_program_takes_its_rungs_and_their_outcomes(db: None) -> None:  # noqa: ARG001
    """ON DELETE CASCADE — the chosen semantic, asserted rather than described.

    The outcome half matters too: `0009` cascades `challenge_outcome` off `challenge`,
    so the rows go together and no outcome is left keyed to a challenge that is gone.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        program_id = _insert_program(cur)
        rung_id = _insert_rung(cur, program_id)
        cur.execute(
            "INSERT INTO challenge_outcome (user_id, challenge_id, data_confidence) "
            "VALUES (%s, %s, 'ok')",
            (SENTINEL_USER_ID, rung_id),
        )
        cur.execute(
            "DELETE FROM program WHERE user_id = %s AND id = %s", (SENTINEL_USER_ID, program_id)
        )
        cur.execute("SELECT count(*) FROM challenge WHERE user_id = %s", (SENTINEL_USER_ID,))
        rungs = cur.fetchone()
        cur.execute(
            "SELECT count(*) FROM challenge_outcome WHERE user_id = %s", (SENTINEL_USER_ID,)
        )
        outcomes = cur.fetchone()
    assert rungs is not None and rungs[0] == 0, "the rung outlived its ladder"
    assert outcomes is not None and outcomes[0] == 0


def test_rekeying_a_program_moves_its_rungs(db: None) -> None:  # noqa: ARG001
    """ON UPDATE CASCADE — the action this repo has now been bitten by twice without.

    A FK missing it does not silently skip a re-key, it ERRORS (that is what `0006` had
    to go back and fix for `device_token`, and what §12.2's `subscription` sketch would
    have done to `claim_sentinel`). Here the rungs follow the id instead.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        program_id = _insert_program(cur)
        rung_id = _insert_rung(cur, program_id)
        cur.execute(
            "UPDATE program SET id = %s WHERE user_id = %s AND id = %s",
            (program_id + 5000, SENTINEL_USER_ID, program_id),
        )
        cur.execute(
            "SELECT program_id FROM challenge WHERE user_id = %s AND id = %s",
            (SENTINEL_USER_ID, rung_id),
        )
        row = cur.fetchone()
    assert row is not None
    assert row[0] == program_id + 5000, "the rung was left pointing at the old program id"


def test_the_constraint_declares_both_cascades(db: None) -> None:  # noqa: ARG001
    """The catalog's own answer, so a future migration cannot quietly weaken the actions.

    `confdeltype`/`confupdtype` are 'c' for CASCADE, 'n' for SET NULL, 'a' for NO ACTION.
    `SET NULL` would orphan a rung into a standalone commitment (`0013` argues why that
    is the wrong answer); this is what stops that being a one-word edit nobody notices.
    """
    with transaction() as cur:
        cur.execute(
            "SELECT confdeltype, confupdtype FROM pg_constraint "
            "WHERE conname = 'challenge_program_id_fkey' AND conrelid = 'challenge'::regclass"
        )
        row = cur.fetchone()
    assert row is not None, "0013's foreign key is not on the table"
    assert (row[0], row[1]) == ("c", "c")
