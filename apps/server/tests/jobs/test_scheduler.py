"""Scheduler unit tests — next-fire math + the per-user sweep (Phase 6.3c, §6).

No sleeping, no DB: ``next_fire`` is pure arithmetic, and the sweep is exercised
with ``active_users`` stubbed, so these assert the LOOP's contract (every active
owner is fired, with their own tz, and one owner's failure does not cost the
others their run) rather than re-testing ``chain.run_step`` — which the
supervision suite already covers.
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID
from zoneinfo import ZoneInfo

import pytest

from healthee.core.tenancy import Tenant
from healthee.jobs import chain, scheduler

_UTC = ZoneInfo("UTC")
_IST = ZoneInfo("Asia/Kolkata")

# Two owners in DIFFERENT zones — the sweep must hand each their own tz, since that
# is what resolves their local day.
_A = Tenant(id=UUID("11111111-1111-1111-1111-111111111111"), tz="Asia/Kolkata")
_B = Tenant(id=UUID("22222222-2222-2222-2222-222222222222"), tz="America/Chicago")


@pytest.fixture
def two_tenants(monkeypatch: pytest.MonkeyPatch) -> list[Tenant]:
    """Stub the owner lookup so the sweep's loop is tested without a DB."""
    tenants = [_A, _B]
    monkeypatch.setattr(scheduler, "active_users", lambda: tenants)
    return tenants


def test_next_fire_is_today_when_target_is_still_ahead() -> None:
    now = datetime(2026, 7, 15, 3, 0, tzinfo=_UTC)  # 08:30 IST
    fire = scheduler.next_fire(now, 10, 30)  # 10:30 IST today
    assert fire.astimezone(_IST) == datetime(2026, 7, 15, 10, 30, tzinfo=_IST)


def test_next_fire_rolls_to_tomorrow_when_target_has_passed() -> None:
    now = datetime(2026, 7, 15, 6, 0, tzinfo=_UTC)  # 11:30 IST — past 10:30
    fire = scheduler.next_fire(now, 10, 30)
    assert fire.astimezone(_IST) == datetime(2026, 7, 16, 10, 30, tzinfo=_IST)


def test_select_next_picks_the_earliest_upcoming_job() -> None:
    now = datetime(2026, 7, 15, 3, 0, tzinfo=_UTC)  # 08:30 IST — all three ahead
    fire_at, job = scheduler._select_next(now)
    assert job.step == "correlate"  # 10:30 is the first of 10:30/10:45/11:00
    assert fire_at.astimezone(_IST).hour == 10
    assert fire_at.astimezone(_IST).minute == 30


def test_fire_sweeps_every_active_owner_with_their_own_tz(
    monkeypatch: pytest.MonkeyPatch,
    two_tenants: list[Tenant],  # noqa: ARG001
) -> None:
    """The step runs once PER owner, each carrying that owner's id and zone.

    A global single fire (the pre-6.3c behaviour) would leave every owner but one
    without a nightly chain — and, before the tz thread, would anchor them all to
    one user's local day.
    """
    called: list[tuple[str, UUID, str]] = []

    def spy(name: str, user_id: UUID, tz: str, *_a, **_kw) -> chain.StepOutcome:
        called.append((name, user_id, tz))
        return chain.StepOutcome(name, "ok")

    monkeypatch.setattr(chain, "run_step", spy)
    scheduler._fire(scheduler.Job(step="recs", hour=10, minute=45))

    assert called == [("recs", _A.id, "Asia/Kolkata"), ("recs", _B.id, "America/Chicago")]


def test_one_owners_failure_does_not_abort_the_sweep(
    monkeypatch: pytest.MonkeyPatch,
    two_tenants: list[Tenant],  # noqa: ARG001
) -> None:
    """Owner A raising must not cost owner B their run — and must still be reported.

    ``run_step`` supervises the step BODY, but not everything it does (resolving the
    owner's local day from their tz happens first), so a raise can still reach the
    sweep. One user's bad row silently ending everyone else's nightly chain is the
    failure this isolates.
    """
    notices: list[str] = []
    monkeypatch.setattr(scheduler, "send_telegram", lambda text, **_: notices.append(text) or True)
    fired: list[UUID] = []

    def spy(name: str, user_id: UUID, tz: str, *_a, **_kw) -> chain.StepOutcome:  # noqa: ARG001
        if user_id == _A.id:
            raise RuntimeError("bad timezone row")
        fired.append(user_id)
        return chain.StepOutcome(name, "ok")

    monkeypatch.setattr(chain, "run_step", spy)
    scheduler._fire(scheduler.Job(step="recs", hour=10, minute=45))  # must not raise

    assert fired == [_B.id], "owner B lost their chain to owner A's failure"
    # Reported to the health surface, with the owner — logged, never swallowed.
    assert any("failed for owner" in n and str(_A.id) in n for n in notices)


def test_a_broken_owner_lookup_propagates(monkeypatch: pytest.MonkeyPatch) -> None:
    """If the owner LIST itself can't be read there is no sweep to continue.

    That is a real outage, not one tenant's problem, so it must surface rather than
    be logged-and-ignored into a silently sweep-less night.
    """

    def boom() -> list[Tenant]:
        raise RuntimeError("db down")

    monkeypatch.setattr(scheduler, "active_users", boom)
    with pytest.raises(RuntimeError, match="db down"):
        scheduler._fire(scheduler.Job(step="recs", hour=10, minute=45))


def test_every_job_step_is_a_known_chain_step() -> None:
    assert {j.step for j in scheduler.JOBS} <= set(chain.STEP_NAMES)
