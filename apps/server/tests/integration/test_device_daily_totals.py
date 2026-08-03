"""The strap's daily counter, from the push to the derived cell and back again (#121).

## What this file exists to prevent

The strap reports its own since-midnight step count on BLE 0x0016. It used to be written
straight into `derived_daily.steps_total` AFTER the derive pass, and stored nowhere else
— so the next derive over that day recomputed the cell from the per-minute
`steps_per_minute` sum and the device's count was gone, with nothing to restore it from.
Measured on production 2026-08-02: of 143 `steps_total` rows, **142 carried the per-minute
sum and exactly one carried `strap_0x16`**, and the documented repair procedure
(`db/rederive`) was itself one of the things destroying them.

`test_a_rederive_with_no_new_push_still_lands_the_strap_counter` is the regression net
for exactly that, and it is the assertion the rest of the design exists to make possible:
the counter is raw data now, and `steps_total` is a derivation over it.

⛔ The 142 days are not recovered by any of this. `device_daily_total` starts empty and
nothing backfills it — those numbers only ever existed in the cell that was overwritten.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Any, LiteralString
from uuid import UUID
from zoneinfo import ZoneInfo

import pytest

from healthee.core.db import admin_connection, tenant_connection, transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.db import migrate, rederive
from healthee.derive import derive_batch
from healthee.ingest import HelioPayload, ingest_helio

pytestmark = pytest.mark.integration

_TABLES = "sample, sleep_session, workout, derived_daily, weight_log, profile, device_daily_total"

_IST = ZoneInfo(SENTINEL_TZ)

# The strap's own count for the day, and the (deliberately much smaller) per-minute sum —
# the gap a stalled pager leaves. Every assertion here turns on the two being far apart.
_STRAP_STEPS = 9264
_STEPS_PER_MINUTE = 100.0
_MINUTES = 10
_PER_MINUTE_SUM = _STEPS_PER_MINUTE * _MINUTES  # 1000

_STRAP_DISTANCE_M = 5081.0
_STRAP_CALORIES = 451.0

_HEIGHT_CM = 175.0
_STRIDE_M = 0.414 * _HEIGHT_CM / 100.0  # [[distance_from_steps]]

# A second owner, to prove the counter is scoped like every other tenant row.
_OWNER_B = UUID("dddddddd-dddd-dddd-dddd-dddddddddddd")


def _reset() -> None:
    migrate.apply_migrations()
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(f"TRUNCATE {_TABLES}")


def _ms(dt: datetime) -> int:
    return int(dt.timestamp() * 1000)


def _local_day() -> date:
    """The owner's today. Relative, not fixed, so `rederive --days 1` covers it."""
    return user_today(SENTINEL_TZ)


def _payload(
    *, day: date, steps: int | None, distance_m: float | None = None, with_profile: bool = False
) -> HelioPayload:
    """A push with a per-minute step stream and, optionally, the strap's own total.

    The per-minute samples start at LOCAL MIDNIGHT of `day` — always in the past and
    always inside the day, under any runner timezone.
    """
    midnight = datetime(day.year, day.month, day.day, tzinfo=_IST)
    body: dict[str, Any] = {
        "samples": [
            {
                "metric": "steps_per_minute",
                "ts": _ms(midnight + timedelta(minutes=i + 1)),
                "value": _STEPS_PER_MINUTE,
            }
            for i in range(_MINUTES)
        ]
    }
    if steps is not None or distance_m is not None:
        body["daily_totals"] = [
            {
                "day": day.isoformat(),
                "steps": steps,
                "distance_m": distance_m,
                "calories": _STRAP_CALORIES,
            }
        ]
    if with_profile:
        body["profile"] = {
            "height_cm": _HEIGHT_CM,
            "sex": "male",
            "dob": "1990-06-15",
            "weight_kg": 70.0,
        }
    return HelioPayload.model_validate(body)


