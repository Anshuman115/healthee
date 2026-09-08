"""Pure statistical kernels for the analytics layer.

These are the sacred, verbatim-ported methods (standards §"Science code is
sacred"): Spearman lag correlation, the Mann-Whitney U effect size
(rank-biserial), and the Benjamini-Hochberg FDR adjustment. They take plain
Python/numpy inputs and touch no database, so they are directly unit-testable
against known values and are shared by both ``correlations`` and ``cutoffs``.

Ported from legacy ``analytics/correlations.py`` (``_spearman_lag``,
``_mann_whitney_effect``, ``_apply_bh_fdr``) and ``analytics/cutoff_finder.py``
(``_mwu_compare``) — the formulas, thresholds, and rank-biserial definition are
identical; only the packaging (a DB-free module) is new.
"""

from __future__ import annotations

from datetime import date, timedelta
from typing import Any, cast

import numpy as np
from scipy import stats

# Minimum paired observations before a correlation is trustworthy at our scale.
MIN_N = 10

# Mann-Whitney needs at least this many in each arm to be meaningful.
_MWU_MIN_TREATED = 3


def aligned_pairs(
    series_a: dict[date, float],
    series_b: dict[date, float],
    lag_days: int,
) -> list[tuple[date, float, float]]:
    """The (day, a(d), b(d + lag_days)) triples that a lag correlation is computed over.

    Extracted from :func:`spearman_lag`'s own loop, unchanged, so that the points a
    correlation was measured on can be reported beside the correlation itself
    (``read/findings.py`` sends them; the finding-detail screen draws the scatter). It
    is one function rather than two because a scatter assembled by a second alignment
    rule could show a different set of days than the number it sits under was computed
    from — a plot that quietly disagrees with its own statistic.

    The date rides along because the caller needs to bound the points it serves by a
    reference day (``docs/AS_OF_DAY.md``); :func:`spearman_lag` ignores it.

    ## Two loop-invariants hoisted, and NOTHING else (`PERF_AUDIT.md` B3)

    This is the single most expensive thing `correlate` does: 828 calls, one per ordered
    metric pair per lag, each walking the owner's whole history. Profiled at four years
    of data it was **0.464 s of the step's 1.044 s — 44%, more than all of scipy
    together**, and it grows as `O(metrics² × lags × history)`.

    The loop shape, the pairing rule, the ordering and the output are UNCHANGED. What
    moved out of the loop body is a `timedelta` that was being CONSTRUCTED on every one
    of ~1.2 million iterations from a value that cannot vary inside the call, and a
    second dict probe: `target in series_b` followed by `series_b[target]` hashed the
    same key twice. Measured on 1,460 days, best of five over 200 calls each:

        lag 0   0.264 ms -> 0.081 ms      lag 1   0.320 ms -> 0.082 ms

    `tests/analytics/test_aligned_pairs_equivalence.py` holds the pre-change loop
    verbatim as a reference and asserts the two agree element for element across lags,
    gaps, and empty and disjoint series. That equivalence is the licence for touching a
    file whose docstring says these methods are never simplified: the arithmetic
    `d + timedelta(days=k)` for a fixed `k` is the same arithmetic, and the test is what
    makes that a checked claim rather than a plausible one. No statistic changed, and no
    finding changed: 774 findings before and after, on the same data.
    """
    out: list[tuple[date, float, float]] = []
    delta = timedelta(days=lag_days)
    lookup = series_b.get
    missing = object()
    for d, va in series_a.items():
        vb = lookup(d + delta, missing)
        if vb is not missing:
            out.append((d, va, vb))  # type: ignore[arg-type]
    return out


