"""Unit tests for the upsert layer that need no database — a fake cursor records
what SQL would run. Covers the unknown-metric coerce-drop, the _fresh() gating
predicate, and the one-per-day weight de-dup.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.ingest.models import SampleIn, SleepIn
from healthee.ingest.upsert import (
    build_fresh_predicate,
    epoch_to_utc,
    upsert_samples,
    upsert_weight,
)


class FakeCursor:
    """Minimal cursor stub: records executes and hands back canned fetch rows."""

    def __init__(
        self, fetchone: list[Any] | None = None, fetchall: list[Any] | None = None
    ) -> None:
        self.executed: list[tuple[str, Any]] = []
        self.executemany_rows: list[Any] | None = None
        self._fetchone = list(fetchone or [])
        self._fetchall = list(fetchall or [])

    def execute(self, sql: str, params: Any = None) -> None:
        self.executed.append((sql, params))

    def executemany(self, sql: str, rows: Any) -> None:  # noqa: ARG002
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
