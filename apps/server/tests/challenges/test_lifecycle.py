"""Seeded-DB tests for the challenge state machine (WP-C2).

What these exist to catch, in order of how badly it would hurt:

1. **A baseline captured wrong or captured twice.** It is frozen once at adopt and
   is the anchor of every before/after the ledger will ever claim.
2. **A cap that is not per owner.** Legacy's was global; leaked here, one owner
   filling their three slots would lock every other owner out.
3. **A window that ran out unmet recorded as "completed"** — a system that files
   failures as successes cannot learn from either.
4. **A read that writes.** `list_challenges` must never close anything.

Auto-skips without a reachable TimescaleDB (the suite-wide policy).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import pytest
from tests.challenges import _seed

from healthee.challenges import lifecycle, store
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, user_today
from healthee.db import migrate

pytestmark = pytest.mark.integration

IST = SENTINEL_TZ
_START = date(2026, 3, 1)
_TODAY = date(2026, 3, 7)
_AFTER_WINDOW = date(2026, 3, 8)
_ADOPTED = datetime(2026, 3, 1, 6, 0, tzinfo=UTC)  # 11:30 IST on 03-01


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


@pytest.fixture
def two_owners(clean_db: None) -> Iterator[None]:  # noqa: ARG001
    _seed.ensure_owner_b()
    yield
    _seed.remove_owner_b()


def _week(cur, owner, values: list[float], metric: str = "steps_total") -> None:
    _seed.seed_metric(
        cur, owner, metric, {_START + timedelta(days=i): v for i, v in enumerate(values)}
    )


# ── adopt: the baseline is frozen from the owner's own trailing data ─────────


def test_adopt_freezes_the_owners_own_trailing_baseline(clean_db: None) -> None:  # noqa: ARG001
    """Seven days of 3000/4000 alternating before 03-08 ⇒ 3428.6, and 03-08 excluded.

    The adoption day itself must not count: a baseline that includes the challenge's
    own first day compares the owner against a number they were already inside.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _week(cur, _seed.OWNER, [3000.0 + (i % 2) * 1000 for i in range(7)])
        _seed.seed_metric(cur, _seed.OWNER, "steps_total", {_AFTER_WINDOW: 99999.0})
        challenge_id = _seed.seed_challenge(cur, _seed.OWNER)
        result = lifecycle.adopt(cur, _seed.OWNER, IST, challenge_id, today=_AFTER_WINDOW)
    assert result["ok"] is True
    assert result["challenge"]["baseline_value"] == 3428.6
    assert result["challenge"]["status"] == "active"


