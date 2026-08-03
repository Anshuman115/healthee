"""The rolling allowance ledger itself — the window, the key, and the refund.

``test_premium_cap.py`` proves the GATE spends this correctly over HTTP. This file proves
the thing underneath it is a *rolling N local days* and not a calendar period wearing its
name, which is the whole difference between what ``PRICING.md`` promises and what
``core.rate_limit`` would have delivered.

Two windows now run on it — a premium owner's 30 days (``gate.PREMIUM_WINDOW_DAYS``) and
the 7 days a re-granted free taste would use — so the window is a *parameter*, and both
the arithmetic and the **kv key** are exercised at both lengths. The key matters as much as
the arithmetic: a stored instant means nothing without the window it is counted in, so one
key shared by two windows would have each tier spending the other's ledger.

Every window assertion drives the injectable ``now``, because a rule that can only be
exercised by waiting a month is one nobody exercises (``core.entitlement.evaluate``
records the same reason).

The ledger is per owner, so the two-owner case runs against a real database with RLS
underneath rather than being argued from the SQL.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

import pytest
from tests.conftest import entitle

from healthee.core import allowance
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID

pytestmark = [
    pytest.mark.integration,
    # `seed_owner_b` provisions owner B and nothing removed it. `--user`-less ops
    # tooling walks every active owner it finds, so the stray is not free (#119).
    pytest.mark.usefixtures("owner_sweep"),
]

FEATURE = "coach"

# A fixed, unremarkable instant to anchor every window assertion: 21:00 on a Monday, in
# the middle of the week and nowhere near a midnight, so a rule that secretly reset on a
# calendar boundary cannot pass by coincidence.
MONDAY_EVENING = datetime(2026, 3, 2, 21, 0, tzinfo=UTC)

# A zone that actually observes DST, for the 30-day window. `SENTINEL_TZ` is Asia/Kolkata,
# which never shifts — so every local-vs-absolute assertion made in it passes either way.
DST_TZ = "America/New_York"
DST_ZONE = ZoneInfo(DST_TZ)


@pytest.fixture
def owner(db: None) -> UUID:  # noqa: ARG001 — the fixture is the database
    """The sentinel owner with an empty ledger (``seed_all``'s reset truncates ``kv``)."""
    from tests.contracts.seed import seed_all

    seed_all()
    entitle(SENTINEL_USER_ID, premium=False)
    return SENTINEL_USER_ID


def spend(
    owner: UUID, now: datetime, *, limit: int = 1, window_days: int = 7, tz: str = SENTINEL_TZ
) -> allowance.Verdict:
    return allowance.spend(owner, tz, FEATURE, limit, now=now, window_days=window_days)


# ── the window rolls with the USE, not with the calendar ──────────────────────


def test_the_first_use_is_granted_and_the_second_is_not(owner: UUID) -> None:
    assert spend(owner, MONDAY_EVENING).allowed is True
    refused = spend(owner, MONDAY_EVENING + timedelta(minutes=1))
    assert refused.allowed is False
    assert refused.used == 1
    assert refused.limit == 1


def test_it_is_still_refused_six_days_and_23_hours_later(owner: UUID) -> None:
    """The hard edge. A window that quietly meant "six days" would pass every other test."""
    spend(owner, MONDAY_EVENING)
    assert spend(owner, MONDAY_EVENING + timedelta(days=6, hours=23)).allowed is False


def test_it_is_granted_again_exactly_seven_days_later(owner: UUID) -> None:
    spend(owner, MONDAY_EVENING)
    assert spend(owner, MONDAY_EVENING + timedelta(days=7)).allowed is True


def test_a_midnight_does_not_reset_it_the_way_a_daily_counter_would(owner: UUID) -> None:
    """THE distinction this module exists for, pinned rather than described.

    ``core.rate_limit`` resets at the owner's local midnight, so a use at 21:00 would be
    free again three hours later. If this ledger ever became that one, this is the test
    that would say so — and it is the exact case a real owner hits, because people ask
    their questions in the evening.
    """
    spend(owner, MONDAY_EVENING)
    local_midnight_after = MONDAY_EVENING + timedelta(hours=3)  # 00:00 UTC, 05:30 in IST
    assert spend(owner, local_midnight_after).allowed is False
    assert spend(owner, MONDAY_EVENING + timedelta(days=1)).allowed is False


def test_the_reset_instant_is_the_use_plus_seven_local_days(owner: UUID) -> None:
    """What the 402 tells the owner has to be the instant the window actually opens."""
    spend(owner, MONDAY_EVENING)
    refused = spend(owner, MONDAY_EVENING + timedelta(hours=1))
    assert refused.resets_at == MONDAY_EVENING + timedelta(days=7)
    # …and waiting exactly that long really does work, which is what makes it not a guess.
    assert spend(owner, refused.resets_at).allowed is True


def test_the_window_keeps_rolling_after_it_reopens(owner: UUID) -> None:
    """A second use starts its own seven days — the ledger is not one-shot-then-open."""
    spend(owner, MONDAY_EVENING)
    later = MONDAY_EVENING + timedelta(days=7)
    assert spend(owner, later).allowed is True
    assert spend(owner, later + timedelta(days=6)).allowed is False
    assert spend(owner, later + timedelta(days=7)).allowed is True


# ── thirty days is thirty LOCAL days, exactly as seven was ────────────────────


def test_the_thirty_day_window_is_thirty_local_days_across_a_dst_transition(
    owner: UUID,
) -> None:
    """The premium cap's window, measured where local days and 24-hour days disagree.

    A use at 21:00 local on 2026-02-20 in New York is under EST; thirty LOCAL days later is
    2026-03-22, which is under EDT — the clocks went forward on 2026-03-08. So the reset
    instant is **719 hours** after the use, not 720, and the owner gets their question back
    at 21:00 local exactly as promised rather than at 22:00.

    An implementation that added ``timedelta(days=30)`` to the *instant* would put the
    reset an hour late and still pass every assertion made in Asia/Kolkata, which is why
    this one is made here.
    """
    use = datetime(2026, 2, 20, 21, 0, tzinfo=DST_ZONE).astimezone(UTC)
    assert spend(owner, use, window_days=30, tz=DST_TZ).allowed is True

    refused = spend(owner, use + timedelta(hours=718), window_days=30, tz=DST_TZ)
    assert refused.allowed is False, "the 30-day window rolled early"
    assert refused.resets_at - use == timedelta(hours=719), "the window counted 24-hour days"
    assert refused.resets_at.astimezone(DST_ZONE).hour == 21  # the promise, in wall-clock

    # …and at 719 hours it really does open.
    assert spend(owner, use + timedelta(hours=719), window_days=30, tz=DST_TZ).allowed is True


def test_a_use_29_local_days_old_still_counts_against_the_thirty_day_window(
    owner: UUID,
) -> None:
    """The hard edge again, at the length the premium cap actually uses."""
    spend(owner, MONDAY_EVENING, window_days=30)
    assert spend(owner, MONDAY_EVENING + timedelta(days=29), window_days=30).allowed is False
    assert spend(owner, MONDAY_EVENING + timedelta(days=30), window_days=30).allowed is True


# ── a refusal is not a use ────────────────────────────────────────────────────


def test_a_refused_attempt_does_not_push_the_window_forward(owner: UUID) -> None:
    """The bug this shape exists to avoid: recording refusals would lock an owner out
    forever, because every rejected tap would re-arm the seven days."""
    spend(owner, MONDAY_EVENING)
    for hours in (1, 24, 100, 160):
        spend(owner, MONDAY_EVENING + timedelta(hours=hours))
    assert spend(owner, MONDAY_EVENING + timedelta(days=7)).allowed is True


# ── refunds ───────────────────────────────────────────────────────────────────


def test_a_refund_gives_the_use_back(owner: UUID) -> None:
    spend(owner, MONDAY_EVENING)
    allowance.refund(owner, SENTINEL_TZ, FEATURE, now=MONDAY_EVENING)
    assert spend(owner, MONDAY_EVENING + timedelta(minutes=1)).allowed is True


def test_a_refund_can_never_mint_allowance(owner: UUID) -> None:
    """Refunding more than was spent must leave the owner with one use, not five."""
    spend(owner, MONDAY_EVENING)
    for _ in range(5):
        allowance.refund(owner, SENTINEL_TZ, FEATURE, now=MONDAY_EVENING)
    assert spend(owner, MONDAY_EVENING).allowed is True
    assert spend(owner, MONDAY_EVENING).allowed is False


def test_a_refund_cannot_reach_into_a_window_that_has_already_rolled(owner: UUID) -> None:
    """A late refund of an expired use is a no-op, not a credit against the new window."""
    spend(owner, MONDAY_EVENING)
    much_later = MONDAY_EVENING + timedelta(days=8)
    assert spend(owner, much_later).allowed is True  # the new week's use
    allowance.refund(owner, SENTINEL_TZ, FEATURE, now=much_later)
    assert spend(owner, much_later).allowed is True  # refunded the NEW one, which is right
    assert spend(owner, much_later).allowed is False


def test_a_refund_only_reaches_the_window_it_was_charged_against(owner: UUID) -> None:
    """A refund aimed at the wrong window must not give back a use from another one.

    ``gate.refund_ai_use`` carries ``window_days`` with the charge precisely so this cannot
    happen; if it re-derived the tier instead, a subscription that lapsed mid-request would
    refund the row nobody wrote and leave the charged one standing.
    """
    spend(owner, MONDAY_EVENING, window_days=30)
    allowance.refund(owner, SENTINEL_TZ, FEATURE, now=MONDAY_EVENING, window_days=7)
    assert spend(owner, MONDAY_EVENING, window_days=30).allowed is False, (
        "a 7-day refund gave back a 30-day use"
    )
    allowance.refund(owner, SENTINEL_TZ, FEATURE, now=MONDAY_EVENING, window_days=30)
    assert spend(owner, MONDAY_EVENING, window_days=30).allowed is True


# ── peek reports, it does not spend ───────────────────────────────────────────


def test_peek_never_records_anything(owner: UUID) -> None:
    for _ in range(10):
        assert allowance.peek(owner, SENTINEL_TZ, FEATURE, 1, now=MONDAY_EVENING).allowed is True
    assert spend(owner, MONDAY_EVENING).allowed is True
    assert allowance.peek(owner, SENTINEL_TZ, FEATURE, 1, now=MONDAY_EVENING).allowed is False


# ── the ledger's own shape ────────────────────────────────────────────────────


def _allowance_rows(owner: UUID) -> list[tuple[str, str]]:
    from healthee.core.db import tenant_transaction

    with tenant_transaction(owner) as cur:
        cur.execute(
            "SELECT key, value FROM kv WHERE user_id = %s AND key LIKE 'allowance%%' ORDER BY key",
            (owner,),
        )
        return [(row[0], row[1]) for row in cur.fetchall()]


def test_the_ledger_is_one_row_per_owner_per_feature_with_no_date_in_the_key(
    owner: UUID,
) -> None:
    """The #77 leak, not reintroduced: a date in the KEY would grow a row per period.

    Asserted against the table rather than the docstring, because the docstring is what
    was wrong last time. The window length IS in the key and is not a date — it is a fixed
    per-tier constant, so six weeks of use still leave exactly one row.
    """
    for day in range(0, 40, 7):  # six weeks of legitimate weekly use
        spend(owner, MONDAY_EVENING + timedelta(days=day))
    rows = _allowance_rows(owner)
    assert len(rows) == 1, f"the ledger grew a row per period: {rows}"
    key, value = rows[0]
    assert key == f"allowance:{FEATURE}:7d"
    assert value.count(",") == 0, f"the stored window is not bounded to the limit: {value!r}"


def test_the_two_windows_do_not_share_a_kv_row(owner: UUID) -> None:
    """A 7-day taste and a 30-day cap on the SAME (owner, feature) must not collide.

    They would, under the old key. A use ten days old is outside a 7-day window and inside
    a 30-day one, so the same stored instants read differently depending on who is asking:
    a lapsed premium owner's month of questions would be read as a spent free week, and a
    re-granted free taste would eat a paid slot. The window is in the key for exactly this.
    """
    assert spend(owner, MONDAY_EVENING, window_days=7).allowed is True
    assert spend(owner, MONDAY_EVENING, window_days=7).allowed is False, "premise: 7d is spent"

    # …and the 30-day ledger has not been touched by any of that.
    assert spend(owner, MONDAY_EVENING, window_days=30).allowed is True
    seven = allowance.peek(owner, SENTINEL_TZ, FEATURE, 1, now=MONDAY_EVENING, window_days=7)
    assert seven.used == 1, "the 30-day spend wrote into the 7-day row"

    keys = [key for key, _ in _allowance_rows(owner)]
    assert keys == [f"allowance:{FEATURE}:30d", f"allowance:{FEATURE}:7d"], keys


def test_a_corrupt_ledger_row_is_dropped_rather_than_raising(owner: UUID) -> None:
    """A row somebody hand-edited must not 500 every AI request that owner makes."""
    from healthee.core.db import tenant_transaction

    with tenant_transaction(owner) as cur:
        cur.execute(
            "INSERT INTO kv (user_id, key, value) VALUES (%s, %s, %s)",
            (owner, f"allowance:{FEATURE}:7d", "not-an-instant"),
        )
    assert spend(owner, MONDAY_EVENING).allowed is True


# ── per-owner isolation ───────────────────────────────────────────────────────


def test_one_owners_spent_window_does_not_touch_another(owner: UUID) -> None:
    """Two owners, one ledger table, RLS underneath — measured, not argued."""
    from tests.contracts.seed_owner_b import OWNER_B, OWNER_B_TZ, seed_owner_b

    seed_owner_b()
    entitle(OWNER_B, premium=False)
    assert spend(owner, MONDAY_EVENING).allowed is True
    assert spend(owner, MONDAY_EVENING).allowed is False
    assert allowance.spend(OWNER_B, OWNER_B_TZ, FEATURE, 1, now=MONDAY_EVENING).allowed is True
