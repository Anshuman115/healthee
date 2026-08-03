"""The re-derive repair tool: reachable, and identical to the live derive path (#107).

The capability this replaces (`derive.derive_all_nights`) was correct code that nothing
called, which is how the ingest path came to skip the night pass for two weeks without
anyone noticing. So the tests here are about reachability as much as arithmetic: the
module has a `main()`, that `main()` rebuilds a derived layer that was deliberately left
empty, and it does so through the same `derive_batch` the push uses — so the two cannot
drift apart on the order nights and days run in.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo

import pytest

from healthee.core import db as db_module
from healthee.core.db import admin_connection
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate, rederive
from healthee.ingest import HelioPayload, ingest_helio
from healthee.ingest.service import DerivePlan

pytestmark = pytest.mark.integration

_TABLES = "sample, sleep_session, workout, derived_daily, weight_log, profile, device_daily_total"

_SLEEP_HR_BPM = 52.0


def _reset() -> None:
    migrate.apply_migrations()
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(f"TRUNCATE {_TABLES}")


def _ms(dt: datetime) -> int:
    return int(dt.timestamp() * 1000)


def _skip_derive(conn: Any, user_id: UUID, tz: str, plan: DerivePlan) -> None:  # noqa: ARG001
    """Ingest without deriving — the state a stalled derive layer leaves behind."""


def _seed_last_night() -> date:
    """Push one night of raw data with derivation suppressed. Returns its wake date."""
    wake = datetime.now(tz=UTC).replace(minute=0, second=0, microsecond=0) - timedelta(hours=2)
    start = wake - timedelta(hours=7)
    samples, ts = [], start
    while ts < wake:
        samples.append({"metric": "hr", "ts": _ms(ts), "value": _SLEEP_HR_BPM})
        ts += timedelta(minutes=1)
    payload = HelioPayload.model_validate(
        {
            "samples": samples,
            "sleep": [
                {
                    "start_ts": _ms(start),
                    "end_ts": _ms(wake),
                    "kind": "main",
                    "rem_min": 80,
                    "light_min": 220,
                    "deep_min": 80,
                    "wake_min": 40,
                    "stages": [[_ms(start), _ms(wake), 2]],
                }
            ],
            "profile": {"height_cm": 175.0, "sex": "male", "dob": "1990-06-15", "weight_kg": 70.0},
        }
    )
    ingest_helio(payload, SENTINEL_USER_ID, SENTINEL_TZ, derive=_skip_derive)
    return wake.astimezone(ZoneInfo(SENTINEL_TZ)).date()


def _rhr(day: date) -> float | None:
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT value FROM derived_daily WHERE user_id = %s AND day = %s AND metric = %s",
            (SENTINEL_USER_ID, day, "rhr_daily"),
        )
        row = cur.fetchone()
    return float(row[0]) if row else None


def test_rederive_rebuilds_a_derived_layer_that_was_left_empty(db: None) -> None:  # noqa: ARG001
    """The repair itself: raw data present, derived layer absent, then repaired."""
    _reset()
    wake_day = _seed_last_night()
    assert _rhr(wake_day) is None  # precondition: nothing derived it

    assert rederive.main(["--user", str(SENTINEL_USER_ID), "--days", "3"]) == 0

    assert _rhr(wake_day) == pytest.approx(_SLEEP_HR_BPM)


def test_rederive_defaults_to_every_active_owner(db: None) -> None:  # noqa: ARG001
    """No --user is the incident form: repair everyone, not nobody."""
    _reset()
    wake_day = _seed_last_night()

    assert rederive.main(["--days", "3"]) == 0

    assert _rhr(wake_day) == pytest.approx(_SLEEP_HR_BPM)


def test_rederive_refuses_an_owner_it_cannot_resolve(db: None) -> None:  # noqa: ARG001
    """A typo'd UUID is refused, not silently re-derived as nothing at all."""
    _reset()
    assert rederive.main(["--user", str(uuid4())]) == 2


def test_main_releases_the_pool_on_both_paths(db: None) -> None:  # noqa: ARG001
    """A CLI that leaves the pool open prints 15 s of thread warnings after succeeding.

    Asserted on the module global because that IS the singleton `close_pool` drops —
    there is no public reader, and the observable symptom (psycopg's teardown warnings
    on stderr, seconds after the process is logically done) is not something a test can
    catch. Both paths, since the refusal path exits through the same `finally`.
    """
    _reset()
    _seed_last_night()

    assert rederive.main(["--days", "1"]) == 0
    assert db_module._pool is None

    assert rederive.main(["--user", str(uuid4())]) == 2
    assert db_module._pool is None


def test_the_day_range_ends_on_the_owners_today() -> None:
    """Today's rows are what a stalled derive layer is missing right now."""
    today = date(2026, 6, 20)

    assert rederive.day_range(today, 3) == [date(2026, 6, 18), date(2026, 6, 19), today]
    assert rederive.day_range(today, 1) == [today]


def test_the_day_range_is_oldest_first() -> None:
    """`derive_batch` walks days in order, and later days read earlier ones' rows."""
    window = rederive.day_range(date(2026, 6, 20), rederive.DEFAULT_WINDOW_DAYS)

    assert window == sorted(window)
    assert len(window) == rederive.DEFAULT_WINDOW_DAYS


def test_a_non_positive_window_is_refused() -> None:
    """Zero days is a typo, not a request to derive nothing."""
    with pytest.raises(rederive.RederiveRefusedError):
        rederive.day_range(date(2026, 6, 20), 0)


def test_a_gated_metric_is_purgeable_once_its_gate_is_reopened() -> None:
    """The refusal is about the GATE, not about the metric being untouchable forever.

    ``--rescore-tracks`` re-attempts every scored session in the window, so after it the
    rows that remain unwritten really are rows today's code would not produce.
    """
    gates = rederive.open_gates(rescore_tracks=True)

    assert rederive.purge_metrics(["vo2max_submax"], applying=True, gates=gates) == (
        "vo2max_submax",
    )
    assert rederive.gated_off(gates) == ()


def test_an_ungated_metric_needs_no_flag() -> None:
    """The common case stays one step: name it, apply it."""
    shut = rederive.open_gates(rescore_tracks=False)

    assert rederive.purge_metrics(["vo2max_estimate"], applying=True, gates=shut) == (
        "vo2max_estimate",
    )
    assert rederive.gated_off(shut) == ("vo2max_submax",)


def test_purging_nothing_is_allowed_only_while_nothing_is_applied() -> None:
    """No metrics + no --apply is the default invocation and must stay silent."""
    shut = rederive.open_gates(rescore_tracks=False)

    assert rederive.purge_metrics([], applying=False, gates=shut) == ()
    with pytest.raises(rederive.RederiveRefusedError):
        rederive.purge_metrics([], applying=True, gates=shut)
