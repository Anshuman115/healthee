"""The v2-native metric registry for the analytics layer.

This module is the single source of truth for *which* metrics the analytics read
and how their sentinel filters look — and it is where the WP6 seam fix lives. The
legacy analytics listed v1 metric names that v2's ``derive`` layer never emits
(``distance_m``, ``calories``, ``sleep_score``, ``hrv_sleep_avg_ms``, ``pai_*``,
zone-minute names, …). Each name below was confirmed against
``healthee.derive`` (the ``_upsert_daily`` call sites) so every metric here is a
row that actually lands in ``derived_daily`` — or, for ``moderate_min`` /
``vigorous_min``, a value stored inside the ``mvpa_min`` flags (read via
``series.flag_series``).

v1 → v2 mapping applied (retired names dropped):
  hrv_sleep_avg_ms  → hrv_sleep_avg          (derive/hrv_spo2_resp.py:28)
  distance_m        → distance_m_daily       (derive/activity.py:42)
  calories          → total_calories         (derive/energy.py:123)
  sleep_score       → sleep_health_score_4dim(derive/sleep_score.py:119)
  moderate_min      → mvpa_min flags.moderate(derive/mvpa.py:66)
  vigorous_min      → mvpa_min flags.vigorous(derive/mvpa.py:66)
  pai_today/pai_total, minutes_moderate_zone/minutes_high_zone,
  max_hr_daily, floors_climbed_daily, brisk_pace_minutes, walk_minutes,
  sleep_light_min/deep_min/awake_min/awake_count, stress → DROPPED
    (no derive/ _upsert_daily writes these to derived_daily on v2).
"""

from __future__ import annotations

# 1.4826 × MAD ≈ σ for a normal distribution — converts MAD to a robust SD so a
# 2σ-equivalent threshold keeps its usual meaning. This is the normal-consistency
# constant 1/Φ⁻¹(0.75), a statistical identity, NOT a research claim: it carries no
# knowledge citation because the corpus has no note that grounds it. (A citation to
# a "baselines" id sat here until 2026-07-17; no such note has ever existed — it
# named a MODULE, analytics/baselines.py, and resolved to nothing for a reader
# tapping the ⓘ. Removed rather than pointed at the nearest plausible note.)
MAD_TO_SD = 1.4826

# Canonical per-day metrics, all confirmed present in derived_daily (see the
# module docstring for the derive/ call site behind each). One definition, shared
# by baselines, anomalies, and correlations (standards §Duplication).
V2_DAILY_METRICS: tuple[str, ...] = (
    "rhr_daily",
    "hrv_sleep_avg",
    "spo2_overnight",
    "spo2_overnight_min",
    "respiratory_rate_sleep",
    "sleep_health_score_4dim",
    "sleep_regularity_index",
    "sleep_dim_duration",
    "sleep_dim_efficiency",
    "sleep_dim_timing",
    "sleep_dim_regularity",
    "sleep_need_min",
    "sleep_debt_min",
    "steps_total",
    "distance_m_daily",
    "total_calories",
    "active_calories",
    "basal_calories",
    "mvpa_min",
    "cardio_load",
    "recovery_score",
    "vo2max_estimate",
)

# Series that live inside another metric's flags rather than as their own row.
# Maps synthetic-metric-name → (owning derived_daily metric, flags JSON key).
FLAG_DERIVED_METRICS: dict[str, tuple[str, str]] = {
    "moderate_min": ("mvpa_min", "moderate"),
    "vigorous_min": ("mvpa_min", "vigorous"),
}

# Manual-log / event kinds evaluated against metric changes.
# label → (source table, manual_entry.kind). All read from manual_entry in v2 —
# the legacy `session`-view path for manual sessions is gone (seam fix).
EVENT_KINDS: dict[str, tuple[str, str]] = {
    "alcohol": ("manual_entry", "alcohol"),
    "caffeine": ("manual_entry", "caffeine"),
    "meditation": ("manual_entry", "meditation"),
    "exercise": ("manual_entry", "exercise"),
    "fasting": ("manual_entry", "fasting"),
}

# Sentinel / artifact filters — SQL value-range fragments keeping only valid rows
# (e.g. rhr=0 means "not measured", not a real zero). Ported verbatim from legacy
# METRIC_FILTERS with the v1→v2 renames applied and the duplicate
# ``hrv_sleep_avg_ms`` key (legacy lines 59 & 78) deduped to a single
# ``hrv_sleep_avg``. Metrics absent here default to ``TRUE`` (no filter).
METRIC_FILTERS: dict[str, str] = {
    "rhr_daily": "value > 30 AND value < 120",
    "hrv_sleep_avg": "value > 5 AND value < 200",
    "spo2_overnight": "value > 70",
    "spo2_overnight_min": "value > 70",
    "respiratory_rate_sleep": "value > 5 AND value < 30",
    "sleep_health_score_4dim": "value BETWEEN 0 AND 4",
    "sleep_regularity_index": "value BETWEEN 0 AND 100",
    "steps_total": "value >= 0",
    "distance_m_daily": "value >= 0",
    "total_calories": "value >= 500",
    "active_calories": "value >= 0",
    "basal_calories": "value >= 0",
    "mvpa_min": "value >= 0",
    "moderate_min": "value >= 0",
    "vigorous_min": "value >= 0",
    "cardio_load": "value >= 0",
    "recovery_score": "value BETWEEN 0 AND 100",
    "weight_kg": "value > 30 AND value < 250",
}


def metric_filter(metric: str) -> str:
    """The SQL value-filter fragment for a metric, or ``TRUE`` when none applies.

    The result is a hardcoded constant from ``METRIC_FILTERS`` (never
    caller-controlled), so interpolating it into SQL is safe (standards §2).
    """
    return METRIC_FILTERS.get(metric, "TRUE")
