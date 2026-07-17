"""The calorie walk integrates a LOCAL day, including the two that aren't 24 h long.

``_day_bounds_utc`` is correct — ZoneInfo re-resolves the offset at each end, so a
DST-transition day legitimately brackets 23 h or 25 h. ``energy._tee_met`` then walked
a fixed ``range(1440)`` from the day's first instant, which on those two days is not
the length of the day:

    America/New_York 2026-03-08 (spring forward, 23 h): real minutes 1380
        -> a 1440-minute walk runs 60 min INTO the next local day (over-counts)
    America/New_York 2026-11-01 (fall back, 25 h):      real minutes 1500
        -> a 1440-minute walk MISSES the last local hour (under-counts)

Harmless while every owner was in Asia/Kolkata (no DST); 6.4 made per-user timezones
live, so this mis-integrated a real user's calories twice a year.

The NON-DST day is the regression guard and matters as much as the fixes: any change
to a normal day's calories would be a regression, not a fix. ``test_normal_day_*``
pins the count at exactly 1440 and ``test_non_dst_day_calories_are_byte_identical``
pins the resulting kcal against the pre-fix hardcoded-1440 walk.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.derive._common import _day_bounds_utc, _day_minutes
from healthee.derive.energy import _tee_met

_NY = "America/New_York"
_IST = "Asia/Kolkata"

# ── the minute count itself (pure, no DB) ────────────────────────────────────
#
# Hand-derived from the bounds contract, NOT recorded from the code. `_day_bounds_utc`
# returns [00:00:00 local, 23:59:59 local], so the span is (24h - 1s) scaled by the
# day's real length, and the count is inclusive of both endpoint minutes:
#
#   normal 24 h day:  span = 86399 s -> 86399 // 60 = 1439, +1 = 1440
#   spring forward:   the local day is 23 h, span = 86399 - 3600 = 82799 s
#                     -> 82799 // 60 = 1379, +1 = 1380
#   fall back:        the local day is 25 h, span = 86399 + 3600 = 89999 s
#                     -> 89999 // 60 = 1499, +1 = 1500


@pytest.mark.parametrize(
    ("tz", "day", "expected"),
    [
        (_NY, date(2026, 3, 8), 1380),  # spring forward: 23 h
        (_NY, date(2026, 11, 1), 1500),  # fall back: 25 h
        (_NY, date(2026, 6, 15), 1440),  # normal EDT day — REGRESSION GUARD
        (_NY, date(2026, 1, 15), 1440),  # normal EST day — REGRESSION GUARD
        (_IST, date(2026, 3, 8), 1440),  # India never transitions — REGRESSION GUARD
        (_IST, date(2026, 11, 1), 1440),  # REGRESSION GUARD
        ("UTC", date(2026, 3, 8), 1440),  # REGRESSION GUARD
    ],
)
def test_day_minutes_follows_the_real_local_day(tz: str, day: date, expected: int) -> None:
    assert _day_minutes(*_day_bounds_utc(day, tz)) == expected


# ── the gap this suite does NOT yet close: a MIDNIGHT fall-back ──────────────
#
# Every zone above transitions at 02:00/03:00, so a day's own 23:59:59 is never an
# ambiguous wall-clock time. In a zone that falls back AT MIDNIGHT it is: the 23:00
# hour of the PRECEDING day runs twice, and `_day_bounds_utc` builds its end as
# `start.replace(hour=23, minute=59, second=59)`, which PEP 495 resolves with fold=0
# — the FIRST pass. The second pass is then outside the bracket, so the 25 h day
# measures 1440 minutes and the walk drops its final hour.
#
# Verified against `zoneinfo` for these exact dates (never assumed — offsets are data):
#   America/Santiago 2026-04-04  03:00Z -> 2026-04-05 04:00Z  = 25 h, reported 1440
#   Asia/Beirut      2026-10-24  21:00Z -> 2026-10-24 22:00Z  = 25 h, reported 1440
# `read/today_series._local_day_utc_range` already derives the edge the correct way
# (the NEXT local midnight, half-open) and gets 25 h for both.
_MIDNIGHT_FALLBACK_DAYS = [
    ("America/Santiago", date(2026, 4, 4), 1500),
    ("Asia/Beirut", date(2026, 10, 24), 1500),
]


@pytest.mark.parametrize(("tz", "day", "expected"), _MIDNIGHT_FALLBACK_DAYS)
@pytest.mark.xfail(
    strict=True,
    reason="KNOWN: _day_bounds_utc resolves an ambiguous 23:59:59 with fold=0, so a "
    "midnight fall-back day measures 1440 instead of 1500 and activity/mvpa/"
    "cardio_load/energy each drop its last hour. Fixing it moves real science "
    "output, so it is its own PR with known-value tests (CLAUDE.md).",
)
def test_midnight_fall_back_day_is_25h(tz: str, day: date, expected: int) -> None:
    """A zone that falls back at midnight still owns 25 h — we currently see 24."""
    assert _day_minutes(*_day_bounds_utc(day, tz)) == expected


@pytest.mark.parametrize(("tz", "day"), [(t, d) for t, d, _ in _MIDNIGHT_FALLBACK_DAYS])
def test_the_midnight_fall_back_days_really_are_25h(tz: str, day: date) -> None:
    """The premise of the xfail above, proven from `zoneinfo` rather than asserted.

    If a tz-database update moves these transitions, THIS fails — loudly — instead
    of the xfail silently becoming a test of nothing.
    """
    zone = ZoneInfo(tz)
    start = datetime(day.year, day.month, day.day, tzinfo=zone).astimezone(UTC)
    nxt = day + timedelta(days=1)
    end = datetime(nxt.year, nxt.month, nxt.day, tzinfo=zone).astimezone(UTC)
    assert (end - start) == timedelta(hours=25), f"{tz} {day} is no longer a 25 h day"


def test_spring_forward_at_midnight_starts_at_the_days_first_real_instant() -> None:
    """The mirror case, which IS already correct — a local midnight that never happens.

    America/Santiago 2026-09-06 jumps 00:00 -> 01:00, so that date has no midnight.
    `ZoneInfo` resolves the non-existent time with the pre-transition offset, which
    lands exactly on 01:00 — the first instant the day actually has — and the day
    measures 23 h. Pinned because "ZoneInfo silently picks one" is only benign here
    by luck of which one, and a regression would shift a day's whole window.
    """
    tz, day = "America/Santiago", date(2026, 9, 6)
    start_utc, end_utc = _day_bounds_utc(day, tz)
    first = start_utc.astimezone(ZoneInfo(tz))
    assert (first.hour, first.date()) == (1, day), f"day starts at {first}, not 01:00"
    assert _day_minutes(start_utc, end_utc) == 1380
    assert end_utc.astimezone(ZoneInfo(tz)).date() == day


def test_normal_day_minute_count_is_exactly_the_old_constant() -> None:
    """Every non-DST day still yields 1440 — the semantic the old `range(1440)` had.

    Swept across a full year in a no-DST zone: if the new derivation disagreed with
    1440 on even one ordinary day, the fix would be a regression.
    """
    for k in range(365):
        day = date(2026, 1, 1) + timedelta(days=k)
        assert _day_minutes(*_day_bounds_utc(day, _IST)) == 1440


def test_the_walk_covers_midnight_to_2359_and_stops() -> None:
    """The inclusive [00:00, 23:59] semantic, asserted on the walk's own endpoints.

    The loop steps UTC minutes from the day's first instant; minute 0 must be local
    00:00 and the LAST minute must be local 23:59 — never 00:00 of the next day.
    """
    for tz, day in ((_NY, date(2026, 3, 8)), (_NY, date(2026, 11, 1)), (_IST, date(2026, 6, 1))):
        start_utc, end_utc = _day_bounds_utc(day, tz)
        n = _day_minutes(start_utc, end_utc)
        local = ZoneInfo(tz)
        first = start_utc.astimezone(local)
        last = (start_utc + timedelta(minutes=n - 1)).astimezone(local)
        one_past = (start_utc + timedelta(minutes=n)).astimezone(local)
        assert (first.hour, first.minute) == (0, 0)
        assert (last.hour, last.minute, last.date()) == (23, 59, day)
        assert one_past.date() == day + timedelta(days=1)  # the next minute has left


# ── the calorie total (seeded DB) ────────────────────────────────────────────

_BMR = 1700.0  # kcal/day; 1 MET == BMR/1440 per minute
_STRIDE_M = 0.7
_STEPS_PER_MIN = 100.0

# Hand-derived METs for the seeded fixture (energy.py + [[energy_expenditure_derivation]]):
#   a stepping minute: 100 steps x 0.7 m = 70 m/min. 70 < 134 (the ACSM walk/run switch),
#     so VO2 = 0.1 x 70 + 3.5 = 10.5 ml/kg/min -> 10.5 / 3.5 = 3.0 MET.
#   a minute within +/-7 min of a stepping minute (NEAT_WINDOW): AWAKE_ACTIVE_MET = 1.55.
#   any other awake, unstepped minute: AWAKE_SEDENTARY_MET = 1.3.
# No sleep_session and no workout are seeded, so nothing is asleep or excluded.
_STEP_MET = 3.0
_ACTIVE_MET = 1.55
_SEDENTARY_MET = 1.3

# One isolated stepping minute lifts a day by, in MET-minutes:
#   the minute itself:            3.0 - 1.3          = 1.7
#   its 14 halo minutes (+/-7):  14 x (1.55 - 1.3)   = 3.5
#                                               total  5.2 MET-minutes
# Written as the arithmetic so a reviewer can check each term; the METs above are
# re-typed from the note/model here, never imported from `energy`, so this stays an
# independent expectation rather than a restatement of the implementation.
_HALO_MINUTES = 14  # +/-NEAT_WINDOW(7) around the stepping minute, excluding itself
_ONE_STEP_MINUTE_MET_GAIN = (_STEP_MET - _SEDENTARY_MET) + _HALO_MINUTES * (
    _ACTIVE_MET - _SEDENTARY_MET
)  # = 1.7 + 3.5 = 5.2


def _kcal(met_minutes: float) -> float:
    """MET-minutes -> kcal at this fixture's BMR anchor (1 MET == BMR/1440 per min)."""
    return met_minutes * _BMR / 1440.0


