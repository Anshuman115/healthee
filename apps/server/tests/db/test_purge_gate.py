"""D5 — the gated-metric refusal is enforced beside the DELETE, not only at the CLI.

`stale_derived.purge_stale` is the only `DELETE` against `derived_daily` in the tree, and
the one way this feature can destroy CORRECT data is a compute-once metric whose gate the
running repair did not re-open: `derive/gps_scoring.py` scores a track at most once, so a
plain run never re-attempts `vo2max_submax` and every correctly-scored session's row
matches "not written by this run" while being perfectly current.

That refusal used to live in `rederive.purge_metrics`, whose only caller is `main`.
`rederive.run` and `rederive_owner` both take `purge=` and `applying=` directly and passed
them straight through, applying neither refusal. No such caller exists today — which is
precisely why this file exists: a guard one layer away from the thing it guards is a
caveat about which door you came in by, and the module's own argument is that this is "a
refusal with the fix in the message, not a caveat in the docs".

Everything here runs on the ADMIN connection, past every layer that could be doing the
work, so what is asserted is the delete's own guard and nothing else. The CLI's copy of
the same refusal is covered by `test_stale_derived.py`.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import date, timedelta
from uuid import UUID

import pytest

from healthee.core.db import admin_connection
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.db import migrate
from healthee.db.stale_derived import PurgeRefusedError, purge_stale

pytestmark = pytest.mark.integration

# The compute-once metric, and the flag that re-opens its gate.
_GATED = "vo2max_submax"
_FLAG = "--rescore-tracks"

# One ordinary metric beside it, so "only the gated name is refused" is observable.
_PLAIN = "vo2max_estimate"


@pytest.fixture
def day(db: None) -> Iterator[date]:  # noqa: ARG001 — gates on DB reachability
    """An empty derived layer for the sentinel, and the day these rows sit on."""
    migrate.apply_migrations()
    on = date.today() - timedelta(days=1)
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM derived_daily WHERE user_id = %s", (SENTINEL_USER_ID,))
    yield on
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM derived_daily WHERE user_id = %s", (SENTINEL_USER_ID,))


def _plant(on: date, metric: str, user_id: UUID = SENTINEL_USER_ID) -> None:
    """A row written by code that no longer runs — old `derived_at`, so it reads stale."""
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags, derived_at) "
            "VALUES (%s, %s, %s, 42.3, '{}'::jsonb, now() - interval '30 days') "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET derived_at = EXCLUDED.derived_at",
            (user_id, on, metric),
        )


def _metrics(user_id: UUID = SENTINEL_USER_ID) -> set[str]:
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("SELECT metric FROM derived_daily WHERE user_id = %s", (user_id,))
        return {row[0] for row in cur.fetchall()}


def test_a_gated_metric_is_refused_by_the_delete_itself(day: date) -> None:
    """THE finding. Reached past the CLI, the refusal must still fire."""
    _plant(day, _GATED)

    with (
        admin_connection() as conn,
        conn.cursor() as cur,
        pytest.raises(PurgeRefusedError, match=_FLAG),
    ):
        purge_stale(cur, SENTINEL_USER_ID, (day, day), [_GATED], gates=frozenset())

    assert _GATED in _metrics(), "a refused purge deleted the row anyway"


def test_the_refusal_names_the_flag_that_fixes_it(day: date) -> None:
    """The fix is in the message, not in the docs — that is the module's own rule."""
    _plant(day, _GATED)

    with (
        admin_connection() as conn,
        conn.cursor() as cur,
        pytest.raises(PurgeRefusedError) as raised,
    ):
        purge_stale(cur, SENTINEL_USER_ID, (day, day), [_GATED], gates=frozenset())

    message = str(raised.value)
    assert _GATED in message
    assert "only LOOK stale" in message


def test_one_gated_name_refuses_the_whole_request(day: date) -> None:
    """A batch is refused entire rather than partially applied.

    Deleting the metrics that happened to be safe and reporting a refusal for the rest
    would leave the operator holding a half-done repair they did not ask for, and the
    counts they were shown would describe neither state.
    """
    _plant(day, _GATED)
    _plant(day, _PLAIN)

    with (
        admin_connection() as conn,
        conn.cursor() as cur,
        pytest.raises(PurgeRefusedError),
    ):
        purge_stale(cur, SENTINEL_USER_ID, (day, day), [_PLAIN, _GATED], gates=frozenset())

    assert _metrics() == {_GATED, _PLAIN}, "part of a refused batch was applied"


def test_the_delete_proceeds_once_the_gate_is_named(day: date) -> None:
    """The other half: the refusal must not be a blanket one.

    A run that DID re-open the gate has re-attempted the metric, so a row it still did not
    write really is stale and removing it is the whole point of the tool.
    """
    _plant(day, _GATED)

    with admin_connection() as conn, conn.cursor() as cur:
        removed = purge_stale(cur, SENTINEL_USER_ID, (day, day), [_GATED], gates=frozenset({_FLAG}))

    assert removed == {_GATED: 1}
    assert _GATED not in _metrics()


def test_an_ungated_metric_is_untouched_by_the_check(day: date) -> None:
    """The check must not become a general refusal — the ordinary repair still works."""
    _plant(day, _PLAIN)

    with admin_connection() as conn, conn.cursor() as cur:
        removed = purge_stale(cur, SENTINEL_USER_ID, (day, day), [_PLAIN], gates=frozenset())

    assert removed == {_PLAIN: 1}
    assert _PLAIN not in _metrics()
