"""Known-value tests for live challenge progress across every cadence and direction.

Each case seeds a hand-written series and asserts the exact numbers the engine must
produce — hit days, progress, streak, cumulative totals. Both comparators are
proven, because a direction bug scores a user's good day as a failure and is
invisible in a one-sided suite.

Auto-skips without a reachable TimescaleDB.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges.evaluate import evaluate_challenge
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, user_today
from healthee.db import migrate

pytestmark = pytest.mark.integration

_START = date(2026, 3, 1)
_TODAY = date(2026, 3, 7)
_ADOPTED = datetime(2026, 3, 1, 6, 0, tzinfo=UTC)  # 11:30 IST on 03-01


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _challenge(**overrides) -> dict:
    """A ``challenge`` row as the read layer will hand it over."""
    return {
        "metric": "steps_total",
        "comparator": ">=",
        "target_value": 8000.0,
        "cadence": "daily",
        "window_days": 7,
        "adopted_at": _ADOPTED,
        "baseline_value": None,
    } | overrides


def _week(values: list[float]) -> dict[date, float]:
    """``values`` laid out on 2026-03-01 … 2026-03-07."""
    return {_START + timedelta(days=i): v for i, v in enumerate(values)}


# ── daily, ">=" ──────────────────────────────────────────────────────────────


def test_daily_at_least_counts_hits_and_the_trailing_streak(clean_db: None) -> None:  # noqa: ARG001
    """9000 ×2, 5000, 9000 ×4 ⇒ six hit days of seven, and a streak of four.

    The streak walks back from 03-07: four hits, then 03-03's 5000 breaks it (no
    sleep data is seeded, so nothing is protected).
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur, _seed.OWNER, "steps_total", _week([9000, 9000, 5000, 9000, 9000, 9000, 9000])
        )
        result = evaluate_challenge(cur, _seed.OWNER, SENTINEL_TZ, _challenge(), today=_TODAY)
    assert result["cadence"] == "daily"
    assert result["hit_days"] == 6
    assert result["progress"] == round(6 / 7, 3)
    assert result["complete"] is False
    assert result["streak"] == 4
    assert result["today_value"] == 9000.0
    assert result["today_hit"] is True
    assert result["protected_today"] is False
    assert (result["elapsed"], result["days_left"], result["window"]) == (7, 0, 7)
    assert (result["unit"], result["label"]) == ("", "Steps")


def test_daily_completes_when_every_day_hits(clean_db: None) -> None:  # noqa: ARG001
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "steps_total", _week([9000] * 7))
        result = evaluate_challenge(cur, _seed.OWNER, SENTINEL_TZ, _challenge(), today=_TODAY)
    assert (result["hit_days"], result["progress"], result["complete"]) == (7, 1.0, True)
    assert result["streak"] == 7


# ── daily, "<=" (the capping direction) ──────────────────────────────────────


def test_daily_at_most_scores_the_opposite_direction(clean_db: None) -> None:  # noqa: ARG001
    """A cap challenge: keep cardio load at or below 50 on each of seven days.

    Same shape as the ">=" case with the values mirrored — 30, 40, 60, 30 ×4 — so
    six days hit and the streak is four. (The brief's example, a late-caffeine cap,
    has no trackable metric in the registry yet; what is proven here is the
    direction logic, which is what that challenge would rely on.)
    """
    challenge = _challenge(metric="cardio_load", comparator="<=", target_value=50.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "cardio_load", _week([30, 40, 60, 30, 30, 30, 30]))
        result = evaluate_challenge(cur, _seed.OWNER, SENTINEL_TZ, challenge, today=_TODAY)
    assert result["hit_days"] == 6
    assert result["streak"] == 4
    assert result["today_hit"] is True
    assert result["label"] == "Cardio load"