def _seed_steps(cur, minutes: list[datetime]) -> None:
    """One `steps_per_minute` sample at each given UTC minute; nothing else exists."""
    for table in ("sample", "sleep_session", "workout", "derived_daily"):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names
    for m in minutes:
        cur.execute(
            "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, %s, %s)",
            (SENTINEL_USER_ID, m, "steps_per_minute", _STEPS_PER_MIN),
        )


def _local_minute(day: date, tz: str, hour: int, minute: int) -> datetime:
    return datetime(day.year, day.month, day.day, hour, minute, tzinfo=ZoneInfo(tz)).astimezone(UTC)


def _tee_fixed(cur, day: date, tz: str) -> float:
    """The day's TEE as the FIXED code integrates it — length from the real bounds."""
    return _tee_met(cur, SENTINEL_USER_ID, *_day_bounds_utc(day, tz), _BMR, _STRIDE_M)


def _tee_hardcoded_1440(cur, day: date, tz: str) -> float:
    """The day's TEE as the BUGGY code integrated it — always 1440 minutes.

    Reproduced by handing `_tee_met` an end bound exactly 1439 minutes after the start:
    `_day_minutes` then returns 1439 + 1 = 1440, so the walk (and the sample window it
    queries) is precisely the old fixed-length one.
    """
    start_utc, _ = _day_bounds_utc(day, tz)
    return _tee_met(
        cur, SENTINEL_USER_ID, start_utc, start_utc + timedelta(minutes=1439), _BMR, _STRIDE_M
    )


