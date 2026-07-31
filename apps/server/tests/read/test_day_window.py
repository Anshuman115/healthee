"""The intraday day-window predicate must prune chunks WITHOUT moving a single row.

``read/today_series`` answers "today" over the ``sample`` hypertable. It used to
filter on ``(ts AT TIME ZONE %s)::date = %s`` alone, which Postgres can only apply
as a Filter — so no ``ts`` predicate meant no chunk exclusion and answering "today"
read every chunk of all history (measured: 7,914 buffers / 53 chunks on one year of
per-minute HR, vs 17 buffers / 1 chunk with a ``ts`` range).

The fix ADDS a ``ts >= start AND ts < next_start`` bound and KEEPS the date filter.
That is only safe if the added predicate selects **exactly** the same instants the
date filter does. This suite is that proof, and it is deliberately run against the
database rather than against Python's idea of a timezone: it is Postgres' ``AT TIME
ZONE`` that has to agree with :func:`_day_bounds_utc`, not `zoneinfo`.

That makes this the cross-check on the ONE definition of a local day (#58 unified the
read side and the derive side onto :func:`_day_bounds_utc`): whatever `zoneinfo` picks
for an ambiguous or non-existent local midnight, Postgres has to agree that the
resulting bracket holds exactly the instants whose local date is ``day``.

DST is the case that matters. A local day is 23 h or 25 h on a transition, and a
fixed 24 h bracket would drop or double-count an hour — silently, as a wrong health
number rather than an error.
"""

from __future__ import annotations

from datetime import date

import pytest

from healthee.core.db import transaction
from healthee.derive._common import _day_bounds_utc

pytestmark = pytest.mark.integration

# (tz, day, why). The DST rows are the point; the others are the controls.
_DAYS = [
    ("America/New_York", date(2026, 3, 8), "spring forward — a 23 h local day"),
    ("America/New_York", date(2026, 11, 1), "fall back — a 25 h local day"),
    ("America/New_York", date(2026, 6, 15), "normal 24 h day"),
    ("Asia/Kolkata", date(2026, 6, 15), "no DST, +05:30 half-hour offset"),
    ("Asia/Kolkata", date(2026, 3, 8), "no DST on a day that IS a US transition"),
    ("Europe/Berlin", date(2026, 3, 29), "spring forward at 02:00 local"),
    ("Europe/Berlin", date(2026, 10, 25), "fall back at 03:00 local"),
    ("Pacific/Chatham", date(2026, 4, 5), "fall back, +12:45 quarter-hour offset"),
    ("Australia/Lord_Howe", date(2026, 4, 5), "fall back by THIRTY minutes, not an hour"),
    ("UTC", date(2026, 6, 15), "the trivial zone"),
    # #58: the midnight transitions, where the local day's own 23:59:59 is ambiguous
    # or non-existent. Postgres must agree with `zoneinfo` on every instant of these.
    ("America/Santiago", date(2026, 4, 4), "25 h — falls back AT the next midnight"),
    ("Asia/Beirut", date(2026, 10, 24), "25 h — falls back AT the next midnight"),
    ("America/Nuuk", date(2026, 3, 28), "23 h — springs forward 23:00 -> next midnight"),
    ("America/Santiago", date(2026, 9, 6), "23 h — a date with NO local midnight"),
]


@pytest.mark.parametrize(("tz", "day", "why"), _DAYS, ids=[f"{t}:{d}" for t, d, _ in _DAYS])
def test_ts_range_matches_the_tz_date_filter_exactly(
    db: None,  # noqa: ARG001 — gates on a reachable DB
    tz: str,
    day: date,
    why: str,
) -> None:
    """Every minute of the local day is in the range, and nothing else is.

    Generated per-minute across a 4-day span centred on ``day`` and compared as SETS:
    the two predicates must agree on every instant, so ``ts`` -range pruning cannot
    change a payload. A 24 h-assuming bracket fails the two DST rows.
    """
    ts_from, ts_to = _day_bounds_utc(day, tz)
    with transaction() as cur:
        cur.execute(
            "SELECT "
            "  count(*) FILTER (WHERE (g AT TIME ZONE %s)::date = %s) AS by_date, "
            "  count(*) FILTER (WHERE g >= %s AND g < %s) AS by_range, "
            "  count(*) FILTER (WHERE ((g AT TIME ZONE %s)::date = %s) "
            "                     <> (g >= %s AND g < %s)) AS disagree "
            "FROM generate_series(%s::date - 2, %s::date + 2, interval '1 minute') g",
            (tz, day, ts_from, ts_to, tz, day, ts_from, ts_to, day, day),
        )
        row = cur.fetchone()
    assert row is not None, "the aggregate returned no row"
    by_date, by_range, disagree = row

    assert disagree == 0, f"{tz} {day} ({why}): {disagree} instants classified differently"
    assert by_date == by_range, f"{tz} {day} ({why}): {by_date} by date vs {by_range} by range"
    assert by_date > 0, "the fixture generated no rows inside the day — test is vacuous"


