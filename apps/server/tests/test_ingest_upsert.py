"""Unit tests for the upsert layer that need no database — a fake cursor records
what SQL would run. Covers the unknown-metric coerce-drop, the _fresh() gating
predicate, and the one-per-day weight de-dup.
"""

from __future__ import annotations

import logging
from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.ingest.daily_totals import upsert_daily_totals
from healthee.ingest.models import DailyTotalIn, SampleIn, SleepIn, WorkoutIn
from healthee.ingest.upsert import (
    build_fresh_predicate,
    epoch_to_utc,
    upsert_samples,
    upsert_weight,
    upsert_workouts,
)


class FakeCursor:
    """Minimal cursor stub: records executes and hands back canned fetch rows."""

    def __init__(
        self, fetchone: list[Any] | None = None, fetchall: list[Any] | None = None
    ) -> None:
        self.executed: list[tuple[str, Any]] = []
        self.executemany_rows: list[Any] | None = None
        self.executemany_sql: str | None = None
        self._fetchone = list(fetchone or [])
        self._fetchall = list(fetchall or [])

    def execute(self, sql: str, params: Any = None) -> None:
        self.executed.append((sql, params))

    def executemany(self, sql: str, rows: Any) -> None:
        self.executemany_sql = sql
        self.executemany_rows = list(rows)

    def fetchone(self) -> Any:
        return self._fetchone.pop(0) if self._fetchone else None

    def fetchall(self) -> Any:
        return self._fetchall.pop(0) if self._fetchall else []


def _ms(dt: datetime) -> int:
    return int(dt.timestamp() * 1000)


def test_upsert_samples_drops_unknown_metrics() -> None:
    cur = FakeCursor()
    samples = [
        SampleIn(metric="hr", ts=1_718_000_000_000, value=61.0),
        SampleIn(metric="bogus", ts=1_718_000_060_000, value=1.0),
        SampleIn(metric="hrv", ts=1_718_000_120_000, value=44.0),
    ]
    accepted, rejected = upsert_samples(cur, SENTINEL_USER_ID, samples)  # type: ignore[arg-type]
    assert (accepted, rejected) == (2, 1)
    assert cur.executemany_rows is not None
    assert len(cur.executemany_rows) == 2  # only the whitelisted rows pipelined


def test_upsert_samples_no_valid_rows_runs_no_write() -> None:
    cur = FakeCursor()
    accepted, rejected = upsert_samples(
        cur,  # type: ignore[arg-type]
        SENTINEL_USER_ID,
        [SampleIn(metric="bogus", ts=1_718_000_000_000, value=1.0)],
    )
    assert (accepted, rejected) == (0, 1)
    assert cur.executemany_rows is None


def _session(start: datetime, end: datetime, kind: str = "main") -> SleepIn:
    return SleepIn(start_ts=_ms(start), end_ts=_ms(end), kind=kind)


def test_fresh_predicate_gates_old_existing_nights() -> None:
    now = datetime(2026, 6, 20, 6, 0, tzinfo=UTC)
    tonight = _session(now - timedelta(hours=8), now)  # latest night, new
    old = _session(now - timedelta(days=10, hours=8), now - timedelta(days=10))
    recent = _session(now - timedelta(days=2, hours=8), now - timedelta(days=2))
    # Both old and recent already exist in the DB; tonight is new.
    existing_rows = [(epoch_to_utc(old.start_ts),), (epoch_to_utc(recent.start_ts),)]
    cur = FakeCursor(fetchall=[existing_rows])
    is_fresh = build_fresh_predicate(
        cur,  # type: ignore[arg-type]
        SENTINEL_USER_ID,
        [old, recent, tonight],
    )

    assert is_fresh(tonight) is True  # new → always fresh
    assert is_fresh(recent) is True  # existing but within 3 days of latest
    assert is_fresh(old) is False  # existing AND >3 days before latest → skip


def test_fresh_predicate_all_new_when_table_empty() -> None:
    now = datetime(2026, 6, 20, 6, 0, tzinfo=UTC)
    a = _session(now - timedelta(days=5, hours=8), now - timedelta(days=5))
    b = _session(now - timedelta(hours=8), now)
    cur = FakeCursor(fetchall=[[]])  # nothing existing
    is_fresh = build_fresh_predicate(cur, SENTINEL_USER_ID, [a, b])  # type: ignore[arg-type]
    assert is_fresh(a) is True and is_fresh(b) is True


