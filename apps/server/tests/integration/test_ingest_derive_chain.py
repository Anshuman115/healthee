"""The ingest -> night -> day derivation chain, end to end against a real DB (#107).

## What this file exists to prevent

`ingest_helio` used to derive only DAYS. `derive_night` — which writes `rhr_daily`,
`hrv_sleep_avg`, `respiratory_rate_sleep`, `spo2_overnight` and the 4-dimension sleep
score — was reachable from exactly one function that nothing in the running system
called. So every night-derived metric silently stopped existing after the last manual
re-derive, and every day metric that READS one (VO2max, cardio load, sleep debt,
recovery, and the biological age above them) degraded to a withhold or a fallback.

Nothing failed. The push returned 200, `data_health` said "ok" (it measures raw sample
arrival, not derivation), and the dashboard simply went quiet — the failure shape this
product exists to make impossible. It ran that way in production for two weeks.

## Why the assertions are what they are

`test_a_push_with_a_night_derives_the_nights_metrics` is the direct regression net: the
night metrics either exist for the wake day or they do not.

`test_the_day_derive_reads_the_night_the_same_push_wrote` is the ORDER net, and it is
the one that matters most. Nights must run BEFORE days, because `derive_day` reads what
`derive_night` writes. Days-first is not a loudly wrong answer — on a RE-push it looks
perfect, because the previous run already left last night's rows behind. It is wrong
only on the first push of a new night, i.e. every night, once, in production. So the
assertions here are on values that can ONLY come from a night derived in the SAME
transaction: `cardio_load`'s `rhr` flag (which silently falls back to 60 bpm when no
`rhr_daily` row exists yet) and `sleep_debt_min` (which reads the `tst_min` the sleep
score writes, and is simply absent without it).
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import Any, LiteralString
from zoneinfo import ZoneInfo

import pytest

from healthee.core.db import admin_connection
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.ingest import HelioPayload, ingest_helio
from healthee.ingest.service import DerivePlan

pytestmark = pytest.mark.integration

_TABLES = "sample, sleep_session, workout, derived_daily, weight_log, profile, device_daily_total"

_IST = ZoneInfo(SENTINEL_TZ)

# One fixed night in the owner's own zone. Fixed (not `now()`-relative) so the local
# wake date is the same under TZ=UTC and TZ=Asia/Kolkata — the whole chain anchors on
# the owner's zone, and a test that drifted with the runner's would hide that.
_NIGHT_START = datetime(2026, 6, 19, 23, 0, tzinfo=_IST)
_NIGHT_END = datetime(2026, 6, 20, 7, 0, tzinfo=_IST)
_WAKE_DAY = date(2026, 6, 20)

# The measured resting HR this night carries. Deliberately far from `cardio_load`'s
# `_RHR_FALLBACK` of 60 bpm: the gap between them is what makes the ordering assertion
# possible at all. Every in-window HR sample is this value, so the minimum 5-minute
# rolling average — the RHR definition — is exactly it.
_SLEEP_HR_BPM = 50.0
_WAKE_HR_BPM = 120.0

_HRV_MS = 45.0
_SPO2_PCT = 96.0
_RESP_RATE = 14.0

# Staged sleep minutes. TST = 420 (7 h) against an age-36 need of 480, so the day's
# sleep debt is a hand-computable 60 minutes.
_REM_MIN, _LIGHT_MIN, _DEEP_MIN, _WAKE_MIN = 90, 240, 90, 30
_TST_MIN = _REM_MIN + _LIGHT_MIN + _DEEP_MIN
_SLEEP_NEED_MIN = 480.0
_SLEEP_DEBT_MIN = _SLEEP_NEED_MIN - _TST_MIN


def _reset() -> None:
    migrate.apply_migrations()
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(f"TRUNCATE {_TABLES}")


def _ms(dt: datetime) -> int:
    return int(dt.timestamp() * 1000)


def _series(metric: str, start: datetime, end: datetime, value: float, step_min: int) -> list[dict]:
    """Evenly spaced samples of one metric over [start, end)."""
    out, ts = [], start
    while ts < end:
        out.append({"metric": metric, "ts": _ms(ts), "value": value})
        ts += timedelta(minutes=step_min)
    return out


def _night_payload() -> HelioPayload:
    """One complete night plus the waking hour after it, and a complete profile.

    Everything the chain needs and nothing it doesn't: HR through the sleep window
    (RHR), the three overnight vitals, a staged main-sleep session (the 4-dim score and
    its `tst_min`), waking HR (cardio load), and the profile + weight both
    `derive_cardio_load` and `derive_sleep_debt` load.
    """
    wake_hour_start = datetime(2026, 6, 20, 9, 0, tzinfo=_IST)
    samples: list[dict] = [
        *_series("hr", _NIGHT_START, _NIGHT_END, _SLEEP_HR_BPM, 1),
        *_series("hrv", _NIGHT_START, _NIGHT_END, _HRV_MS, 30),
        *_series("spo2", _NIGHT_START, _NIGHT_END, _SPO2_PCT, 30),
        *_series("respiratory_rate", _NIGHT_START, _NIGHT_END, _RESP_RATE, 30),
        *_series("hr", wake_hour_start, wake_hour_start + timedelta(hours=1), _WAKE_HR_BPM, 1),
    ]
    awake_from = _NIGHT_END - timedelta(minutes=_WAKE_MIN)
    return HelioPayload.model_validate(
        {
            "samples": samples,
            "sleep": [
                {
                    "start_ts": _ms(_NIGHT_START),
                    "end_ts": _ms(_NIGHT_END),
                    "kind": "main",
                    "rem_min": _REM_MIN,
                    "light_min": _LIGHT_MIN,
                    "deep_min": _DEEP_MIN,
                    "wake_min": _WAKE_MIN,
                    "stages": [
                        [_ms(_NIGHT_START), _ms(awake_from), 2],
                        [_ms(awake_from), _ms(_NIGHT_END), 7],
                    ],
                }
            ],
            "profile": {
                "name": "Chain Test",
                "height_cm": 175.0,
                "sex": "male",
                "dob": "1990-06-15",
                "weight_kg": 70.0,
            },
        }
    )


def _bare_night(wake_at: datetime) -> dict:
    """A minimal staged main-sleep session ending at `wake_at` — no samples needed."""
    start = wake_at - timedelta(hours=7)
    return {
        "start_ts": _ms(start),
        "end_ts": _ms(wake_at),
        "kind": "main",
        "stages": [[_ms(start), _ms(start + timedelta(minutes=6)), 2]],
    }


def _derived(day: date, metric: str) -> tuple[float, dict] | None:
    """One materialized `derived_daily` cell as (value, flags), or None if absent.

    Read as the ADMIN so the observer is independent of the RLS scoping the path under
    test relies on — the posture `test_ingest_integration._count` documents.
    """
    query: LiteralString = (
        "SELECT value, flags FROM derived_daily WHERE user_id = %s AND day = %s AND metric = %s"
    )
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(query, (SENTINEL_USER_ID, day, metric))
        row = cur.fetchone()
    return (float(row[0]), row[1] or {}) if row else None


def _value(day: date, metric: str) -> float:
    cell = _derived(day, metric)
    assert cell is not None, f"{metric} was never derived for {day}"
    return cell[0]


def _flags(day: date, metric: str) -> dict[str, Any]:
    cell = _derived(day, metric)
    assert cell is not None, f"{metric} was never derived for {day}"
    return cell[1]


# The night metrics, and the value each must carry given `_night_payload`. Every one of
# these was absent in production while the day metrics kept updating.
_NIGHT_METRICS = {
    "rhr_daily": _SLEEP_HR_BPM,
    "hrv_sleep_avg": _HRV_MS,
    "spo2_overnight": _SPO2_PCT,
    "respiratory_rate_sleep": _RESP_RATE,
}


def test_a_push_with_a_night_derives_the_nights_metrics(db: None) -> None:  # noqa: ARG001
    """A push carrying a sleep session materializes that night's metrics."""
    _reset()
    ingest_helio(_night_payload(), SENTINEL_USER_ID, SENTINEL_TZ)

    for metric, expected in _NIGHT_METRICS.items():
        assert _value(_WAKE_DAY, metric) == pytest.approx(expected), metric
    assert _flags(_WAKE_DAY, "sleep_health_score_4dim")["tst_min"] == _TST_MIN


