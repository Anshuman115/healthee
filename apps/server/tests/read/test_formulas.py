"""Known-value tests for the computed-on-read formulas (no DB): strain 0-21, live
readiness decay, sleep performance %, and the acute:chronic ratio. These are the
audit-verified science ported verbatim — a behaviour change must break a test here.
"""

from __future__ import annotations

import pytest

from healthee.read.fitness import acwr, strain_from_load
from healthee.read.health_metrics import sleep_performance_pct
from healthee.read.recovery import decayed_readiness


def test_strain_zero_load_is_zero() -> None:
    assert strain_from_load(0.0, 100.0) == 0.0


def test_strain_at_p95_is_max() -> None:
    # load == P95 → 21·(1)**0.75 == 21.
    assert strain_from_load(100.0, 100.0) == 21.0


def test_strain_concave_curve() -> None:
    # Half the P95 load reads well above half strain (concave ≈log curve).
    assert strain_from_load(50.0, 100.0) == round(21.0 * 0.5**0.75, 1)  # ≈12.5


def test_strain_no_baseline_is_none() -> None:
    assert strain_from_load(40.0, None) is None
    assert strain_from_load(40.0, 0.0) is None


def test_readiness_no_strain_unchanged() -> None:
    assert decayed_readiness(72, 0.0, 50.0) == 72


def test_readiness_decays_at_typical_load() -> None:
    # strain == typical → decay 0.5·min(1,1) = 0.5 → 72·0.5 = 36.
    assert decayed_readiness(72, 50.0, 50.0) == 36


def test_readiness_decay_capped_at_half() -> None:
    # strain far above typical still caps decay at 50%.
    assert decayed_readiness(80, 500.0, 50.0) == 40


def test_sleep_performance_ratio_and_cap() -> None:
    assert sleep_performance_pct(380, 480) == 79  # 100·380/480
    assert sleep_performance_pct(600, 480) == 100  # capped
    assert sleep_performance_pct(None, 480) is None
    assert sleep_performance_pct(400, 0) is None


def test_acwr_optimal_flat_load() -> None:
    trend = {"trend_30d": [{"value": 50.0} for _ in range(28)]}
    out = acwr(trend)
    assert out is not None
    assert out["ratio"] == 1.0
    assert out["state"] == "optimal"


def test_acwr_states() -> None:
    def ratio_state(acute: float, chronic_tail: float) -> str:
        vals = [chronic_tail] * 21 + [acute] * 7  # last 7 are the acute window
        out = acwr({"trend_30d": [{"value": v} for v in vals]})
        assert out is not None
        return out["state"]

    assert ratio_state(30, 60) == "detraining"  # ratio 0.5
    assert ratio_state(90, 60) == "caution"  # ratio 1.5
    assert ratio_state(200, 60) == "overreaching"


def test_acwr_needs_seven_days() -> None:
    assert acwr({"trend_30d": [{"value": 50.0} for _ in range(6)]}) is None
    assert acwr(None) is None


@pytest.mark.parametrize("p95,load,expected", [(120.0, 60.0, 12.5), (200.0, 200.0, 21.0)])
def test_strain_parametrized(p95: float, load: float, expected: float) -> None:
    assert strain_from_load(load, p95) == round(21.0 * (load / p95) ** 0.75, 1)