def _derived(day: date, metric: str, user_id: UUID = SENTINEL_USER_ID) -> tuple[float, dict]:
    """One `derived_daily` cell as (value, flags), read as the ADMIN — an observer
    independent of the RLS scoping the path under test relies on."""
    query: LiteralString = (
        "SELECT value, flags FROM derived_daily WHERE user_id = %s AND day = %s AND metric = %s"
    )
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(query, (user_id, day, metric))
        row = cur.fetchone()
    assert row is not None, f"{metric} was never derived for {day}"
    return float(row[0]), row[1] or {}


# ── the precedence, through the real derive chain ─────────────────────────────


def test_a_push_derives_steps_from_the_strap_counter(db: None) -> None:  # noqa: ARG001
    """The device's own count is what the day carries, and it says so on the row."""
    _reset()
    day = _local_day()
    ingest_helio(_payload(day=day, steps=_STRAP_STEPS), SENTINEL_USER_ID, SENTINEL_TZ)

    value, flags = _derived(day, "steps_total")
    assert value == float(_STRAP_STEPS)
    assert flags["source"] == "strap_0x16"
    # The instrument that lost is still readable — a quiet day and a stalled stream are
    # different things and must stay distinguishable.
    assert flags["steps_per_minute_sum"] == _PER_MINUTE_SUM


def test_a_day_with_no_strap_report_carries_the_per_minute_sum(db: None) -> None:  # noqa: ARG001
    """The fallback tier, labelled as itself rather than passed off as the counter."""
    _reset()
    day = _local_day()
    ingest_helio(_payload(day=day, steps=None), SENTINEL_USER_ID, SENTINEL_TZ)

    value, flags = _derived(day, "steps_total")
    assert value == _PER_MINUTE_SUM
    assert flags["source"] == "steps_per_minute"


def test_a_rederive_with_no_new_push_still_lands_the_strap_counter(db: None) -> None:  # noqa: ARG001
    """⭐ THE regression net for #121 — the exact shape that cost 142 production days.

    Before the fix this sequence ended with `steps_total` = the per-minute sum, forever:
    the counter lived only in the cell `derive/activity.py` rebuilds, so re-deriving
    replaced an authoritative measurement with the one our own code calls "possibly
    frozen/incomplete". No backup held the original, because it had never been anywhere
    else. `rederive` — the *documented repair procedure* — was one of the things doing it.

    Now the counter is raw data the repair tool never touches, and the answer is
    reproduced rather than remembered, so the repair is idempotent by construction.
    """
    _reset()
    day = _local_day()
    ingest_helio(_payload(day=day, steps=_STRAP_STEPS), SENTINEL_USER_ID, SENTINEL_TZ)
    assert _derived(day, "steps_total")[0] == float(_STRAP_STEPS)

    # No new push. Exactly the command in DEPLOY.md §F, twice — a repair is not a
    # one-shot: it must survive being run again by an operator who is not sure it worked.
    assert rederive.main(["--user", str(SENTINEL_USER_ID), "--days", "1"]) == 0
    assert rederive.main(["--user", str(SENTINEL_USER_ID), "--days", "1"]) == 0

    value, flags = _derived(day, "steps_total")
    assert value == float(_STRAP_STEPS), "a re-derive destroyed the strap's counter"
    assert flags["source"] == "strap_0x16"


def test_a_later_derive_pass_picks_up_a_counter_that_arrived_after_it(db: None) -> None:  # noqa: ARG001
    """Order stopped being load-bearing: a late counter is picked up, not lost.

    The old shape had to run AFTER derive or the value was overwritten. This one wants to
    run before (so the same push shows it), but getting that wrong now costs one pass of
    latency instead of the measurement.
    """
    _reset()
    day = _local_day()
    ingest_helio(_payload(day=day, steps=None), SENTINEL_USER_ID, SENTINEL_TZ)
    assert _derived(day, "steps_total")[0] == _PER_MINUTE_SUM

    with tenant_connection(SENTINEL_USER_ID) as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO device_daily_total (user_id, day, steps) VALUES (%s, %s, %s)",
            (SENTINEL_USER_ID, day, _STRAP_STEPS),
        )
    with tenant_connection(SENTINEL_USER_ID) as conn:
        derive_batch(conn, SENTINEL_USER_ID, SENTINEL_TZ, [], [day])

    assert _derived(day, "steps_total")[0] == float(_STRAP_STEPS)