def test_adopt_records_no_baseline_rather_than_a_zero_when_there_is_no_data(
    clean_db: None,  # noqa: ARG001
) -> None:
    """ "We don't know their baseline" and "their baseline is zero" are different claims.

    A 0 here would make every later `improvement_pct` a division by nothing and the
    adapter's ease floor meaningless.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        challenge_id = _seed.seed_challenge(cur, _seed.OWNER)
        result = lifecycle.adopt(cur, _seed.OWNER, IST, challenge_id, today=_AFTER_WINDOW)
    assert result["ok"] is True
    assert result["challenge"]["baseline_value"] is None


@pytest.mark.parametrize("tz", ["Asia/Kolkata", "America/New_York", "Pacific/Kiritimati"])
def test_the_window_ends_at_the_owners_local_midnight_after_the_last_day(
    clean_db: None,  # noqa: ARG001
    tz: str,
) -> None:
    """A 7-day window closes at 00:00 LOCAL on the 8th day, in three different zones.

    Anchored to the owner's real local today rather than a pinned date, because
    `adopted_at` is the actual instant of adoption — that is the whole point of the
    conversion. Built from a UTC instant instead, an IST owner's window would end at
    05:30 in the middle of their morning: the calendar-date-vs-instant class again.
    """
    expected = datetime.combine(user_today(tz) + timedelta(days=7), time.min, tzinfo=ZoneInfo(tz))
    with tenant_transaction(_seed.OWNER) as cur:
        challenge_id = _seed.seed_challenge(cur, _seed.OWNER)
        result = lifecycle.adopt(cur, _seed.OWNER, tz, challenge_id)
    assert result["challenge"]["ends_at"] == expected


def test_a_challenge_that_is_not_suggested_cannot_be_adopted(clean_db: None) -> None:  # noqa: ARG001
    """Re-adopting a live challenge would reset the baseline mid-flight."""
    with tenant_transaction(_seed.OWNER) as cur:
        challenge_id = _seed.seed_challenge(cur, _seed.OWNER)
        lifecycle.adopt(cur, _seed.OWNER, IST, challenge_id, today=_START)
        again = lifecycle.adopt(cur, _seed.OWNER, IST, challenge_id, today=_START)
    assert (again["ok"], again["reason"]) == (False, "not_suggested")


@pytest.mark.parametrize("status", ["active", "completed", "abandoned"])
def test_the_write_itself_refuses_a_challenge_that_is_no_longer_suggested(
    clean_db: None,  # noqa: ARG001
    status: str,
) -> None:
    """The status predicate lives in the UPDATE, not only in `adopt`'s pre-check.

    Exercised directly because that is the only way to reach it: `adopt` checks the
    status first, so the guard exists solely for the case where two requests both
    pass that check and race. The loser must update zero rows — otherwise it resets
    the winner's baseline mid-flight, silently re-anchoring every before/after the
    ledger will later claim.

    (Found by mutation testing: deleting the predicate broke nothing until this
    existed.)
    """
    now = datetime.now(tz=UTC)
    with tenant_transaction(_seed.OWNER) as cur:
        cid = _seed.seed_challenge(cur, _seed.OWNER, status=status)
        assert store.mark_adopted(cur, _seed.OWNER, cid, now, now, 100.0) is False
        assert _seed.stored(cur, _seed.OWNER, cid)["baseline_value"] is None


@pytest.mark.parametrize("status", ["suggested", "completed", "abandoned"])
def test_only_an_active_challenge_can_be_closed_out(
    clean_db: None,  # noqa: ARG001
    status: str,
) -> None:
    """The same race guard on the finishing writes — a frozen outcome must stay frozen.

    Re-closing an already-closed challenge would overwrite a terminal status (an
    `expired` quietly becoming `completed`) and re-stamp its timestamps.
    """
    now = datetime.now(tz=UTC)
    with tenant_transaction(_seed.OWNER) as cur:
        cid = _seed.seed_challenge(cur, _seed.OWNER, status=status)
        assert store.mark_finished(cur, _seed.OWNER, cid, "completed", now) is False
        assert store.mark_abandoned(cur, _seed.OWNER, cid, now) is False
        assert _seed.stored(cur, _seed.OWNER, cid)["status"] == status


def test_an_unknown_challenge_is_refused_by_name(clean_db: None) -> None:  # noqa: ARG001
    """An explicit named refusal, never an empty success (standards §Errors)."""
    with tenant_transaction(_seed.OWNER) as cur:
        result = lifecycle.adopt(cur, _seed.OWNER, IST, 987654, today=_START)
    assert (result["ok"], result["reason"]) == (False, "not_found")


# ── the cap is PER OWNER ─────────────────────────────────────────────────────


def test_a_fourth_challenge_is_refused(clean_db: None) -> None:  # noqa: ARG001
    """Three is the cap; the fourth is told why, and by how much."""
    with tenant_transaction(_seed.OWNER) as cur:
        for _ in range(lifecycle.MAX_ACTIVE):
            cid = _seed.seed_challenge(cur, _seed.OWNER)
            assert lifecycle.adopt(cur, _seed.OWNER, IST, cid, today=_START)["ok"] is True
        fourth = _seed.seed_challenge(cur, _seed.OWNER)
        result = lifecycle.adopt(cur, _seed.OWNER, IST, fourth, today=_START)
    assert (result["ok"], result["reason"]) == (False, "too_many_active")
    assert "3 of 3" in result["error"]


# ── abandon ──────────────────────────────────────────────────────────────────


def test_abandon_ends_an_active_challenge(clean_db: None) -> None:  # noqa: ARG001
    with tenant_transaction(_seed.OWNER) as cur:
        cid = _seed.seed_challenge(cur, _seed.OWNER)
        lifecycle.adopt(cur, _seed.OWNER, IST, cid, today=_START)
        result = lifecycle.abandon(cur, _seed.OWNER, IST, cid, today=_TODAY)
    assert result["ok"] is True
    assert result["challenge"]["status"] == "abandoned"
    assert result["challenge"]["abandoned_at"] is not None


def test_a_suggestion_cannot_be_abandoned(clean_db: None) -> None:  # noqa: ARG001
    """Nothing was taken on, so nothing can be given up — and the answer says which."""
    with tenant_transaction(_seed.OWNER) as cur:
        cid = _seed.seed_challenge(cur, _seed.OWNER)
        result = lifecycle.abandon(cur, _seed.OWNER, IST, cid, today=_TODAY)
    assert (result["ok"], result["reason"]) == (False, "not_active")


# ── auto-completion: both paths ──────────────────────────────────────────────


def test_a_met_target_closes_the_challenge_as_completed(clean_db: None) -> None:  # noqa: ARG001
    """Seven of seven days at 9000 against an 8000 target, on day seven."""
    with tenant_transaction(_seed.OWNER) as cur:
        _week(cur, _seed.OWNER, [9000.0] * 7)
        cid = _seed.seed_challenge(cur, _seed.OWNER, status="active", adopted_at=_ADOPTED)
        closed = lifecycle.finalize_due(cur, _seed.OWNER, IST, _TODAY)
        challenge = _seed.stored(cur, _seed.OWNER, cid)
    assert closed == [{"challenge_id": cid, "status": "completed"}]
    assert challenge["status"] == "completed"
    assert challenge["completed_at"] is not None


def test_a_window_that_ran_out_unmet_closes_as_expired(clean_db: None) -> None:  # noqa: ARG001
    """Four of seven days hit; on 03-08 the window is over and it was NOT met.

    Legacy called this "completed". `completed_at` stays NULL, because it never was.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _week(cur, _seed.OWNER, [9000.0, 9000.0, 1000.0, 1000.0, 1000.0, 9000.0, 9000.0])
        cid = _seed.seed_challenge(cur, _seed.OWNER, status="active", adopted_at=_ADOPTED)
        closed = lifecycle.finalize_due(cur, _seed.OWNER, IST, _AFTER_WINDOW)
        challenge = _seed.stored(cur, _seed.OWNER, cid)
    assert closed == [{"challenge_id": cid, "status": "expired"}]
    assert challenge["status"] == "expired"
    assert challenge["completed_at"] is None


