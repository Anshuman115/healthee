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


def metric_label(metric: str) -> str:
    """A metric's display name — the ONE definition of it.

    Two callers now: ``notable`` puts it on a shift, and ``insights.surfaces`` puts it
    in the per-metric prompt's task sentence. The prompt used to take a label as an
    unvalidated query parameter instead, which put attacker-controllable text inside an
    instruction and — because the label was not in the cache key — let one day's text be
    served under a different name than the one that asked for it.

    The fallback un-underscores the id rather than returning nothing: a metric this table
    has not been taught still has a readable name, and a blank where a name belongs is
    the one thing a sentence cannot survive.
    """
    return METRIC_META.get(metric, {}).get("label", metric.replace("_", " "))


# The manifest note licensing each card, for the app's ⓘ sheet. MANIFEST IDS, never
# aliases — an alias resolves to nothing in every consumer of a cited id, so a card citing
# one opens an empty explainer (``read/activity.py``).
#
# The three calorie rows carried NO note id at all, unlike their VO2max, MVPA and strain
# siblings, so ``energy_expenditure_derivation``'s own Directive 3 estimate label (the
# ±15-20% individual error) had nowhere to render (audit C6). A metric absent from this
# map ships ``note_id: None`` — an honest "we have not cited this one" rather than a
# guessed id, which is the failure mode a default here would create.
METRIC_NOTE_ID: dict[str, str] = {
    "rhr_daily": "resting_heart_rate",
    "steps_total": "steps_mortality",
    "distance_m_daily": "distance_from_steps",
    "active_calories": "energy_expenditure_derivation",
    "total_calories": "energy_expenditure_derivation",
    "basal_calories": "energy_expenditure_derivation",
    "weight_kg": "weight_bmi_body_composition",
}

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
