"""Known-value + parity tests for the robust baselines.

The batched ``compute_baselines`` (one grouped query, the /api/today read path)
MUST stay numerically identical to the single-metric ``compute_baseline`` — they
share one implementation, and this pins that contract with hand-computable values
so the two can never silently diverge. Auto-skips without a reachable TimescaleDB.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from healthee.analytics.baselines import compute_baseline, compute_baselines
from healthee.core.db import transaction
from healthee.db import migrate

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _seed_db as sd  # noqa: E402 — shared v2-native seeding helpers

pytestmark = pytest.mark.integration


def _reset() -> None:
    migrate.apply_migrations()
    with transaction() as cur:
        sd.clean(cur)


def test_batched_baselines_match_single_metric(db: None) -> None:  # noqa: ARG001
    """The grouped path returns, field for field, what per-metric calls return."""
    _reset()
    days = sd.recent_days(20)
    with transaction() as cur:
        sd.seed_daily(cur, "rhr_daily", {d: 50.0 + (i % 5) for i, d in enumerate(days)})
        sd.seed_daily(cur, "hrv_sleep_avg", {d: 40.0 + (i % 7) for i, d in enumerate(days)})
        sd.seed_daily(cur, "steps_total", {d: 3000.0 + i * 137 for i, d in enumerate(days)})

    metrics = ["rhr_daily", "hrv_sleep_avg", "steps_total"]
    batch = compute_baselines(metrics, window_days=30)
    for m in metrics:
        single = compute_baseline(m, window_days=30)
        b = batch[m]
        assert (b.n, b.median, b.mad, b.p25, b.p75, b.min, b.max) == (
            single.n,
            single.median,
            single.mad,
            single.p25,
            single.p75,
            single.min,
            single.max,
        ), m


def test_baseline_known_values(db: None) -> None:  # noqa: ARG001
    """[50,52,54,56,58] → median 54, p25 52, p75 56, MAD median(|x−54|)=2."""
    _reset()
    days = sd.recent_days(5)
    vals = [50.0, 52.0, 54.0, 56.0, 58.0]
    with transaction() as cur:
        sd.seed_daily(cur, "rhr_daily", dict(zip(days, vals, strict=True)))

    b = compute_baselines(["rhr_daily"], window_days=30)["rhr_daily"]
    assert b.n == 5
    assert b.median == 54.0
    assert b.p25 == 52.0
    assert b.p75 == 56.0
    assert b.min == 50.0
    assert b.max == 58.0
    assert b.mad == 2.0  # median of [4,2,0,2,4]


def test_baseline_respects_per_metric_sentinel_filter(db: None) -> None:  # noqa: ARG001
    """rhr_daily's filter (value>30 AND value<120) must drop out-of-range rows in the
    grouped query exactly as the per-metric query did — a wearable 0/200 is 'not
    measured', not a real resting-HR."""
    _reset()
    days = sd.recent_days(5)
    # three valid + two sentinels (10 too low, 200 too high) → only three count
    vals = [50.0, 52.0, 54.0, 10.0, 200.0]
    with transaction() as cur:
        sd.seed_daily(cur, "rhr_daily", dict(zip(days, vals, strict=True)))

    b = compute_baselines(["rhr_daily"], window_days=30)["rhr_daily"]
    assert b.n == 3  # the 10 and 200 were filtered out
    assert b.median == 52.0
    assert b.max == 54.0  # NOT 200 — the sentinel is gone


def test_missing_metric_is_empty(db: None) -> None:  # noqa: ARG001
    """A metric with no rows in the window comes back n=0 / None (never a KeyError)."""
    _reset()
    out = compute_baselines(["rhr_daily", "hrv_sleep_avg"], window_days=30)
    assert set(out) == {"rhr_daily", "hrv_sleep_avg"}
    for b in out.values():
        assert b.n == 0
        assert b.median is None and b.mad is None


def test_empty_metric_list_returns_empty(db: None) -> None:  # noqa: ARG001
    assert compute_baselines([], window_days=30) == {}
