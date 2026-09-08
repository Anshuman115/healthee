"""`refresh=true` is metered; a cached read is not — `AUTH_AUDIT.md` E4.

Every insight route takes `refresh: bool = False` and forwards it, and
`insights/surfaces.py` skips the cache when it is true. The gate above them is
`InsightUser` / `NotableUser`, and `api.gate.PREMIUM_ALLOWANCE` holds one entry — the
coach. By that table's own documented semantics ("a feature ABSENT from this table is
UNLIMITED"), `INSIGHT` and `NOTABLE` were uncapped for a paying owner and
`core.rate_limit` was applied to neither, so polling `?refresh=true` spent the
OpenRouter budget in a loop.

The free half is the load-bearing half of this file. A limiter that charged the CACHED
read would lock a paying owner out of cards that cost nothing to serve — a worse bug
than the one being fixed, and invisible to a test that only counts refusals.
"""

from __future__ import annotations

import contextlib
from collections.abc import Iterator
from typing import cast
from uuid import uuid4

import pytest
from fastapi import HTTPException

from healthee.api.refresh_budget import REFRESHES_PER_DAY, charge_refresh
from healthee.core import db as db_module
from healthee.core.supabase_auth import RequestUser
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.db import migrate

pytestmark = [pytest.mark.integration, pytest.mark.usefixtures("owner_sweep")]

_TZ = "Asia/Kolkata"


@pytest.fixture
def owner(db: None) -> Iterator[RequestUser]:  # noqa: ARG001 — gates on a reachable DB
    """A real owner, because the ledger is a `kv` row under RLS."""
    migrate.apply_migrations()
    user_id = uuid4()
    with db_module.transaction() as cur:
        cur.execute("INSERT INTO app_user (id) VALUES (%s)", (str(user_id),))
    yield RequestUser(id=user_id, timezone=_TZ)
    db_module.close_pool()


def test_a_cached_read_costs_nothing_and_stays_costing_nothing(owner: RequestUser) -> None:
    """Far more calls than the budget, none of them a refresh, none of them refused."""
    for _ in range(REFRESHES_PER_DAY * 5):
        assert charge_refresh(owner, refresh=False) is False


def test_a_cached_read_writes_no_ledger_row_at_all(owner: RequestUser) -> None:
    """Not merely "allowed" — nothing is spent, so there is nothing to spend later.

    A limiter that counted reads and only REFUSED refreshes would pass the test above
    and still exhaust the owner's budget by looking at the Sleep tab.
    """
    charge_refresh(owner, refresh=False)
    with db_module.tenant_transaction(owner.id) as cur:
        cur.execute(
            "SELECT count(*) FROM kv WHERE user_id = %s AND key LIKE 'ratelimit:%%'",
            (owner.id,),
        )
        row = cur.fetchone()
    assert row is not None and row[0] == 0


def test_the_budgeted_refreshes_are_allowed(owner: RequestUser) -> None:
    for attempt in range(REFRESHES_PER_DAY):
        assert charge_refresh(owner, refresh=True) is True, f"refresh {attempt + 1} refused"


def test_the_refresh_after_the_budget_is_429(owner: RequestUser) -> None:
    for _ in range(REFRESHES_PER_DAY):
        charge_refresh(owner, refresh=True)
    with pytest.raises(HTTPException) as caught:
        charge_refresh(owner, refresh=True)
    assert caught.value.status_code == 429


def test_the_refusal_says_when_it_resets(owner: RequestUser) -> None:
    """ "Try again later" without a when is the vague refusal the standards forbid."""
    for _ in range(REFRESHES_PER_DAY):
        charge_refresh(owner, refresh=True)
    with pytest.raises(HTTPException) as caught:
        charge_refresh(owner, refresh=True)
    detail_map = cast("dict[str, object]", caught.value.detail)
    assert detail_map["reason"] == "insight_refreshes_spent"
    assert detail_map["limit"] == REFRESHES_PER_DAY
    assert detail_map["resets_at"]
    assert caught.value.headers is not None
    assert int(caught.value.headers["Retry-After"]) > 0


def test_a_spent_owner_can_still_read_their_cached_cards(owner: RequestUser) -> None:
    """The refusal is about the REWRITE, not about the card. Stated, and asserted."""
    for _ in range(REFRESHES_PER_DAY + 1):
        with contextlib.suppress(HTTPException):
            charge_refresh(owner, refresh=True)
    assert charge_refresh(owner, refresh=False) is False


def test_one_owners_budget_is_not_anothers(owner: RequestUser) -> None:
    """The ledger is per-owner; the sentinel is a second real owner to prove it."""
    for _ in range(REFRESHES_PER_DAY):
        charge_refresh(owner, refresh=True)
    with pytest.raises(HTTPException):
        charge_refresh(owner, refresh=True)
    other = RequestUser(id=SENTINEL_USER_ID, timezone=_TZ)
    assert charge_refresh(other, refresh=True) is True
