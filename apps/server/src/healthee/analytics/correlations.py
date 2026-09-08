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
from uuid import UUID

from healthee.analytics.finding import EFFECT_MANN_WHITNEY, EFFECT_SPEARMAN, Finding
from healthee.analytics.metrics import EVENT_KINDS, FLAG_DERIVED_METRICS, V2_DAILY_METRICS
from healthee.analytics.notes import notes_for
from healthee.analytics.series import daily_series, event_days
from healthee.analytics.stats import (
    MIN_N,
    aligned_pairs,
    bh_fdr,
    mann_whitney_effect,
    spearman_lag,
)
from healthee.core.db import tenant_transaction

# Metrics correlated: the canonical daily set plus the two flag-derived series.
CORRELATED_METRICS: tuple[str, ...] = V2_DAILY_METRICS + tuple(FLAG_DERIVED_METRICS)

# Effect-size / significance thresholds for surfacing a finding (verbatim).
MIN_SPEARMAN_R = 0.30
MIN_EVENT_DELTA = 0.5  # rank-biserial effect between event/non-event groups
# Benjamini-Hochberg q. Liberal for n=1 exploration; tighten as data grows.
#
# ⚠ `analytics/cutoffs.py` has a constant of the SAME NAME set to 0.20, and the two are
# deliberately not shared (audit D11 raised the collision). They bound different search
# spaces: this one screens every metric pair on the correlations surface, where the
# family is large and a false finding is shown as a finding; that one screens six
# candidate cutoff hours for two substances, where the family is small and the output is
# already gated on a literature-direction match. NEITHER is governed by a note — no
# corpus claim sets an exploratory FDR level — and neither should acquire a citation it
# cannot support. What they must not do is drift into looking like one number.
FDR_Q_THRESHOLD = 0.10

# Minimum event-days before an event-effect test is worth running.
_MIN_EVENT_DAYS = 3

# How many paired days travel with a significant pairwise finding, so the app can plot
# the relationship rather than only quote a number about it.
#
# The cap is a PAYLOAD bound, not a statistical one — ``stats.MIN_N`` already decides
# whether a correlation exists at all. ``series.daily_series`` reads the owner's entire
# history by design (the engine needs every day it has), so an owner three years in would
# otherwise put ~1,100 pairs per finding into a JSONB column and then onto the wire: the
# unbounded-data case standards section 1 names, on a payload ``/api/today`` carries up to
# five of and ``/api/sleep`` up to ten.
#
# **90, argued against the surface that draws it rather than picked.** The scatter is
# ~320 px wide with a 6 px inset and a 3 px dot radius, so the x-axis holds roughly 50
# separable columns; at 90 points the cloud is already ~2 dots per column and denser is a
# smear the eye cannot resolve. Each pair is ~39 bytes on the wire, so this bounds the
# worst case at ~18 KB on a Today payload the gap report measures at ~20 KB — a payload
# that doubled to show detail nobody can see would be trading the app's cold-start budget
# for nothing.
#
# When the cap bites, the MOST RECENT pairs are kept — the days an owner can still
# place — and ``points_truncated`` says so. That flag is not decoration: the plotted
# points are then a tail of the set the effect size was computed over, and a scatter that
# silently shows fewer points than its own ``n_samples`` invites the reader to check a
# correlation against a picture that cannot show it.
MAX_REPORTED_PAIRS = 90


def compute_all_findings(
    user_id: UUID,
    tz: str,
    pairwise_lags: tuple[int, ...] = (0, 1),
    event_lags: tuple[int, ...] = (0, 1),
) -> list[Finding]:
    """Compute every candidate finding, FDR-adjust, and mark significance."""
    with tenant_transaction(user_id) as cur:
        series = {m: daily_series(cur, user_id, m) for m in CORRELATED_METRICS}
        events = {
            label: event_days(cur, user_id, tz, kind) for label, (_, kind) in EVENT_KINDS.items()
        }

    findings = _pairwise_findings(series, pairwise_lags)
    findings += _event_findings(series, events, event_lags)

    for f, q in zip(findings, bh_fdr([f.p_value for f in findings]), strict=True):
        f.q_value = q
    for f in findings:
        _mark_significance(f)
    _attach_pairs(findings, series)
    return findings


def _attach_pairs(findings: list[Finding], series: dict[str, dict[date, float]]) -> None:
    """Record the paired days behind each SIGNIFICANT pairwise finding, in its ``details``.

    A finding used to travel as summary statistics alone — an effect size, a q-value, an
    n — so the finding-detail screen could state that a correlation is not a cause and
    could not show the owner the points that would let them judge it. The points existed:
    ``compute_all_findings`` holds both full series in memory at this moment, and
    ``stats.aligned_pairs`` is the same pairing the effect size was computed from.

    **Only after significance is marked, and only for the findings that survive it.**
    Attaching to every candidate would write the owner's whole history into ~200 JSONB
    rows per night to serve at most a handful of them, and the ones not served are
    precisely the ones nothing will ever plot.

    Event findings get nothing here on purpose: a Mann-Whitney effect compares two
    GROUPS, so it has no paired points to plot, and inventing an x-axis for it would be
    drawing a chart the statistic does not license. Their ``details`` already carry the
    two group sizes, which is what that shape can honestly say.
    """
    for f in findings:
        if not (f.significant and f.kind == "pairwise_lag" and f.metric_b):
            continue
        pairs = aligned_pairs(series.get(f.metric_a, {}), series.get(f.metric_b, {}), f.lag_days)
        pairs.sort(key=lambda p: p[0])
        kept = pairs[-MAX_REPORTED_PAIRS:]
        f.details = {
            **f.details,
            "points": [{"date": d.isoformat(), "a": va, "b": vb} for d, va, vb in kept],
            "points_truncated": len(kept) < len(pairs),
        }


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
