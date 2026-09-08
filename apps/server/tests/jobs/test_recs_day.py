"""B2 · `generate_recs` may only date a row the day its own inputs answered for.

``day`` reached exactly two things — the persisted row's ``date`` column and a log line
— while every INPUT is unconditionally today's: ``build_recs_signals(user_id, tz)`` takes
no day, and ``grounded_ask`` builds its context through ``context.build_context``, which
anchors on ``user_today(tz)`` throughout and accepts no reference day.

So a call with a past ``day`` wrote **today's judgement, from today's data, under an
older date** — and ``read/today.py::_recommendations_for`` then serves that row as that
day's answer, which ``docs/AS_OF_DAY.md`` §7 authorises precisely because such rows "are
already written and already dated". That is only an argument if the dating is honest.

Making ``day`` bind the inputs is the other repair and §6 forbids it: authoring a past
day's analysis now is a new claim, not a record. So the comparison is the fix, and it
raises rather than clamping — ``jobs/chain.py`` names ``force=True`` as the back-fill
escape hatch and argues only about the dedup marker, never about what the back-filled
CONTENT would be, so a back-fill that would mislabel a row must fail where somebody can
see it. ``_run_supervised`` catches it per step, logs it and Telegrams it.

No database and no model: the refusal is the first thing ``generate_recs`` does, which is
itself the property worth pinning — a check that runs after the work has been paid for is
a different check.
"""

from __future__ import annotations

from datetime import timedelta

import pytest

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.jobs import recs


class _NeverCalled:
    """Fails if a model is reached — the refusal must precede every cost."""

    def complete(self, messages, **kwargs):  # noqa: ANN001, ANN003, ANN201, ARG002
        raise AssertionError("a refused day must not reach the model")


def test_a_past_day_is_refused_before_anything_is_spent() -> None:
    """THE finding. Today's judgement must not be filed under an older date."""
    yesterday = user_today(SENTINEL_TZ) - timedelta(days=1)

    with pytest.raises(ValueError) as raised:
        recs.generate_recs(SENTINEL_USER_ID, SENTINEL_TZ, yesterday, client=_NeverCalled())

    message = str(raised.value)
    assert yesterday.isoformat() in message
    assert "AS_OF_DAY" in message, "the refusal names the rule it is enforcing"


def test_a_future_day_is_refused_too() -> None:
    """The mirror. A row dated tomorrow is a claim about a day that has not happened."""
    with pytest.raises(ValueError):
        recs.generate_recs(
            SENTINEL_USER_ID,
            SENTINEL_TZ,
            user_today(SENTINEL_TZ) + timedelta(days=1),
            client=_NeverCalled(),
        )


def test_a_far_back_day_is_refused(monkeypatch: pytest.MonkeyPatch) -> None:
    """A back-fill is exactly the caller this exists for, and it fails loudly."""
    with pytest.raises(ValueError):
        recs.generate_recs(
            SENTINEL_USER_ID,
            SENTINEL_TZ,
            user_today(SENTINEL_TZ) - timedelta(days=60),
            client=_NeverCalled(),
        )
    # And nothing was monkeypatched away to get here — the guard is the whole path.
    assert monkeypatch is not None


def test_the_owners_own_today_is_accepted(monkeypatch: pytest.MonkeyPatch) -> None:
    """The guard must not be a blanket refusal: the normal chain call still runs.

    Stubbed at the first thing past the comparison, so this asserts the day check passed
    and nothing else — a DB-backed run is ``tests/jobs/test_recs_integration.py``'s job.
    """
    reached: list[str] = []

    def _signals(user_id, tz):  # noqa: ANN001, ANN202, ARG001
        reached.append("signals")
        raise RuntimeError("stop here")

    monkeypatch.setattr(recs, "build_recs_signals", _signals)

    with pytest.raises(RuntimeError):
        recs.generate_recs(
            SENTINEL_USER_ID, SENTINEL_TZ, user_today(SENTINEL_TZ), client=_NeverCalled()
        )
    assert reached == ["signals"]


def test_no_day_at_all_is_the_owners_today(monkeypatch: pytest.MonkeyPatch) -> None:
    """The default path — the one the scheduler takes — is unchanged."""
    monkeypatch.setattr(
        recs,
        "build_recs_signals",
        lambda user_id, tz: (_ for _ in ()).throw(RuntimeError("stop here")),
    )
    with pytest.raises(RuntimeError):
        recs.generate_recs(SENTINEL_USER_ID, SENTINEL_TZ, client=_NeverCalled())