@pytest.mark.usefixtures("db")
def test_fall_back_day_counts_its_last_local_hour() -> None:
    """25 h day: steps at 23:30 local are INSIDE the day and must be counted.

    The old walk stopped at UTC-minute 1439 = 22:59 local here, so a real evening walk
    vanished from the total entirely.
    """
    day = date(2026, 11, 1)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        at_2330 = _local_minute(day, _NY, 23, 30)
        _seed_steps(cur, [at_2330])
        fixed_with = _tee_fixed(cur, day, _NY)
        buggy_with = _tee_hardcoded_1440(cur, day, _NY)
        _seed_steps(cur, [])
        fixed_empty = _tee_fixed(cur, day, _NY)
        buggy_empty = _tee_hardcoded_1440(cur, day, _NY)

    # THE BUG: the old walk cannot see the 23:30 steps at all — stepping or not, it
    # returns the same number.
    assert buggy_with == buggy_empty
    # THE FIX: the stepping minute lands, worth exactly its hand-derived 5.2 MET-min.
    assert fixed_with - fixed_empty == pytest.approx(_kcal(_ONE_STEP_MINUTE_MET_GAIN), abs=1e-9)
    # A quiet 25 h day is 1500 sedentary minutes — the old walk under-counted by 60.
    assert fixed_empty == pytest.approx(_kcal(1500 * _SEDENTARY_MET), abs=1e-9)
    assert buggy_empty == pytest.approx(_kcal(1440 * _SEDENTARY_MET), abs=1e-9)


