"""Reading a challenge metric's daily series, its baseline, and its protected days.

The data side of the engine: everything here answers "what did this owner actually
do on each of their local days", which is what makes a challenge auto-tracked from
their own data with zero manual check-ins (CHALLENGES.md §1).

Ported from legacy ``llm/challenges.py`` (``_series`` :50, ``_protected_days`` :73,
``_recent_value`` :157). Three things had to change, and none of them is a science
change:

1. **Storage.** Legacy read ``metric_sample`` (a dropped v1 view) and let "the last
   sample of the day" win. ``derived_daily`` is already one canonical row per
   owner-day, so that tie-break has nothing left to break — the reads go through
   ``analytics.series``, the ONE v2 daily-series reader.
2. **Owner-scoping.** Legacy had no ``user_id`` anywhere. Every read here is
   owner-scoped (MULTI_USER.md §3.3) and runs on the caller's cursor.
3. **Timezone.** Legacy hardcoded ``AT TIME ZONE 'Asia/Kolkata'`` in the SQL and
   ``datetime.now(tz=USER_TZ).date()`` in Python. Both are the calendar-date-vs-
   instant bug class that shipped two live wrong numbers in this repo; the owner's
   zone is threaded through instead (``core.tenancy``). ``derived_daily.day`` is
   ALREADY the owner's local date, so only the ``workout`` read — whose rows are
   instants — needs a conversion.
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from healthee.analytics.series import daily_series, flag_series
from healthee.challenges.metrics import (
    DerivedSource,
    ManualEntrySource,
    WorkoutCountSource,
    spec,
)
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur
from healthee.derive.robust import median

# A night below this fraction of the owner's OWN 30-day sleep median is "genuinely
# rough". RELATIVE TO SELF on purpose: an absolute threshold would protect a chronic
# short sleeper every single day, which would make the streak meaningless for exactly
# the person this product was built for. Verbatim from legacy `_protected_days` (:83).
_ROUGH_NIGHT_FRACTION = 0.6

# Sleep-median lookback, and the fewest nights it takes to trust that median.
# Verbatim from legacy `_protected_days` (:78, :80).
_SLEEP_MEDIAN_DAYS = 30
_MIN_NIGHTS_FOR_MEDIAN = 5

# The metric whose nights define "a rough night" for streak protection.
_SLEEP_METRIC = "tst_min"

# Trailing days a baseline is computed over. Verbatim from legacy `_recent_value` (:157).
BASELINE_DAYS = 7

# The fewest MEASURED days inside that window for a :func:`recent_window` value to say
# more about the person than about which days happened to record. More than half the
# estimator's seven is the line. It lives here, beside the estimator it qualifies,
# because two callers now judge the same number by it and a second copy would be a
# second definition of "enough data" (CLAUDE.md): the ledger refuses to publish a
# before/after below it (``ledger._confidence``), and generation refuses to CALIBRATE a
# target below it (``bounds.calibrate``) — the same reason, applied backwards and
# forwards in time.
MIN_COMPARISON_DAYS = 4


def metric_series(
    cur: Cur, user_id: UUID, tz: str, metric: str, since: date, until: date | None = None
) -> dict[date, float]:
    """Daily ``{local date: value}`` for one owner's challenge metric since ``since``.

    Dispatches on the registry's source binding: a ``derived_daily`` value, a
    numeric field of that row's ``flags`` (total sleep time), a count of qualifying
    workouts, or a self-logged daily total.

    ``until`` bounds only the ONE source that has to enumerate days rather than read
    them — a :class:`ManualEntrySource`, which zero-fills (see
    :func:`_manual_sums`). It defaults to the OWNER's today, and every caller that
    already holds a pinned anchor passes it so a zero-fill can never run past the
    day the caller is scoring. The device-backed sources ignore it: their absent
    days stay absent, because for those "no row" genuinely means "no data".
    """
    source = spec(metric).source
    if isinstance(source, WorkoutCountSource):
        return _workout_counts(cur, user_id, tz, since, source.min_duration_s)
    if isinstance(source, ManualEntrySource):
        return _manual_sums(cur, user_id, tz, since, until or user_today(tz), source)
    return _derived_series(cur, user_id, source, since)


def _derived_series(
    cur: Cur, user_id: UUID, source: DerivedSource, since: date
) -> dict[date, float]:
    """One owner's ``derived_daily`` series — the ``value`` column or a ``flags`` field."""
    if source.flag_key is not None:
        return flag_series(cur, user_id, source.metric, source.flag_key, since)
    return daily_series(cur, user_id, source.metric, since)


def _workout_counts(
    cur: Cur, user_id: UUID, tz: str, since: date, min_duration_s: int
) -> dict[date, float]:
    """Qualifying workouts per local day, bucketed in the OWNER's zone.

    ``workout.start_ts`` is an instant, so the local day is ``AT TIME ZONE %s`` —
    parameterized with the owner's zone, never the module constant legacy inlined.
    The extra ``start_ts >= since - 2 days`` bound is a *sargable superset* of the
    local-date predicate (no zone is more than 14 h from UTC, so one day of slack
    always covers it): it keeps ``workout_start_idx`` usable while the exact
    boundary stays with the local-date comparison.
    """
    cur.execute(
        "SELECT (start_ts AT TIME ZONE %s)::date AS local_day, count(*) "
        "FROM workout WHERE user_id = %s "
        "  AND start_ts >= %s::date - interval '2 days' "
        "  AND (start_ts AT TIME ZONE %s)::date >= %s "
        "  AND COALESCE(duration_s, 0) >= %s "
        "GROUP BY local_day",
        (tz, user_id, since, tz, since, min_duration_s),
    )
    return {row[0]: float(row[1]) for row in cur.fetchall()}


