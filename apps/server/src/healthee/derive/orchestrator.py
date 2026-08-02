"""Derive orchestration — the per-night and per-day passes, in dependency order.

``derive_night`` materializes one sleep session's metrics; ``derive_day`` runs the
daily chain (MVPA -> activity/calories -> VO2max -> cardio-load -> sleep debt ->
recovery) so each step's inputs are already written. ``derive_batch`` is the ONE
transactional entry point over many of both, and it owns the order between them.

Ported verbatim from legacy v2 ``derive_night`` / ``derive_day``; the only change is
DB plumbing — the legacy autocommit ``connect()`` becomes the shared ``core.db``
pool, preserving one transaction per unit of work.

## Why there is exactly one batch entry point (#107)

There used to be two: ``derive_days`` (days only) and ``derive_all_nights`` (nights
only, in its own transaction, called by nothing). The ingest path reached for the
days-only one, so ``derive_night`` never ran in the running system and every
night-derived metric quietly stopped existing — for two weeks, behind a 200 and a
green ``data_health``.

The structural fix is not "also call the other one": it is that **there is no way to
derive a batch of days without its nights**. A caller passes both; this module
decides the order. ``derive_all_nights`` is gone with it — its capability lives in
``healthee.db.rederive``, which routes through this same function, so the repair path
cannot disagree with the live path about the order.
"""

from __future__ import annotations

from datetime import date, datetime
from uuid import UUID

from psycopg import Connection
from psycopg.rows import TupleRow

from healthee.derive._common import Cur, _upsert_daily, _wake_date
from healthee.derive.activity import derive_daily_activity
from healthee.derive.cardio_load import derive_cardio_load
from healthee.derive.hrv_spo2_resp import derive_night_vitals
from healthee.derive.mvpa import derive_mvpa
from healthee.derive.recovery import derive_recovery
from healthee.derive.rhr import derive_rhr
from healthee.derive.sleep_score import derive_sleep_debt, derive_sleep_score
from healthee.derive.vo2max import derive_vo2max

# One sleep session's window, as (start_ts, end_ts) in UTC — the unit ``derive_night``
# consumes and the shape a batch's `nights` list carries.
SleepWindow = tuple[datetime, datetime]


def derive_night(cur: Cur, user_id: UUID, tz: str, start_ts: datetime, end_ts: datetime) -> dict:
    """Derive per-night metrics for one sleep session; returns what was written.

    Every metric is read and materialized under `user_id` (0004 folded the owner
    into the derived_daily key; 6.3b scoped the reads), anchored on the owner's
    local `tz` wake date."""
    day = _wake_date(end_ts, tz)
    out: dict = {}

    rhr, n = derive_rhr(cur, user_id, start_ts, end_ts)
    if rhr is not None:
        _upsert_daily(cur, user_id, day, "rhr_daily", rhr, {"n": n})
        out["rhr_daily"] = round(rhr, 2)

    out.update(derive_night_vitals(cur, user_id, day, start_ts, end_ts))

    cur.execute(
        "SELECT rem_min, light_min, deep_min, wake_min FROM sleep_session "
        "WHERE user_id = %s AND start_ts=%s",
        (user_id, start_ts),
    )
    sr = cur.fetchone()
    if sr:
        out.update(
            derive_sleep_score(cur, user_id, tz, start_ts, end_ts, sr[0], sr[1], sr[2], sr[3], day)
        )
    return out


def derive_day(cur: Cur, user_id: UUID, tz: str, day: date) -> dict:
    """Full daily derive pass in dependency order.

    MVPA -> activity/calories -> VO2max (needs MVPA + rhr) -> cardio-load (needs
    rhr) -> sleep debt (needs TST) -> recovery (needs hrv/rhr/rr + sleep need).
    """
    out: dict = {}
    if m := derive_mvpa(cur, user_id, tz, day):
        out.update(m)
    out.update(derive_daily_activity(cur, user_id, tz, day))
    if v := derive_vo2max(cur, user_id, tz, day):
        out.update(v)
    if c := derive_cardio_load(cur, user_id, tz, day):
        out.update(c)
    if s := derive_sleep_debt(cur, user_id, tz, day):
        out.update(s)
    if rec := derive_recovery(cur, user_id, day):
        out.update(rec)
    return out


def derive_batch(
    conn: Connection[TupleRow],
    user_id: UUID,
    tz: str,
    nights: list[SleepWindow],
    days: list[date],
) -> None:
    """Derive `nights` and then `days` in the CALLER's open transaction on `conn`.

    ## The order is the contract, not an implementation detail

    Nights run FIRST because :func:`derive_day` READS what :func:`derive_night` WRITES:
    ``rhr_daily`` feeds VO2max and cardio load, the sleep score's ``tst_min`` feeds
    sleep debt, and ``hrv_sleep_avg`` / ``rhr_daily`` / ``respiratory_rate_sleep`` feed
    recovery. Reversed, this function still returns cleanly and still writes rows — it
    just writes them against yesterday's inputs, or against a fallback, or not at all.

    That failure hides especially well: on a RE-push the previous run has already left
    last night's rows behind, so days-first looks perfect. It is wrong only on the FIRST
    push of a new night — which is to say every night, once, in production.
    ``tests/derive/test_derive_batch_order.py`` pins the order directly and
    ``tests/integration/test_ingest_derive_chain.py`` pins its consequences end to end.

    ## Transaction boundary

    Does NOT commit — the caller owns it. The ingest path calls this mid-push (after
    upserting new samples/sessions, before the daily-total override) so the whole push
    stays atomic: a failure anywhere rolls back the upserts, the derivation, and the
    override together. One cursor for the whole batch, so nights are visible to the day
    pass without a round trip through a commit.
    """
    with conn.cursor() as cur:
        for start_ts, end_ts in nights:
            derive_night(cur, user_id, tz, start_ts, end_ts)
        for day in days:
            derive_day(cur, user_id, tz, day)


def stored_nights(cur: Cur, user_id: UUID, tz: str, since: date) -> list[SleepWindow]:
    """The owner's stored MAIN sleep sessions waking on/after ``since``, oldest first.

    The repair path's input (``healthee.db.rederive``), bounded by WAKE date — the
    session's end in the owner's zone — because that is the day every row
    :func:`derive_night` writes is keyed to. Naps are excluded: :func:`derive_night` is
    a statement about a night, the same rule ``ingest.service`` applies when it collects
    a push's fresh nights.
    """
    cur.execute(
        "SELECT start_ts, end_ts FROM sleep_session WHERE user_id = %s AND kind = 'main' "
        "AND (end_ts AT TIME ZONE %s)::date >= %s ORDER BY start_ts",
        (user_id, tz, since),
    )
    return [(row[0], row[1]) for row in cur.fetchall()]