def test_the_same_series_scores_oppositely_under_the_two_comparators(
    clean_db: None,  # noqa: ARG001
) -> None:
    """One series, both directions: 7 hits one way, 0 the other. No shared bug can hide."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "cardio_load", _week([30] * 7))
        low = evaluate_challenge(
            cur,
            _seed.OWNER,
            SENTINEL_TZ,
            _challenge(metric="cardio_load", comparator="<=", target_value=50.0),
            today=_TODAY,
        )
        high = evaluate_challenge(
            cur,
            _seed.OWNER,
            SENTINEL_TZ,
            _challenge(metric="cardio_load", comparator=">=", target_value=50.0),
            today=_TODAY,
        )
    assert (low["hit_days"], high["hit_days"]) == (7, 0)


# ── streak protection inside evaluation ──────────────────────────────────────


def test_a_rough_night_keeps_the_streak_alive_through_a_missed_day(
    clean_db: None,  # noqa: ARG001
) -> None:
    """A 200-minute night against a 420-minute median protects 03-05's miss.

    Without protection the streak would be 2 (03-07, 03-06); the protected day is
    stepped over, so the run reaches back to 03-01 — six hit days.
    """
    nights = {_TODAY - timedelta(days=i): 420.0 for i in range(30)}
    nights[date(2026, 3, 5)] = 200.0
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur, _seed.OWNER, "steps_total", _week([9000, 9000, 9000, 9000, 1000, 9000, 9000])
        )
        _seed.seed_sleep(cur, _seed.OWNER, nights)
        result = evaluate_challenge(cur, _seed.OWNER, SENTINEL_TZ, _challenge(), today=_TODAY)
    assert result["hit_days"] == 6
    assert result["streak"] == 6


def test_protected_today_is_flagged_when_today_itself_was_the_rough_day(
    clean_db: None,  # noqa: ARG001
) -> None:
    """The app needs to say "rest day, streak safe" rather than "you missed"."""
    nights = {_TODAY - timedelta(days=i): 420.0 for i in range(30)}
    nights[_TODAY] = 180.0
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur, _seed.OWNER, "steps_total", _week([9000, 9000, 9000, 9000, 9000, 9000, 1000])
        )
        _seed.seed_sleep(cur, _seed.OWNER, nights)
        result = evaluate_challenge(cur, _seed.OWNER, SENTINEL_TZ, _challenge(), today=_TODAY)
    assert result["today_hit"] is False
    assert result["protected_today"] is True
    assert result["streak"] == 6


# ── weekly and total ─────────────────────────────────────────────────────────


def test_weekly_sums_the_rolling_seven_days_only(clean_db: None) -> None:  # noqa: ARG001
    """7 × 20 = 140 of a 150-minute weekly target; the day before the window is excluded.

    02-28 carries 100 minutes and is inside the queried series (the read starts one
    day early), so a weekly window that reached further back would report 240.
    """
    values = _week([20.0] * 7) | {date(2026, 2, 28): 100.0}
    challenge = _challenge(metric="mvpa_min", cadence="weekly", target_value=150.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "mvpa_min", values)
        result = evaluate_challenge(cur, _seed.OWNER, SENTINEL_TZ, challenge, today=_TODAY)
    assert result["cadence"] == "weekly"
    assert result["current"] == 140.0
    assert result["progress"] == round(140 / 150, 3)
    assert result["complete"] is False
    assert result["unit"] == "min"


def test_total_sums_from_adoption_to_today_over_a_longer_window(
    clean_db: None,  # noqa: ARG001
) -> None:
    """140 minutes of a 500-minute total, seven days into a fourteen-day window.

    Unlike ``weekly`` this counts from the adoption day, so the 100 minutes logged
    on 02-28 — before the challenge existed — must not be credited to it.
    """
    values = _week([20.0] * 7) | {date(2026, 2, 28): 100.0}
    challenge = _challenge(metric="mvpa_min", cadence="total", target_value=500.0, window_days=14)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "mvpa_min", values)
        result = evaluate_challenge(cur, _seed.OWNER, SENTINEL_TZ, challenge, today=_TODAY)
    assert result["current"] == 140.0
    assert result["progress"] == round(140 / 500, 3)
    assert (result["elapsed"], result["days_left"]) == (7, 7)


def test_total_completes_when_the_sum_reaches_the_target(clean_db: None) -> None:  # noqa: ARG001
    challenge = _challenge(metric="mvpa_min", cadence="total", target_value=140.0, window_days=14)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "mvpa_min", _week([20.0] * 7))
        result = evaluate_challenge(cur, _seed.OWNER, SENTINEL_TZ, challenge, today=_TODAY)
    assert (result["current"], result["progress"], result["complete"]) == (140.0, 1.0, True)


# ── sources other than a plain metric row ────────────────────────────────────


def test_a_workout_challenge_is_scored_from_the_workout_table(clean_db: None) -> None:  # noqa: ARG001
    """Three qualifying sessions of a four-a-week target."""
    challenge = _challenge(metric="workouts_week", cadence="weekly", target_value=4.0)
    with tenant_transaction(_seed.OWNER) as cur:
        for offset in (1, 3, 5):
            _seed.seed_workout(
                cur, _seed.OWNER, datetime(2026, 3, 1 + offset, 12, 0, tzinfo=UTC), 2400
            )
        result = evaluate_challenge(cur, _seed.OWNER, "UTC", challenge, today=_TODAY)
    assert result["current"] == 3.0
    assert result["progress"] == 0.75


def test_a_sleep_challenge_is_scored_from_the_flag_series(clean_db: None) -> None:  # noqa: ARG001
    """Five nights at or above 420 minutes of a seven-day daily target."""
    challenge = _challenge(metric="tst_min", target_value=420.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_sleep(cur, _seed.OWNER, _week([430, 430, 300, 430, 430, 300, 430]))
        result = evaluate_challenge(cur, _seed.OWNER, SENTINEL_TZ, challenge, today=_TODAY)
    assert result["hit_days"] == 5
    assert result["label"] == "Sleep"


# ── the day anchor and the input vocabulary ──────────────────────────────────


@pytest.mark.parametrize("tz", ["Pacific/Kiritimati", "Pacific/Midway"])
def test_today_defaults_to_the_owners_local_day(clean_db: None, tz: str) -> None:  # noqa: ARG001
    """Two zones 25 h apart never share a date, so a UTC anchor gets one of them wrong.

    ``date.today()`` is the server container's UTC date and is nobody's local day —
    the Python twin of the ``current_date`` anchors 6.4a removed from SQL. Seeding
    ONLY each owner's own local today makes a wrong anchor read as ``None``.
    """
    local_today = user_today(tz)
    adopted = datetime.combine(local_today, datetime.min.time(), tzinfo=UTC)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "steps_total", {local_today: 9000.0})
        result = evaluate_challenge(
            cur, _seed.OWNER, tz, _challenge(adopted_at=adopted, window_days=1)
        )
    assert result["today_value"] == 9000.0, "the anchor is not the owner's local day"
    assert result["today_hit"] is True


def test_adoption_day_resolves_in_the_owners_zone(clean_db: None) -> None:  # noqa: ARG001
    """23:00 UTC on 03-01 is already 04:30 on 03-02 in IST — the challenge started then.

    Getting this wrong shifts the whole window by a day: the calendar-date-vs-instant
    bug class that shipped two live wrong numbers in this repo.
    """
    adopted = datetime(2026, 3, 1, 23, 0, tzinfo=UTC)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "steps_total", _week([9000] * 7))
        result = evaluate_challenge(
            cur, _seed.OWNER, SENTINEL_TZ, _challenge(adopted_at=adopted), today=_TODAY
        )
    assert result["elapsed"] == 6, "started on 03-02 IST, so 03-07 is day six"
    assert result["hit_days"] == 6


def test_a_naive_adoption_timestamp_is_refused(clean_db: None) -> None:  # noqa: ARG001
    """Silently assuming the server's zone is how a day gets lost."""
    with tenant_transaction(_seed.OWNER) as cur, pytest.raises(ValueError, match="timezone-aware"):
        evaluate_challenge(
            cur,
            _seed.OWNER,
            SENTINEL_TZ,
            _challenge(adopted_at=datetime(2026, 3, 1, 6, 0)),
            today=_TODAY,
        )


@pytest.mark.parametrize(
    ("field", "value", "error"),
    [
        ("metric", "happiness", KeyError),
        ("comparator", "~=", ValueError),
        ("cadence", "fortnightly", ValueError),
    ],
)
def test_an_untrackable_rule_raises_rather_than_scoring_zero(
    clean_db: None,  # noqa: ARG001
    field: str,
    value: str,
    error: type[Exception],
) -> None:
    """Legacy scored these as 0 % forever — a broken challenge that looked like a lazy user."""
    with tenant_transaction(_seed.OWNER) as cur, pytest.raises(error):
        evaluate_challenge(
            cur, _seed.OWNER, SENTINEL_TZ, _challenge(**{field: value}), today=_TODAY
        )