ID_NUUK_SPRING = ("America/Nuuk", date(2026, 3, 28))
# The probe below constructs the WALL-CLOCK time 23:59:59.5, so it can only run where
# that wall time exists. America/Nuuk springs forward at 23:00 on 2026-03-28: the last
# hour of that date never happens, and asking for it would test Postgres' choice for a
# non-existent time rather than the bracket. The equivalence test above already walks
# every real instant of that day.
_SUB_SECOND_DAYS = [row for row in _DAYS if row[:2] != ID_NUUK_SPRING]


@pytest.mark.parametrize(
    ("tz", "day", "why"), _SUB_SECOND_DAYS, ids=[f"{t}:{d}" for t, d, _ in _SUB_SECOND_DAYS]
)
def test_the_last_sub_second_of_the_day_is_inside_the_range(
    db: None,  # noqa: ARG001 — gates on a reachable DB
    tz: str,
    day: date,
    why: str,
) -> None:
    """A sample at 23:59:59.5 local belongs to ``day`` and MUST be in the range.

    Separate from the equivalence test above because that one walks per MINUTE and
    is therefore blind to a sub-second gap at the boundary — exactly the gap a
    `23:59:59` end bound opens, since `sample` stores sub-second timestamps. A `hr`
    sample lands here whenever the strap's minute tick has any sub-second offset.
    """
    ts_from, ts_to = _day_bounds_utc(day, tz)
    with transaction() as cur:
        cur.execute(
            "WITH g AS (SELECT ((%s::date + time '23:59:59.5') AT TIME ZONE %s) AS ts) "
            "SELECT (ts AT TIME ZONE %s)::date = %s, (ts >= %s AND ts < %s) FROM g",
            (day, tz, tz, day, ts_from, ts_to),
        )
        row = cur.fetchone()
    assert row is not None, "the fixture instant returned no row"
    in_day, in_range = row

    assert in_day, f"{tz} {day} ({why}): fixture instant is not in the day — test is vacuous"
    assert in_range, f"{tz} {day} ({why}): the day's final second falls OUTSIDE the ts range"


def test_dst_days_are_not_24_hours(db: None) -> None:  # noqa: ARG001 — gates on a reachable DB
    """The controls above would also pass a broken fixed-24 h bracket if no row here
    actually spanned a transition. Pin the lengths so the DST cases stay real."""
    hours = {}
    for tz, day, _ in _DAYS:
        ts_from, ts_to = _day_bounds_utc(day, tz)
        hours[(tz, day)] = (ts_to - ts_from).total_seconds() / 3600

    assert hours[("America/New_York", date(2026, 3, 8))] == 23
    assert hours[("America/New_York", date(2026, 11, 1))] == 25
    assert hours[("Europe/Berlin", date(2026, 3, 29))] == 23
    assert hours[("Europe/Berlin", date(2026, 10, 25))] == 25
    assert hours[("Australia/Lord_Howe", date(2026, 4, 5))] == 24.5  # a 30-minute shift
    assert hours[("Asia/Kolkata", date(2026, 6, 15))] == 24
    # The #58 midnight transitions — the days a `23:59:59` end mis-measured by an hour.
    assert hours[("America/Santiago", date(2026, 4, 4))] == 25
    assert hours[("Asia/Beirut", date(2026, 10, 24))] == 25
    assert hours[ID_NUUK_SPRING] == 23
    assert hours[("America/Santiago", date(2026, 9, 6))] == 23
