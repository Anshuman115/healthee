"""Live progress for an adopted challenge, scored from the owner's own data.

Ported from legacy ``llm/challenges.py::evaluate_challenge`` (:87). The scoring —
what counts as a hit, how the three cadences aggregate, how the streak walks
backwards through protected days — is verbatim. What changed:

* the owner and their zone are threaded in (legacy had neither), so "today" and
  every day bucket resolve in the OWNER's calendar (``core.tenancy.user_today``,
  never ``date.today()``, which is the server container's UTC date);
* an unknown metric / comparator / cadence RAISES instead of silently scoring 0 %.
  Legacy's ``comp == ">=" else <=`` fallback quietly turned a typo'd comparator into
  the opposite rule — a confidently wrong number, which is the one thing this
  product exists not to ship (standards §"errors are never swallowed");
* the function is split into its two cadence branches to stay inside the 40-line
  gate. No branch's arithmetic changed;
* the result carries ``window`` on every cadence (legacy emitted it only for
  ``daily``) — additive, so a cumulative result can state the window it is scored
  over instead of leaving the caller to re-read the row.
"""

from __future__ import annotations

from collections.abc import Callable
from datetime import date, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from healthee.challenges.metrics import CADENCES, COMPARATORS, spec
from healthee.challenges.series import metric_series, protected_days
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur

# Fallback window when a challenge row carries none. Verbatim from legacy (:93).
_DEFAULT_WINDOW_DAYS = 7

# The rolling window a `weekly` cadence sums over. Verbatim from legacy (:108).
_WEEKLY_DAYS = 7


def evaluate_challenge(
    cur: Cur, user_id: UUID, tz: str, challenge: dict, today: date | None = None
) -> dict:
    """Score one adopted challenge against the owner's data as of ``today``.

    ``challenge`` is a ``challenge`` row as a mapping: ``metric``, ``comparator``,
    ``target_value``, ``cadence``, ``window_days``, ``adopted_at``. ``today``
    defaults to the OWNER's today and exists so a caller evaluating a batch (and a
    test) pins one date for the whole run.
    """
    metric_spec = spec(challenge["metric"])
    comparator = _validated(challenge["comparator"], COMPARATORS, "comparator")
    cadence = _validated(challenge["cadence"], CADENCES, "cadence")
    today = today or user_today(tz)
    start = start_date(challenge.get("adopted_at"), tz, today)
    window = max(1, int(challenge.get("window_days") or _DEFAULT_WINDOW_DAYS))
    target = float(challenge["target_value"])
    # One day of lead-in so a same-day adopt still sees the day it started on.
    series = metric_series(cur, user_id, tz, challenge["metric"], start - timedelta(days=1))
    elapsed = (today - start).days + 1
    common = {
        "target": target,
        "today_value": series.get(today),
        "days_left": max(0, window - elapsed),
        "elapsed": elapsed,
        "unit": metric_spec.unit,
        "label": metric_spec.label,
    }
    if cadence in ("weekly", "total"):
        return common | _cumulative(series, cadence, target, start, today, window)
    meets = _meets(comparator, target)
    return common | _daily(cur, user_id, tz, series, meets, start, today, window, elapsed)


def _cumulative(
    series: dict[date, float], cadence: str, target: float, start: date, today: date, window: int
) -> dict:
    """``weekly`` (rolling 7-day total) / ``total`` (whole-window total) scoring.

    Verbatim from legacy (:106–118), including that completion is ``current >=
    target`` regardless of comparator — a cumulative challenge is a "reach this
    total" rule, and a ``<=`` cap is expressed as a ``daily`` challenge instead.
    """
    if cadence == "weekly":
        current = sum(series.get(today - timedelta(days=i), 0.0) for i in range(_WEEKLY_DAYS))
    else:
        current = sum(v for day, v in series.items() if start <= day <= today)
    return {
        "cadence": cadence,
        "window": window,
        "current": round(current, 1),
        "progress": round(min(1.0, current / target), 3) if target > 0 else 0.0,
        "complete": current >= target,
    }


def _daily(
    cur: Cur,
    user_id: UUID,
    tz: str,
    series: dict[date, float],
    meets: Callable[[float], bool],
    start: date,
    today: date,
    window: int,
    elapsed: int,
) -> dict:
    """``daily`` scoring: hit the per-day target on each of ``window`` days.

    Verbatim from legacy (:120–144). Progress is hit days over the window; the
    streak is the trailing run of hits, surviving days protected by a rough night.
    """
    days = [start + timedelta(days=i) for i in range(min(elapsed, window))]
    hits = [d for d in days if d in series and meets(series[d])]
    protected = protected_days(cur, user_id, tz, start, today)
    today_value = series.get(today)
    today_hit = today_value is not None and meets(today_value)
    return {
        "cadence": "daily",
        "window": window,
        "hit_days": len(hits),
        "progress": round(min(1.0, len(hits) / window), 3),
        "complete": len(hits) >= window,
        "streak": _streak(series, meets, protected, start, today),
        "today_hit": today_hit,
        "protected_today": (not today_hit) and (today in protected),
    }


def _streak(
    series: dict[date, float],
    meets: Callable[[float], bool],
    protected: set[date],
    start: date,
    today: date,
) -> int:
    """Trailing run of hit days back to ``start``, unbroken by a protected day.

    A protected day neither extends nor breaks the run: the walk steps over it.
    Verbatim from legacy (:125–134).
    """
    streak = 0
    day = today
    while day >= start:
        if day in series and meets(series[day]):
            streak += 1
        elif day not in protected:
            break
        day -= timedelta(days=1)
    return streak


def _meets(comparator: str, target: float) -> Callable[[float], bool]:
    """The day-level predicate for a challenge's direction."""
    if comparator == ">=":
        return lambda value: value >= target
    return lambda value: value <= target


def _validated(value: str, allowed: frozenset[str], field: str) -> str:
    """``value`` if the vocabulary allows it, else raise — never a silent fallback."""
    if value not in allowed:
        raise ValueError(f"unknown challenge {field} {value!r} (expected one of {sorted(allowed)})")
    return value


def start_date(adopted_at: datetime | None, tz: str, today: date) -> date:
    """The owner's local date a challenge started on; ``today`` if never adopted.

    ``adopted_at`` is a ``timestamptz`` and must arrive timezone-aware: converting a
    NAIVE datetime with ``astimezone`` would silently assume the SERVER process's
    zone and can shift the start by a day — the calendar-date-vs-instant bug class.
    """
    if adopted_at is None:
        return today
    if adopted_at.tzinfo is None:
        raise ValueError("challenge.adopted_at must be timezone-aware (it is a timestamptz)")
    return adopted_at.astimezone(ZoneInfo(tz)).date()
