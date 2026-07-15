"""Deterministic inputs for the analytics stats-kernel golden test.

One place builds the arrays so the fixture generator (which runs the LEGACY
kernels) and the CI test (which runs the NEW ``analytics.stats``) feed
*byte-identical* input. No randomness — every value is a closed-form function of
an index, so the golden fixture is reproducible. stdlib-only (no numpy/scipy
here) so it imports cleanly in either process.
"""

from __future__ import annotations

from datetime import date, timedelta

_BASE = date(2026, 1, 1)
_N = 40


def series_a() -> dict[date, float]:
    """A daily series with structure (a saw-tooth), not a straight line."""
    return {_BASE + timedelta(days=i): float((i * 7 + 3) % 13) for i in range(_N)}


def series_b() -> dict[date, float]:
    """A series correlated with A plus a deterministic wobble."""
    return {_BASE + timedelta(days=i): float((i * 7 + 3) % 13) * 1.5 + (i % 5) for i in range(_N)}


def metric_series() -> dict[date, float]:
    """A metric series for the event-effect test."""
    return {_BASE + timedelta(days=i): float((i * 3) % 17) for i in range(_N)}


def event_days() -> set[date]:
    """Event-day set (every 4th day) for the event-effect test."""
    return {_BASE + timedelta(days=i) for i in range(_N) if i % 4 == 0}


def group_treated() -> list[float]:
    """The 'after-H' arm for the two-group Mann-Whitney (cutoff path)."""
    return [12.0, 11.0, 13.0, 10.0, 14.0, 12.0, 11.0]


def group_control() -> list[float]:
    """The control arm for the two-group Mann-Whitney (cutoff path)."""
    return [5.0, 6.0, 7.0, 4.0, 8.0, 5.0, 6.0, 7.0, 3.0, 9.0, 5.0, 6.0]


def p_values() -> list[float]:
    """A fixed p-value vector for the Benjamini-Hochberg FDR test."""
    return [0.001, 0.02, 0.2, 0.5, 0.04, 0.9, 0.01, 0.3]
