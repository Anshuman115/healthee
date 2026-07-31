"""Two-owner isolation for the challenge lifecycle (WP-C2).

Split from ``test_lifecycle`` because these prove a different property: not that the
state machine is correct, but that it is correct **for one owner at a time**. Legacy
had no ``user_id`` anywhere (CHALLENGES.md §2.4), so every one of these is a bug the
port could reintroduce without a single behavioural test noticing.

Both owners always hold IDENTICALLY-SHAPED rows, so a leak surfaces as the wrong
ANSWER rather than a row-count wobble — the silent-wrongness shape.

Note which mechanism catches what: the explicit ``AND user_id = %s`` in
``challenges/store.py`` is the filter, `0008`'s RLS is the backstop underneath it,
and ``tests/db/test_tenant_read_scoping.py`` (an AST guard) is what fails the build
if a future statement drops the predicate. With RLS live, dropping it may still
return the right rows at runtime — which is exactly why the guard exists.

Auto-skips without a reachable TimescaleDB (the suite-wide policy).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges import lifecycle, store
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.db import migrate

pytestmark = pytest.mark.integration

IST = SENTINEL_TZ
_START = date(2026, 3, 1)
_TODAY = date(2026, 3, 7)
_ADOPTED = datetime(2026, 3, 1, 6, 0, tzinfo=UTC)  # 11:30 IST on 03-01


@pytest.fixture
def two_owners(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    _seed.ensure_owner_b()
    yield
    _seed.reset()
    _seed.remove_owner_b()


def _week(cur, owner, values: list[float], metric: str = "steps_total") -> None:
    _seed.seed_metric(
        cur, owner, metric, {_START + timedelta(days=i): v for i, v in enumerate(values)}
    )


def test_one_owner_filling_the_cap_does_not_block_another(two_owners: None) -> None:  # noqa: ARG001
    """THE per-owner test. Legacy's cap was global, and this is what that would do.

    Owner A takes all three slots; owner B must still be able to adopt their first.
    A global count would refuse B with "already running 3 of 3" — challenges they
    have never seen.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        for _ in range(lifecycle.MAX_ACTIVE):
            cid = _seed.seed_challenge(cur, _seed.OWNER)
            lifecycle.adopt(cur, _seed.OWNER, IST, cid, today=_START)
    with tenant_transaction(_seed.OTHER_OWNER) as cur:
        b_id = _seed.seed_challenge(cur, _seed.OTHER_OWNER)
        result = lifecycle.adopt(cur, _seed.OTHER_OWNER, IST, b_id, today=_START)
        assert store.count_active(cur, _seed.OTHER_OWNER) == 1
    assert result["ok"] is True


def test_one_owner_cannot_adopt_or_abandon_anothers_challenge(two_owners: None) -> None:  # noqa: ARG001
    """B's id does not resolve for A at all — not "forbidden", simply not there.

    A 403 for the ids that exist and a 404 for the ones that do not would confirm
    another tenant's ids to anyone who asked (MULTI_USER.md §10).
    """
    with tenant_transaction(_seed.OTHER_OWNER) as cur:
        b_id = _seed.seed_challenge(cur, _seed.OTHER_OWNER)
        lifecycle.adopt(cur, _seed.OTHER_OWNER, IST, b_id, today=_START)
    with tenant_transaction(_seed.OWNER) as cur:
        adopted = lifecycle.adopt(cur, _seed.OWNER, IST, b_id, today=_START)
        abandoned = lifecycle.abandon(cur, _seed.OWNER, IST, b_id, today=_TODAY)
    assert (adopted["reason"], abandoned["reason"]) == ("not_found", "not_found")
    with tenant_transaction(_seed.OTHER_OWNER) as cur:
        assert _seed.stored(cur, _seed.OTHER_OWNER, b_id)["status"] == "active"


def test_finalizing_one_owner_never_touches_another(two_owners: None) -> None:  # noqa: ARG001
    """Both owners hold an identically-shaped finished challenge; only A's is closed."""
    ids = {}
    for owner in (_seed.OWNER, _seed.OTHER_OWNER):
        with tenant_transaction(owner) as cur:
            _week(cur, owner, [9000.0] * 7)
            ids[owner] = _seed.seed_challenge(cur, owner, status="active", adopted_at=_ADOPTED)
    with tenant_transaction(_seed.OWNER) as cur:
        lifecycle.finalize_due(cur, _seed.OWNER, IST, _TODAY)
    with tenant_transaction(_seed.OTHER_OWNER) as cur:
        assert _seed.stored(cur, _seed.OTHER_OWNER, ids[_seed.OTHER_OWNER])["status"] == "active"
    with tenant_transaction(_seed.OWNER) as cur:
        assert _seed.stored(cur, _seed.OWNER, ids[_seed.OWNER])["status"] == "completed"


def test_the_feed_never_shows_another_owners_challenges(two_owners: None) -> None:  # noqa: ARG001
    with tenant_transaction(_seed.OTHER_OWNER) as cur:
        _seed.seed_challenge(cur, _seed.OTHER_OWNER, title="B's own")
    with tenant_transaction(_seed.OWNER) as cur:
        mine = _seed.seed_challenge(cur, _seed.OWNER, title="A's own")
        feed = lifecycle.list_challenges(cur, _seed.OWNER, IST, today=_TODAY)
    assert [c["id"] for c in feed["suggested"]] == [mine]