def spearman_lag(
    series_a: dict[date, float],
    series_b: dict[date, float],
    lag_days: int,
) -> tuple[float, float, int] | None:
    """Spearman rank correlation of a(d) vs b(d + lag_days).

    Returns (rho, p_value, n_pairs) or None when fewer than ``MIN_N`` day-pairs
    align. Verbatim from legacy ``_spearman_lag``; the pair-alignment loop moved
    verbatim into :func:`aligned_pairs` so the same pairing feeds the reported points.
    """
    pairs = aligned_pairs(series_a, series_b, lag_days)
    if len(pairs) < MIN_N:
        return None
    xa = np.asarray([p[1] for p in pairs])
    xb = np.asarray([p[2] for p in pairs])
    # scipy ≥1.18 returns a SignificanceResult with .statistic/.pvalue; the stubs
    # type it loosely, so cast for the type checker (values are plain floats).
    res = cast(Any, stats.spearmanr(xa, xb))
    rho = float(res.statistic)
    p = float(res.pvalue)
    if np.isnan(rho):
        return None
    return rho, p, len(pairs)


def mann_whitney_effect(
    metric_series: dict[date, float],
    event_days: set[date],
    lag_days: int,
) -> tuple[float, float, int, int] | None:
    """Compare a metric on (event_day + lag) vs all other days.

    Returns (rank_biserial_r, p_value, n_event, n_other) or None when
    underpowered. rank_biserial_r ∈ [-1, 1]. Verbatim from legacy
    ``_mann_whitney_effect``.
    """
    treated: list[float] = []
    control: list[float] = []
    event_lagged = {d + timedelta(days=lag_days) for d in event_days}
    for d, v in metric_series.items():
        (treated if d in event_lagged else control).append(v)
    return _rank_biserial(treated, control)


def mann_whitney_groups(
    treated: list[float],
    control: list[float],
    min_treated: int,
    min_control: int,
) -> tuple[float, float, int, int, float, float] | None:
    """Mann-Whitney U between two explicit groups (the cutoff-finder path).

    Returns (rank_biserial_r, p_value, n_treated, n_control, median_treated,
    median_control) or None when either arm is below its minimum. Verbatim from
    legacy ``cutoff_finder._mwu_compare`` (which used per-family minimums).
    """
    if len(treated) < min_treated or len(control) < min_control:
        return None
    result = _rank_biserial(treated, control, min_treated=min_treated, min_control=min_control)
    if result is None:
        return None
    rb, p, n1, n2 = result
    return rb, p, n1, n2, float(np.median(treated)), float(np.median(control))


def _rank_biserial(
    treated: list[float],
    control: list[float],
    *,
    min_treated: int = _MWU_MIN_TREATED,
    min_control: int = MIN_N,
) -> tuple[float, float, int, int] | None:
    """Two-sided Mann-Whitney U + rank-biserial effect size, or None if too small.

    rank-biserial r = 2U / (n1·n2) − 1 — the standard Mann-Whitney effect size,
    signed so **positive ⇒ the treated group tends larger** than control (U is
    scipy's U for the treated sample). The legacy formula (1 − 2U/n1n2) was the
    negation of this and silently inverted the cutoff-finder's direction gate.
    """
    if len(treated) < min_treated or len(control) < min_control:
        return None
    try:
        res = cast(Any, stats.mannwhitneyu(treated, control, alternative="two-sided"))
    except ValueError:
        return None
    u_stat = float(res.statistic)
    p = float(res.pvalue)
    n1, n2 = len(treated), len(control)
    rb = (2.0 * u_stat) / (n1 * n2) - 1.0
    return float(rb), float(p), n1, n2


def bh_fdr(p_values: list[float]) -> list[float]:
    """Benjamini-Hochberg FDR-adjusted q-values, preserving input order.

    q_i = p_i · n / rank, monotone-enforced then clipped to [0, 1]. Verbatim from
    legacy ``_apply_bh_fdr`` (both copies were identical). Empty in → empty out.
    """
    if not p_values:
        return []
    arr = np.asarray(p_values, dtype=float)
    n = len(arr)
    order = np.argsort(arr)
    ranked = arr[order]
    q_raw = ranked * n / (np.arange(n) + 1)
    q = np.minimum.accumulate(q_raw[::-1])[::-1]
    q = np.clip(q, 0, 1)
    q_by_index = np.empty(n)
    q_by_index[order] = q
    return [float(x) for x in q_by_index]