def test_fresh_predicate_gates_an_old_existing_nap_too() -> None:
    """Naps mark their day since audit B5, so they have to be gateable (audit B5).

    The existing-starts lookup covered MAIN sleep only, which was harmless while the emit
    was the only consumer — naps never reach it. With `_marks_its_day` as a second
    consumer, an unfiltered lookup would make every re-pushed nap permanently "new" and
    re-derive its day on every sync of history.
    """
    now = datetime(2026, 6, 20, 6, 0, tzinfo=UTC)
    tonight = _session(now - timedelta(hours=8), now)
    old_nap = _session(now - timedelta(days=10, hours=1), now - timedelta(days=10), kind="nap")
    cur = FakeCursor(fetchall=[[(epoch_to_utc(old_nap.start_ts),)]])
    is_fresh = build_fresh_predicate(cur, SENTINEL_USER_ID, [old_nap, tonight])  # type: ignore[arg-type]

    # The LOOKUP is what the fix changed, so the lookup is what is asserted. Asserting
    # only the predicate's answer passes against the bug: `FakeCursor` hands back its
    # canned rows whatever the query asked for, so a filtered `starts` list still gets
    # the nap back and still reads as stale. That is `HOW_WE_VERIFY.md`'s fourth way a
    # mutation lies — a right mutation over a thin test — and it survived once here.
    _, params = cur.executed[0]
    assert epoch_to_utc(old_nap.start_ts) in params[1], (
        "a nap that is already on file must be asked about, or it is permanently new"
    )
    assert is_fresh(old_nap) is False
    assert is_fresh(tonight) is True


def test_a_nap_only_page_is_fresh_because_it_carries_no_night_to_date_it_from() -> None:
    """The page audit B5 is actually about: a session-only page with a nap and no night.

    The window is "within three days of the batch's latest NIGHT", so a page with no night
    has no cutoff — every session on it is fresh, and its day gets derived. That is the
    right answer, and it stays right because the window still comes from main sleep alone.
    """
    now = datetime(2026, 6, 20, 14, 0, tzinfo=UTC)
    nap = _session(now - timedelta(minutes=40), now, kind="nap")
    cur = FakeCursor(fetchall=[[(epoch_to_utc(nap.start_ts),)]])  # already on file
    is_fresh = build_fresh_predicate(cur, SENTINEL_USER_ID, [nap])  # type: ignore[arg-type]

    assert is_fresh(nap) is True


# --- B4: a re-push that omits a duration must not zero the one on file -------


def _workout(**kwargs: Any) -> WorkoutIn:
    return WorkoutIn.model_validate({"start_ts": 1_718_000_000_000, **kwargs})


def test_an_omitted_duration_is_absent_at_the_boundary_not_zero() -> None:
    """`0` was the model default, so "did not say" and "measured zero" were one value."""
    assert _workout().duration_s is None
    assert _workout().sport is None
    assert _workout(duration_s=0).duration_s == 0


def test_a_re_push_that_omits_a_duration_preserves_the_recorded_one() -> None:
    """THE defect. A zeroed session drops out of three gates at once: `read/fitness.py`
    and `challenges/series.py` filter on `>= min_duration_s`, and `energy._tee_met` stops
    removing its minutes from the MET walk, so the day's calories move."""
    cur = FakeCursor()
    upsert_workouts(cur, SENTINEL_USER_ID, [_workout(calories=310)])  # type: ignore[arg-type]
    sql, params = cur.executed[0]
    assert "duration_s = COALESCE(%s::int, workout.duration_s)" in sql
    assert "sport = COALESCE(%s::int, workout.sport)" in sql
    assert params[-2:] == (None, None), "the conflict branch must see the raw absence"


def test_a_first_insert_still_supplies_the_columns_not_null_default() -> None:
    """The residual, pinned rather than assumed: `workout.duration_s` is NOT NULL
    DEFAULT 0, so a first insert of a duration-less workout stores 0. Making that
    absence representable is a migration on `workout` plus six read sites."""
    cur = FakeCursor()
    upsert_workouts(cur, SENTINEL_USER_ID, [_workout()])  # type: ignore[arg-type]
    sql, _ = cur.executed[0]
    assert "COALESCE(%s::int, 0), COALESCE(%s::int, 0)" in sql