def test_the_day_derive_reads_the_night_the_same_push_wrote(db: None) -> None:  # noqa: ARG001
    """Nights are derived BEFORE days — proven by two day metrics that need a night.

    Fails if the order is reversed:

      * `cardio_load` would score the waking hour against `_RHR_FALLBACK` (60 bpm)
        instead of the 50 bpm this night actually measured — a wrong number, written
        with full confidence, in the currency the workout screen also quotes;
      * `sleep_debt_min` / `sleep_need_min` would not exist at all, because
        `derive_sleep_debt` reads the `tst_min` that `derive_sleep_score` writes.
    """
    _reset()
    ingest_helio(_night_payload(), SENTINEL_USER_ID, SENTINEL_TZ)

    assert _flags(_WAKE_DAY, "cardio_load")["rhr"] == round(_SLEEP_HR_BPM)
    assert _value(_WAKE_DAY, "sleep_need_min") == pytest.approx(_SLEEP_NEED_MIN)
    assert _value(_WAKE_DAY, "sleep_debt_min") == pytest.approx(_SLEEP_DEBT_MIN)


def test_a_second_identical_push_derives_the_same_numbers(db: None) -> None:  # noqa: ARG001
    """Re-pushing the same night is idempotent through the derive chain too.

    The freshness gate that keeps a re-push of ~80 historical nights cheap must not
    also be what makes the FIRST push correct — so the night's own numbers have to
    survive a second push unchanged, gate or no gate.
    """
    _reset()
    ingest_helio(_night_payload(), SENTINEL_USER_ID, SENTINEL_TZ)
    ingest_helio(_night_payload(), SENTINEL_USER_ID, SENTINEL_TZ)

    for metric, expected in _NIGHT_METRICS.items():
        assert _value(_WAKE_DAY, metric) == pytest.approx(expected), metric
    assert _value(_WAKE_DAY, "sleep_debt_min") == pytest.approx(_SLEEP_DEBT_MIN)


