"""Scheduler unit tests — the tick model + per-owner local fire times (6.4c, §6).

No sleeping, no DB: ``Sweeper.tick`` takes the instant to evaluate, and
``active_users``/``chain.run_chain`` are stubbed, so these assert the LOOP's contract
(who fires, on whose local day, exactly once, and what a failure costs the others)
rather than re-testing ``run_chain`` — which the supervision suite already covers.

The previous suite tested ``next_fire``/``_select_next``: a "compute the next matching
instant, sleep, fire" timer. Those functions are gone, and with them their tests — not
because the expectations became inconvenient, but because the model they encoded is
the bug ``test_two_owners_sharing_a_fire_time_both_fire`` now pins. Under a next-fire
loop the earliest single (owner, instant) is selected and fired; the loop then
recomputes and sees the *identical* instant of every other owner in that zone as
already past, so each of them is deferred to tomorrow — every day, forever. The stub
below counts fires per owner, so that model fails the test rather than passing it.
"""

from __future__ import annotations

from datetime import date, datetime
from uuid import UUID
from zoneinfo import ZoneInfo

import pytest

from healthee.core.tenancy import Tenant
from healthee.jobs import chain, scheduler

_UTC = ZoneInfo("UTC")

# Two owners in DIFFERENT zones — the sweep must hand each their own tz and their own
# local day. Kiritimati (UTC+14) and Midway (UTC-11) are 25 hours apart: at most
# instants they are not merely at different local times, they are on different DATES.
_EAST = Tenant(id=UUID("11111111-1111-1111-1111-111111111111"), tz="Pacific/Kiritimati")
_WEST = Tenant(id=UUID("22222222-2222-2222-2222-222222222222"), tz="Pacific/Midway")

# Two owners sharing ONE zone — the shared-fire-time trap.
_TWIN_A = Tenant(id=UUID("33333333-3333-3333-3333-333333333333"), tz="Asia/Kolkata")
_TWIN_B = Tenant(id=UUID("44444444-4444-4444-4444-444444444444"), tz="Asia/Kolkata")


class FakeChain:
    """A stand-in for ``chain.run_chain`` with the real per-owner per-day dedup.

    The marker is the thing that makes the tick model safe, so a stub without it would
    let the tick tests pass against a scheduler that re-runs a chain every 5 minutes.
    """

    def __init__(self) -> None:
        self.runs: list[tuple[UUID, date]] = []
        self.done: set[tuple[UUID, date]] = set()
        self.raises_for: set[UUID] = set()
        self.correlate_fails_for: set[UUID] = set()

    def run_chain(
        self, user_id: UUID, tz: str, day: date | None = None, **_kw
    ) -> chain.ChainResult:
        assert day is not None, "the sweep must pass the owner's own local day"
        if user_id in self.raises_for:
            raise RuntimeError("bad timezone row")
        if (user_id, day) in self.done:
            return chain.ChainResult(day=day, deduped=True)
        self.runs.append((user_id, day))
        if user_id in self.correlate_fails_for:
            # Mirrors the real chain: an unmarked day, so the next tick retries it.
            return chain.ChainResult(
                day=day,
                deduped=False,
                steps=[chain.StepOutcome("correlate", "failed", error="boom")],
            )
        self.done.add((user_id, day))
        return chain.ChainResult(
            day=day, deduped=False, steps=[chain.StepOutcome("correlate", "ok")]
        )

    def fired(self, tenant: Tenant) -> int:
        return sum(1 for user_id, _ in self.runs if user_id == tenant.id)


@pytest.fixture
def fake_chain(monkeypatch: pytest.MonkeyPatch) -> FakeChain:
    fake = FakeChain()
    monkeypatch.setattr(chain, "run_chain", fake.run_chain)
    return fake


@pytest.fixture
def notices(monkeypatch: pytest.MonkeyPatch) -> list[str]:
    sent: list[str] = []
    monkeypatch.setattr(scheduler, "send_telegram", lambda text, **_: sent.append(text) or True)
    return sent


def _owners(monkeypatch: pytest.MonkeyPatch, *tenants: Tenant) -> None:
    monkeypatch.setattr(scheduler, "active_users", lambda: list(tenants))


# ── the trap: shared fire times ────────────────────────────────────────────────


