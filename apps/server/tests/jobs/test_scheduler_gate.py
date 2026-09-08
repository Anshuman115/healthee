"""The scheduler's arrival gate, at the LOOP level — a passed fire time is not enough.

The defect these pin: the loop fired at 10:30 whether or not the owner's phone had
handed anything over, wrote a briefing about a night no row described, then set the
per-day marker so the real sleep arriving at noon got no chain at all. The module
docstring claimed 10:30 was late enough that this could not happen. Nothing checked.

The gate is injected here, so these assert what the LOOP does with its answer — holds,
fires on the tick it opens, charges no budget for waiting, reports a quiet day once.
Whether the gate's SQL answers correctly is ``test_data_gate.py``, against a database.
"""

from __future__ import annotations

from datetime import date, datetime

import pytest
from tests.jobs._sweeper_bed import (
    EAST,
    TWIN_A,
    UTC,
    FakeChain,
    Gate,
    owners,
)

from healthee.jobs import scheduler


def test_a_shut_gate_holds_the_chain_past_the_fire_time(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """Past 10:30 with nothing arrived is NOT a reason to run. This is the whole fix."""
    owners(monkeypatch, TWIN_A)
    now = datetime(2026, 7, 20, 5, 5, tzinfo=UTC)  # 10:35 IST — past the fire time

    scheduler.Sweeper(gate=Gate(open_=False)).tick(now)

    assert fake_chain.runs == [], "the chain ran on a day nothing had arrived for"


def test_the_chain_runs_on_the_tick_the_data_arrives(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """The gate opening is what fires the chain — and it fires ONCE, not once per tick."""
    owners(monkeypatch, TWIN_A)
    gate = Gate(open_=False)
    sweeper = scheduler.Sweeper(gate=gate)

    sweeper.tick(datetime(2026, 7, 20, 5, 5, tzinfo=UTC))  # 10:35 IST, nothing yet
    assert fake_chain.runs == []

    gate.open = True  # the phone is opened; the strap hands over the night
    sweeper.tick(datetime(2026, 7, 20, 5, 10, tzinfo=UTC))  # 10:40 IST
    sweeper.tick(datetime(2026, 7, 20, 5, 15, tzinfo=UTC))  # 10:45 IST

    assert fake_chain.runs == [(TWIN_A.id, date(2026, 7, 20))]


def test_a_sync_at_five_to_midnight_still_gets_that_days_chain(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain, notices: list[str]
) -> None:
    """Late is late, not lost — the loop asks its question on every tick of the day.

    It also fires AFTER the quiet-day notice has gone out, which is correct and worth
    pinning: the notice is a report that nothing had arrived by 22:00, not a deadline
    that closes the day.
    """
    owners(monkeypatch, TWIN_A)
    gate = Gate(open_=False)
    sweeper = scheduler.Sweeper(gate=gate)

    sweeper.tick(datetime(2026, 7, 20, 17, 0, tzinfo=UTC))  # 22:30 IST — notice fires
    assert len(notices) == 1
    assert fake_chain.runs == []

    gate.open = True
    sweeper.tick(datetime(2026, 7, 20, 18, 25, tzinfo=UTC))  # 23:55 IST

    assert fake_chain.runs == [(TWIN_A.id, date(2026, 7, 20))]


def test_the_gate_is_asked_about_the_owners_own_local_day(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """A gate asked about the wrong day is a gate that opens on the wrong data.

    Kiritimati is a DATE ahead of Midway at this instant, so a gate handed a global
    "today" instead of the owner's own would be asked about 2026-07-20 here.
    """
    owners(monkeypatch, EAST)
    gate = Gate(open_=True)

    scheduler.Sweeper(gate=gate).tick(datetime(2026, 7, 20, 21, 0, tzinfo=UTC))

    assert gate.asked == [(EAST.id, date(2026, 7, 21), "Pacific/Kiritimati", False)]


# ── a shut gate must be visible, and must cost nothing ─────────────────────────


def test_a_quiet_day_is_reported_once_not_once_per_tick(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain, notices: list[str]
) -> None:
    """A gate that can stay shut is only honest if the shut state reaches the surface.

    Once, though: the sweep asks this ~24 times after 22:00, and 24 identical alerts is
    the alert fatigue `_ATTEMPT_BUDGET` exists to prevent, arriving by another door.
    """
    owners(monkeypatch, TWIN_A)
    sweeper = scheduler.Sweeper(gate=Gate(open_=False))

    for minute in range(0, 50, 5):  # 22:30 IST onward, ten ticks
        sweeper.tick(datetime(2026, 7, 20, 17, minute, tzinfo=UTC))

    assert len(notices) == 1, f"expected one quiet-day notice, got {len(notices)}"
    assert "has not run" in notices[0]
    assert fake_chain.runs == []


def test_no_quiet_day_notice_before_the_notice_hour(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain, notices: list[str]
) -> None:
    """11:00 with nothing synced is an ordinary morning, not an incident."""
    owners(monkeypatch, TWIN_A)

    scheduler.Sweeper(gate=Gate(open_=False)).tick(
        datetime(2026, 7, 20, 5, 30, tzinfo=UTC)  # 11:00 IST
    )

    assert notices == []


def test_a_shut_gate_spends_no_retry_budget(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """Waiting is not attempting.

    If a shut gate charged the budget, an owner who synced at lunchtime would find their
    three attempts already spent on the morning they had not synced yet — the fix
    reintroducing the bug it exists to remove, one step further along.
    """
    owners(monkeypatch, TWIN_A)
    gate = Gate(open_=False)
    sweeper = scheduler.Sweeper(gate=gate, budget=3)

    for minute in range(0, 60, 5):  # twelve ticks with nothing arrived
        sweeper.tick(datetime(2026, 7, 20, 5, minute, tzinfo=UTC))

    gate.open = True
    sweeper.tick(datetime(2026, 7, 20, 6, 5, tzinfo=UTC))  # 11:35 IST

    assert fake_chain.runs == [(TWIN_A.id, date(2026, 7, 20))], (
        "a shut gate spent the retry budget, so the owner's real sync got no chain"
    )


def test_the_night_is_required_until_the_fallback_hour(
    monkeypatch: pytest.MonkeyPatch,
    fake_chain: FakeChain,  # noqa: ARG001 — the gate is what this asserts on
) -> None:
    """Before `SLEEP_FALLBACK` the sweep asks for the night; after it, it will take less.

    The flag is the whole of the 00:53 fix at the loop level: an owner awake at midnight
    syncs post-midnight samples, and only this `False` stops those from answering for a
    night that has not happened. A sweep that always passed `True` would restore the bug
    while every other test in this file still passed.
    """
    owners(monkeypatch, TWIN_A)
    gate = Gate(open_=False)
    sweeper = scheduler.Sweeper(gate=gate)

    sweeper.tick(datetime(2026, 7, 20, 5, 5, tzinfo=UTC))  # 10:35 IST
    sweeper.tick(datetime(2026, 7, 20, 9, 0, tzinfo=UTC))  # 14:30 IST

    assert [asked[-1] for asked in gate.asked] == [False, True]


def test_a_strap_off_day_still_gets_its_chain_after_the_fallback(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """Requiring the night flatly would cost an unworn night the whole day's chain.

    "You recorded no sleep last night" is a true and useful thing for a day to say, so
    the widening has to actually fire — a fallback that never opened would be the fix
    failing shut, which is quieter than failing open and just as wrong.
    """
    owners(monkeypatch, TWIN_A)

    class NightlessGate(Gate):
        def __call__(self, user_id, day, tz, without_night):  # noqa: ANN001, ANN204
            super().__call__(user_id, day, tz, without_night)
            return without_night  # samples exist; no session does

    sweeper = scheduler.Sweeper(gate=NightlessGate())
    sweeper.tick(datetime(2026, 7, 20, 5, 5, tzinfo=UTC))  # 10:35 IST — holds
    assert fake_chain.runs == []

    sweeper.tick(datetime(2026, 7, 20, 9, 0, tzinfo=UTC))  # 14:30 IST — runs
    assert fake_chain.runs == [(TWIN_A.id, date(2026, 7, 20))]
