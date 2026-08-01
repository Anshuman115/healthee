"""Seeding helpers for the illness-flag producer's integration tests.

The producer reads exactly two shapes, so these write exactly two: nightly
``respiratory_rate_sleep`` rows in ``derived_daily``, and a main ``sleep_session`` with
``skin_temp_c`` samples inside its window (skin temperature has no daily row —
[[skin_temp_signals]]).

Dates are FIXED, never "N days ago": a suite anchored to the wall clock cannot fail the
way a timezone bug actually fails, because the expected value drifts with the bug.

Not a pytest module (underscore-prefixed); imported by the test modules.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from healthee.core.db import admin_connection, transaction
from healthee.core.tenancy import SENTINEL_USER_ID

OWNER = SENTINEL_USER_ID
OTHER_OWNER = UUID("77777777-1111-4000-8000-000000000077")

TZ = "Asia/Kolkata"

# The night under test, and 15 nights of history behind it.
NIGHT = date(2026, 5, 20)

# A healthy person's steady nights: RR alternates 13/14 (median 13.5, MAD 0.5) and skin
# temperature 33.0/33.5 (median 33.25, MAD 0.25) — the same fixture the pure rule tests
# hand-compute against, so a DB-level expectation can be read off those.
HEALTHY_RR = (13.0, 14.0)
HEALTHY_TEMP = (33.0, 33.5)

# An illness night: +2.5 br/min and +0.75 °C over those medians. Both clear their
# trigger and their MAD multiple, so the tier turns only on `sustained`.
ILL_RR = 16.0
ILL_TEMP = 34.0

_TABLES = ("derived_daily", "sample", "sleep_session", "illness_flag", "kv")


def reset() -> None:
    """Empty every table these tests touch, across ALL owners.

    ADMIN, because ``TRUNCATE`` is not granted to the app role and a reset must clear
    rows an RLS-scoped connection cannot even see (6.5b-2).
    """
    with admin_connection() as conn, conn.cursor() as cur:
        for table in _TABLES:
            cur.execute(f"TRUNCATE {table}")  # noqa: S608 — module constant, never input


def ensure_owner_b() -> None:
    """Create the second tenant, so isolation can be PROVED rather than assumed."""
    with transaction() as cur:
        cur.execute(
            "INSERT INTO app_user (id, email, timezone) VALUES (%s, %s, %s) "
            "ON CONFLICT (id) DO NOTHING",
            (OTHER_OWNER, "illness-owner-b@example.test", TZ),
        )


def steady_history(
    cur, user_id: UUID, last_night: date = NIGHT, *, nights: int = 16, temp: bool = True
) -> None:
    """``nights`` consecutive ordinary nights ending at ``last_night`` (inclusive).

    Sixteen by default: fourteen for the baseline, one more so the SUSTAINED check can
    re-derive night N-1 against its own window, and the night under test itself.
    """
    for index in range(nights):
        night = last_night - timedelta(days=index)
        write_night(
            cur,
            user_id,
            night,
            rr=HEALTHY_RR[index % 2],
            temp_c=HEALTHY_TEMP[index % 2] if temp else None,
        )


def write_night(cur, user_id: UUID, night: date, *, rr: float | None, temp_c: float | None) -> None:
    """One night's two inputs, keyed to the wake date ``night``."""
    if rr is not None:
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value) VALUES (%s, %s, %s, %s) "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
            (user_id, night, "respiratory_rate_sleep", rr),
        )
    if temp_c is not None:
        start, end = _night_window(night)
        cur.execute(
            "INSERT INTO sleep_session (user_id, start_ts, end_ts, kind) "
            "VALUES (%s, %s, %s, 'main') ON CONFLICT (user_id, start_ts) DO NOTHING",
            (user_id, start, end),
        )
        cur.execute(
            "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, %s, %s) "
            "ON CONFLICT (user_id, metric, ts) DO UPDATE SET value = EXCLUDED.value",
            (user_id, start + timedelta(hours=2), "skin_temp_c", temp_c),
        )


def _night_window(night: date) -> tuple[datetime, datetime]:
    """Main sleep for wake-date ``night``: the previous local evening 23:00 → 07:00.

    The END is what stamps the wake date, matching ``derive._wake_date`` — the two limbs
    must land on the same night or the flag would compare a Tuesday's temperature with a
    Monday's breathing.
    """
    zone = ZoneInfo(TZ)
    before = night - timedelta(days=1)
    start = datetime(before.year, before.month, before.day, 23, 0, tzinfo=zone)
    end = datetime(night.year, night.month, night.day, 7, 0, tzinfo=zone)
    return start, end


def stored_flag(cur, user_id: UUID, night: date) -> tuple | None:
    """The raw stored row for one owner-night, or ``None``."""
    cur.execute(
        "SELECT severity, rr_delta_bpm, temp_delta_c, sustained, research_note_ids "
        "FROM illness_flag WHERE user_id = %s AND date = %s",
        (user_id, night),
    )
    return cur.fetchone()
