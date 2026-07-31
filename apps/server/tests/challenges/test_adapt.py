"""Seeded-DB tests for the adapter's read half: the signal gates and unit scaling.

``test_adapt_rules`` pins the arithmetic; this pins what the engine is willing to
adapt ON. Every ``None`` here is a live commitment left alone because the evidence
to move it was not there — which is the honest answer far more often than a
recalibration is.

Auto-skips without a reachable TimescaleDB.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges.adapt import suggest_adaptation
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.db import migrate

pytestmark = pytest.mark.integration

_START = date(2026, 3, 1)
_TODAY = date(2026, 3, 7)  # day seven — past the five-day signal gate
_ADOPTED = datetime(2026, 3, 1, 6, 0, tzinfo=UTC)  # 11:30 IST on 03-01

_RUNNING = {"complete": False}


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _challenge(**overrides) -> dict:
    return {
        "metric": "steps_total",
        "comparator": ">=",
        "target_value": 5000.0,
        "cadence": "daily",
        "window_days": 14,
        "adopted_at": _ADOPTED,
        "baseline_value": None,
    } | overrides


def _seed_week(cur, metric: str, value: float, days: int = 7) -> None:
    """``days`` consecutive days of the same value, starting on the adoption day."""
    _seed.seed_metric(
        cur, _seed.OWNER, metric, {_START + timedelta(days=i): value for i in range(days)}
    )


# ── the happy path ───────────────────────────────────────────────────────────


def test_a_week_of_beating_the_target_raises_it(clean_db: None) -> None:  # noqa: ARG001
    """Seven days averaging 6000 against a 5000 target — ratio 1.2, so +20 %."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, "steps_total", 6000.0)
        result = suggest_adaptation(
            cur, _seed.OWNER, SENTINEL_TZ, _challenge(), _RUNNING, today=_TODAY
        )
    assert result == {
        "direction": "up",
        "suggested": 6000.0,
        "current": 5000.0,
        "reason": "averaging 6000 vs 5000 target",
    }


def test_a_week_of_falling_short_eases_it(clean_db: None) -> None:  # noqa: ARG001
    """60 of a 100-minute target is ratio 0.6; −15 % lands on 85, above the 52.5 floor."""
    challenge = _challenge(metric="mvpa_min", target_value=100.0, baseline_value=50.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, "mvpa_min", 60.0)
        result = suggest_adaptation(cur, _seed.OWNER, SENTINEL_TZ, challenge, _RUNNING, _TODAY)
    assert result is not None
    assert (result["direction"], result["suggested"]) == ("down", 85.0)


# ── unit scaling: the achieved value must be in the TARGET's units ───────────


def test_a_weekly_target_is_compared_against_a_weekly_total(clean_db: None) -> None:  # noqa: ARG001
    """30 min/day is 210 min/week against a 100-minute weekly target — ratio 2.1.

    Compared unscaled, 30 vs 100 would read as ratio 0.3 and EASE a target the user
    is doubling: the failure mode is not a missed adaptation but an inverted one.
    150 is the MVPA ceiling, so the +20 % lands on 120.
    """
    challenge = _challenge(metric="mvpa_min", cadence="weekly", target_value=100.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, "mvpa_min", 30.0)
        result = suggest_adaptation(cur, _seed.OWNER, SENTINEL_TZ, challenge, _RUNNING, _TODAY)
    assert result is not None
    assert (result["direction"], result["suggested"]) == ("up", 120.0)
    assert result["reason"] == "averaging 210min vs 100min target"


def test_a_total_target_is_scaled_by_the_whole_window(clean_db: None) -> None:  # noqa: ARG001
    """30/day over a ten-day window is 300 against a 200 total — ratio 1.5 ⇒ 240.

    ``cardio_load`` has no evidence ideal, so its ceiling is owner-relative: a frozen
    baseline of 180 allows up to 270, and 240 is under it.
    """
    challenge = _challenge(
        metric="cardio_load",
        cadence="total",
        target_value=200.0,
        window_days=10,
        baseline_value=180.0,
    )
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, "cardio_load", 30.0)
        result = suggest_adaptation(cur, _seed.OWNER, SENTINEL_TZ, challenge, _RUNNING, _TODAY)
    assert result is not None
    assert (result["direction"], result["suggested"]) == ("up", 240.0)