# The newest weight_log row as `upsert_weight` reads it: (ts, kg, is_today).
def _weight_row(kg: float, *, today: bool) -> tuple:
    return (datetime(2026, 6, 20, 7, tzinfo=UTC), kg, today)


def test_weight_inserts_when_there_is_no_row_at_all() -> None:
    cur = FakeCursor(fetchone=[None])
    upsert_weight(cur, SENTINEL_USER_ID, SENTINEL_TZ, 72.5)  # type: ignore[arg-type]
    assert len(cur.executed) == 2  # SELECT + INSERT
    assert "INSERT INTO weight_log" in cur.executed[1][0]
    assert cur.executed[1][1] == (SENTINEL_USER_ID, 72.5)


def test_weight_skips_when_unchanged_today() -> None:
    cur = FakeCursor(fetchone=[_weight_row(72.5, today=True)])
    upsert_weight(cur, SENTINEL_USER_ID, SENTINEL_TZ, 72.505)  # type: ignore[arg-type]  # <0.01 kg → no write
    assert len(cur.executed) == 1  # only the SELECT ran


def test_weight_updates_when_changed_today() -> None:
    cur = FakeCursor(fetchone=[_weight_row(72.5, today=True)])
    upsert_weight(cur, SENTINEL_USER_ID, SENTINEL_TZ, 74.0)  # type: ignore[arg-type]
    assert len(cur.executed) == 2  # SELECT + UPDATE
    assert "UPDATE weight_log" in cur.executed[1][0]
    assert cur.executed[1][1] == (74.0, SENTINEL_USER_ID, datetime(2026, 6, 20, 7, tzinfo=UTC))


# --- #85: an unchanged re-push must not reset the weight's age ---------------


def test_an_unchanged_weight_from_an_earlier_day_writes_nothing() -> None:
    """THE laundering case, and the reason any weight-freshness gate can work at all.

    The app re-pushes its cached weight on every sync and `/api/profile` hands that
    same weight back for a reinstall to restore, so an unchanged value arrives forever.
    Dedupe only within the local day and each new day's first sync INSERTs it again at
    `now()` — which is what the 2026-07-15 prod dump actually contains: 41 rows over six
    weeks, all 79.9 kg but one, from an owner who weighed themselves about twice. The
    weight can then never look older than a day, so `freshness.weight_is_stale` could
    never fire and BMI → VO₂max → biological age would run on a mass from months ago.
    """
    cur = FakeCursor(fetchone=[_weight_row(79.9, today=False)])
    upsert_weight(cur, SENTINEL_USER_ID, SENTINEL_TZ, 79.9)  # type: ignore[arg-type]
    assert len(cur.executed) == 1  # SELECT only — no INSERT, so the age is preserved


def test_a_changed_weight_from_an_earlier_day_still_inserts_a_new_row() -> None:
    # The other half: a real new measurement is still a new row, dated now. Without
    # this the "skip" above would be indistinguishable from dropping weight logging.
    cur = FakeCursor(fetchone=[_weight_row(79.9, today=False)])
    upsert_weight(cur, SENTINEL_USER_ID, SENTINEL_TZ, 78.4)  # type: ignore[arg-type]
    assert len(cur.executed) == 2
    assert "INSERT INTO weight_log" in cur.executed[1][0]
    assert cur.executed[1][1] == (SENTINEL_USER_ID, 78.4)


# --- #121: the strap's daily totals are RAW data with a table of their own ----


def _total(**kwargs: Any) -> DailyTotalIn:
    return DailyTotalIn.model_validate({"day": "2026-06-16", **kwargs})


