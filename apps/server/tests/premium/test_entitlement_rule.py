"""The entitlement rule itself — the full status matrix, as pure functions (6.6a).

``core.entitlement.evaluate`` is deliberately pure and takes an injectable ``now``, so
the two things most likely to be got wrong — the grace window and the expiry — are
tested by arithmetic rather than by waiting a week. No DB: a rule this important should
not be reachable only through a fixture.

Every row of MULTI_USER.md §12.2's vocabulary appears here, INCLUDING the ones that must
be refused. A matrix that only checked the happy statuses would pass identically against
``return True``.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from healthee.core.config import get_settings
from healthee.core.entitlement import GRACE_DAYS, Subscription, evaluate

NOW = datetime(2026, 8, 1, 12, 0, tzinfo=UTC)
LATER = NOW + timedelta(days=30)
EARLIER = NOW - timedelta(days=1)


def _row(
    status: str,
    *,
    period_end: datetime | None = LATER,
    trial_end: datetime | None = None,
) -> Subscription:
    return Subscription(
        status=status, plan="annual", trial_end=trial_end, current_period_end=period_end
    )


# ── the statuses that grant access ────────────────────────────────────────────


@pytest.mark.parametrize("status", ["active", "trialing"])
def test_a_live_status_inside_its_period_is_premium(env: None, status: str) -> None:  # noqa: ARG001
    assert evaluate(_row(status), NOW).premium is True


def test_a_trial_is_bounded_by_trial_end_not_the_period(env: None) -> None:  # noqa: ARG001
    """A provider that sets both must not have the longer one silently win.

    `trial_end` is the instant the trial is over; `current_period_end` on a trialing row
    is whenever the first paid period would end. Reading the second would hand out a
    month of free inference to anyone who started a trial.
    """
    row = _row("trialing", period_end=NOW + timedelta(days=365), trial_end=EARLIER)
    verdict = evaluate(row, NOW)
    assert verdict.premium is False
    assert verdict.expires_at == EARLIER


def test_a_trial_with_only_a_period_end_still_works(env: None) -> None:  # noqa: ARG001
    """Falling back is not guessing — some providers only ever set one of the two."""
    assert evaluate(_row("trialing", trial_end=None), NOW).premium is True


# ── the statuses that do not ──────────────────────────────────────────────────


@pytest.mark.parametrize("status", ["none", "canceled", "expired"])
def test_a_dead_status_is_never_premium_however_long_its_period_runs(
    env: None,  # noqa: ARG001
    status: str,
) -> None:
    """§12.7's "keep access after cancel/refund/chargeback" loophole.

    The period end is deliberately far in the FUTURE here: a rule that only checked the
    date would pass this row, which is the exact mistake being guarded against.
    """
    assert evaluate(_row(status, period_end=NOW + timedelta(days=999)), NOW).premium is False


def test_an_active_row_past_its_period_end_is_not_premium(env: None) -> None:  # noqa: ARG001
    """ "Granted once, forgotten" — the reason `is_premium` re-checks the date every call."""
    verdict = evaluate(_row("active", period_end=EARLIER), NOW)
    assert verdict.premium is False
    assert verdict.status == "active"  # the STORED status is still reported honestly


def test_a_row_with_no_end_instant_at_all_is_not_premium(env: None) -> None:  # noqa: ARG001
    """Fails closed: an entitlement nobody can date is one nobody can revoke."""
    assert evaluate(_row("active", period_end=None), NOW).premium is False


def test_no_row_at_all_is_not_premium(env: None) -> None:  # noqa: ARG001
    """The default for every owner who has never paid — including the sentinel."""
    verdict = evaluate(None, NOW)
    assert verdict.premium is False
    assert verdict.status == "none"
    assert verdict.expires_at is None


# ── the dunning window (§12.5) ────────────────────────────────────────────────


def test_past_due_stays_premium_inside_the_grace_window(env: None) -> None:  # noqa: ARG001
    """One failed renewal must not instantly wall a paying user out."""
    ended = NOW - timedelta(days=GRACE_DAYS - 1)
    assert evaluate(_row("past_due", period_end=ended), NOW).premium is True


def test_past_due_is_locked_out_once_the_grace_window_closes(env: None) -> None:  # noqa: ARG001
    ended = NOW - timedelta(days=GRACE_DAYS, seconds=1)
    assert evaluate(_row("past_due", period_end=ended), NOW).premium is False


def test_the_grace_window_is_added_to_the_period_end_not_to_now(env: None) -> None:  # noqa: ARG001
    """The boundary is the thing being asserted, so it is asserted as a VALUE.

    `expires_at` is `current_period_end + GRACE_DAYS`; an implementation that granted
    "seven more days from whenever you ask" would renew itself forever.
    """
    ended = NOW - timedelta(days=2)
    assert evaluate(_row("past_due", period_end=ended), NOW).expires_at == ended + timedelta(
        days=GRACE_DAYS
    )


# ── the self-hosted override ──────────────────────────────────────────────────


def test_self_host_unlocked_entitles_an_owner_with_no_row(
    env: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A self-hosted box pays its own LLM bill, so the paywall's premise does not hold."""
    monkeypatch.setenv("SELF_HOST_UNLOCKED", "true")
    get_settings.cache_clear()
    verdict = evaluate(None, NOW)
    assert verdict.premium is True
    assert verdict.source == "self_host"


def test_self_host_unlocked_is_off_by_default(env: None) -> None:  # noqa: ARG001
    """The hosted service must never be unlocked by forgetting to set something."""
    assert get_settings().self_host_unlocked is False


def test_a_premium_verdict_names_where_it_came_from(env: None) -> None:  # noqa: ARG001
    """ "You paid" and "this whole box is unlocked" are different facts about a deploy."""
    assert evaluate(_row("active"), NOW).source == "subscription"
    assert evaluate(_row("expired"), NOW).source == "none"