def test_a_metric_with_no_ideal_and_no_baseline_is_never_raised(clean_db: None) -> None:  # noqa: ARG001
    """The same over-performance, with nothing to bound the raise against ⇒ no change.

    Legacy raised this +20 % with no ceiling at all, every five days, forever. With
    no evidence ideal AND no frozen baseline there is no honest number to stop at, so
    the engine declines rather than guessing (CLAUDE.md — "not enough data" wins).
    """
    challenge = _challenge(
        metric="cardio_load", cadence="total", target_value=200.0, window_days=10
    )
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, "cardio_load", 30.0)
        result = suggest_adaptation(cur, _seed.OWNER, SENTINEL_TZ, challenge, _RUNNING, _TODAY)
    assert result is None


def test_a_live_sri_challenge_stops_at_the_notes_threshold(clean_db: None) -> None:  # noqa: ARG001
    """End to end (#67): a week of SRI 80 against a 62 target raises to 70, not 74.

    ``test_adapt_rules`` pins the arithmetic; this proves the ceiling is reached through
    the real read path — the registry's `sri` key resolving to the
    ``sleep_regularity_index`` row, and the recovery guard correctly NOT intercepting
    (regularity is recovery-supporting, so it is not a hard training lever).
    """
    challenge = _challenge(metric="sri", target_value=62.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, "sleep_regularity_index", 80.0)
        result = suggest_adaptation(cur, _seed.OWNER, SENTINEL_TZ, challenge, _RUNNING, _TODAY)
    assert result is not None
    assert (result["direction"], result["suggested"]) == ("up", 70.0)
    assert result["reason"] == "averaging 80 vs 62 target"


def test_a_live_sri_challenge_already_at_the_threshold_is_left_alone(clean_db: None) -> None:  # noqa: ARG001
    """The same week against a 70 target: no room above the ceiling, so no suggestion.

    Under the old 85 this raised an adopted commitment to 84 — past the number the
    generator would ever have proposed and past anything the note states.
    """
    challenge = _challenge(metric="sri", target_value=70.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, "sleep_regularity_index", 95.0)
        result = suggest_adaptation(cur, _seed.OWNER, SENTINEL_TZ, challenge, _RUNNING, _TODAY)
    assert result is None


# ── the signal gates ─────────────────────────────────────────────────────────


def test_no_adaptation_before_five_days_have_elapsed(clean_db: None) -> None:  # noqa: ARG001
    """On day four the same performance means nothing yet — four days is not a trend."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, "steps_total", 6000.0)
        result = suggest_adaptation(
            cur, _seed.OWNER, SENTINEL_TZ, _challenge(), _RUNNING, today=date(2026, 3, 4)
        )
    assert result is None


def test_no_adaptation_on_too_few_logged_days(clean_db: None) -> None:  # noqa: ARG001
    """Two logged days of seven elapsed: adapting on that would be a call on noise."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, "steps_total", 6000.0, days=2)
        result = suggest_adaptation(
            cur, _seed.OWNER, SENTINEL_TZ, _challenge(), _RUNNING, today=_TODAY
        )
    assert result is None


def test_a_completed_challenge_is_not_adapted(clean_db: None) -> None:  # noqa: ARG001
    """It is finished — moving the goalposts now would rewrite a result."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, "steps_total", 6000.0)
        result = suggest_adaptation(
            cur, _seed.OWNER, SENTINEL_TZ, _challenge(), {"complete": True}, today=_TODAY
        )
    assert result is None


def test_capping_challenges_are_left_alone(clean_db: None) -> None:  # noqa: ARG001
    """A "<=" cap has no ported adaptation rule; guessing one would be inventing science."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, "steps_total", 6000.0)
        result = suggest_adaptation(
            cur, _seed.OWNER, SENTINEL_TZ, _challenge(comparator="<="), _RUNNING, today=_TODAY
        )
    assert result is None


@pytest.mark.parametrize("overrides", [{"adopted_at": None}, {"target_value": 0.0}])
def test_a_challenge_without_a_live_target_is_not_adapted(
    clean_db: None,  # noqa: ARG001
    overrides: dict,
) -> None:
    """Never adopted, or a zero target — there is nothing to calibrate against."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, "steps_total", 6000.0)
        result = suggest_adaptation(
            cur, _seed.OWNER, SENTINEL_TZ, _challenge(**overrides), _RUNNING, today=_TODAY
        )
    assert result is None
