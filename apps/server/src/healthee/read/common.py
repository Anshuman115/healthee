"""Shared read-layer primitives: daily-series helpers and the sport-code names.
One definition, reused by every read service (standards §Duplication).

The timezone is threaded in as an IANA name (``tz: str``) — 6.3b removed the
single-tenant ``USER_TZ_NAME``/``USER_TZ`` constants in favour of
``core.tenancy.SENTINEL_TZ``, hardwired at the read entry points until 6.4 sources
it from the authenticated user. It is always bound as a ``%s`` parameter to
``AT TIME ZONE`` so every day-bucketing query stays parameterized.

6.4a extends that to the window ANCHORS: a "last N days" window ends at the OWNER's
today (``core.tenancy.USER_TODAY_SQL``), never at the database session's
``current_date`` — see that constant for why.

## Every window and every "latest" now ends at a DAY, not at the clock

``docs/AS_OF_DAY.md``: these reads answer for a reference day, which defaults to the
owner's today and may be any earlier one. That makes ``day > (anchor - N)`` only half a
window — the closing half, ``day <= anchor``, is what stops an answer for 29 July from
containing a row filed under 3 August. The FUTURE LEAK is the mirror of the
stale-as-current failure ``derive/freshness.py`` exists for, and it lives in exactly the
places the word "latest" appears, which is why the bound is applied here, once, in the
primitives every read service shares rather than at each of their call sites.

``on_or_before`` is required, not defaulted. A default would be ``user_today``, and a
caller that forgot to pass its own day would then silently get the unbounded behaviour
back — the one failure this parameter exists to make impossible.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date
from typing import LiteralString, cast
from uuid import UUID

from healthee.analytics.baselines import Baseline, compute_baselines_cur
from healthee.analytics.metrics import metric_filter
from healthee.core.tenancy import AS_OF_DAY_SQL, user_today
from healthee.derive._common import Cur


def derived_series(
    cur: Cur, user_id: UUID, metric: str, days: int, on_or_before: date
) -> list[dict]:
    """The ``days`` days ENDING at ``on_or_before`` of one owner's ``derived_daily``
    metric, oldest first, sentinel-filtered. Replaces the legacy ``_series_for_metric``
    (which read the ``metric_sample`` view). The filter fragment is a hardcoded constant
    from the metric registry — safe to interpolate (standards §2)."""
    flt = metric_filter(metric)  # constant from METRIC_FILTERS — safe to interpolate
    cur.execute(
        cast(
            LiteralString,
            "SELECT day, value FROM derived_daily "
            f"WHERE user_id = %s AND metric = %s AND {flt} "
            f"AND day > ({AS_OF_DAY_SQL} - %s::int) AND day <= {AS_OF_DAY_SQL} ORDER BY day",
        ),
        (user_id, metric, on_or_before, days, on_or_before),
    )
    return [{"date": r[0].isoformat(), "value": float(r[1])} for r in cur.fetchall()]


# The flag keys a daily card forwards as ``provenance`` — WHICH instrument produced the
# number and WHAT it was assembled from. An explicit allow-list rather than "everything
# except caveats", so a new diagnostic flag cannot start appearing on a public payload by
# accident; adding one here is a decision.
#
# Every entry is a fact the derive layer already computed and the read layer used to
# throw away (audit C5 and C6):
#
#   source              which of two instruments counted the day's steps —
#                       ``derive/device_totals.py`` exists entirely to decide this, and
#                       #121 is the incident that made it the whole point. VO2max names
#                       its instrument on the wire; steps went through the same reasoning
#                       and the answer stopped at the database.
#   reported_at         when the strap's counter reading ARRIVED at the server.
#   read_at             when the strap was ASKED for it (0019) — the instant the counter
#                       is actually a claim about: "a counter read at 09:00 is a statement
#                       about a partial day". This key said `reported_at` and meant this,
#                       which is write-path audit A1: the arrival was quoted to the owner
#                       as the reading. Explicitly NULL — never absent — on a device-tier
#                       row that did not record it, because "this reading does not say when
#                       it was taken" is a fact about the number's making, not a missing
#                       question. Every row written before 0019 is in that state.
#   steps_per_minute_sum  the OTHER instrument's number, carried so a reader can see the
#                       divergence without the served value having been blended from both.
#   sample_minutes      how many minutes of the day the per-minute stream spoke for — the
#                       count behind the value, and the fact that decides whether a zero
#                       is a measurement at all (audit C7).
#   method / stride_m   how a distance was got: the device's metres, or steps × a stride
#                       derived from the owner's height.
#   bmr / workout_cal   the calorie split. ``derive/energy.py`` records how much of the
#                       day came from the MET-by-state model and how much from the
#                       device's own figure for workout windows (licensed by
#                       [[energy_expenditure_derivation]] D2) — and the owner saw one
#                       number with no indication of the mix.
#   pal                 total ÷ BMR, the physical-activity level that number implies.
_PROVENANCE_FLAGS = (
    "source",
    "reported_at",
    "read_at",
    "steps_per_minute_sum",
    "sample_minutes",
    "method",
    "stride_m",
    "bmr",
    "workout_cal",
    "pal",
)


def provenance(flags: dict) -> dict:
    """How this value was produced, as the derive layer recorded it — never re-derived.

    A pass-through of the keys in :data:`_PROVENANCE_FLAGS` that the row actually carries.
    Keys the row does not carry are ABSENT rather than null: this block describes what is
    known about a specific number's making, and a null ``workout_cal`` on a step count
    would read as "no workout calories" instead of "not a question about steps".

    Empty for a metric whose derivation recorded nothing about itself, which is an honest
    empty — the same contract ``caveats`` holds beside it.
    """
    return {key: flags[key] for key in _PROVENANCE_FLAGS if key in flags}


def latest_derived(
    cur: Cur, user_id: UUID, metric: str, on_or_before: date
) -> tuple[date, float, dict] | None:
    """The newest ``derived_daily`` row AT OR BEFORE ``on_or_before``, as (day, value, flags).

    "The latest row" and "the latest row this day may know about" are the same query on
    the current day and different queries on any older one. Only the second is answerable
    for a past day, so it is the only one this module offers.
    """
    cur.execute(
        "SELECT day, value, flags FROM derived_daily WHERE user_id = %s AND metric=%s "
        "AND day <= %s ORDER BY day DESC LIMIT 1",
        (user_id, metric, on_or_before),
    )
    row = cur.fetchone()
    if not row:
        return None
    return row[0], float(row[1]), (row[2] or {})


def latest_derived_many(
    cur: Cur, user_id: UUID, metrics: Sequence[str], on_or_before: date
) -> dict[str, tuple[date, float, dict]]:
    """Newest row at or before ``on_or_before`` per metric, in ONE ``DISTINCT ON`` query.

    Same shape and semantics as calling :func:`latest_derived` per metric (newest
    admissible row wins, no sentinel filter), but collapses the N-metric fan-out to a
    single statement — the ``/api/today`` aggregator's latest-value loader. Metrics with
    no rows are simply absent from the result (mirroring ``latest_derived`` → None)."""
    out: dict[str, tuple[date, float, dict]] = {}
    wanted = list(dict.fromkeys(metrics))
    if not wanted:
        return out
    cur.execute(
        "SELECT DISTINCT ON (metric) metric, day, value, flags FROM derived_daily "
        "WHERE user_id = %s AND metric = ANY(%s) AND day <= %s ORDER BY metric, day DESC",
        (user_id, wanted, on_or_before),
    )
    for metric, day, value, flags in cur.fetchall():
        out[metric] = (day, float(value), (flags or {}))
    return out


def derived_series_many(
    cur: Cur, user_id: UUID, metrics: Sequence[str], days: int, on_or_before: date
) -> dict[str, list[dict]]:
    """``days`` days ending at ``on_or_before``, several metrics, in ONE query.

    Batched form of :func:`derived_series` (same per-metric sentinel filter, same
    window, oldest-first) so the Today sparklines load in a single statement
    instead of one query per slot. Every requested metric gets a key (empty list
    when it has no rows)."""
    out: dict[str, list[dict]] = {m: [] for m in dict.fromkeys(metrics)}
    if not out:
        return out
    wanted = list(out)
    # Per-metric sentinel filter OR'd — each fragment is a METRIC_FILTERS constant.
    where = " OR ".join(f"(metric = %s AND {metric_filter(m)})" for m in wanted)
    cur.execute(
        cast(
            LiteralString,
            "SELECT metric, day, value FROM derived_daily "
            f"WHERE user_id = %s AND day > ({AS_OF_DAY_SQL} - %s::int) "
            f"AND day <= {AS_OF_DAY_SQL} AND (" + where + ") "
            "ORDER BY metric, day",
        ),
        (user_id, on_or_before, days, on_or_before, *wanted),
    )
    for metric, day, value in cur.fetchall():
        out[metric].append({"date": day.isoformat(), "value": float(value)})
    return out


def as_of_block(cur: Cur, user_id: UUID, tz: str, as_of: date) -> dict:
    """Which day a payload answers for, whether it is the owner's today, and when the
    day's rows were computed — ``docs/AS_OF_DAY.md`` rules 5 and 6.

    One definition, because three endpoints carry it and a payload that named its day
    differently from its sibling would be exactly the drift the rules exist against
    (standards §Duplication). ``is_today`` is the fact a client cannot derive for itself:
    the owner's calendar day is the server's to decide, and a phone comparing against its
    own clock is the wall-clock bug ``core/tenancy.py`` exists to prevent.

    The phrasing every surface must use with this is **as of** that date, not **on** it.
    A past-day answer is our best account of that day from the rows filed under it, using
    today's model — not a transcript of what the app said then, because re-derives and
    science fixes mean the two can differ (``docs/AS_OF_DAY.md`` section 5; #118 is the
    standing proof that wrong rows persist until purged).
    """
    return {
        "day": as_of.isoformat(),
        "is_today": as_of == user_today(tz),
        "derived_at": day_derived_at(cur, user_id, as_of),
    }


def day_derived_at(cur: Cur, user_id: UUID, day: date) -> str | None:
    """When this owner's rows for ``day`` were last COMPUTED, or None when it has none.

    ``docs/AS_OF_DAY.md`` rule 6: a row for 29 July computed during a September re-derive
    is still 29 July's answer, and the reader is entitled to know when it was computed.
    The newest ``derived_at`` across the day's rows, because a day is derived as a batch
    and the last write is when the answer as a whole was settled — #118 is the standing
    proof that a run can leave some of a day's rows untouched, and reporting the OLDEST
    would name a pass that no longer accounts for the value being served.

    Null is a real answer: a day with no derived rows has no computation to date. It is
    never filled from a neighbouring day.
    """
    cur.execute(
        "SELECT max(derived_at) FROM derived_daily WHERE user_id = %s AND day = %s",
        (user_id, day),
    )
    row = cur.fetchone()
    return row[0].isoformat() if row and row[0] else None


@dataclass(frozen=True)
class TodayReads:
    """Per-request preloaded reads for the Today aggregator, so the per-metric card
    and recovery-signal payloads look values up instead of each issuing their own
    ``latest_derived`` + ``compute_baseline`` fan-out. ``None`` is never stored —
    an absent metric simply isn't a key."""

    latest: dict[str, tuple[date, float, dict]]
    baselines: dict[str, Baseline]