# ── distance follows the same precedence ──────────────────────────────────────


def test_the_device_distance_wins_and_survives_a_rederive(db: None) -> None:  # noqa: ARG001
    """`_apply_distance` had the identical defect and gets the identical fix."""
    _reset()
    day = _local_day()
    ingest_helio(
        _payload(day=day, steps=_STRAP_STEPS, distance_m=_STRAP_DISTANCE_M, with_profile=True),
        SENTINEL_USER_ID,
        SENTINEL_TZ,
    )
    assert rederive.main(["--user", str(SENTINEL_USER_ID), "--days", "1"]) == 0

    value, flags = _derived(day, "distance_m_daily")
    assert value == _STRAP_DISTANCE_M
    assert (flags["source"], flags["method"]) == ("strap_0x16", "device")


def test_distance_without_a_device_figure_is_the_stride_over_the_winning_steps(
    db: None,  # noqa: ARG001
) -> None:
    """Steps × stride, where "steps" is the count the day actually serves.

    Before #121 the ingest override recomputed this from the strap steps and a stride it
    read back out of the derived row's own flags; the next derive then recomputed it from
    the per-minute sum. The two numbers took turns.
    """
    _reset()
    day = _local_day()
    ingest_helio(
        _payload(day=day, steps=_STRAP_STEPS, with_profile=True), SENTINEL_USER_ID, SENTINEL_TZ
    )

    value, flags = _derived(day, "distance_m_daily")
    assert value == pytest.approx(_STRAP_STEPS * _STRIDE_M, abs=0.01)
    assert (flags["source"], flags["method"]) == ("strap_0x16", "stride")


def test_the_devices_calorie_number_is_stored_and_never_served(db: None) -> None:  # noqa: ARG001
    """The strap sends calories; the raw table keeps them; nothing derives from them.

    Free-living energy is the MET-by-state model (CLAUDE.md — never a device's own
    HR-based number), so `total_calories` must come out nothing like the 451 the strap
    reported. Stored-but-unused is deliberate, and this is what keeps it that way.
    """
    _reset()
    day = _local_day()
    ingest_helio(
        _payload(day=day, steps=_STRAP_STEPS, with_profile=True), SENTINEL_USER_ID, SENTINEL_TZ
    )

    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT calories FROM device_daily_total WHERE user_id = %s AND day = %s",
            (SENTINEL_USER_ID, day),
        )
        stored = cur.fetchone()
    assert stored is not None and float(stored[0]) == _STRAP_CALORIES
    assert _derived(day, "total_calories")[0] != _STRAP_CALORIES


# ── owner scoping ─────────────────────────────────────────────────────────────


def test_one_owners_counter_never_reaches_another_owners_day(db: None) -> None:  # noqa: ARG001
    """B's day is derived from B's own data — RLS backstop and explicit predicate both.

    Same day, same metric, and A's counter is absurd for B (who walked ten minutes), so
    a read that lost its owner filter returns a wrong number rather than an empty one.
    """
    _reset()
    day = _local_day()
    ingest_helio(_payload(day=day, steps=_STRAP_STEPS), SENTINEL_USER_ID, SENTINEL_TZ)
    with transaction() as cur:  # `app_user` is identity — no RLS policy (0008)
        cur.execute(
            "INSERT INTO app_user (id, email, timezone) VALUES (%s, %s, %s) "
            "ON CONFLICT (id) DO NOTHING",
            (_OWNER_B, "owner-d@example.test", SENTINEL_TZ),
        )
    with tenant_connection(_OWNER_B) as conn:
        derive_batch(conn, _OWNER_B, SENTINEL_TZ, [], [day])

    value, flags = _derived(day, "steps_total", _OWNER_B)
    assert value == 0.0, "another owner's strap counter reached this day"
    assert flags["source"] == "steps_per_minute"
    assert _derived(day, "steps_total")[0] == float(_STRAP_STEPS)  # A's is untouched