def test_repushed_history_does_not_re_derive_its_nights(db: None) -> None:  # noqa: ARG001
    """Re-pushing old nights must not re-derive them — the cost property, preserved.

    The app re-sends its whole sleep history on every sync. `build_fresh_predicate`
    already keeps that from re-emitting ~80 nights of per-minute rows; the night derive
    is gated on the SAME predicate, so it inherits the property rather than reopening
    the cost in a new place.
    """
    _reset()
    now = datetime.now(UTC).replace(microsecond=0)
    old = [_bare_night(now - timedelta(days=n)) for n in (7, 6, 5)]
    ingest_helio(HelioPayload.model_validate({"sleep": old}), SENTINEL_USER_ID, SENTINEL_TZ)

    planned: list[DerivePlan] = []

    def _capture(conn: Any, user_id: Any, tz: str, plan: DerivePlan) -> None:  # noqa: ARG001
        planned.append(plan)

    tonight = _bare_night(now)
    ingest_helio(
        HelioPayload.model_validate({"sleep": [*old, tonight]}),
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        derive=_capture,
    )

    assert len(planned) == 1
    assert [start for start, _ in planned[0].nights] == [
        datetime.fromtimestamp(tonight["start_ts"] / 1000, tz=UTC)
    ]


def test_a_push_with_no_sleep_still_derives_its_days(db: None) -> None:  # noqa: ARG001
    """No sleep in the payload is not an error — the day pass still runs."""
    _reset()
    noon = datetime(2026, 6, 20, 12, 0, tzinfo=UTC)
    payload = HelioPayload.model_validate(
        {
            "samples": [{"metric": "hr", "ts": _ms(noon), "value": 61.0}],
            "daily_totals": [{"day": "2026-06-20", "steps": 9264}],
        }
    )
    summary = ingest_helio(payload, SENTINEL_USER_ID, SENTINEL_TZ)
    assert summary.days_derived == 1
    assert _value(_WAKE_DAY, "steps_total") == pytest.approx(9264.0)
