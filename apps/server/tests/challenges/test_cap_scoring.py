"""Known-value tests for #61 — the comparator on a CUMULATIVE cadence.

The defect this file exists over: `weekly`/`total` scored `current >= target`
whatever the comparator, so a `<=` cap was graded backwards and the owner was
marked complete at the exact moment they blew it. A confidently wrong number, in
the direction that congratulates someone for the thing the challenge existed to
reduce.

Split out of ``test_evaluate`` rather than added to it: the "reach a target"
scoring and the "stay under a cap" scoring are two rules, and each must be able
to fail without the other (and the file gate is 400 lines).

Every number below is hand-computed, and the matrix is deliberately both
comparators × all three cadences — a one-sided suite is exactly what let this
survive WP-C1.

Auto-skips without a reachable TimescaleDB.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges.evaluate import evaluate_challenge
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
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


#
# The defect: `weekly`/`total` scored `current >= target` whatever the comparator,
# so a `<=` cap was marked COMPLETE at the exact moment it was blown. Every case
# below is hand-computed, and the matrix is deliberately both comparators × all
# three cadences — a one-sided suite is what let this survive WP-C1.


def test_the_same_series_scores_oppositely_on_a_cumulative_cadence(
    clean_db: None,  # noqa: ARG001
) -> None:
    """THE #61 REGRESSION TEST. 7 × 3 = 21 units against a target of 5.

    Under `>=` that is a completed "reach 21 units" rule. Under `<=` it is a cap
    blown four times over — and the defect scored it `complete: True`, i.e. it
    congratulated the owner for the drinking the challenge existed to reduce.
    """
    entries = [(datetime(2026, 3, 1 + i, 20, 0, tzinfo=UTC), 3.0, "units") for i in range(7)]
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(cur, _seed.OWNER, "alcohol", entries)
        reach = evaluate_challenge(
            cur,
            _seed.OWNER,
            "UTC",
            _challenge(metric="alcohol_units", cadence="total", comparator=">=", target_value=5.0),
            today=_TODAY,
        )
        cap = evaluate_challenge(
            cur,
            _seed.OWNER,
            "UTC",
            _challenge(metric="alcohol_units", cadence="total", comparator="<=", target_value=5.0),
            today=_TODAY,
        )
    assert (reach["current"], cap["current"]) == (21.0, 21.0), "same series, same total"
    assert reach["complete"] is True
    assert cap["complete"] is False, "a blown cap is not a completed challenge"
    assert cap["breached"] is True
    assert (reach["breached"], cap["progress"]) == (False, 0.0)


@pytest.mark.parametrize("cadence", ["weekly", "total"])
def test_a_cumulative_cap_kept_for_the_whole_window_completes(
    clean_db: None,  # noqa: ARG001
    cadence: str,
) -> None:
    """7 × 0.5 = 3.5 units under a 5-unit cap, on a 7-day window that has elapsed.

    Completion needs the window to have RUN OUT, not merely a number to compare:
    nothing about day three proves a cap will be kept on day six.
    """
    entries = [(datetime(2026, 3, 1 + i, 20, 0, tzinfo=UTC), 0.5, "units") for i in range(7)]
    challenge = _challenge(
        metric="alcohol_units", cadence=cadence, comparator="<=", target_value=5.0
    )
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(cur, _seed.OWNER, "alcohol", entries)
        result = evaluate_challenge(cur, _seed.OWNER, "UTC", challenge, today=_TODAY)
    assert (result["current"], result["breached"]) == (3.5, False)
    assert (result["progress"], result["complete"]) == (1.0, True)


def test_a_cumulative_cap_is_incomplete_while_the_window_is_still_running(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Day 3 of 7, nothing logged: 3/7 = 0.429 of the way through, not complete."""
    challenge = _challenge(
        metric="alcohol_units", cadence="total", comparator="<=", target_value=5.0
    )
    with tenant_transaction(_seed.OWNER) as cur:
        result = evaluate_challenge(cur, _seed.OWNER, "UTC", challenge, today=date(2026, 3, 3))
    assert (result["current"], result["breached"]) == (0.0, False)
    assert (result["progress"], result["complete"]) == (round(3 / 7, 3), False)


