"""#89 · data coverage — the definition, pinned against seeded days.

INTELLIGENCE §3 promised ``citations[]``, a grade floor and **data coverage** as response
metadata. The first two shipped; the third had no definition anywhere. These tests are
what makes the definition a fact rather than a docstring:

    days in the window that carry a stored daily value, out of days in the window,
    per metric, counted through the SAME sentinel-filtered count the personal
    baselines are computed from.

The sentinel case is the one that matters most. ``rhr_daily = 0`` means "not measured",
and a coverage number that counted it would tell an owner they have data they do not —
the exact shape of dishonesty this whole subsystem exists to prevent.
"""

from __future__ import annotations

import sys
from datetime import date, timedelta
from pathlib import Path

import pytest

from healthee.analytics import coverage
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.db import migrate

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _seed_db as sd  # noqa: E402 — shared v2-native seeding helpers

pytestmark = pytest.mark.integration


def _days(n: int) -> list[date]:
    """The owner's last ``n`` local days, oldest first — the window coverage counts."""
    today = user_today(SENTINEL_TZ)
    return [today - timedelta(days=i) for i in reversed(range(n))]


def _reset() -> None:
    migrate.apply_migrations()
    sd.clean()


def test_coverage_counts_days_with_data_not_days_in_range(db: None) -> None:  # noqa: ARG001
    """9 seeded days inside a 14-day window is 9/14 — the whole definition."""
    _reset()
    window = _days(14)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, "rhr_daily", {d: 55.0 for d in window[-9:]})
    (result,) = coverage.measure(SENTINEL_USER_ID, SENTINEL_TZ, ["rhr_daily"], 14)
    assert (result.metric, result.days_with_data, result.window_days) == ("rhr_daily", 9, 14)
    assert result.fraction == pytest.approx(9 / 14)


def test_a_sentinel_zero_is_not_data(db: None) -> None:  # noqa: ARG001
    """`rhr_daily = 0` means NOT MEASURED — counting it would overstate the window."""
    _reset()
    window = _days(14)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, "rhr_daily", {d: 55.0 for d in window[:5]})
        sd.seed_daily(cur, "rhr_daily", {d: 0.0 for d in window[5:]})
    (result,) = coverage.measure(SENTINEL_USER_ID, SENTINEL_TZ, ["rhr_daily"], 14)
    assert result.days_with_data == 5


def test_days_outside_the_window_do_not_count(db: None) -> None:  # noqa: ARG001
    """The window is the owner's trailing N local days, not "every row we hold"."""
    _reset()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, "steps_total", {d: 8000.0 for d in _days(30)})
    (short,) = coverage.measure(SENTINEL_USER_ID, SENTINEL_TZ, ["steps_total"], 7)
    (long,) = coverage.measure(SENTINEL_USER_ID, SENTINEL_TZ, ["steps_total"], 30)
    assert (short.days_with_data, long.days_with_data) == (7, 30)


def test_a_metric_with_no_rows_is_zero_not_absent(db: None) -> None:  # noqa: ARG001
    """0/14 is an answer. Dropping the metric would make "no data" look like "not asked"."""
    _reset()
    (result,) = coverage.measure(SENTINEL_USER_ID, SENTINEL_TZ, ["hrv_sleep_avg"], 14)
    assert (result.days_with_data, result.window_days) == (0, 14)


def test_coverage_is_per_metric_and_never_blended(db: None) -> None:  # noqa: ARG001
    """Two metrics, two counts, in the order the surface declared them."""
    _reset()
    window = _days(14)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, "rhr_daily", {d: 55.0 for d in window[-3:]})
        sd.seed_daily(cur, "steps_total", {d: 8000.0 for d in window})
    results = coverage.measure(SENTINEL_USER_ID, SENTINEL_TZ, ["steps_total", "rhr_daily"], 14)
    assert [(c.metric, c.days_with_data) for c in results] == [
        ("steps_total", 14),
        ("rhr_daily", 3),
    ]


def test_the_payload_names_the_window_even_with_no_metrics(db: None) -> None:  # noqa: ARG001
    """An answer scoped to no metric still says WHICH days it is silent about.

    "This answer read no metric directly" and "we have no data" are different states, and
    an empty payload with no window would collapse them (standards §1).
    """
    _reset()
    payload = coverage.measured_payload(SENTINEL_USER_ID, SENTINEL_TZ, [], 21)
    assert payload == {"window_days": 21, "days_with_data": {}}


def test_the_payload_publishes_counts_not_percentages(db: None) -> None:  # noqa: ARG001
    """Two integers cannot be rounded into a lie; a percentage can."""
    _reset()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, "rhr_daily", {d: 55.0 for d in _days(14)[-3:]})
    payload = coverage.measured_payload(SENTINEL_USER_ID, SENTINEL_TZ, ["rhr_daily"], 14)
    assert payload == {"window_days": 14, "days_with_data": {"rhr_daily": 3}}


def test_duplicate_metrics_collapse(db: None) -> None:  # noqa: ARG001
    _reset()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, "rhr_daily", {d: 55.0 for d in _days(14)})
    results = coverage.measure(SENTINEL_USER_ID, SENTINEL_TZ, ["rhr_daily", "rhr_daily"], 14)
    assert len(results) == 1
