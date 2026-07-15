"""Derive orchestration — the per-night and per-day passes, in dependency order.

``derive_night`` materializes one sleep session's metrics; ``derive_day`` runs the
daily chain (MVPA -> activity/calories -> VO2max -> cardio-load -> sleep debt ->
recovery) so each step's inputs are already written. ``derive_days`` is the
transactional convenience the ingest path calls after upserting new data.

Ported verbatim from legacy v2 ``derive_night`` / ``derive_day`` /
``derive_all_nights``; the only change is DB plumbing — the legacy autocommit
``connect()`` becomes the shared ``core.db`` pool, preserving one transaction per
unit of work.
"""

from __future__ import annotations

from datetime import date, datetime

from psycopg import Connection
from psycopg.rows import TupleRow

from healthee.core.db import connection
from healthee.derive._common import Cur, _upsert_daily, _wake_date
from healthee.derive.activity import derive_daily_activity
from healthee.derive.cardio_load import derive_cardio_load
from healthee.derive.hrv_spo2_resp import derive_night_vitals
from healthee.derive.mvpa import derive_mvpa
from healthee.derive.recovery import derive_recovery
from healthee.derive.rhr import derive_rhr
from healthee.derive.sleep_score import derive_sleep_debt, derive_sleep_score
from healthee.derive.vo2max import derive_vo2max


def derive_night(cur: Cur, start_ts: datetime, end_ts: datetime) -> dict:
    """Derive per-night metrics for one sleep session; returns what was written."""
    day = _wake_date(end_ts)
    out: dict = {}

    rhr, n = derive_rhr(cur, start_ts, end_ts)
    if rhr is not None:
        _upsert_daily(cur, day, "rhr_daily", rhr, {"n": n})
        out["rhr_daily"] = round(rhr, 2)

    out.update(derive_night_vitals(cur, day, start_ts, end_ts))

    cur.execute(
        "SELECT rem_min, light_min, deep_min, wake_min FROM sleep_session WHERE start_ts=%s",
        (start_ts,),
    )
    sr = cur.fetchone()
    if sr:
        out.update(derive_sleep_score(cur, start_ts, end_ts, sr[0], sr[1], sr[2], sr[3], day))
    return out


def derive_day(cur: Cur, day: date) -> dict:
    """Full daily derive pass in dependency order.

    MVPA -> activity/calories -> VO2max (needs MVPA + rhr) -> cardio-load (needs
    rhr) -> sleep debt (needs TST) -> recovery (needs hrv/rhr/rr + sleep need).
    """
    out: dict = {}
    if m := derive_mvpa(cur, day):
        out.update(m)
    out.update(derive_daily_activity(cur, day))
    if v := derive_vo2max(cur, day):
        out.update(v)
    if c := derive_cardio_load(cur, day):
        out.update(c)
    if s := derive_sleep_debt(cur, day):
        out.update(s)
    if rec := derive_recovery(cur, day):
        out.update(rec)
    return out


def derive_days(conn: Connection[TupleRow], days: list[date]) -> None:
    """Derive every day within the CALLER's open transaction on `conn`.

    Does NOT commit — the caller owns the transaction boundary. The ingest path
    calls this mid-push (after upserting new samples/sessions, before the
    daily-total override) so the whole push stays atomic: a failure anywhere rolls
    back the upserts, the derivation, and the override together.
    """
    with conn.cursor() as cur:
        for day in days:
            derive_day(cur, day)


def derive_all_nights() -> dict[str, dict]:
    """Derive per-night metrics for every stored main sleep session."""
    results: dict[str, dict] = {}
    with connection() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT start_ts, end_ts FROM sleep_session WHERE kind='main' ORDER BY start_ts"
        )
        for start_ts, end_ts in cur.fetchall():
            results[start_ts.isoformat()] = derive_night(cur, start_ts, end_ts)
    return results
