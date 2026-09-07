"""Known-value tests for the computed-on-read formulas (no DB): strain 0-21, live
readiness decay, sleep performance %, and the acute:chronic ratio. These are the
audit-verified science ported verbatim — a behaviour change must break a test here.
"""

from __future__ import annotations

import pytest

from healthee.read.acwr import acwr
from healthee.read.fitness import strain_from_load
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


def test_acwr_flat_load_is_a_ratio_and_never_a_verdict() -> None:
    """The ratio and its two terms ship; no categorical judgement does.

    ``state`` was a bare string — "detraining" / "optimal" / "caution" /
    "overreaching" — off cut-points [[training_load_acwr]] calls "soft heuristics, not
    guardrails" and whose figure Impellizzeri 2019 showed to be schematic rather than
    data-derived. The note's summary is "never a verdict"; this asserts the wire agrees.
    """
    trend = {"trend_30d": [{"value": 50.0} for _ in range(28)]}
    out = acwr(trend)
    assert out is not None
    assert out["ratio"] == 1.0
    assert "state" not in out
    assert out["n_acute"] == 7
    assert out["n_chronic"] == 28
    # Its OWN note, Contested. It cited `training_stress_score`, a different note.
    assert out["research_notes"] == ["training_load_acwr"]


def test_acwr_reports_the_ratio_it_measured() -> None:
    def ratio(acute: float, chronic_tail: float) -> float:
        vals = [chronic_tail] * 21 + [acute] * 7  # last 7 are the acute window
        out = acwr({"trend_30d": [{"value": v} for v in vals]})
        assert out is not None
        return out["ratio"]

    # The acute window is a SUBSET of the chronic one, so the denominator moves with the
    # numerator: at an acute 30 against a 60 tail the chronic mean is 52.5, not 60. That
    # is Lolli 2019's mathematical coupling, computed here rather than argued — and the
    # reason the note refuses to let this ratio carry a verdict.
    assert ratio(30, 60) == 0.57  # 30 / 52.5
    assert ratio(90, 60) == 1.33  # 90 / 67.5
    assert ratio(200, 60) == 2.11  # 200 / 95.0


def test_acwr_is_suppressed_below_twenty_eight_days_of_chronic_history() -> None:
    """[[training_load_acwr]] D6, Established: suppress under 28 days of chronic history.

    Seven rows was the old floor and it is the degenerate case in its purest form: with
    exactly seven values ``vals[-7:]`` and ``vals[-28:]`` are the SAME values, so the
    ratio is 1.0 by construction and the payload published the sweet spot from one week
    with no history to compare it against.
    """
    for n in (6, 7, 20, 27):
        assert acwr({"trend_30d": [{"value": 50.0} for _ in range(n)]}) is None
    assert acwr({"trend_30d": [{"value": 50.0} for _ in range(28)]}) is not None
    assert acwr(None) is None


def test_acwr_is_suppressed_when_chronic_load_is_zero() -> None:
    """The note's other suppression limb — a small denominator manufactures ratios."""
    assert acwr({"trend_30d": [{"value": 0.0} for _ in range(28)]}) is None


@pytest.mark.parametrize("p95,load,expected", [(120.0, 60.0, 12.5), (200.0, 200.0, 21.0)])
def test_strain_parametrized(p95: float, load: float, expected: float) -> None:
    assert strain_from_load(load, p95) == round(21.0 * (load / p95) ** 0.75, 1)
