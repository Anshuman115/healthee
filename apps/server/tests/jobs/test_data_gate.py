"""The arrival gate's SQL, against a real database.

``jobs/data_gate.day_data_arrived`` is the second of the two conditions the scheduler
fires on, and the one that ended the defect its module docstring opens with: a chain
that ran at 10:30 whether or not the owner's phone had handed anything over.

The loop's rule — what a shut gate costs, when it is reported — is pinned in
``test_scheduler.py`` against an injected gate. This file is the other half: whether
the SQL answers "has day D's data arrived" correctly, which is a question about
Postgres' day boundaries and RLS and cannot be answered by a stub.

**The case that matters most is #3.** Yesterday's data must not open today's gate;
that is the exact shape of the bug (the strap had a full history, just nothing since
the night), and a predicate that dropped the lower bound would pass every other test
here while restoring it.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

from healthee.core.db import admin_connection
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.derive._common import _day_bounds_utc
from healthee.jobs.data_gate import day_data_arrived

pytestmark = pytest.mark.integration

_TZ = "Asia/Kolkata"
_IST = ZoneInfo(_TZ)
_DAY = date(2026, 7, 20)
_OWNER = SENTINEL_USER_ID


def _clean() -> None:
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("TRUNCATE sample, sleep_session")


def _at(hour: int, minute: int = 0, *, day: date = _DAY) -> datetime:
    """A UTC instant from a wall-clock time in the owner's zone."""
    return datetime(day.year, day.month, day.day, hour, minute, tzinfo=_IST)


def _sample(ts: datetime, *, owner=_OWNER) -> None:
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO sample (user_id, metric, ts, value) VALUES (%s, %s, %s, %s) "
            "ON CONFLICT DO NOTHING",
            (owner, "heart_rate", ts, 60.0),
        )


def _night(start: datetime, end: datetime, *, owner=_OWNER) -> None:
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO sleep_session (user_id, start_ts, end_ts, kind) "
            "VALUES (%s, %s, %s, 'main') ON CONFLICT DO NOTHING",
            (owner, start, end),
        )


@pytest.fixture(autouse=True)
def _clean_rows(db: None) -> None:  # noqa: ARG001 — gates on DB reachability
    _clean()


# ── the gate ───────────────────────────────────────────────────────────────────


def test_nothing_at_all_keeps_the_gate_shut() -> None:
    """An owner whose phone has never synced has no day to answer for."""
    assert day_data_arrived(_OWNER, _DAY, _TZ) is False


def test_a_sample_measured_on_the_day_opens_it() -> None:
    _sample(_at(3, 0))  # 03:00 local — overnight heart rate

    assert day_data_arrived(_OWNER, _DAY, _TZ) is True


def test_yesterdays_data_does_not_open_todays_gate() -> None:
    """THE regression. The strap had a full history; it had just sent nothing since.

    A predicate that lost its lower bound — or asked "has this owner any data at all" —
    passes every other test in this file and reinstates the exact bug: a chain firing
    at 10:30 on a database whose newest row is yesterday's.
    """
    _sample(_at(23, 30, day=_DAY - timedelta(days=1)))
    _night(
        _at(22, 0, day=_DAY - timedelta(days=2)),
        _at(5, 0, day=_DAY - timedelta(days=1)),
    )

    assert day_data_arrived(_OWNER, _DAY, _TZ) is False


def test_a_night_that_woke_on_the_day_opens_it_with_no_samples() -> None:
    """The per-minute stream demonstrably stalls; the staged night is then all we get.

    The session STARTS on the previous local day — which is what an ordinary night
    does — so a gate keyed on ``start_ts`` would call this "yesterday's" and stay shut
    on precisely the row it exists to notice.
    """
    _night(_at(23, 0, day=_DAY - timedelta(days=1)), _at(6, 30))

    assert day_data_arrived(_OWNER, _DAY, _TZ) is True


def test_tomorrows_data_does_not_open_todays_gate() -> None:
    """Nothing measured after day D may inform day D's answer (AS_OF_DAY)."""
    _sample(_at(9, 0, day=_DAY + timedelta(days=1)))

    assert day_data_arrived(_OWNER, _DAY, _TZ) is False


def test_the_next_local_midnight_belongs_to_tomorrow() -> None:
    """The bracket is half-open, so its own upper edge is outside it.

    A closed ``<=`` would let the first instant of tomorrow open today's gate — and,
    read the other way, would have a day answered for by data that is not its own.
    """
    _, next_midnight_utc = _day_bounds_utc(_DAY, _TZ)
    _sample(next_midnight_utc)

    assert day_data_arrived(_OWNER, _DAY, _TZ) is False


def test_the_last_instant_before_that_midnight_is_still_todays() -> None:
    """The other side of the same edge — the bracket must not be short by a second."""
    _, next_midnight_utc = _day_bounds_utc(_DAY, _TZ)
    _sample(next_midnight_utc - timedelta(seconds=1))

    assert day_data_arrived(_OWNER, _DAY, _TZ) is True


def test_a_night_ending_exactly_at_the_next_local_midnight_is_tomorrows() -> None:
    """The half-open edge again, on the OTHER arm.

    The sample arm's bound is pinned two tests up. This one exists because it was not:
    a mutation loosening only the sleep arm to ``end_ts <= %s`` passed the whole file,
    which is what an untested predicate looks like from the outside.
    """
    _, next_midnight_utc = _day_bounds_utc(_DAY, _TZ)
    _night(_at(21, 0), next_midnight_utc)

    assert day_data_arrived(_OWNER, _DAY, _TZ) is False


def test_a_night_ending_a_second_before_that_midnight_is_todays() -> None:
    """And its other side, so the bracket cannot be fixed by shrinking it."""
    _, next_midnight_utc = _day_bounds_utc(_DAY, _TZ)
    _night(_at(21, 0), next_midnight_utc - timedelta(seconds=1))

    assert day_data_arrived(_OWNER, _DAY, _TZ) is True


def test_another_owners_sync_does_not_open_this_owners_gate(
    owner_sweep: None,  # noqa: ARG001 — removes the provisioned owner at teardown
) -> None:
    """Otherwise one active household fires every dormant owner's chain, every day.

    A second owner, so "did this row open the WRONG owner's gate" is a question this
    suite can actually ask. RLS scopes the connection AND the predicate names the
    owner; both have to hold, and a single-owner test can see neither.
    """
    from tests.contracts.seed_owner_b import OWNER_B, seed_owner_b

    seed_owner_b()
    _clean()
    _sample(_at(3, 0), owner=OWNER_B)

    assert day_data_arrived(_OWNER, _DAY, _TZ) is False
    assert day_data_arrived(OWNER_B, _DAY, _TZ) is True
