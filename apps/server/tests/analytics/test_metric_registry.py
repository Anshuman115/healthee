"""Unit tests for the recognized-metric registry (``KNOWN_METRICS``).

Pure (no DB): pins that the accepted set is the derived union of the canonical v2
registries, and that garbage — including retired v1 names — is not in it.
"""

from __future__ import annotations

from healthee.analytics.metrics import (
    FLAG_DERIVED_METRICS,
    KNOWN_METRICS,
    METRIC_FILTERS,
    V2_DAILY_METRICS,
    is_known_metric,
)


def test_known_metrics_is_the_union_of_every_source() -> None:
    expected = frozenset(V2_DAILY_METRICS) | FLAG_DERIVED_METRICS.keys() | METRIC_FILTERS.keys()
    assert expected == KNOWN_METRICS


def test_canonical_names_are_known() -> None:
    for metric in (*V2_DAILY_METRICS, *FLAG_DERIVED_METRICS, *METRIC_FILTERS):
        assert is_known_metric(metric)
    assert is_known_metric("hrv_sleep_avg")  # the canonical v2 name the v2 app sends
    assert is_known_metric("weight_kg")  # a METRIC_FILTERS-only alias


def test_garbage_and_retired_v1_names_are_not_known() -> None:
    assert not is_known_metric("bogus")
    assert not is_known_metric("")
    assert not is_known_metric("rhr")  # v1 short name
    assert not is_known_metric("hrv_sleep_avg_ms")  # retired v1 name (not back-compat)
    assert not is_known_metric("sleep_score")  # retired v1 name