def test_a_running_challenge_is_left_alone(clean_db: None) -> None:  # noqa: ARG001
    """Day three of seven, four days short — the verdict is still open."""
    with tenant_transaction(_seed.OWNER) as cur:
        _week(cur, _seed.OWNER, [9000.0] * 3)
        cid = _seed.seed_challenge(cur, _seed.OWNER, status="active", adopted_at=_ADOPTED)
        closed = lifecycle.finalize_due(cur, _seed.OWNER, IST, date(2026, 3, 3))
        assert _seed.stored(cur, _seed.OWNER, cid)["status"] == "active"
    assert closed == []


def test_a_reached_total_closes_early_but_an_unbroken_cap_waits(clean_db: None) -> None:  # noqa: ARG001
    """The irrevocability rule, both ways, on day three of seven.

    A `>=` total of 150 minutes is reached and can never be un-reached ⇒ closed now.
    A `<=` cap that has merely not been blown yet proves nothing — the owner still
    has the rest of today — ⇒ left running.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _week(cur, _seed.OWNER, [60.0, 60.0, 60.0], metric="mvpa_min")
        reached = _seed.seed_challenge(
            cur,
            _seed.OWNER,
            status="active",
            adopted_at=_ADOPTED,
            metric="mvpa_min",
            cadence="total",
            target_value=150.0,
        )
        cap = _seed.seed_challenge(
            cur,
            _seed.OWNER,
            status="active",
            adopted_at=_ADOPTED,
            metric="alcohol_units",
            cadence="total",
            comparator="<=",
            target_value=5.0,
        )
        closed = lifecycle.finalize_due(cur, _seed.OWNER, IST, date(2026, 3, 3))
        statuses = {c: _seed.stored(cur, _seed.OWNER, c)["status"] for c in (reached, cap)}
    assert closed == [{"challenge_id": reached, "status": "completed"}]
    assert statuses == {reached: "completed", cap: "active"}


def test_a_blown_cap_closes_immediately(clean_db: None) -> None:  # noqa: ARG001
    """9 units against a 5-unit total cap on day two: nothing un-drinks a drink."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(
            cur, _seed.OWNER, "alcohol", [(datetime(2026, 3, 1, 20, 0, tzinfo=UTC), 9.0, "units")]
        )
        cid = _seed.seed_challenge(
            cur,
            _seed.OWNER,
            status="active",
            adopted_at=datetime(2026, 3, 1, 0, 0, tzinfo=UTC),
            metric="alcohol_units",
            cadence="total",
            comparator="<=",
            target_value=5.0,
        )
        closed = lifecycle.finalize_due(cur, _seed.OWNER, "UTC", date(2026, 3, 2))
    assert closed == [{"challenge_id": cid, "status": "expired"}]