def test_daily_totals_are_written_to_the_raw_table_not_a_derived_cell() -> None:
    """The whole of #121 in one assertion: this layer no longer produces a metric.

    It used to INSERT INTO derived_daily — the table a derive pass rebuilds — which is
    why 142 days of the strap's own step count were destroyed and unrecoverable.
    """
    cur = FakeCursor()
    stored = upsert_daily_totals(
        cur,  # type: ignore[arg-type]
        SENTINEL_USER_ID,
        [_total(steps=9264, distance_m=5081.0, calories=451.0)],
    )
    assert stored == 1
    # One per-batch read (the regression check below), never one execute per row: the
    # batch itself is pipelined.
    assert [sql for sql, _ in cur.executed] == [
        "SELECT day, steps FROM device_daily_total "
        "WHERE user_id = %s AND day = ANY(%s) AND steps IS NOT NULL"
    ]
    assert cur.executemany_rows == [
        (SENTINEL_USER_ID, date(2026, 6, 16), 9264, 5081.0, 451.0, None)
    ]


def test_a_report_with_no_numbers_at_all_is_not_stored() -> None:
    """An empty entry is not a measurement — storing it would claim the strap reported."""
    cur = FakeCursor()
    assert upsert_daily_totals(cur, SENTINEL_USER_ID, [_total()]) == 0  # type: ignore[arg-type]
    assert cur.executemany_rows is None


def test_a_report_carrying_only_distance_is_still_stored() -> None:
    """Each field stands alone: the derivation reads steps and distance independently,
    so a partial report is kept rather than dropped for lacking a step count — which is
    what the old `apply_daily_totals` did, skipping the whole entry."""
    cur = FakeCursor()
    assert upsert_daily_totals(cur, SENTINEL_USER_ID, [_total(distance_m=5081.0)]) == 1  # type: ignore[arg-type]
    assert cur.executemany_rows == [(SENTINEL_USER_ID, date(2026, 6, 16), None, 5081.0, None, None)]


# --- A1: the READ instant travels, and absent means unknown -------------------


def test_the_read_instant_reaches_the_column_as_the_phone_recorded_it() -> None:
    """`readAtMs` is when the strap was ASKED. It had no field and no column until 0019."""
    read_at = datetime(2026, 6, 16, 9, 0, tzinfo=UTC)
    cur = FakeCursor()
    upsert_daily_totals(cur, SENTINEL_USER_ID, [_total(steps=9264, read_at=_ms(read_at))])  # type: ignore[arg-type]
    assert cur.executemany_rows is not None
    assert cur.executemany_rows[0][5] == read_at


def test_a_client_that_sends_no_read_instant_stores_unknown_never_now() -> None:
    """The A1 failure to avoid: recreating the same lie with a new mechanism.

    An older app build sends no `read_at`. The column must then say nothing, because a
    substituted instant is indistinguishable from a recorded one — which is exactly what
    `reported_at` standing in for the reading was.
    """
    cur = FakeCursor()
    upsert_daily_totals(cur, SENTINEL_USER_ID, [_total(steps=9264)])  # type: ignore[arg-type]
    assert cur.executemany_rows is not None
    assert cur.executemany_rows[0][5] is None
    sql = cur.executemany_sql or ""
    assert "read_at = EXCLUDED.read_at" in sql
    assert "COALESCE(EXCLUDED.read_at" not in sql


def test_a_regressing_counter_is_logged_rather_than_swallowed(
    caplog: pytest.LogCaptureFixture,
) -> None:
    """Audit B6 stays SUSPECTED, and stops being invisible.

    The stored value is NOT guarded — the reason is in `upsert_daily_totals`' docstring —
    but a lower reading replacing a higher one now names both numbers in a warning, so the
    next occurrence is evidence instead of speculation.
    """
    cur = FakeCursor(fetchall=[[(date(2026, 6, 16), 9264)]])
    with caplog.at_level(logging.WARNING):
        upsert_daily_totals(cur, SENTINEL_USER_ID, [_total(steps=112)])  # type: ignore[arg-type]
    assert "device_daily_total counter regressed" in caplog.text
    # And the lower reading is still what lands: this is the RAW table.
    assert cur.executemany_rows is not None
    assert cur.executemany_rows[0][2] == 112


def test_a_rising_counter_says_nothing(caplog: pytest.LogCaptureFixture) -> None:
    """A since-midnight accumulator climbing all day is the normal case, not an event."""
    cur = FakeCursor(fetchall=[[(date(2026, 6, 16), 4200)]])
    with caplog.at_level(logging.WARNING):
        upsert_daily_totals(cur, SENTINEL_USER_ID, [_total(steps=9264)])  # type: ignore[arg-type]
    assert "regressed" not in caplog.text
