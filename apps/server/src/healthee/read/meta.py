"""Metric display metadata + the Today secondary-card slots.

``METRIC_META`` (label/unit/digits) and ``TODAY_SECONDARY_METRICS`` port from
legacy. Only metrics the v2 ``derive`` layer actually writes to ``derived_daily``
(plus ``weight_kg`` from ``weight_log``) can yield a card — a slot whose metric
has no v2 row is simply skipped, exactly as legacy skipped an empty metric.
"""

from __future__ import annotations

# label / unit / digits per metric — the subset the read layer surfaces. Ported
# from legacy METRIC_META (v1-only names that v2 never derives are dropped).
METRIC_META: dict[str, dict] = {
    "rhr_daily":          {"label": "Resting HR",       "unit": "bpm",  "digits": 0},
    "hrv_sleep_avg":      {"label": "HRV (sleep avg)",  "unit": "ms",   "digits": 1},
    "steps_total":        {"label": "Steps",            "unit": None,   "digits": 0},
    "distance_m_daily":   {"label": "Distance",         "unit": "m",    "digits": 0},
    "active_calories":    {"label": "Active calories",  "unit": "kcal", "digits": 0},
    "total_calories":     {"label": "Total calories",   "unit": "kcal", "digits": 0},
    "basal_calories":     {"label": "BMR (resting)",    "unit": "kcal", "digits": 0},
    "weight_kg":          {"label": "Weight",           "unit": "kg",   "digits": 1},
}  # fmt: skip

# Today's secondary cards — each slot is a list of candidate metrics, first with
# data wins; order = display order. Ported from legacy TODAY_SECONDARY_METRICS
# with the v1→v2 renames applied (``distance_m`` alias and ``floors_climbed_daily``
# — never derived in v2 — dropped; ``calories`` alias dropped, v2 has none).
TODAY_SECONDARY_METRICS: list[list[str]] = [
    ["rhr_daily"],
    ["steps_total"],
    ["active_calories"],
    ["total_calories"],
    ["basal_calories"],
    ["distance_m_daily"],
    ["weight_kg"],
]
