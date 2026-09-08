"""What a push plans to derive: its fresh nights, and the days it touched (#107).

Unit-level, no database — `_derive_plan` takes the freshness predicate as an argument
precisely so the rule can be exercised without one. The DB-backed half (that the real
predicate gates a re-pushed history) lives in
`tests/integration/test_ingest_derive_chain.py`.
"""

from __future__ import annotations

from datetime import UTC, date, datetime

from healthee.ingest.models import HelioPayload, SleepIn
from healthee.ingest.service import _derive_plan

_TZ = "Asia/Kolkata"


def _ms(dt: datetime) -> int:
    return int(dt.timestamp() * 1000)


def _night(day: int, *, kind: str = "main") -> dict:
    """A session running 22:00 UTC on `day` to 05:00 UTC the next morning."""
    return {
        "start_ts": _ms(datetime(2026, 6, day, 22, 0, tzinfo=UTC)),
        "end_ts": _ms(datetime(2026, 6, day + 1, 5, 0, tzinfo=UTC)),
        "kind": kind,
    }


def _payload(**fields: object) -> HelioPayload:
    return HelioPayload.model_validate(fields)


def _always_fresh(_session: SleepIn) -> bool:
    return True


def _never_fresh(_session: SleepIn) -> bool:
    return False


def test_a_fresh_night_is_planned_as_a_night_and_as_its_days() -> None:
    """The seam the bug lived in: the night's DAYS were collected, the night was not."""
    plan = _derive_plan(_payload(sleep=[_night(19)]), _TZ, _always_fresh)

    assert plan.nights == [
        (datetime(2026, 6, 19, 22, tzinfo=UTC), datetime(2026, 6, 20, 5, tzinfo=UTC))
    ]
    # 22:00 and 05:00 UTC are both 2026-06-20 in Asia/Kolkata (+05:30).
    assert plan.days == [date(2026, 6, 20)]


def test_a_stale_night_is_planned_as_neither() -> None:
    """Fresh-gating is what keeps a re-push of ~80 historical nights cheap.

    Asserted on BOTH lists: gating the night but not its days would put the expensive
    half back, and gating the days but not the night would derive a night whose day
    never gets recomputed.
    """
    plan = _derive_plan(_payload(sleep=[_night(19)]), _TZ, _never_fresh)

    assert plan.nights == []
    assert plan.days == []


def test_a_nap_is_never_a_night_but_it_does_mark_its_day() -> None:
    """`derive_night` writes overnight vitals keyed to a wake date — a nap is not one.

    The DAY is a different question, and the two used to share one predicate (audit B5).
    `energy._tee_met` and `cardio_load` both select sleep sessions with no `kind` filter,
    so every nap minute is scored at `SLEEP_MET = 0.95` rather than NEAT and is excluded
    from the day's TRIMP. A push carrying a nap and nothing else for that day planned NO
    work, and both numbers stayed computed as though the owner had been awake through it.
    """
    plan = _derive_plan(_payload(sleep=[_night(19, kind="nap")]), _TZ, _always_fresh)

    assert plan.nights == []
    # 22:00 and 05:00 UTC are both 2026-06-20 in Asia/Kolkata (+05:30).
    assert plan.days == [date(2026, 6, 20)]


def test_a_stale_nap_is_planned_as_nothing() -> None:
    """Naps mark their day, but freshness still gates them.

    Without this, a re-push of months of history would re-derive a day per stored nap on
    every sync — the cost `build_fresh_predicate` exists to avoid, arriving through the
    door B5 opened.
    """
    plan = _derive_plan(_payload(sleep=[_night(19, kind="nap")]), _TZ, _never_fresh)

    assert plan.nights == []
    assert plan.days == []


def test_nights_are_planned_oldest_first() -> None:
    """Order within the pass, so a night's own 7-day windows see the earlier nights."""
    plan = _derive_plan(_payload(sleep=[_night(21), _night(19), _night(20)]), _TZ, _always_fresh)

    assert [start for start, _ in plan.nights] == [
        datetime(2026, 6, 19, 22, tzinfo=UTC),
        datetime(2026, 6, 20, 22, tzinfo=UTC),
        datetime(2026, 6, 21, 22, tzinfo=UTC),
    ]


def test_days_come_from_samples_workouts_and_totals_too() -> None:
    """A push with no sleep at all still plans its days — and plans no nights."""
    noon = datetime(2026, 6, 20, 12, 0, tzinfo=UTC)
    plan = _derive_plan(
        _payload(
            samples=[
                {"metric": "hr", "ts": _ms(noon), "value": 61.0},
                {"metric": "bogus", "ts": _ms(datetime(2026, 6, 25, 12, tzinfo=UTC)), "value": 1.0},
            ],
            workouts=[{"start_ts": _ms(datetime(2026, 6, 21, 8, tzinfo=UTC))}],
            daily_totals=[{"day": "2026-06-22", "steps": 100}],
        ),
        _TZ,
        _always_fresh,
    )

    assert plan.nights == []
    # The unknown metric is dropped by the upsert, so it must not mark a day affected.
    assert plan.days == [date(2026, 6, 20), date(2026, 6, 21), date(2026, 6, 22)]
