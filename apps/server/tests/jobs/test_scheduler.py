"""Scheduler unit tests — next-fire math + a job invocation calls the chain step.

No sleeping, no DB: ``next_fire`` is pure arithmetic and ``_fire`` is checked to
delegate to ``chain.run_step`` (which the supervision suite already covers).
"""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from healthee.jobs import chain, scheduler

_UTC = ZoneInfo("UTC")
_IST = ZoneInfo("Asia/Kolkata")


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


def test_fire_calls_the_supervised_chain_step(monkeypatch: pytest.MonkeyPatch) -> None:
    called: list[str] = []
    monkeypatch.setattr(
        chain, "run_step", lambda name, **_: called.append(name) or chain.StepOutcome(name, "ok")
    )
    scheduler._fire(scheduler.Job(step="recs", hour=10, minute=45))
    assert called == ["recs"]


def test_every_job_step_is_a_known_chain_step() -> None:
    assert {j.step for j in scheduler.JOBS} <= set(chain.STEP_NAMES)
