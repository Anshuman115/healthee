"""`aligned_pairs` after the hoist pairs exactly what it paired before it.

`stats.py`'s own docstring calls these the sacred, verbatim-ported methods, and standards
section 1 says science code is never "simplified" during a refactor. `PERF_AUDIT.md` B3
measured this function at 44% of the whole `correlate` step, so it was worth speeding up
— and the only honest way to touch it is to keep the pre-change loop and prove the two
agree, rather than to reason that they must.

:func:`_as_shipped` below is that loop, transcribed character for character from the
version before the change:

    out = []
    for d, va in series_a.items():
        target = d + timedelta(days=lag_days)
        if target in series_b:
            out.append((d, va, series_b[target]))
    return out

Every assertion here compares against it — element for element and IN ORDER, because the
order is the order the numpy arrays are built in and a set-equal check would pass against
a shuffle. The cases are the ones where a pairing rule can quietly differ: gaps on either
side, a lag that runs off the end, series with nothing in common, and empty inputs.
"""

from __future__ import annotations

import random
from datetime import date, timedelta

import pytest

from healthee.analytics.stats import aligned_pairs

_BASE = date(2024, 3, 1)


def _as_shipped(
    series_a: dict[date, float], series_b: dict[date, float], lag_days: int
) -> list[tuple[date, float, float]]:
    """The loop exactly as it stood before the hoist. Never optimise this one."""
    out: list[tuple[date, float, float]] = []
    for d, va in series_a.items():
        target = d + timedelta(days=lag_days)
        if target in series_b:
            out.append((d, va, series_b[target]))
    return out


def _series(days: int, *, keep: float, seed: int) -> dict[date, float]:
    rng = random.Random(seed)
    return {
        _BASE + timedelta(days=i): round(rng.uniform(30.0, 90.0), 4)
        for i in range(days)
        if rng.random() < keep
    }


@pytest.mark.parametrize("lag_days", [0, 1, 2, 7, -1])
@pytest.mark.parametrize(
    ("days", "keep_a", "keep_b"),
    [
        (1460, 1.0, 1.0),  # four dense years — the shape the audit profiled
        (365, 0.95, 0.90),  # ordinary gaps on both sides
        (90, 0.4, 0.4),  # sparse: most days pair with nothing
        (30, 1.0, 1.0),  # short, dense
    ],
)
def test_the_hoisted_loop_pairs_exactly_what_the_shipped_loop_paired(
    days: int, keep_a: float, keep_b: float, lag_days: int
) -> None:
    """Same triples, same values, same order, at every lag and density."""
    series_a = _series(days, keep=keep_a, seed=11)
    series_b = _series(days, keep=keep_b, seed=29)

    assert aligned_pairs(series_a, series_b, lag_days) == _as_shipped(
        series_a, series_b, lag_days
    ), f"the pairing diverged at days={days} keep=({keep_a}, {keep_b}) lag={lag_days}"


def test_disjoint_series_pair_nothing() -> None:
    """No overlap at all — the case a `get`-with-default can silently get wrong."""
    series_a = {_BASE + timedelta(days=i): float(i) for i in range(10)}
    series_b = {_BASE + timedelta(days=100 + i): float(i) for i in range(10)}

    assert aligned_pairs(series_a, series_b, 0) == []
    assert aligned_pairs(series_a, series_b, 0) == _as_shipped(series_a, series_b, 0)


def test_an_empty_series_on_either_side_pairs_nothing() -> None:
    series = {_BASE: 50.0}

    assert aligned_pairs({}, series, 0) == []
    assert aligned_pairs(series, {}, 0) == []
    assert aligned_pairs({}, {}, 1) == []


def test_a_zero_value_pairs_like_any_other() -> None:
    """0.0 is falsy, and a sentinel-based lookup written with `or` would drop it.

    A metric that is legitimately zero on a day — no MVPA, no alcohol — must pair, and
    must pair as 0.0 rather than vanishing. This is the one way the rewrite could have
    changed a NUMBER rather than a timing, so it is asked directly.
    """
    series_a = {_BASE: 5.0, _BASE + timedelta(days=1): 0.0}
    series_b = {_BASE: 0.0, _BASE + timedelta(days=1): 7.0}

    pairs = aligned_pairs(series_a, series_b, 0)

    assert pairs == [(_BASE, 5.0, 0.0), (_BASE + timedelta(days=1), 0.0, 7.0)]
    assert pairs == _as_shipped(series_a, series_b, 0)
