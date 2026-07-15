"""Integration tests for the ingest service against a real TimescaleDB (CI
service container; auto-skips locally when no DB is reachable).

Covers: a push lands raw + typed rows; a second identical push is idempotent; the
strap daily-total override wins over what derive wrote (proving apply order); and
fresh-gating does not re-emit an old night's per-minute rows.

The derive step is a stub (WP2 owns real derivation) — one stub writes a
placeholder steps_total so the override test can prove it runs AFTER derive.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any, LiteralString

import pytest
from psycopg import Connection

from healthee.core.db import transaction
from healthee.db import migrate
from healthee.ingest import HelioPayload, ingest_helio

pytestmark = pytest.mark.integration

_TABLES = "sample, sleep_session, workout, derived_daily, weight_log, profile"


def _reset() -> None:
    migrate.apply_migrations()
    with transaction() as cur:
        cur.execute(f"TRUNCATE {_TABLES}")


def _noop_derive(conn: Connection, days: list[Any]) -> None:  # noqa: ARG001
    """Derive stub: does nothing (WP2 owns real derivation)."""


def _placeholder_steps_derive(conn: Connection, days: list[Any]) -> None:
    """Derive stub that writes a WRONG steps_total for each day, so the override
    test proves apply_daily_totals runs after (and beats) derive."""
    with conn.cursor() as cur:
        for day in days:
            cur.execute(
                "INSERT INTO derived_daily (day, metric, value, flags) "
                "VALUES (%s, 'steps_total', 1, '{}'::jsonb) "
                "ON CONFLICT (day, metric) DO UPDATE SET value = EXCLUDED.value",
                (day,),
            )


def _count(sql: LiteralString, params: tuple[Any, ...] = ()) -> int:
    with transaction() as cur:
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
    summary = ingest_helio(_basic_payload(), derive=_noop_derive)
    assert summary.samples_accepted == 2
    assert summary.samples_rejected == 1
    assert summary.sleep == 1
    assert summary.workouts == 1
    assert _count("SELECT count(*) FROM sample WHERE metric = 'hr'") == 1
    assert _count("SELECT count(*) FROM sleep_session") == 1
    assert _count("SELECT count(*) FROM workout") == 1
    # main sleep emitted per-minute stage rows
    assert _count("SELECT count(*) FROM sample WHERE metric = 'sleep_stage'") > 0


def test_second_identical_push_is_idempotent(db: None) -> None:  # noqa: ARG001
    _reset()
    ingest_helio(_basic_payload(), derive=_noop_derive)
    before = _count("SELECT count(*) FROM sample")
    sessions_before = _count("SELECT count(*) FROM sleep_session")
    ingest_helio(_basic_payload(), derive=_noop_derive)
    assert _count("SELECT count(*) FROM sample") == before
    assert _count("SELECT count(*) FROM sleep_session") == sessions_before


def test_daily_total_override_beats_derive(db: None) -> None:  # noqa: ARG001
    _reset()
    payload = HelioPayload.model_validate(
        {
            "samples": [
                {"metric": "hr", "ts": _ms(datetime(2026, 6, 16, 12, tzinfo=UTC)), "value": 60.0}
            ],
            "daily_totals": [{"day": "2026-06-16", "steps": 9264, "distance_m": 5081}],
        }
    )
    summary = ingest_helio(payload, derive=_placeholder_steps_derive)
    assert summary.daily_totals == 1
    steps = _count(
        "SELECT value FROM derived_daily WHERE day = '2026-06-16' AND metric = 'steps_total'"
    )
    assert steps == 9264  # strap counter beat the derive placeholder of 1
    dist = _count(
        "SELECT value FROM derived_daily WHERE day = '2026-06-16' AND metric = 'distance_m_daily'"
    )
    assert dist == 5081
    src = _flag("2026-06-16", "steps_total")
    assert src == "strap_0x16"


def _flag(day: str, metric: str) -> str:
    with transaction() as cur:
        cur.execute(
            "SELECT flags->>'source' FROM derived_daily WHERE day = %s AND metric = %s",
            (day, metric),
        )
        row = cur.fetchone()
    return str(row[0]) if row and row[0] else ""


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
    ingest_helio(HelioPayload.model_validate({"sleep": [old]}), derive=_noop_derive)
    old_lo, old_hi = old_start, old_start + timedelta(minutes=10)
    emitted = _count(
        "SELECT count(*) FROM sample WHERE metric = 'sleep_stage' AND ts BETWEEN %s AND %s",
        (old_lo, old_hi),
    )
    assert emitted > 0

    # Delete the emitted rows, then re-push the (now existing, stale) old night
    # alongside a fresh tonight. The stale night must NOT be re-emitted.
    with transaction() as cur:
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
    ingest_helio(HelioPayload.model_validate({"sleep": [old, tonight]}), derive=_noop_derive)

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
