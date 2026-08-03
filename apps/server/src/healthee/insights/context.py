"""V2-native LLM context builders — daily-metric sections + orchestration.

This is the fix for legacy hole #3's context half (INTELLIGENCE §5.4): legacy read
the v1 compat views with a ``source='zepp_cloud'`` filter and v1 metric names, so
the today-snapshot / trend / "recent daily metrics" sections came back EMPTY on v2
data and the LLM silently under-reported. Every builder here reads ``derived_daily``
(one canonical row per day) with the v2 metric names from ``analytics.metrics`` —
the seam bug is impossible by construction.

The session/log/finding sections live in ``context_sessions.py``; this module
orchestrates all of them into one markdown context string.

**No statistic here is computed across two instruments (#125).** The three reductions
below (a z-score, a 7-day mean, a 30-day median) and the anomaly scan all ask
``context_provenance.InstrumentGuard`` first, and a metric whose window holds more than
one instrument is not reduced at all — it is named in the guard's own section instead.
[[hr_reserve_vo2max]] Directive 4 forbids the average, #117 made it impossible inside
``derive/vo2max_tier.py``, and this is the other half: the tier picks one instrument per
DAY, and nothing here may re-mix the days it wrote.
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
from healthee.core.tenancy import USER_TODAY_SQL, user_today
from healthee.insights.context_provenance import (
    InstrumentGuard,
    guard_from_rows,
    instrument_legends,
    instrument_tag,
    registered_metrics,
)
from healthee.insights.context_sessions import (
    findings_section,
    manual_entries_section,
    sleep_section,
)

# Every statistic below is computed against a 30-day baseline, and the anomaly scan walks
# 14 days each carrying its own 30-day baseline — so the widest span any single number here
# can rest on is their sum. The instrument guard reads exactly that span: ONE window, so
# the four sections cannot disagree about whether a metric mixed instruments, and erring
# wide is the safe direction (it withholds a statistic, it never invents one).
_BASELINE_WINDOW_DAYS = 30
_ANOMALY_LOOKBACK_DAYS = 14
_INSTRUMENT_WINDOW_DAYS = _BASELINE_WINDOW_DAYS + _ANOMALY_LOOKBACK_DAYS

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


def _today_snapshot(user_id: UUID, tz: str, guard: InstrumentGuard) -> str:
    """Latest value per daily metric vs its personal 30-day baseline (z-score).

    The z-score is a comparison against a median, so a blocked metric is skipped whole: a
    value from one instrument scored against a median over two measures the instrument
    change, not the owner.
    """
    lines = [
        "## Today snapshot (latest day vs personal 30d baseline)",
        "| metric | latest | median | z |",
        "|---|---|---|---|",
    ]
    any_row = False
    for metric in DEFAULT_DAILY_METRICS:
        latest = None if guard.blocks(metric) else latest_value(user_id, metric)
        if latest is None:
            continue
        any_row = True
        day, value = latest
        baseline = compute_baseline(user_id, tz, metric, window_days=_BASELINE_WINDOW_DAYS)
        z = baseline.z_score(value)
        z_str = (
            f"{z:+.2f}σ{' ⚠️' if z is not None and abs(z) >= 2 else ''}" if z is not None else "-"
        )
        med = f"{baseline.median:.1f}" if baseline.median is not None else "-"
        lines.append(f"| {guard.label(metric)} | {value:.1f} ({day}) | {med} | {z_str} |")
    return "\n".join(lines) if any_row else ""


def _trends(user_id: UUID, tz: str, guard: InstrumentGuard) -> str:
    """7-day average vs 30-day median per metric — trend direction.

    Both halves are reductions and the Δ between them is a third, so a blocked metric
    produces no row: across an instrument change the arrow would report the change of
    instrument as a change in the owner's fitness.
    """
    lines = [
        "## Trend summary (7-day avg vs 30-day median)",
        "| metric | 7d avg | 30d median | Δ | dir |",
        "|---|---|---|---|---|",
    ]
    any_row = False
    with tenant_transaction(user_id) as cur:
        for metric in DEFAULT_DAILY_METRICS:
            if guard.blocks(metric):
                continue
            row = _seven_day_avg(cur, user_id, tz, metric)
            # On THIS cursor: the self-opening form would borrow a second pooled
            # connection per metric while this one is held (see compute_baselines).
            baseline = compute_baseline_cur(
                cur, user_id, tz, metric, window_days=_BASELINE_WINDOW_DAYS
            )
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
                f"| {guard.label(metric)} | {row:.1f} | {baseline.median:.1f} | "
                f"{delta:+.1f} | {arrow} |"
            )
    return "\n".join(lines) if any_row else ""


def _seven_day_avg(cur, user_id: UUID, tz: str, metric: str) -> float | None:
    """Mean of a metric's last 7 days from ``derived_daily`` (sentinel unfiltered
    is fine here — these are already-derived canonical daily values)."""
    cur.execute(
        "SELECT AVG(value) FROM derived_daily WHERE user_id = %s AND metric=%s AND day > %s",
        (user_id, metric, user_today(tz) - timedelta(days=7)),
    )
    row = cur.fetchone()
    return float(row[0]) if row and row[0] is not None else None


def _recent_daily(cur, user_id: UUID, tz: str, days: int) -> str:
    """Compact per-day table over ``derived_daily`` — the regression-tested section.

    On v2 data this MUST be non-empty (legacy returned empty here). Pivoted in
    Python to avoid dynamic SQL; metric list is a module constant.

    ``flags->>'method'`` rides along because a bare number cannot say which INSTRUMENT
    produced it, and for ``vo2max_estimate`` that is the difference between a measured run
    and a questionnaire ([[hr_reserve_vo2max]] D4, #120). Extracted in SQL rather than
    fetching whole ``flags`` blobs for ten metrics × ``days`` rows: this section is
    deliberately compact, and so is its query. ``context_provenance`` owns which metrics
    that column means anything for — every other cell is byte-identical to before.
    """
    metrics = [m for m, _ in _RECENT_COLUMNS]
    cur.execute(
        "SELECT (day)::date AS d, metric, value, flags->>'method' FROM derived_daily "
        f"WHERE user_id = %s AND metric = ANY(%s) AND day > ({USER_TODAY_SQL} - %s::int) "
        "ORDER BY d DESC",
        (user_id, metrics, tz, days),
    )
    by_day: dict[date, dict[str, str]] = {}
    tagged: set[str] = set()
    for d, metric, value, stored_method in cur.fetchall():
        tag = instrument_tag(metric, stored_method)
        if tag:
            tagged.add(metric)
        by_day.setdefault(d, {})[metric] = f"{_fmt(value)} {tag}" if tag else _fmt(value)
    if not by_day:
        return ""
    header = "| date | " + " | ".join(label for _, label in _RECENT_COLUMNS) + " |"
    sep = "|" + "---|" * (len(_RECENT_COLUMNS) + 1)
    lines = [f"## Recent daily metrics (last {days} days, {tz})", header, sep]
    for d in sorted(by_day, reverse=True):
        cells = [by_day[d].get(m, "-") for m, _ in _RECENT_COLUMNS]
        lines.append(f"| {d} | " + " | ".join(cells) + " |")
    return "\n".join([*lines, *instrument_legends(tagged)])


def _fmt(value: float | None) -> str:
    if value is None:
        return "-"
    return str(int(value)) if float(value).is_integer() else f"{value:.1f}"


def _baselines(user_id: UUID, tz: str, guard: InstrumentGuard) -> str:
    """Robust personal baselines (median ± σ, quartiles) for the daily metrics.

    ``n`` is days-with-a-value out of the window — the SAME count ``analytics/coverage.py``
    publishes as data coverage (INTELLIGENCE §3.1 pins it to ``Baseline.n``), so the header
    names the window and the model can read coverage off it rather than assume.
    """
    lines = [
        f"## Personal baselines (trailing {_BASELINE_WINDOW_DAYS}d, robust median ± σ)",
        f"| metric | n/{_BASELINE_WINDOW_DAYS}d | median | ± σ | p25–p75 |",
        "|---|---|---|---|---|",
    ]
    any_row = False
    for b in compute_all(user_id, tz, DEFAULT_DAILY_METRICS, _BASELINE_WINDOW_DAYS):
        if b.median is None or guard.blocks(b.metric):
            continue
        any_row = True
        sd = b.robust_sd
        sd_str = f"±{sd:.1f}" if sd is not None else "-"
        band = f"{b.p25:.0f}–{b.p75:.0f}" if b.p25 is not None and b.p75 is not None else "-"
        lines.append(f"| {guard.label(b.metric)} | {b.n} | {b.median:.1f} | {sd_str} | {band} |")
    return "\n".join(lines) if any_row else ""


def _anomalies(user_id: UUID, tz: str, guard: InstrumentGuard) -> str:
    """Recent |z|≥2 deviations vs personal baseline, each with its note ids.

    An anomaly IS a z-score, so a blocked metric's anomalies are dropped here rather than
    filtered in ``analytics/anomalies``: the detector is shared with surfaces that do not
    assemble this context, and the judgement "this window may not be reduced" belongs
    beside the reductions it governs.
    """
    rows = [
        a
        for a in anomalies_mod.detect(
            user_id, tz, days_back=_ANOMALY_LOOKBACK_DAYS, window_days=_BASELINE_WINDOW_DAYS
        )
        if not guard.blocks(a.metric)
    ]
    if not rows:
        return ""
    lines = [
        f"## Recent anomalies (last {_ANOMALY_LOOKBACK_DAYS}d, |z|≥2 vs personal baseline)",
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
        guard = _instrument_guard(cur, user_id, tz)
        session_sections = [
            _recent_daily(cur, user_id, tz, days),
            sleep_section(cur, user_id, tz, days),
            manual_entries_section(cur, user_id, tz, days),
        ]
    sections = [
        _today_snapshot(user_id, tz, guard),
        _trends(user_id, tz, guard),
        *session_sections,
        _baselines(user_id, tz, guard),
        _anomalies(user_id, tz, guard),
        findings_section(user_id, question),
        # Last, and never omitted when it fires: it is the statement that the numbers the
        # sections above did NOT print were refused rather than absent.
        guard.section(),
    ]
    return "\n\n".join(s for s in sections if s)


def _instrument_guard(cur, user_id: UUID, tz: str) -> InstrumentGuard:
    """Which instruments each instrument-bearing metric's reduction window holds (#125).

    ONE grouped query for every registered metric, on the caller's cursor. ``DISTINCT``
    in SQL rather than in Python because the guard needs the SET of instruments, not the
    rows: the window is up to 44 days × the registered metrics, and none of those values
    is ever rendered.
    """
    cur.execute(
        "SELECT DISTINCT metric, flags->>'method' FROM derived_daily "
        f"WHERE user_id = %s AND metric = ANY(%s) AND day > ({USER_TODAY_SQL} - %s::int)",
        (user_id, list(registered_metrics()), tz, _INSTRUMENT_WINDOW_DAYS),
    )
    return guard_from_rows(cur.fetchall(), _INSTRUMENT_WINDOW_DAYS)