@pytest.mark.usefixtures("db")
def test_spring_forward_day_stops_at_its_own_midnight() -> None:
    """23 h day: steps at 00:30 local on the NEXT day must NOT be billed to this one.

    The old walk ran to UTC-minute 1439 = 00:59 of March 9 local, so the next
    morning's first hour was counted twice — once here, once on its own day.
    """
    day = date(2026, 3, 8)
    next_morning = _local_minute(day + timedelta(days=1), _NY, 0, 30)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed_steps(cur, [next_morning])
        fixed_with = _tee_fixed(cur, day, _NY)
        buggy_with = _tee_hardcoded_1440(cur, day, _NY)
        _seed_steps(cur, [])
        fixed_empty = _tee_fixed(cur, day, _NY)

    # THE BUG: March 9's steps moved March 8's total.
    assert buggy_with > _kcal(1380 * _SEDENTARY_MET)
    # THE FIX: March 8 is untouched by March 9's steps — identical to a stepless day.
    assert fixed_with == pytest.approx(fixed_empty, abs=1e-9)
    # A quiet 23 h day is 1380 sedentary minutes.
    assert fixed_with == pytest.approx(_kcal(1380 * _SEDENTARY_MET), abs=1e-9)


@pytest.mark.usefixtures("db")
@pytest.mark.parametrize("tz", [_IST, _NY])  # a no-DST zone AND a DST zone, off-transition
def test_non_dst_day_calories_are_byte_identical(tz: str) -> None:
    """THE REGRESSION GUARD: an ordinary day's total is EXACTLY what 1440 produced.

    Same seeded data, same day, new walk vs the old hardcoded-1440 walk — equal to the
    last float bit (`==`, not approx). Any movement in a normal day's calories would
    be a regression, not a fix.
    """
    day = date(2026, 6, 15)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed_steps(cur, [_local_minute(day, tz, h, m) for h in (7, 8, 12, 19, 23) for m in (0, 5)])
        new = _tee_fixed(cur, day, tz)
        old = _tee_hardcoded_1440(cur, day, tz)
    assert _day_minutes(*_day_bounds_utc(day, tz)) == 1440
    assert new == old
