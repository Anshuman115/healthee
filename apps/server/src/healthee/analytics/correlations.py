"""Correlation engine — discover patterns in personal health data (v2-native).

Methods (all ported verbatim; the kernels live in ``stats``):
  * pairwise lag correlation (Spearman) between daily metrics, incl. cross-day;
  * event-effect detection (Mann-Whitney U) — logged-event days vs others;
  * Benjamini-Hochberg FDR across all candidates.

The seam fix: every series is read v2-native from ``derived_daily`` /
``manual_entry`` via ``series`` (no ``metric_sample``/``session`` views, no
``source='zepp_cloud'`` filter, no v1 metric names). Findings persist to the
``finding`` table via ``finding``. Classical stats at our scale (≈100 days, ~100
pairs) — no ML.
"""

from __future__ import annotations

from datetime import date

from healthee.analytics.finding import EFFECT_MANN_WHITNEY, EFFECT_SPEARMAN, Finding
from healthee.analytics.metrics import EVENT_KINDS, FLAG_DERIVED_METRICS, V2_DAILY_METRICS
from healthee.analytics.notes import notes_for
from healthee.analytics.series import daily_series, event_days
from healthee.analytics.stats import MIN_N, bh_fdr, mann_whitney_effect, spearman_lag
from healthee.core.db import transaction

# Metrics correlated: the canonical daily set plus the two flag-derived series.
CORRELATED_METRICS: tuple[str, ...] = V2_DAILY_METRICS + tuple(FLAG_DERIVED_METRICS)

# Effect-size / significance thresholds for surfacing a finding (verbatim).
MIN_SPEARMAN_R = 0.30
MIN_EVENT_DELTA = 0.5  # rank-biserial effect between event/non-event groups
FDR_Q_THRESHOLD = 0.10  # liberal for n=1 exploration; tighten as data grows

# Minimum event-days before an event-effect test is worth running.
_MIN_EVENT_DAYS = 3


def compute_all_findings(
    pairwise_lags: tuple[int, ...] = (0, 1),
    event_lags: tuple[int, ...] = (0, 1),
) -> list[Finding]:
    """Compute every candidate finding, FDR-adjust, and mark significance."""
    with transaction() as cur:
        series = {m: daily_series(cur, m) for m in CORRELATED_METRICS}
        events = {label: event_days(cur, kind) for label, (_, kind) in EVENT_KINDS.items()}

    findings = _pairwise_findings(series, pairwise_lags)
    findings += _event_findings(series, events, event_lags)

    for f, q in zip(findings, bh_fdr([f.p_value for f in findings]), strict=True):
        f.q_value = q
    for f in findings:
        _mark_significance(f)
    return findings


def _pairwise_findings(
    series: dict[str, dict[date, float]], lags: tuple[int, ...]
) -> list[Finding]:
    """Spearman lag correlations across all ordered metric pairs."""
    names = [m for m in series if len(series[m]) >= MIN_N]
    out: list[Finding] = []
    for a in names:
        for b in names:
            if a == b:
                continue
            for lag in lags:
                if lag == 0 and a > b:  # halve symmetric lag-0 workload
                    continue
                result = spearman_lag(series[a], series[b], lag)
                if result:
                    out.append(_pairwise_finding(a, b, lag, *result))
    return out


def _pairwise_finding(a: str, b: str, lag: int, rho: float, p: float, n: int) -> Finding:
    desc = (
        f"Spearman({a} at d, {b} at d+{lag}) = {rho:+.2f} over {n} days (p={p:.3f})"
        if lag
        else f"Spearman({a}, {b}) = {rho:+.2f} over {n} days (p={p:.3f})"
    )
    return Finding(
        kind="pairwise_lag",
        description=desc,
        metric_a=a,
        metric_b=b,
        event_kind=None,
        lag_days=lag,
        effect_size=rho,
        effect_metric=EFFECT_SPEARMAN,
        p_value=p,
        q_value=None,
        n_samples=n,
        significant=False,
        research_note_ids=notes_for([a, b]),
    )


def _event_findings(
    series: dict[str, dict[date, float]],
    events: dict[str, set[date]],
    lags: tuple[int, ...],
) -> list[Finding]:
    """Mann-Whitney event-effects: event-days vs others for each metric."""
    out: list[Finding] = []
    for label, days_set in events.items():
        if len(days_set) < _MIN_EVENT_DAYS:
            continue
        for metric, sm in series.items():
            if len(sm) < MIN_N:
                continue
            for lag in lags:
                result = mann_whitney_effect(sm, days_set, lag)
                if result:
                    out.append(_event_finding(label, metric, lag, *result))
    return out


def _event_finding(
    label: str, metric: str, lag: int, rb: float, p: float, n_ev: int, n_other: int
) -> Finding:
    tag = "same day" if lag == 0 else f"+{lag}d"
    desc = (
        f"{label} days vs others ({tag}, {metric}): rank-biserial r={rb:+.2f} "
        f"(p={p:.3f}, n_event={n_ev}, n_other={n_other})"
    )
    return Finding(
        kind="event_effect",
        description=desc,
        metric_a=metric,
        metric_b=None,
        event_kind=label,
        lag_days=lag,
        effect_size=rb,
        effect_metric=EFFECT_MANN_WHITNEY,
        p_value=p,
        q_value=None,
        n_samples=n_ev + n_other,
        significant=False,
        research_note_ids=notes_for([metric], [label]),
        details={"n_event": n_ev, "n_other": n_other},
    )


def _mark_significance(f: Finding) -> None:
    """Set ``f.significant`` from its effect size and FDR q-value (verbatim gate)."""
    if f.q_value is None or f.n_samples < MIN_N:
        return
    if f.effect_metric == EFFECT_SPEARMAN:
        f.significant = abs(f.effect_size) >= MIN_SPEARMAN_R and f.q_value <= FDR_Q_THRESHOLD
    elif f.effect_metric == EFFECT_MANN_WHITNEY:
        f.significant = abs(f.effect_size) >= MIN_EVENT_DELTA and f.q_value <= FDR_Q_THRESHOLD