def build_today_reads(
    cur: Cur,
    user_id: UUID,
    tz: str,
    latest_metrics: Sequence[str],
    baseline_metrics: Sequence[str],
    on_or_before: date,
) -> TodayReads:
    """Preload the Today latest-values (1 query) + 30-day baselines (1 query).

    Both go through ``cur`` — the aggregator's own connection. The baselines used to
    come from the self-opening ``compute_baselines``, which borrowed a SECOND pooled
    connection on every single request while this one was held.

    Both END at ``on_or_before``: the baseline window is what every z-score on the page is
    read against, so a baseline that ran to today would price a past day's value against
    days that had not happened yet.
    """
    return TodayReads(
        latest=latest_derived_many(cur, user_id, latest_metrics, on_or_before),
        baselines=compute_baselines_cur(
            cur, user_id, tz, list(baseline_metrics), window_days=30, end_date=on_or_before
        ),
    )


# Device sport codes (Zepp/Amazfit Huami) → display name. Ported verbatim from
# legacy ``_SPORT_NAMES``. Code 44 = the auto-detected generic "Activity" bout;
# unknown codes fall back to "Activity" (Zepp's generic label), not "Workout".
_SPORT_NAMES: dict[int, str] = {
    1: "Outdoor run", 2: "Walking", 3: "Outdoor cycling", 4: "Treadmill",
    6: "Indoor cycling", 7: "Open-water swim", 8: "Pool swim", 9: "Elliptical",
    10: "Climbing", 12: "Hiking", 14: "Strength", 15: "Rowing", 16: "Yoga",
    21: "HIIT", 22: "Core training", 23: "Stretching", 24: "Cardio",
    44: "Activity", 50: "Jump rope", 52: "Boxing", 60: "Free training",
    1000: "Outdoor run", 1001: "Walking",
}  # fmt: skip


def sport_name(code: int | None) -> str:
    """Display name for a device sport code (legacy ``_sport_name``)."""
    return _SPORT_NAMES.get(code, "Activity") if code is not None else "Activity"
