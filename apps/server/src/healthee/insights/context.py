"""V2-native LLM context builders — daily-metric sections + orchestration.

This is the fix for legacy hole #3's context half (INTELLIGENCE §5.4): legacy read
the v1 compat views with a ``source='zepp_cloud'`` filter and v1 metric names, so
the today-snapshot / trend / "recent daily metrics" sections came back EMPTY on v2
data and the LLM silently under-reported. Every builder here reads ``derived_daily``
(one canonical row per day) with the v2 metric names from ``analytics.metrics`` —
the seam bug is impossible by construction.

The session/log/finding sections live in ``context_sessions.py``; this module
orchestrates all of them into one markdown context string.
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from healthee.analytics import anomalies as anomalies_mod
from healthee.analytics.baselines import (
    DEFAULT_DAILY_METRICS,
    compute_all,
    compute_baseline,
    compute_baseline_cur,
    latest_value,
)
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import USER_TODAY_SQL
from healthee.insights.context_sessions import (
    findings_section,
    manual_entries_section,
    sleep_section,
)

# The subset shown in the compact "recent daily metrics" pivot: (metric, column).
# All are derived_daily rows (v2 names) — the exact set legacy's broken v1 query
# tried and failed to read. Order = column order in the table.
_RECENT_COLUMNS: tuple[tuple[str, str], ...] = (
    ("rhr_daily", "RHR"),
    ("hrv_sleep_avg", "HRV"),
    ("sleep_health_score_4dim", "slpSc"),
    ("sleep_regularity_index", "SRI"),
    ("recovery_score", "recov"),
    ("steps_total", "steps"),
    ("mvpa_min", "MVPA"),
    ("cardio_load", "load"),
    ("active_calories", "actKcal"),
    ("vo2max_estimate", "VO2max"),
)


def _today_snapshot(user_id: UUID) -> str:
    """Latest value per daily metric vs its personal 30-day baseline (z-score)."""
    lines = [
        "## Today snapshot (latest day vs personal 30d baseline)",
        "| metric | latest | median | z |",
        "|---|---|---|---|",
    ]
    any_row = False
    for metric in DEFAULT_DAILY_METRICS:
        latest = latest_value(user_id, metric)
        if latest is None:
            continue
        any_row = True
        day, value = latest
        baseline = compute_baseline(user_id, metric, window_days=30)
        z = baseline.z_score(value)
        z_str = (
            f"{z:+.2f}σ{' ⚠️' if z is not None and abs(z) >= 2 else ''}" if z is not None else "-"
        )
        med = f"{baseline.median:.1f}" if baseline.median is not None else "-"
        lines.append(f"| {metric} | {value:.1f} ({day}) | {med} | {z_str} |")
    return "\n".join(lines) if any_row else ""


def _trends(user_id: UUID) -> str:
    """7-day average vs 30-day median per metric — trend direction."""
    lines = [
        "## Trend summary (7-day avg vs 30-day median)",
        "| metric | 7d avg | 30d median | Δ | dir |",
        "|---|---|---|---|---|",
    ]
    any_row = False
    with tenant_transaction(user_id) as cur:
        for metric in DEFAULT_DAILY_METRICS:
            row = _seven_day_avg(cur, user_id, metric)
            # On THIS cursor: the self-opening form would borrow a second pooled
            # connection per metric while this one is held (see compute_baselines).
            baseline = compute_baseline_cur(cur, user_id, metric, window_days=30)
            if row is None or baseline.median is None:
                continue
            any_row = True
            delta = row - baseline.median
            arrow = (
                "—"
                if abs(delta) < 0.05 * abs(baseline.median or 1)
                else ("↑" if delta > 0 else "↓")
            )
            lines.append(
                f"| {metric} | {row:.1f} | {baseline.median:.1f} | {delta:+.1f} | {arrow} |"
            )
    return "\n".join(lines) if any_row else ""


def _seven_day_avg(cur, user_id: UUID, metric: str) -> float | None:
    """Mean of a metric's last 7 days from ``derived_daily`` (sentinel unfiltered
    is fine here — these are already-derived canonical daily values)."""
    cur.execute(
        "SELECT AVG(value) FROM derived_daily WHERE user_id = %s AND metric=%s AND day > %s",
        (user_id, metric, date.today() - timedelta(days=7)),
    )
    row = cur.fetchone()
    return float(row[0]) if row and row[0] is not None else None


def _recent_daily(cur, user_id: UUID, tz: str, days: int) -> str:
    """Compact per-day table over ``derived_daily`` — the regression-tested section.

    On v2 data this MUST be non-empty (legacy returned empty here). Pivoted in
    Python to avoid dynamic SQL; metric list is a module constant.
    """
    metrics = [m for m, _ in _RECENT_COLUMNS]
    cur.execute(
        "SELECT (day)::date AS d, metric, value FROM derived_daily "
        f"WHERE user_id = %s AND metric = ANY(%s) AND day > ({USER_TODAY_SQL} - %s::int) "
        "ORDER BY d DESC",
        (user_id, metrics, tz, days),
    )
    by_day: dict[date, dict[str, float]] = {}
    for d, metric, value in cur.fetchall():
        by_day.setdefault(d, {})[metric] = value
    if not by_day:
        return ""
    header = "| date | " + " | ".join(label for _, label in _RECENT_COLUMNS) + " |"
    sep = "|" + "---|" * (len(_RECENT_COLUMNS) + 1)
    lines = [f"## Recent daily metrics (last {days} days, {tz})", header, sep]
    for d in sorted(by_day, reverse=True):
        cells = [_fmt(by_day[d].get(m)) for m, _ in _RECENT_COLUMNS]
        lines.append(f"| {d} | " + " | ".join(cells) + " |")
    return "\n".join(lines)


def _fmt(value: float | None) -> str:
    if value is None:
        return "-"
    return str(int(value)) if float(value).is_integer() else f"{value:.1f}"


def _baselines(user_id: UUID) -> str:
    """Robust personal baselines (median ± σ, quartiles) for the daily metrics."""
    lines = [
        "## Personal baselines (trailing 30d, robust median ± σ)",
        "| metric | n | median | ± σ | p25–p75 |",
        "|---|---|---|---|---|",
    ]
    any_row = False
    for b in compute_all(user_id, DEFAULT_DAILY_METRICS, 30):
        if b.median is None:
            continue
        any_row = True
        sd = b.robust_sd
        sd_str = f"±{sd:.1f}" if sd is not None else "-"
        band = f"{b.p25:.0f}–{b.p75:.0f}" if b.p25 is not None and b.p75 is not None else "-"
        lines.append(f"| {b.metric} | {b.n} | {b.median:.1f} | {sd_str} | {band} |")
    return "\n".join(lines) if any_row else ""


def _anomalies(user_id: UUID, tz: str) -> str:
    """Recent |z|≥2 deviations vs personal baseline, each with its note ids."""
    rows = anomalies_mod.detect(user_id, tz, days_back=14, window_days=30)
    if not rows:
        return ""
    lines = [
        "## Recent anomalies (last 14d, |z|≥2 vs personal baseline)",
        "| date | metric | value | z | dir | evidence notes |",
        "|---|---|---|---|---|---|",
    ]
    for a in rows[:20]:
        notes = ", ".join(a.research_note_ids) if a.research_note_ids else "—"
        lines.append(
            f"| {a.when} | {a.metric} | {a.value:.1f} | {a.z:+.2f} | {a.direction} | {notes} |"
        )
    return "\n".join(lines)


def build_context(user_id: UUID, tz: str, *, days: int = 14, question: str | None = None) -> str:
    """Assemble the full v2-native LLM context; empty sections are skipped.

    Opens its own reads (insights owns its context queries) — the caller does not
    thread a cursor. Cheap enough for a per-day-cached generation, never on a hot
    read path (standards §Performance: LLM generation is cached, off the read path).
    """
    with tenant_transaction(user_id) as cur:
        session_sections = [
            _recent_daily(cur, user_id, tz, days),
            sleep_section(cur, user_id, tz, days),
            manual_entries_section(cur, user_id, tz, days),
        ]
    sections = [
        _today_snapshot(user_id),
        _trends(user_id),
        *session_sections,
        _baselines(user_id),
        _anomalies(user_id, tz),
        findings_section(user_id, question),
    ]
    return "\n\n".join(s for s in sections if s)
