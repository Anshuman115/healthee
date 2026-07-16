"""Correlation-finding filtering for the Today + Sleep pages.

Ports legacy ``_is_trivial_finding`` and the sleep-finding slice verbatim: it
drops definitional/derived pairs (steps↔distance, the sleep-quality sub-scores,
near-perfect correlations) so only genuine cross-domain patterns surface. Reads
the ``finding`` table via ``analytics.get_significant_findings`` (already
v2-native).
"""

from __future__ import annotations

from uuid import UUID

from healthee.analytics.finding import get_significant_findings

# Definitionally/derived-related pairs whose correlation is uninformative.
_TRIVIAL_PAIRS: set[frozenset[str]] = {
    frozenset(("steps_total", "distance_m_daily")),
    frozenset(("active_calories", "total_calories")),
    frozenset(("moderate_min", "mvpa_min")),
    frozenset(("vigorous_min", "mvpa_min")),
    frozenset(("distance_m", "distance_m_daily")),
    frozenset(("hrv_sleep_avg", "hrv_sleep_avg_ms")),
}

# Metrics that all measure one underlying thing — correlating two is definitional.
_MOVEMENT_CLUSTER = frozenset({
    "steps_total", "distance_m", "distance_m_daily", "mvpa_min", "active_calories",
    "total_calories", "basal_calories", "moderate_min", "vigorous_min",
})  # fmt: skip
_SLEEP_QUALITY_CLUSTER = frozenset({
    "sleep_dim_duration", "sleep_dim_efficiency", "sleep_dim_timing", "sleep_dim_regularity",
    "sleep_regularity_index", "sleep_health_score_4dim", "asleep",
    "tst_min", "tib_min", "efficiency_pct",
})  # fmt: skip
_DEFINITIONAL_PREFIXES = ("sleep_dim_",)

# Metrics considered "sleep-related" for the Sleep-page correlation panel.
_SLEEP_FINDING_METRICS = {
    "sleep_health_score_4dim",
    "sleep_regularity_index",
    "sleep_dim_duration",
    "sleep_dim_efficiency",
    "sleep_dim_timing",
    "sleep_dim_regularity",
    "hrv_sleep_avg",
    "rhr_daily",
    "respiratory_rate_sleep",
    "spo2_overnight",
    "tst_min",
    "efficiency_pct",
}


def is_trivial_finding(f: dict) -> bool:
    """True for a pairwise finding that is definitional/derived, not an insight."""
    if f.get("kind") != "pairwise_lag":
        return False
    a, b = f.get("metric_a"), f.get("metric_b")
    if not a or not b:
        return False
    if frozenset((a, b)) in _TRIVIAL_PAIRS:
        return True
    if a in _MOVEMENT_CLUSTER and b in _MOVEMENT_CLUSTER:
        return True
    if a in _SLEEP_QUALITY_CLUSTER and b in _SLEEP_QUALITY_CLUSTER:
        return True
    if any(a.startswith(p) and b.startswith(p) for p in _DEFINITIONAL_PREFIXES):
        return True
    eff, n = f.get("effect_size"), f.get("n_samples") or 0
    # Near-perfect ⇒ almost always definitional; high on a small sample ⇒ spurious.
    return eff is not None and (abs(eff) >= 0.95 or (abs(eff) >= 0.85 and n < 20))


def _shape(f: dict) -> dict:
    """Legacy finding payload shape (structured fields for a plain-English card)."""
    return {
        "kind": f["kind"],
        "metric_a": f["metric_a"],
        "metric_b": f.get("metric_b") or None,
        "event_kind": f.get("event_kind") or None,
        "lag_days": f.get("lag_days", 0),
        "description_raw": f["description"],
        "effect_size": f["effect_size"],
        "effect_metric": f["effect_metric"],
        "q_value": f["q_value"],
        "n_samples": f["n_samples"],
        "research_note_ids": f["research_note_ids"],
    }


def top_findings(user_id: UUID, limit: int = 5) -> list[dict]:
    """Up to ``limit`` non-trivial findings for the Today page (legacy top_findings)."""
    out: list[dict] = []
    for f in get_significant_findings(user_id, limit=40):
        if is_trivial_finding(f):
            continue
        out.append(_shape(f))
        if len(out) >= limit:
            break
    return out


def sleep_findings(user_id: UUID, limit: int = 10) -> list[dict]:
    """Sleep-related non-trivial findings for the Sleep page (legacy sleep slice)."""
    out: list[dict] = []
    for f in get_significant_findings(user_id, limit=80):
        a, b = f.get("metric_a"), f.get("metric_b")
        is_cutoff = f.get("kind") == "personal_cutoff"
        related = is_cutoff or a in _SLEEP_FINDING_METRICS or b in _SLEEP_FINDING_METRICS
        if not related or is_trivial_finding(f):
            continue
        out.append(_shape(f))
        if len(out) >= limit:
            break
    return out
