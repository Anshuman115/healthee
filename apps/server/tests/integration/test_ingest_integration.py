"""Integration tests for the ingest service against a real TimescaleDB (CI
service container; auto-skips locally when no DB is reachable).

Covers: a push lands raw + typed rows; a second identical push is idempotent; the
strap's daily totals get stored RAW and stored BEFORE derive (#121); and fresh-gating
does not re-emit an old night's per-minute rows.

The derive step is a stub (the real chain is `test_ingest_derive_chain.py` and
`test_device_daily_totals.py`) — one stub records what the raw table already held when
derive ran, which is the ordering assertion this file can make without a derive layer.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import Any, LiteralString
from uuid import UUID

import pytest
from psycopg import Connection

from healthee.core.db import admin_connection
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.ingest import HelioPayload, ingest_helio
from healthee.ingest.service import DerivePlan

pytestmark = pytest.mark.integration

_TABLES = "sample, sleep_session, workout, derived_daily, weight_log, profile, device_daily_total"


def _reset() -> None:
    migrate.apply_migrations()
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(f"TRUNCATE {_TABLES}")


def _noop_derive(conn: Connection, user_id: UUID, tz: str, plan: DerivePlan) -> None:  # noqa: ARG001
    """Derive stub: does nothing (WP2 owns real derivation)."""


def _reads_the_raw_totals_derive(  # noqa: ARG001 — stub mirrors the DeriveTrigger shape
    conn: Connection, user_id: UUID, tz: str, plan: DerivePlan
) -> None:
    """Derive stub that records what `device_daily_total` held when derive ran.

    The ordering assertion, in the only form that still means anything after #121: the
    strap's counter must already be stored when the derive pass looks, because the pass
    is what turns it into `steps_total`. The old stub wrote a wrong `steps_total` and the
    test asserted the ingest layer overwrote it afterwards — which is precisely the shape
    that lost 142 days of counters, so it is not a behaviour to keep a net under.
    """
    with conn.cursor() as cur:
        for day in plan.days:
            cur.execute(
                "SELECT steps FROM device_daily_total WHERE user_id = %s AND day = %s",
                (user_id, day),
            )
            row = cur.fetchone()
            _SEEN_BY_DERIVE[day] = None if row is None else int(row[0])


# What `_reads_the_raw_totals_derive` saw, per day. Module-level because the trigger's
# signature is fixed by `DeriveTrigger` and has nowhere to return through.
_SEEN_BY_DERIVE: dict[Any, int | None] = {}


def _count(sql: LiteralString, params: tuple[Any, ...] = ()) -> int:
    """Count rows as the ADMIN — i.e. what the database ACTUALLY holds, across owners.

    Deliberately not RLS-scoped (6.5b-2). `test_push_attributes_every_row_to_the_passed
    _owner` asserts `total == owned`; scoped to the sentinel those two counts would be
    the same number by construction and the test would pass against a push that
    attributed every row to a stranger. The app path under test (`ingest_helio`) is the
    thing that must be RLS-scoped, and it is — this is the independent observer.
    """
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        row = cur.fetchone()
    return int(row[0]) if row else 0


def _ms(dt: datetime) -> int:
    return int(dt.timestamp() * 1000)


def _basic_payload() -> HelioPayload:
    now = datetime(2026, 6, 20, 12, 0, tzinfo=UTC)
    return HelioPayload.model_validate(
        {
            "samples": [
                {"metric": "hr", "ts": _ms(now), "value": 61.0},
                {"metric": "hrv", "ts": _ms(now + timedelta(minutes=1)), "value": 44.0},
                {"metric": "bogus", "ts": _ms(now), "value": 9.0},  # dropped
            ],
            "workouts": [
                {
                    "metric": "x",
                    "start_ts": _ms(now - timedelta(hours=2)),
                    "sport": 1,
                    "duration_s": 1800,
                    "calories": 250,
                    "avg_hr": 130,
                },
            ],
            "sleep": [
                {
                    "start_ts": _ms(now - timedelta(hours=8)),
                    "end_ts": _ms(now - timedelta(hours=1)),
                    "kind": "main",
                    "score": 88,
                    "stages": [
                        [
                            _ms(now - timedelta(hours=8)),
                            _ms(now - timedelta(hours=8) + timedelta(minutes=5)),
                            2,
                        ]
                    ],
                }
            ],
        }
    )


def test_push_lands_raw_and_typed_rows(db: None) -> None:  # noqa: ARG001
    _reset()
    summary = ingest_helio(_basic_payload(), SENTINEL_USER_ID, SENTINEL_TZ, derive=_noop_derive)
    assert summary.samples_accepted == 2
    assert summary.samples_rejected == 1
    assert summary.sleep == 1
    assert summary.workouts == 1
    assert _count("SELECT count(*) FROM sample WHERE metric = 'hr'") == 1
    assert _count("SELECT count(*) FROM sleep_session") == 1
    assert _count("SELECT count(*) FROM workout") == 1
    # main sleep emitted per-minute stage rows
    assert _count("SELECT count(*) FROM sample WHERE metric = 'sleep_stage'") > 0


def test_push_attributes_every_row_to_the_passed_owner(db: None) -> None:  # noqa: ARG001
    """6.3a: ingest writes raw + typed rows under the user_id it was given.

    Asserted against the row COUNT under that owner (not merely `IS NOT NULL`), so a
    regression to the 0003 column DEFAULT — which would still produce a non-null
    sentinel and pass a weaker check — is caught once 6.4 passes a real user.
    """
    _reset()
    ingest_helio(_basic_payload(), SENTINEL_USER_ID, SENTINEL_TZ, derive=_noop_derive)
    for table in ("sample", "sleep_session", "workout"):
        total = _count(f"SELECT count(*) FROM {table}")  # noqa: S608 — constant table name
        owned = _count(
            f"SELECT count(*) FROM {table} WHERE user_id = %s",  # noqa: S608 — constant
            (SENTINEL_USER_ID,),
        )
        assert total > 0, f"{table} got no rows"
        assert owned == total, f"{table} has rows not attributed to the passed owner"


def test_second_identical_push_is_idempotent(db: None) -> None:  # noqa: ARG001
    _reset()
    ingest_helio(_basic_payload(), SENTINEL_USER_ID, SENTINEL_TZ, derive=_noop_derive)
    before = _count("SELECT count(*) FROM sample")
    sessions_before = _count("SELECT count(*) FROM sleep_session")
    ingest_helio(_basic_payload(), SENTINEL_USER_ID, SENTINEL_TZ, derive=_noop_derive)
    assert _count("SELECT count(*) FROM sample") == before
    assert _count("SELECT count(*) FROM sleep_session") == sessions_before


def test_a_push_stores_the_strap_totals_raw(db: None) -> None:  # noqa: ARG001
    """#121: the strap's 0x0016 report lands in its own table, whole.

    Before #121 there was no raw table at all: `steps` went into `derived_daily`,
    `distance_m` went into `derived_daily`, and `calories` was dropped on the floor.
    """
    _reset()
    summary = ingest_helio(_totals_payload(), SENTINEL_USER_ID, SENTINEL_TZ, derive=_noop_derive)
    assert summary.daily_totals == 1
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT steps, distance_m, calories, source, user_id FROM device_daily_total "
            "WHERE day = '2026-06-16'"
        )
        row = cur.fetchone()
    assert row is not None, "the strap's daily total has no raw home"
    assert (row[0], row[1], row[2], row[3]) == (9264, 5081.0, 451.0, "strap_0x16")
    assert row[4] == SENTINEL_USER_ID  # owner-scoped like every other raw row


def test_the_raw_totals_are_stored_before_derive_runs(db: None) -> None:  # noqa: ARG001
    """The order that replaced "apply the override after derive" — raw first, then derive.

    Only this direction can be correct now: the day pass is what reads the counter and
    writes `steps_total` from it. Stored afterwards, the value would not be destroyed
    (the whole point of #121) — it would simply wait for the next derive — but the push
    that carried it would leave the day showing the per-minute sum.
    """
    _reset()
    _SEEN_BY_DERIVE.clear()
    ingest_helio(
        _totals_payload(), SENTINEL_USER_ID, SENTINEL_TZ, derive=_reads_the_raw_totals_derive
    )
    assert dict(_SEEN_BY_DERIVE) == {date(2026, 6, 16): 9264}


def test_a_repushed_total_replaces_the_stored_one(db: None) -> None:  # noqa: ARG001
    """The counter is a live since-midnight accumulator; the newest reading is the day's.

    One row per (owner, day), not an append-only log — the second push must update, not
    duplicate, or the derivation would have to pick between two rows with no rule.
    """
    _reset()
    ingest_helio(_totals_payload(), SENTINEL_USER_ID, SENTINEL_TZ, derive=_noop_derive)
    ingest_helio(_totals_payload(steps=11_022), SENTINEL_USER_ID, SENTINEL_TZ, derive=_noop_derive)
    assert _count("SELECT count(*) FROM device_daily_total WHERE day = '2026-06-16'") == 1
    assert _count("SELECT steps FROM device_daily_total WHERE day = '2026-06-16'") == 11_022


def _totals_payload(*, steps: int = 9264) -> HelioPayload:
    return HelioPayload.model_validate(
        {
            "samples": [
                {"metric": "hr", "ts": _ms(datetime(2026, 6, 16, 12, tzinfo=UTC)), "value": 60.0}
            ],
            "daily_totals": [
                {"day": "2026-06-16", "steps": steps, "distance_m": 5081, "calories": 451}
            ],
        }
    )


def test_fresh_gating_skips_old_night_reemit(db: None) -> None:  # noqa: ARG001
    _reset()
    now = datetime.now(UTC).replace(microsecond=0)
    old_start = now - timedelta(days=5, hours=8)
    old = {
        "start_ts": _ms(old_start),
        "end_ts": _ms(old_start + timedelta(hours=7)),
        "kind": "main",
        "stages": [[_ms(old_start), _ms(old_start + timedelta(minutes=6)), 2]],
    }
    # Push A: only the old night → new → fresh → emits its per-minute rows.
    ingest_helio(
        HelioPayload.model_validate({"sleep": [old]}),
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        derive=_noop_derive,
    )
    old_lo, old_hi = old_start, old_start + timedelta(minutes=10)
    emitted = _count(
        "SELECT count(*) FROM sample WHERE metric = 'sleep_stage' AND ts BETWEEN %s AND %s",
        (old_lo, old_hi),
    )
    assert emitted > 0

    # Delete the emitted rows, then re-push the (now existing, stale) old night
    # alongside a fresh tonight. The stale night must NOT be re-emitted.
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "DELETE FROM sample WHERE metric = 'sleep_stage' AND ts BETWEEN %s AND %s",
            (old_lo, old_hi),
        )
    tonight_start = now - timedelta(hours=8)
    tonight = {
        "start_ts": _ms(tonight_start),
        "end_ts": _ms(now),
        "kind": "main",
        "stages": [[_ms(tonight_start), _ms(tonight_start + timedelta(minutes=6)), 2]],
    }
    ingest_helio(
        HelioPayload.model_validate({"sleep": [old, tonight]}),
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        derive=_noop_derive,
    )

    re_emitted = _count(
        "SELECT count(*) FROM sample WHERE metric = 'sleep_stage' AND ts BETWEEN %s AND %s",
        (old_lo, old_hi),
    )
    assert re_emitted == 0  # stale night gated out — not re-emitted
    fresh_rows = _count(
        "SELECT count(*) FROM sample WHERE metric = 'sleep_stage' AND ts BETWEEN %s AND %s",
        (tonight_start, now),
    )
    assert fresh_rows > 0  # tonight is fresh → emitted