def test_two_owners_sharing_a_fire_time_both_fire(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """THE regression. Two owners in one zone are due at the same instant — both run.

    A next-fire timer fires whichever sorts first, then recomputes and finds the other
    owner's identical instant already past → deferred to tomorrow, every day. Here one
    tick asks a question about the present, so "already past" is precisely the
    condition to RUN, not to skip.
    """
    _owners(monkeypatch, _TWIN_A, _TWIN_B)
    now = datetime(2026, 7, 20, 5, 5, tzinfo=_UTC)  # 10:35 IST — past 10:30 for both

    scheduler.Sweeper().tick(now)

    assert fake_chain.fired(_TWIN_A) == 1
    assert fake_chain.fired(_TWIN_B) == 1, "the second owner at the same fire time was skipped"


# ── per-owner local days ───────────────────────────────────────────────────────


def test_each_owner_fires_on_their_own_local_day(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """25 zones apart: the same instant is a different date for each owner."""
    _owners(monkeypatch, _EAST, _WEST)
    # 2026-07-20 21:00 UTC = 2026-07-21 11:00 in Kiritimati, 2026-07-20 10:00 in Midway.
    now = datetime(2026, 7, 20, 21, 0, tzinfo=_UTC)

    scheduler.Sweeper().tick(now)

    assert fake_chain.runs == [(_EAST.id, date(2026, 7, 21))], (
        "the east owner must run on their own local day; the west owner is at 10:00, "
        "before their 10:30 fire time"
    )


def test_an_owner_before_their_local_fire_time_does_not_fire(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """Global fire times fired everyone at one instant; a local one must not."""
    _owners(monkeypatch, _WEST)
    now = datetime(2026, 7, 20, 20, 0, tzinfo=_UTC)  # 09:00 in Midway — too early

    scheduler.Sweeper().tick(now)

    assert fake_chain.runs == []


def test_a_late_signup_still_gets_their_chain_on_the_next_tick(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """An owner created AFTER their fire time is not "missed" — they are simply due.

    Nothing in the tick model schedules a future instant, so an owner who first appears
    in `active_users()` at 15:00 local has an unmarked day and a passed fire time: they
    run on the very next tick.
    """
    _owners(monkeypatch, _TWIN_A)
    late = datetime(2026, 7, 20, 9, 30, tzinfo=_UTC)  # 15:00 IST — long past 10:30

    scheduler.Sweeper().tick(late)

    assert fake_chain.runs == [(_TWIN_A.id, date(2026, 7, 20))]


# ── idempotence + self-healing ─────────────────────────────────────────────────


def test_the_marker_prevents_a_second_run_within_a_local_day(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """The tick repeats every 5 minutes; the day's chain must still run exactly once."""
    _owners(monkeypatch, _TWIN_A)
    sweeper = scheduler.Sweeper()
    for minute in range(0, 60, 5):  # a whole hour of ticks after the fire time
        sweeper.tick(datetime(2026, 7, 20, 5, minute, tzinfo=_UTC))

    assert fake_chain.fired(_TWIN_A) == 1


def test_a_new_local_day_fires_again(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """The marker is per-day, not per-owner: tomorrow is a new chain."""
    _owners(monkeypatch, _TWIN_A)
    sweeper = scheduler.Sweeper()
    sweeper.tick(datetime(2026, 7, 20, 5, 5, tzinfo=_UTC))
    sweeper.tick(datetime(2026, 7, 21, 5, 5, tzinfo=_UTC))

    assert fake_chain.runs == [(_TWIN_A.id, date(2026, 7, 20)), (_TWIN_A.id, date(2026, 7, 21))]


def test_a_missed_tick_is_caught_up_not_lost(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """A container down across the fire time still runs the day's chain when it returns.

    This is the property a next-fire timer cannot have: it would have slept through the
    instant and rescheduled for tomorrow.
    """
    _owners(monkeypatch, _TWIN_A)
    # First tick well before the fire time, next one hours after it (the outage).
    sweeper = scheduler.Sweeper()
    sweeper.tick(datetime(2026, 7, 20, 2, 0, tzinfo=_UTC))  # 07:30 IST
    assert fake_chain.runs == []
    sweeper.tick(datetime(2026, 7, 20, 12, 0, tzinfo=_UTC))  # 17:30 IST, same local day

    assert fake_chain.runs == [(_TWIN_A.id, date(2026, 7, 20))]


def test_a_restarted_process_does_not_re_run_a_done_day(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain
) -> None:
    """The marker lives in the DB, so a fresh Sweeper cannot double-run the day."""
    _owners(monkeypatch, _TWIN_A)
    scheduler.Sweeper().tick(datetime(2026, 7, 20, 5, 5, tzinfo=_UTC))
    scheduler.Sweeper().tick(datetime(2026, 7, 20, 5, 10, tzinfo=_UTC))  # restarted

    assert fake_chain.fired(_TWIN_A) == 1


# ── failure isolation + the retry budget ───────────────────────────────────────


def test_one_owners_failure_does_not_abort_the_sweep(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain, notices: list[str]
) -> None:
    """Owner A raising must not cost owner B their run — and must still be reported."""
    _owners(monkeypatch, _TWIN_A, _TWIN_B)
    fake_chain.raises_for.add(_TWIN_A.id)

    scheduler.Sweeper().tick(datetime(2026, 7, 20, 5, 5, tzinfo=_UTC))  # must not raise

    assert fake_chain.fired(_TWIN_B) == 1, "owner B lost their chain to owner A's failure"
    assert any("chain failed for owner" in n and str(_TWIN_A.id) in n for n in notices)


def test_a_broken_owner_lookup_propagates(monkeypatch: pytest.MonkeyPatch) -> None:
    """If the owner LIST itself can't be read there is no sweep to continue.

    That is an outage, not one tenant's problem, so it must surface rather than be
    logged-and-ignored into a silently sweep-less night.
    """

    def boom() -> list[Tenant]:
        raise RuntimeError("db down")

    monkeypatch.setattr(scheduler, "active_users", boom)
    with pytest.raises(RuntimeError, match="db down"):
        scheduler.Sweeper().tick(datetime(2026, 7, 20, 5, 5, tzinfo=_UTC))


def test_a_failing_chain_is_retried_but_not_forever(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain, notices: list[str]
) -> None:
    """A correlate failure leaves the day unmarked — the retry must be bounded.

    Unbounded, a tick every 5 minutes would re-run the whole chain ~150 times for the
    rest of the owner's day: 150 Telegram alerts and 150 re-sent briefings. The budget
    keeps the transient-blip retry and kills the storm; exhaustion is itself announced,
    so a permanently failing owner is loud once rather than either silent or spamming.
    """
    _owners(monkeypatch, _TWIN_A)
    fake_chain.correlate_fails_for.add(_TWIN_A.id)
    sweeper = scheduler.Sweeper(budget=3)
    for minute in range(0, 60, 5):
        sweeper.tick(datetime(2026, 7, 20, 5, minute, tzinfo=_UTC))

    assert fake_chain.fired(_TWIN_A) == 3, "the retry budget was not enforced"
    assert sum("exhausted its 3 attempts" in n for n in notices) == 1


def test_the_budget_resets_on_the_owners_next_local_day(
    monkeypatch: pytest.MonkeyPatch,
    fake_chain: FakeChain,
    notices: list[str],  # noqa: ARG001
) -> None:
    """Today's exhausted budget must not silence tomorrow's chain."""
    _owners(monkeypatch, _TWIN_A)
    fake_chain.correlate_fails_for.add(_TWIN_A.id)
    sweeper = scheduler.Sweeper(budget=1)
    sweeper.tick(datetime(2026, 7, 20, 5, 5, tzinfo=_UTC))
    sweeper.tick(datetime(2026, 7, 20, 5, 10, tzinfo=_UTC))  # exhausted, no run
    sweeper.tick(datetime(2026, 7, 21, 5, 5, tzinfo=_UTC))  # a new local day

    assert fake_chain.runs == [(_TWIN_A.id, date(2026, 7, 20)), (_TWIN_A.id, date(2026, 7, 21))]


def test_a_successful_day_never_spends_budget_on_later_ticks(
    monkeypatch: pytest.MonkeyPatch, fake_chain: FakeChain, notices: list[str]
) -> None:
    """A deduped tick must not be charged, or a healthy owner would 'exhaust' by 10:45."""
    _owners(monkeypatch, _TWIN_A)
    sweeper = scheduler.Sweeper(budget=2)
    for minute in range(0, 60, 5):
        sweeper.tick(datetime(2026, 7, 20, 5, minute, tzinfo=_UTC))

    assert fake_chain.fired(_TWIN_A) == 1
    assert notices == [], "a healthy owner must never reach the exhaustion alert"


def test_the_retry_budget_does_not_grow_without_bound(
    monkeypatch: pytest.MonkeyPatch,
    fake_chain: FakeChain,  # noqa: ARG001
) -> None:
    """Budget entries for past days are pruned — the loop runs for months."""
    _owners(monkeypatch, _TWIN_A)
    sweeper = scheduler.Sweeper()
    for day in range(1, 15):
        sweeper.tick(datetime(2026, 7, day, 5, 5, tzinfo=_UTC))

    assert len(sweeper._attempts) == 1
