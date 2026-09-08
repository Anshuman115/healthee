"""Correlation-finding filtering for the Today + Sleep pages.

Ports legacy ``_is_trivial_finding`` and the sleep-finding slice verbatim: it
drops definitional/derived pairs (steps↔distance, the sleep-quality sub-scores,
near-perfect correlations) so only genuine cross-domain patterns surface. Reads
the ``finding`` table via ``analytics.significant_findings`` (already v2-native)
on the CALLER's cursor — both entry points are called from inside the Today/Sleep
aggregators' transaction, so taking the cursor is what keeps each request on ONE
pooled connection (standards §1: "no per-item connections").
"""

from __future__ import annotations

from datetime import date, datetime
from uuid import UUID

from healthee.analytics.finding import significant_findings
from healthee.core.tenancy import reference_day, user_today
from healthee.derive._common import Cur, _day_bounds_utc

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


def _shape(f: dict, as_of: date | None = None) -> dict:
    """Legacy finding payload shape (structured fields for a plain-English card).

    ``points`` is the addition: the paired days the correlation was actually computed
    over, so the finding-detail screen can draw the scatter that lets the owner see for
    themselves that a correlation is not a cause. Nothing is reconstructed here — they
    are the pairs ``analytics/correlations.py`` recorded at compute time, in
    ``details``, from the same alignment the effect size came out of.

    Empty for an event finding, which compares two GROUPS and has no paired points; the
    honest answer there is no chart, not an invented axis.
    """
    points, truncated = _points(f.get("details"), as_of)
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
        "points": points,
        # The count of what is PLOTTABLE, beside ``n_samples`` — the count the effect
        # size was computed from. They differ when the payload cap bit or when the
        # as-of bound dropped a point, and a screen that showed the second while
        # plotting the first would be describing a chart it is not drawing.
        "points_n": len(points),
        "points_truncated": truncated,
    }


def _points(details: dict | None, as_of: date | None) -> tuple[list[dict], bool]:
    """The stored pairs, bounded by ``as_of``, and whether the served set is partial.

    The bound is belt-and-braces and it stays: a finding is already withheld from a day
    that precedes its ``computed_at`` (``analytics.finding.significant_findings``), so a
    served finding cannot in practice carry a pair dated after the day being answered
    for. Making it structural rather than inherited is the whole lesson of
    ``docs/AS_OF_DAY.md`` section 3 — "latest" is everywhere, and a future leak is what
    happens when one place relies on another place's bound.
    """
    stored = (details or {}).get("points") or []
    kept = [p for p in stored if as_of is None or p.get("date", "") <= as_of.isoformat()]
    truncated = bool((details or {}).get("points_truncated")) or len(kept) < len(stored)
    return kept, truncated


def _discovered_before(tz: str, day: date | None) -> datetime | None:
    """The instant ``day`` ended in the owner's zone, or None when it IS their today.

    None rather than "the end of today", deliberately: on the current day the whole point
    of a finding is that the nightly correlator may have written it minutes ago, and an
    upper bound there would only be a chance to be wrong about the owner's midnight. The
    bound exists to keep a finding out of a day that PRECEDES it.
    """
    as_of = reference_day(day, tz)
    if as_of >= user_today(tz):
        return None
    return _day_bounds_utc(as_of, tz)[1]


def top_findings(
    cur: Cur, user_id: UUID, tz: str, limit: int = 5, day: date | None = None
) -> list[dict]:
    """Up to ``limit`` non-trivial findings for the Today page (legacy top_findings).

    ``day`` withholds every finding discovered after it — the app must not show a
    pattern on a date before anyone had found it.
    """
    as_of = reference_day(day, tz)
    out: list[dict] = []
    for f in significant_findings(
        cur, user_id, limit=40, discovered_before=_discovered_before(tz, day)
    ):
        if is_trivial_finding(f):
            continue
        out.append(_shape(f, as_of))
        if len(out) >= limit:
            break
    return out


def sleep_findings(
    cur: Cur, user_id: UUID, tz: str, limit: int = 10, day: date | None = None
) -> list[dict]:
    """Sleep-related non-trivial findings for the Sleep page (legacy sleep slice)."""
    as_of = reference_day(day, tz)
    out: list[dict] = []
    for f in significant_findings(
        cur, user_id, limit=80, discovered_before=_discovered_before(tz, day)
    ):
        a, b = f.get("metric_a"), f.get("metric_b")
        is_cutoff = f.get("kind") == "personal_cutoff"
        related = is_cutoff or a in _SLEEP_FINDING_METRICS or b in _SLEEP_FINDING_METRICS
        if not related or is_trivial_finding(f):
            continue
        out.append(_shape(f, as_of))
        if len(out) >= limit:
            break
    return out
