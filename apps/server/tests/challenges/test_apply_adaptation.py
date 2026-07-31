"""Applying a recalibration — the server-authoritative half of §5.2.

``test_adapt_rules`` pins the arithmetic and ``test_adapt`` pins what the engine is
willing to adapt ON. This pins what happens when the owner says yes: the target that
LANDS is the one the server just recomputed from their own rows, and nothing else can
put a number there.

Mutation testing is why this file exists: the endpoint tests only exercised the
"nothing is due" path, so replacing the stored value with an arbitrary 50,000 broke
no test at all.

Auto-skips without a reachable TimescaleDB (the suite-wide policy).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges import lifecycle
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.db import migrate

pytestmark = pytest.mark.integration

IST = SENTINEL_TZ
_START = date(2026, 3, 1)
_TODAY = date(2026, 3, 7)
_ADOPTED = datetime(2026, 3, 1, 6, 0, tzinfo=UTC)  # 11:30 IST on 03-01


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _beating_it(cur, target: float = 5000.0) -> int:
    """A live challenge the owner is averaging 6000 against — ratio 1.2, a raise is due."""
    _seed.seed_metric(
        cur, _seed.OWNER, "steps_total", {_START + timedelta(days=i): 6000.0 for i in range(7)}
    )
    return _seed.seed_challenge(
        cur,
        _seed.OWNER,
        status="active",
        adopted_at=_ADOPTED,
        target_value=target,
        window_days=14,
    )


def test_the_target_that_lands_is_the_one_the_server_computed(clean_db: None) -> None:  # noqa: ARG001
    """5000 × 1.2 = 6000, under the 8000 steps ideal — and 6000 is what is STORED.

    The stored value is asserted separately from the returned suggestion on purpose:
    a service that reported the right number and wrote a different one would satisfy
    either assertion alone.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        cid = _beating_it(cur)
        result = lifecycle.apply_adaptation(cur, _seed.OWNER, IST, cid, today=_TODAY)
        stored = _seed.stored(cur, _seed.OWNER, cid)
    assert result["ok"] is True
    assert (result["adaptation"]["direction"], result["adaptation"]["suggested"]) == ("up", 6000.0)
    assert stored["target_value"] == 6000.0
    assert result["challenge"]["target_value"] == 6000.0


def test_nothing_due_is_a_named_refusal_and_leaves_the_target_alone(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Inside the productive band the honest answer is "leave it" — and it must say so.

    6000 against a 6000 target is ratio 1.0. A commitment the owner agreed to does
    not move for no reason.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        cid = _beating_it(cur, target=6000.0)
        result = lifecycle.apply_adaptation(cur, _seed.OWNER, IST, cid, today=_TODAY)
        stored = _seed.stored(cur, _seed.OWNER, cid)
    assert (result["ok"], result["reason"]) == (False, "no_adaptation")
    assert stored["target_value"] == 6000.0


@pytest.mark.parametrize("status", ["suggested", "completed", "abandoned"])
def test_only_a_live_challenge_can_be_recalibrated(
    clean_db: None,  # noqa: ARG001
    status: str,
) -> None:
    """A finished challenge's target is part of its record; moving it rewrites history."""
    with tenant_transaction(_seed.OWNER) as cur:
        cid = _beating_it(cur)
        cur.execute(
            "UPDATE challenge SET status = %s WHERE user_id = %s AND id = %s",
            (status, _seed.OWNER, cid),
        )
        result = lifecycle.apply_adaptation(cur, _seed.OWNER, IST, cid, today=_TODAY)
        stored = _seed.stored(cur, _seed.OWNER, cid)
    assert (result["ok"], result["reason"]) == (False, "not_active")
    assert stored["target_value"] == 5000.0


def test_an_unknown_challenge_is_refused_by_name(clean_db: None) -> None:  # noqa: ARG001
    with tenant_transaction(_seed.OWNER) as cur:
        result = lifecycle.apply_adaptation(cur, _seed.OWNER, IST, 987654, today=_TODAY)
    assert (result["ok"], result["reason"]) == (False, "not_found")


def test_one_owner_cannot_recalibrate_anothers_challenge(clean_db: None) -> None:  # noqa: ARG001
    """B's id does not resolve for A, so there is nothing to move."""
    _seed.ensure_owner_b()
    try:
        with tenant_transaction(_seed.OTHER_OWNER) as cur:
            _seed.seed_metric(
                cur,
                _seed.OTHER_OWNER,
                "steps_total",
                {_START + timedelta(days=i): 6000.0 for i in range(7)},
            )
            b_id = _seed.seed_challenge(
                cur,
                _seed.OTHER_OWNER,
                status="active",
                adopted_at=_ADOPTED,
                target_value=5000.0,
                window_days=14,
            )
        with tenant_transaction(_seed.OWNER) as cur:
            result = lifecycle.apply_adaptation(cur, _seed.OWNER, IST, b_id, today=_TODAY)
        with tenant_transaction(_seed.OTHER_OWNER) as cur:
            stored = _seed.stored(cur, _seed.OTHER_OWNER, b_id)
    finally:
        _seed.remove_owner_b()
    assert (result["ok"], result["reason"]) == (False, "not_found")
    assert stored["target_value"] == 5000.0