def _manual_sums(
    cur: Cur, user_id: UUID, tz: str, since: date, until: date, source: ManualEntrySource
) -> dict[date, float]:
    """One owner's self-logged daily totals for a kind, ZERO-FILLED over the window.

    Two decisions are load-bearing and both are argued in
    :class:`~healthee.challenges.metrics.ManualEntrySource`: an unlogged day is a
    zero (so a cap challenge is scoreable for the owner who abstained), and only
    rows carrying this source's unit — or no unit at all — are summed (so nothing
    is converted between units on the owner's behalf).

    ``ts`` is an instant, so the local day is ``AT TIME ZONE %s`` in the OWNER's
    zone; the extra ``ts >= since - 2 days`` bound is the same sargable superset
    trick :func:`_workout_counts` uses to keep the ``ts`` index in play.
    """
    cur.execute(
        "SELECT (ts AT TIME ZONE %s)::date AS local_day, sum(amount) "
        "FROM manual_entry WHERE user_id = %s AND kind = %s "
        "  AND ts >= %s::date - interval '2 days' "
        "  AND (ts AT TIME ZONE %s)::date BETWEEN %s AND %s "
        "  AND amount IS NOT NULL "
        "  AND (unit IS NULL OR lower(unit) = %s) "
        "GROUP BY local_day",
        (tz, user_id, source.kind, since, tz, since, until, source.unit),
    )
    logged = {row[0]: float(row[1]) for row in cur.fetchall()}
    span = (until - since).days  # < 0 ⇒ the window is empty, and so is the series
    return {
        day: logged.get(day, 0.0) for day in (since + timedelta(days=i) for i in range(span + 1))
    }


def recent_window(
    cur: Cur,
    user_id: UUID,
    tz: str,
    metric: str,
    cadence: str,
    ref: date,
    days: int = BASELINE_DAYS,
) -> tuple[float | None, int]:
    """:func:`recent_value` plus HOW MANY days it was built from.

    The count is not decoration: the outcome ledger has to be able to say
    ``insufficient_data`` instead of publishing a before/after computed from two
    days (CHALLENGES.md §2.1), and it cannot tell that from the value alone — a
    mean over two days and a mean over seven look identical.

    ONE implementation of the baseline, with :func:`recent_value` as its thin
    value-only form, so the number the ledger judges and the number the adapter
    floors against can never be computed two different ways.
    """
    series = metric_series(cur, user_id, tz, metric, ref - timedelta(days=days), until=ref)
    values = [v for day, v in sorted(series.items()) if day < ref][-days:]
    if not values:
        return None, 0
    if cadence in ("weekly", "total"):
        return round(sum(values), 1), len(values)
    return round(sum(values) / len(values), 1), len(values)


def recent_value(
    cur: Cur,
    user_id: UUID,
    tz: str,
    metric: str,
    cadence: str,
    ref: date,
    days: int = BASELINE_DAYS,
) -> float | None:
    """The owner's own baseline, in the same units the target is expressed in.

    ``weekly``/``total`` targets are period sums, so the baseline is the SUM of the
    trailing ``days``; ``daily`` targets are per-day levels, so it is their AVERAGE.
    Computed strictly BEFORE ``ref`` — a baseline frozen at adopt time must not
    include the challenge's own first day. Verbatim from legacy ``_recent_value``.

    Returns ``None`` when the owner has no data in the window: "not enough data"
    is a distinct state from "zero", and callers must be able to tell them apart.
    """
    return recent_window(cur, user_id, tz, metric, cadence, ref, days)[0]


def protected_days(cur: Cur, user_id: UUID, tz: str, since: date, today: date) -> set[date]:
    """Days on or after ``since`` that followed a genuinely rough night.

    A daily-challenge miss on one of these does not break the streak — recovery is
    part of the plan, not a failure. "Rough" is measured against the owner's OWN
    30-day sleep median (``< 60 %`` of it), never an absolute hours figure, which is
    the property that keeps the protection meaningful for a chronic short sleeper:
    their median is itself low, so only a night far below THEIR norm qualifies.

    Fewer than five nights in the window ⇒ no protection at all: a median over one
    or two nights is not a norm, and inventing protection from it would silently
    inflate streaks. Ported from legacy ``_protected_days`` (:73) — verbatim except
    for the median itself, which legacy took as the upper-middle night of an even
    window; see the comment on the threshold below.

    ``derived_daily.day`` for a sleep row is the owner's local WAKE date, so the day
    a night is keyed to already IS "the day after that night".
    """
    nights = metric_series(
        cur, user_id, tz, _SLEEP_METRIC, today - timedelta(days=_SLEEP_MEDIAN_DAYS), until=today
    )
    values = list(nights.values())
    if len(values) < _MIN_NIGHTS_FOR_MEDIAN:
        return set()
    # ``derive/robust.median`` — the ONE median. Legacy took the upper-middle night of
    # an even window, which is not a median and made this the third definition of one
    # in the tree; the interpolating form can only lower the threshold slightly, so it
    # never invents protection that was not there (CLAUDE.md: one definition per metric).
    threshold = median(values) * _ROUGH_NIGHT_FRACTION
    return {day for day, value in nights.items() if day >= since and value < threshold}
