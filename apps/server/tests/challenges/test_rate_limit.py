"""The per-owner daily generation budget (``core.rate_limit``).

Three properties, and only one of them is the obvious one:

* the limit HOLDS — the (limit + 1)-th spend is refused, and it says when it resets;
* it is PER OWNER — a second tenant is untouched by the first's exhaustion. This is the
  one that would fail silently if the kv key ever grew a shared namespace, and it is the
  reason the counter is on a table whose PRIMARY KEY already carries the owner;
* it RESETS on the owner's local day, not the server's — the calendar-date-vs-instant bug
  class has already shipped two wrong numbers in this repo.

Integration, because the whole mechanism IS the one SQL statement.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime
from zoneinfo import ZoneInfo

import pytest
from tests.challenges import _seed

from healthee.core import rate_limit
from healthee.core.db import tenant_transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration

_FEATURE = "test_generation"
_LIMIT = 3

# 20:00 IST on the 15th — an instant whose UTC calendar date (14:30 on the 15th) is the
# same day, and whose local midnight is unambiguous. The point of pinning it is that
# every assertion below is about the OWNER's day.
_IST = "Asia/Kolkata"
_EVENING = datetime(2026, 7, 15, 20, 0, tzinfo=ZoneInfo(_IST))


@pytest.fixture
def clean_kv(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.ensure_owner_b()
    _clear_counters()
    yield
    _clear_counters()
    _seed.remove_owner_b()


def _clear_counters() -> None:
    """Drop both owners' kv rows — a leftover counter is a test that passes for free."""
    for owner in (_seed.OWNER, _seed.OTHER_OWNER):
        with tenant_transaction(owner) as cur:
            cur.execute("DELETE FROM kv WHERE user_id = %s", (owner,))


def test_the_limit_holds_and_says_when_it_lifts(clean_kv: None) -> None:  # noqa: ARG001
    """Three spends are the owner's; the fourth is refused with a real instant.

    "Try again later" without a when is the vague refusal standards §Errors forbids, so
    the verdict carries both the resetting instant and the seconds to it.
    """
    verdicts = [
        rate_limit.spend(_seed.OWNER, _IST, _FEATURE, _LIMIT, now=_EVENING) for _ in range(4)
    ]

    assert [v.allowed for v in verdicts] == [True, True, True, False]
    assert [v.used for v in verdicts] == [1, 2, 3, 4]
    refused = verdicts[-1]
    assert refused.resets_at == datetime(2026, 7, 16, 0, 0, tzinfo=ZoneInfo(_IST))
    assert refused.retry_after_s == 4 * 60 * 60  # 20:00 → midnight, in the owner's zone


def test_the_budget_is_per_owner(clean_kv: None) -> None:  # noqa: ARG001
    """A exhausts their day; B has spent nothing and is unaffected.

    The isolation is `0004`'s folded kv PRIMARY KEY, not a prefix in the key string —
    which is exactly why it is asserted rather than assumed.
    """
    for _ in range(_LIMIT + 1):
        rate_limit.spend(_seed.OWNER, _IST, _FEATURE, _LIMIT, now=_EVENING)

    b_first = rate_limit.spend(_seed.OTHER_OWNER, _IST, _FEATURE, _LIMIT, now=_EVENING)

    assert (b_first.allowed, b_first.used) == (True, 1)
    assert not rate_limit.spend(_seed.OWNER, _IST, _FEATURE, _LIMIT, now=_EVENING).allowed


def test_the_counter_resets_on_the_owners_local_day(clean_kv: None) -> None:  # noqa: ARG001
    """A new local day is a new budget — and the row is REUSED, not accumulated.

    The date lives in the value rather than the key precisely so ``kv`` carries one row
    per owner per feature for the life of the account (``core/rate_limit.py``); a test
    that only checked the count would pass with a key-per-day encoding too.
    """
    for _ in range(_LIMIT + 1):
        rate_limit.spend(_seed.OWNER, _IST, _FEATURE, _LIMIT, now=_EVENING)

    tomorrow = rate_limit.spend(_seed.OWNER, _IST, _FEATURE, _LIMIT, now=_EVENING.replace(day=16))

    assert (tomorrow.allowed, tomorrow.used) == (True, 1)
    with tenant_transaction(_seed.OWNER) as cur:
        cur.execute("SELECT count(*) FROM kv WHERE user_id = %s", (_seed.OWNER,))
        found = cur.fetchone()
    assert found is not None and found[0] == 1


def test_the_day_is_the_owners_and_not_the_servers(clean_kv: None) -> None:  # noqa: ARG001
    """02:00 IST on the 16th is still the 15th in UTC — and the budget follows the owner.

    A limiter anchored to the server's date would hand this owner a fresh budget two and a
    half hours early (or late, for a negative offset), which is the same class of bug the
    dob and baseline anchors already shipped.
    """
    for _ in range(_LIMIT):
        rate_limit.spend(_seed.OWNER, _IST, _FEATURE, _LIMIT, now=_EVENING)

    just_past_local_midnight = datetime(2026, 7, 15, 20, 30, tzinfo=UTC)  # 02:00 IST, 16th
    fresh = rate_limit.spend(_seed.OWNER, _IST, _FEATURE, _LIMIT, now=just_past_local_midnight)

    assert (fresh.allowed, fresh.used) == (True, 1)


def test_a_refund_gives_back_exactly_one_and_never_mints_budget(clean_kv: None) -> None:  # noqa: ARG001
    """The un-charge for a refusal that never reached the model, floored at zero.

    Floored because a refund arriving without a matching spend must not create budget
    from nothing — the counter is a record of requests, and a negative one is a lie about
    what happened.
    """
    rate_limit.spend(_seed.OWNER, _IST, _FEATURE, _LIMIT, now=_EVENING)
    for _ in range(3):
        rate_limit.refund(_seed.OWNER, _IST, _FEATURE, now=_EVENING)

    after = rate_limit.spend(_seed.OWNER, _IST, _FEATURE, _LIMIT, now=_EVENING)

    assert (after.allowed, after.used) == (True, 1)


def test_a_refund_cannot_reach_into_a_day_that_has_already_rolled(clean_kv: None) -> None:  # noqa: ARG001
    """Yesterday's refund must not discount today: the update is guarded on the day."""
    rate_limit.spend(_seed.OWNER, _IST, _FEATURE, _LIMIT, now=_EVENING)
    tomorrow = _EVENING.replace(day=16)
    rate_limit.spend(_seed.OWNER, _IST, _FEATURE, _LIMIT, now=tomorrow)

    rate_limit.refund(_seed.OWNER, _IST, _FEATURE, now=_EVENING)  # yesterday's refund

    assert rate_limit.spend(_seed.OWNER, _IST, _FEATURE, _LIMIT, now=tomorrow).used == 2
