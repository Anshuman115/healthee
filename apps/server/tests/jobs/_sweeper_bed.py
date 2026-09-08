"""The shared bed for the two scheduler suites — owners, a fake chain, a fake gate.

Split out when ``test_scheduler.py`` crossed the 400-line gate. The split is by
CONTRACT, not by size: the loop fires on two independent conditions, and each has its
own suite. ``test_scheduler.py`` owns the clock — who is due, on whose local day,
exactly once, and what one owner's failure costs the others. ``test_scheduler_gate.py``
owns the arrival gate — that a passed fire time is not on its own a reason to run.

Not a pytest module (underscore-prefixed), like the derive suite's ``_seed`` and the
analytics suite's ``_seed_db``: it holds beds, never tests.
"""

from __future__ import annotations

from datetime import date
from uuid import UUID
from zoneinfo import ZoneInfo

import pytest

from healthee.core.tenancy import Tenant
from healthee.jobs import chain, scheduler

UTC = ZoneInfo("UTC")

# Two owners in DIFFERENT zones — the sweep must hand each their own tz and their own
# local day. Kiritimati (UTC+14) and Midway (UTC-11) are 25 hours apart: at most
# instants they are not merely at different local times, they are on different DATES.
EAST = Tenant(id=UUID("11111111-1111-1111-1111-111111111111"), tz="Pacific/Kiritimati")
WEST = Tenant(id=UUID("22222222-2222-2222-2222-222222222222"), tz="Pacific/Midway")

# Two owners sharing ONE zone — the shared-fire-time trap.
TWIN_A = Tenant(id=UUID("33333333-3333-3333-3333-333333333333"), tz="Asia/Kolkata")
TWIN_B = Tenant(id=UUID("44444444-4444-4444-4444-444444444444"), tz="Asia/Kolkata")


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


class Gate:
    """An arrival gate the test opens and closes, recording exactly what it was asked."""

    def __init__(self, *, open_: bool = False) -> None:
        self.open = open_
        self.asked: list[tuple[UUID, date, str, bool]] = []

    def __call__(self, user_id: UUID, day: date, tz: str, without_night: bool) -> bool:
        self.asked.append((user_id, day, tz, without_night))
        return self.open


def owners(monkeypatch: pytest.MonkeyPatch, *tenants: Tenant) -> None:
    """Make ``tenants`` the set this tick sweeps."""
    monkeypatch.setattr(scheduler, "active_users", lambda: list(tenants))
