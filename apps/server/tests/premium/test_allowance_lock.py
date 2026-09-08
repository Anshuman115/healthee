"""D6 — the row lock the allowance spend is built on, tested as a lock.

`core/allowance.py` spends a full docstring section arguing why the spend is serialized by
`SELECT … FOR UPDATE` inside one transaction rather than by one self-modifying statement:
the operation is a *set edit* — prune, decide, maybe append — that must also report
**whether it appended**, and a statement returning only the new value cannot say. The
reasoning is right, and `test_allowance_ledger.py` drives an injectable `now` through a
single connection and never runs two transactions against each other. The one property the
lock exists for was the one property untested.

Two shapes, and both are here because they prove different things:

* **the deterministic one.** A held lock, a second spender that must WAIT for it, and an
  assertion that what the second one finally reads is *committed truth* rather than the
  empty window it would have read had it gone first. This is the failure the lock prevents,
  reproduced on purpose rather than hoped for;
* **the plain race.** Several threads calling `spend` at `limit=1` with no coordination,
  asserting exactly one is granted. It cannot prove interleaving happened, but it can only
  ever fail if the lock is gone.

Threads, not processes: the pool is process-wide and hands each thread its own connection
(`_POOL_MAX_SIZE` is 10), which is exactly the shape a FastAPI worker has.
"""

from __future__ import annotations

import threading
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as FutureTimeout
from datetime import UTC, datetime
from uuid import UUID

import pytest
from tests.conftest import entitle

from healthee.core import allowance
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID

pytestmark = [
    pytest.mark.integration,
    pytest.mark.usefixtures("owner_sweep"),
]

FEATURE = "coach"

# The same unremarkable instant `test_allowance_ledger.py` anchors on: mid-week, nowhere
# near a midnight, so nothing here can pass by landing on a calendar boundary.
MONDAY_EVENING = datetime(2026, 3, 2, 21, 0, tzinfo=UTC)

# How long the blocked spender is given to prove it is blocked, and then to finish once
# the lock is released. The first is a floor on "it really waited"; the second is a
# ceiling that turns a deadlock into a failed assertion instead of a hung suite.
_BLOCKED_FOR_S = 0.5
_FINISH_WITHIN_S = 15.0


@pytest.fixture
def owner(db: None) -> UUID:  # noqa: ARG001 — the fixture is the database
    """The sentinel owner with an empty ledger."""
    from tests.contracts.seed import seed_all

    seed_all()
    entitle(SENTINEL_USER_ID, premium=False)
    return SENTINEL_USER_ID


def _spend(owner: UUID, *, limit: int = 1) -> allowance.Verdict:
    return allowance.spend(owner, SENTINEL_TZ, FEATURE, limit, now=MONDAY_EVENING)


def _claim_row(owner: UUID) -> str:
    """Create the empty ledger row and COMMIT it. Returns its key.

    Not scaffolding — it is what makes these tests test the lock. `spend` opens with
    `INSERT … ON CONFLICT DO NOTHING`, which *itself* blocks a concurrent inserter while
    the first transaction is open, so against a missing row the claim serializes the race
    and `FOR UPDATE` is never the thing under test. That is the transient first-use case;
    every call after it meets an existing row, where the claim is a no-op and the lock is
    the only serialization there is. Both mutation runs confirmed the difference: with
    `FOR UPDATE` removed, the versions of these tests that let `spend` create the row
    still passed.
    """
    key = allowance._key(FEATURE, allowance.WINDOW_DAYS)
    with tenant_transaction(owner) as cur:
        cur.execute(allowance._CLAIM_SQL, (owner, key))
    return key


def test_a_second_spender_waits_for_the_lock_and_reads_committed_truth(owner: UUID) -> None:
    """THE property. Without the lock both callers see an empty window and both proceed.

    The first transaction claims and locks the row and then holds it, deliberately, while
    a second thread calls the real `spend`. Two things are asserted and the pair is the
    proof: the second thread is still blocked while the lock is held (so it is waiting,
    not reading around it), and the verdict it eventually returns is a REFUSAL — the state
    the first transaction committed, not the empty window it would have seen had it gone
    first.
    """
    key = _claim_row(owner)
    started = threading.Event()

    def second() -> allowance.Verdict:
        started.set()
        return _spend(owner)

    with ThreadPoolExecutor(max_workers=1) as pool:
        with tenant_transaction(owner) as cur:
            cur.execute(allowance._LOCK_SQL, (owner, key))
            future = pool.submit(second)
            assert started.wait(timeout=_FINISH_WITHIN_S), "the second spender never started"
            # Still blocked: `result` raises rather than returning while we hold the row.
            # A verdict arriving here would mean the spend read around the lock entirely.
            with pytest.raises(FutureTimeout):
                future.result(timeout=_BLOCKED_FOR_S)
            # Spend the owner's single slot, and commit by leaving the block.
            cur.execute(allowance._WRITE_SQL, (allowance._encode([MONDAY_EVENING]), owner, key))
        verdict = future.result(timeout=_FINISH_WITHIN_S)

    assert verdict.allowed is False, (
        "the second spender granted a slot the committed window had already used"
    )
    assert verdict.used == 1


def test_only_one_of_several_racing_spends_is_granted(owner: UUID) -> None:
    """The cheapest possible test of the most expensive possible bug on this path.

    Eight threads, one slot. Without serialization several read "zero used" together and
    several are granted; the ledger then holds one instant and the owner has had eight
    answers for it.
    """
    _claim_row(owner)
    with ThreadPoolExecutor(max_workers=8) as pool:
        verdicts = list(pool.map(lambda _: _spend(owner), range(8)))

    assert sum(1 for v in verdicts if v.allowed) == 1
    assert allowance.peek(owner, SENTINEL_TZ, FEATURE, 1, now=MONDAY_EVENING).used == 1


def test_a_race_at_a_higher_limit_grants_exactly_the_limit(owner: UUID) -> None:
    """The window is a count, not a flag, so the same must hold above one.

    A lock that only ever admitted the first caller would pass the test above and still be
    wrong here: three slots must produce three grants and five refusals, never four.
    """
    _claim_row(owner)
    with ThreadPoolExecutor(max_workers=8) as pool:
        verdicts = list(pool.map(lambda _: _spend(owner, limit=3), range(8)))

    assert sum(1 for v in verdicts if v.allowed) == 3
    assert allowance.peek(owner, SENTINEL_TZ, FEATURE, 3, now=MONDAY_EVENING).used == 3
