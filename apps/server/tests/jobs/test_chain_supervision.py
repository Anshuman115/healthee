"""The crux WP8 test: the supervised chain never swallows a step failure.

Pure control-flow (no DB, no LLM): the three step functions and the kv dedup
marker are stubbed, so these prove the supervision contract exactly —
  * a step that RAISES is caught, reported to Telegram, and returned as `failed`
    (NOT silently passed, NOT crashing the process — the legacy swallow is dead);
  * a `correlate` failure ABORTS `recs` (dependency);
  * a `briefing` failure does not undo the recs that already ran;
  * a second run for the same day is a deduped no-op.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import date
from uuid import UUID

import pytest

from healthee.jobs import chain

DAY = date(2026, 7, 15)

# An arbitrary owner: these tests are pure control-flow, so the id only has to be
# threaded consistently — the per-owner dedup marker is asserted in test_scheduler.
_OWNER = UUID("44444444-4444-4444-4444-444444444444")
_TZ = "Asia/Kolkata"


@pytest.fixture
def notices(monkeypatch: pytest.MonkeyPatch) -> Iterator[list[str]]:
    """Capture Telegram notifications and back the dedup marker with an in-memory set."""
    sent: list[str] = []
    monkeypatch.setattr(chain, "send_telegram", lambda text, **_: sent.append(text) or True)
    marker: set[str] = set()
    monkeypatch.setattr(chain, "_chain_done", lambda _user_id, day: day.isoformat() in marker)
    monkeypatch.setattr(
        chain, "_mark_chain_done", lambda _user_id, day: marker.add(day.isoformat())
    )
    yield sent


def _stub_steps(monkeypatch: pytest.MonkeyPatch, **raisers: bool) -> dict[str, int]:
    """Stub the three steps; names in ``raisers`` raise. Returns a call counter."""
    calls = {"correlate": 0, "recs": 0, "briefing": 0}

    def make(name: str):
        def step(_day: date, _user_id: UUID, _tz: str, *, client=None) -> dict:  # noqa: ARG001
            calls[name] += 1
            if raisers.get(name):
                raise RuntimeError(f"{name} boom")
            return {"ran": name}

        return step

    for name in calls:
        monkeypatch.setattr(chain, f"step_{name}", make(name))
    return calls


def test_a_raising_step_is_caught_reported_and_not_swallowed(
    monkeypatch: pytest.MonkeyPatch, notices: list[str]
) -> None:
    calls = _stub_steps(monkeypatch, recs=True)
    result = chain.run_chain(_OWNER, _TZ, DAY)  # must not raise

    recs = next(s for s in result.steps if s.name == "recs")
    assert recs.status == "failed"
    assert "recs boom" in (recs.error or "")
    # Reported to the health surface — the failure is visible, not hidden.
    assert any("chain step 'recs' failed" in n and "recs boom" in n for n in notices)
    # The other steps still ran; the process was not crashed.
    assert calls == {"correlate": 1, "recs": 1, "briefing": 1}


def test_correlate_failure_aborts_recs(monkeypatch: pytest.MonkeyPatch, notices: list[str]) -> None:
    calls = _stub_steps(monkeypatch, correlate=True)
    result = chain.run_chain(_OWNER, _TZ, DAY)

    statuses = {s.name: s.status for s in result.steps}
    assert statuses["correlate"] == "failed"
    assert statuses["recs"] == "skipped"  # dependency abort
    assert calls["recs"] == 0  # recs was NOT executed on stale inputs
    assert any("chain step 'correlate' failed" in n for n in notices)


def test_briefing_failure_does_not_undo_recs(
    monkeypatch: pytest.MonkeyPatch, notices: list[str]
) -> None:
    calls = _stub_steps(monkeypatch, briefing=True)
    result = chain.run_chain(_OWNER, _TZ, DAY)

    statuses = {s.name: s.status for s in result.steps}
    assert statuses["recs"] == "ok"  # recs completed and its result stands
    assert calls["recs"] == 1
    assert statuses["briefing"] == "failed"
    assert any("chain step 'briefing' failed" in n for n in notices)


def test_second_run_same_day_is_a_deduped_no_op(
    monkeypatch: pytest.MonkeyPatch,
    notices: list[str],  # noqa: ARG001
) -> None:
    calls = _stub_steps(monkeypatch)
    first = chain.run_chain(_OWNER, _TZ, DAY)
    assert first.deduped is False
    assert calls == {"correlate": 1, "recs": 1, "briefing": 1}

    second = chain.run_chain(_OWNER, _TZ, DAY)  # already ran today
    assert second.deduped is True
    assert second.steps == []
    assert calls == {"correlate": 1, "recs": 1, "briefing": 1}  # nothing re-fired

    forced = chain.run_chain(_OWNER, _TZ, DAY, force=True)  # force overrides dedup
    assert forced.deduped is False
    assert calls == {"correlate": 2, "recs": 2, "briefing": 2}