# ── the read is pure ─────────────────────────────────────────────────────────


def test_listing_challenges_never_closes_one(clean_db: None) -> None:  # noqa: ARG001
    """A GET that writes is not idempotent, races itself, and hides on the read budget.

    The challenge below is finished by every measure; listing it must report that
    without changing it. Only a write path may close it.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _week(cur, _seed.OWNER, [9000.0] * 7)
        cid = _seed.seed_challenge(cur, _seed.OWNER, status="active", adopted_at=_ADOPTED)
        feed = lifecycle.list_challenges(cur, _seed.OWNER, IST, today=_AFTER_WINDOW)
        assert _seed.stored(cur, _seed.OWNER, cid)["status"] == "active"
    assert [c["id"] for c in feed["active"]] == [cid]
    assert feed["active"][0]["progress"]["complete"] is True
    assert feed["active"][0]["progress"]["days_left"] == 0


def test_the_feed_separates_suggestions_from_what_ended(clean_db: None) -> None:  # noqa: ARG001
    with tenant_transaction(_seed.OWNER) as cur:
        suggested = _seed.seed_challenge(cur, _seed.OWNER)
        done = _seed.seed_challenge(cur, _seed.OWNER, status="completed")
        feed = lifecycle.list_challenges(cur, _seed.OWNER, IST, today=_TODAY)
    assert [c["id"] for c in feed["suggested"]] == [suggested]
    assert [c["id"] for c in feed["recent"]] == [done]
    assert (feed["active"], feed["max_active"]) == ([], lifecycle.MAX_ACTIVE)


def test_the_feed_carries_the_pending_recalibration(clean_db: None) -> None:  # noqa: ARG001
    """A raise is SURFACED, never applied — §5.2 keeps it behind the owner's tap.

    Seven days averaging 6000 against a 5000 target is ratio 1.2 ⇒ +20 %, and the
    stored target must still read 5000 afterwards. The window is 14 days so the
    challenge is genuinely mid-flight — the adapter (rightly) never moves a target
    that is already met.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _week(cur, _seed.OWNER, [6000.0] * 7)
        cid = _seed.seed_challenge(
            cur,
            _seed.OWNER,
            status="active",
            adopted_at=_ADOPTED,
            target_value=5000.0,
            window_days=14,
        )
        feed = lifecycle.list_challenges(cur, _seed.OWNER, IST, today=_TODAY)
        assert _seed.stored(cur, _seed.OWNER, cid)["target_value"] == 5000.0
    adaptation = feed["active"][0]["progress"]["adaptation"]
    assert (adaptation["direction"], adaptation["suggested"]) == ("up", 6000.0)


def test_adopting_closes_a_finished_challenge_so_the_cap_is_not_stuck(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Three finished-but-unclosed challenges must not lock the owner out.

    This is why `adopt` finalizes first. Without it the cap is computed from stale
    rows, the owner is refused, and there is nothing they can do about it — the
    concrete cost of leaving auto-completion to a nightly job alone.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _week(cur, _seed.OWNER, [9000.0] * 7)
        for _ in range(lifecycle.MAX_ACTIVE):
            _seed.seed_challenge(cur, _seed.OWNER, status="active", adopted_at=_ADOPTED)
        fresh = _seed.seed_challenge(cur, _seed.OWNER)
        result = lifecycle.adopt(cur, _seed.OWNER, IST, fresh, today=_TODAY)
        assert store.count_active(cur, _seed.OWNER) == 1
    assert result["ok"] is True