def test_a_weekly_cap_stays_breached_after_the_bad_day_ages_out(
    clean_db: None,  # noqa: ARG001
) -> None:
    """9 units on 03-01 against a 5-unit rolling-weekly cap, evaluated on 03-09.

    By 03-09 the rolling seven days (03-03 … 03-09) hold nothing, so `current` is 0
    — judging the cap only at today would report a clean week and complete it. The
    breach is scanned across every elapsed day, so it survives.
    """
    challenge = _challenge(
        metric="alcohol_units", cadence="weekly", comparator="<=", target_value=5.0, window_days=9
    )
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(
            cur, _seed.OWNER, "alcohol", [(datetime(2026, 3, 1, 20, 0, tzinfo=UTC), 9.0, "units")]
        )
        result = evaluate_challenge(cur, _seed.OWNER, "UTC", challenge, today=date(2026, 3, 9))
    assert result["current"] == 0.0, "the bad day has aged out of the rolling window"
    assert result["breached"] is True
    assert result["complete"] is False


def test_a_daily_cap_is_unchanged_by_the_cumulative_fix(clean_db: None) -> None:  # noqa: ARG001
    """The `daily` branch already honoured the comparator; #61 must not disturb it.

    2, 2, 9, 2, 2, 2, 2 units against a 3-unit daily cap ⇒ six hit days, streak 4.
    """
    entries = [
        (datetime(2026, 3, 1 + i, 20, 0, tzinfo=UTC), 9.0 if i == 2 else 2.0, "units")
        for i in range(7)
    ]
    challenge = _challenge(
        metric="alcohol_units", cadence="daily", comparator="<=", target_value=3.0
    )
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(cur, _seed.OWNER, "alcohol", entries)
        result = evaluate_challenge(cur, _seed.OWNER, "UTC", challenge, today=_TODAY)
    assert (result["hit_days"], result["streak"], result["complete"]) == (6, 4, False)
    assert "breached" not in result, "breach is a cumulative concept; daily counts hit days"


def test_a_daily_cap_credits_the_days_the_owner_logged_nothing(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Abstaining produces no rows at all — and must score seven hits, not zero.

    This is the case that makes a self-logged cap work: with device metrics an
    absent day is "no data" and cannot be a hit, but for a quantity the OWNER logs,
    "nothing logged" is the datum. Read the other way, the one owner who did exactly
    what was asked would score 0 %.
    """
    challenge = _challenge(
        metric="alcohol_units", cadence="daily", comparator="<=", target_value=1.0
    )
    with tenant_transaction(_seed.OWNER) as cur:
        result = evaluate_challenge(cur, _seed.OWNER, "UTC", challenge, today=_TODAY)
    assert (result["hit_days"], result["complete"], result["streak"]) == (7, True, 7)
    assert result["today_value"] == 0.0


def test_a_weekly_reach_rule_no_longer_counts_days_before_adoption(
    clean_db: None,  # noqa: ARG001
) -> None:
    """100 minutes on 02-28 must not be credited to a challenge adopted on 03-01.

    Legacy summed the seven days ending today with no regard for the start, so on
    day one a weekly challenge could already be part-complete on work done before it
    existed. Evaluated on 03-02: only 03-01 and 03-02 count ⇒ 40, not 140.
    """
    values = _week([20.0] * 7) | {date(2026, 2, 28): 100.0}
    challenge = _challenge(metric="mvpa_min", cadence="weekly", target_value=150.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "mvpa_min", values)
        result = evaluate_challenge(
            cur, _seed.OWNER, SENTINEL_TZ, challenge, today=date(2026, 3, 2)
        )
    assert result["current"] == 40.0
