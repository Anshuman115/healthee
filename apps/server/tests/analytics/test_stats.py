"""Known-value tests for the analytics statistical kernels.

Two layers:
  * a golden-fixture parity test — the NEW ``analytics.stats`` must reproduce, to
    tight tolerance, the LEGACY kernels' output on the shared deterministic
    inputs (``fixtures/analytics/expected_stats.json``, generated out-of-process
    by ``_generate_stats_fixture.py``; CI never imports legacy);
  * standalone known-value checks (perfect monotone → rho≈1; BH-FDR on a
    hand-computable vector) that pin the maths independently of legacy.
"""

from __future__ import annotations

import json
import math
import sys
from datetime import date, timedelta
from pathlib import Path

import pytest

from healthee.analytics import stats

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _stats_seed as seed  # noqa: E402 — shared deterministic inputs (stdlib-only)

_FIXTURE = Path(__file__).resolve().parent.parent / "fixtures" / "analytics" / "expected_stats.json"
_TOL = 1e-9


@pytest.fixture(scope="module")
def golden() -> dict:
    return json.loads(_FIXTURE.read_text())


def _assert_seq(actual: tuple | None, expected: list | None) -> None:
    assert (actual is None) == (expected is None)
    if actual is None or expected is None:
        return
    assert len(actual) == len(expected)
    for a, e in zip(actual, expected, strict=True):
        assert a == pytest.approx(e, abs=_TOL, rel=_TOL)


def test_spearman_lag_matches_legacy(golden: dict) -> None:
    _assert_seq(stats.spearman_lag(seed.series_a(), seed.series_b(), 0), golden["spearman_lag0"])
    _assert_seq(stats.spearman_lag(seed.series_a(), seed.series_b(), 1), golden["spearman_lag1"])


def test_mann_whitney_effect_matches_legacy(golden: dict) -> None:
    got = stats.mann_whitney_effect(seed.metric_series(), seed.event_days(), 0)
    _assert_seq(got, golden["mann_whitney_effect"])


def test_mann_whitney_groups_matches_legacy(golden: dict) -> None:
    got = stats.mann_whitney_groups(
        seed.group_treated(), seed.group_control(), min_treated=5, min_control=10
    )
    _assert_seq(got, golden["mann_whitney_groups"])


def test_bh_fdr_matches_legacy(golden: dict) -> None:
    got = stats.bh_fdr(seed.p_values())
    assert len(got) == len(golden["bh_fdr"])
    for a, e in zip(got, golden["bh_fdr"], strict=True):
        assert a == pytest.approx(e, abs=_TOL, rel=_TOL)


# ── standalone known values (independent of legacy) ─────────────────────────


def test_spearman_perfect_monotone() -> None:
    base = date(2026, 1, 1)
    a = {base + timedelta(days=i): float(i) for i in range(15)}
    b = {base + timedelta(days=i): float(i) ** 2 for i in range(15)}  # monotone, non-linear
    result = stats.spearman_lag(a, b, 0)
    assert result is not None
    rho, p, n = result
    assert rho == pytest.approx(1.0, abs=1e-12)  # rank-perfect
    assert n == 15
    assert p < 1e-6


def test_spearman_below_min_n_is_none() -> None:
    base = date(2026, 1, 1)
    a = {base + timedelta(days=i): float(i) for i in range(stats.MIN_N - 1)}
    assert stats.spearman_lag(a, a, 0) is None


def test_bh_fdr_hand_computed() -> None:
    # Two sorted p-values: q1 = p1·2/1, q2 = p2·2/2, monotone-enforced & clipped.
    assert stats.bh_fdr([0.01, 0.04]) == pytest.approx([0.02, 0.04])
    assert stats.bh_fdr([]) == []
    assert stats.bh_fdr([0.5]) == pytest.approx([0.5])


def test_bh_fdr_monotone_and_clipped() -> None:
    q = stats.bh_fdr([0.9, 0.9, 0.9])
    assert all(x <= 1.0 for x in q)
    assert q == sorted(q)  # already in ascending input order here → non-decreasing


def test_mann_whitney_underpowered_is_none() -> None:
    assert stats.mann_whitney_groups([1.0, 2.0], [3.0, 4.0, 5.0], 5, 10) is None


def test_rank_biserial_sign_matches_shift() -> None:
    # Treated clearly higher than control → +1 under the standard convention
    # (rb = 2U/n1n2 − 1; positive ⇒ treated tends larger).
    got = stats.mann_whitney_groups([10.0] * 6, [1.0] * 12, 5, 10)
    assert got is not None
    assert got[0] == pytest.approx(1.0)
    assert math.isclose(got[4], 10.0) and math.isclose(got[5], 1.0)
