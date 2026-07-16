"""Idempotent upserts for a /ingest/helio batch.

Every write is `ON CONFLICT` so re-ingesting the same push is a no-op — the app
re-sends its full in-memory series + sleep history on every sync, and this must
never create duplicates.

Performance: the batch upserts are *pipelined*, not one-round-trip-per-row. The
legacy push once did a separate `execute()` per sample and hit 180 s timeouts;
`upsert_samples` uses `executemany` (psycopg3 pipelines it into ~one round-trip),
and the expensive per-minute sleep-stage emission is gated to *fresh* sessions so
re-pushing 80 nights of history doesn't re-emit 80 nights of minutes.
"""

from __future__ import annotations

import json
from collections.abc import Callable
from datetime import UTC, date, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from psycopg import Cursor
from psycopg.rows import TupleRow

from healthee.ingest.models import (
    ALLOWED_METRICS,
    DailyTotalIn,
    ProfileIn,
    SampleIn,
    SleepIn,
    WorkoutIn,
)

Cur = Cursor[TupleRow]

# Single-user timezone. Pending a profile/config-sourced tz field, this is the
# ONE place the user's zone is named — weight de-dup and the affected-day
# computation both read it here rather than string-literal it at each site.
USER_TZ_NAME = "Asia/Kolkata"
USER_TZ = ZoneInfo(USER_TZ_NAME)

# A ts above this is epoch-milliseconds; at/below it is epoch-seconds. The app
# sends ms, but tolerate seconds so a future producer can't silently shift 1000×.
_MS_THRESHOLD = 10**12

# A main-sleep session is "fresh" (worth the per-minute emit) if it is new or
# within this many days of the batch's latest night. Re-emitting per-minute rows
# for old, unchanged sessions on every push is pure waste (idempotent inserts
# that already exist) and was a big chunk of the legacy push time.
FRESH_WINDOW_DAYS = 3


def epoch_to_utc(ts: int) -> datetime:
    """Epoch milliseconds (or seconds) → aware UTC datetime."""
    seconds = ts / 1000 if ts > _MS_THRESHOLD else ts
    return datetime.fromtimestamp(seconds, tz=UTC)


def local_date(ts: int) -> date:
    """The user-local calendar date an epoch-ms timestamp falls on."""
    return epoch_to_utc(ts).astimezone(USER_TZ).date()


def upsert_samples(cur: Cur, user_id: UUID, samples: list[SampleIn]) -> tuple[int, int]:
    """Upsert raw time-series points. Returns (accepted, rejected).

    Unknown metrics are coerce-dropped and counted (not a hard error), matching
    the legacy contract so a newer app adding a metric never 422s its whole push.
    """
    rows: list[tuple[UUID, datetime, str, float]] = []
    rejected = 0
    for s in samples:
        if s.metric not in ALLOWED_METRICS:
            rejected += 1
            continue
        rows.append((user_id, epoch_to_utc(s.ts), s.metric, float(s.value)))
    if rows:
        cur.executemany(
            "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, %s, %s) "
            "ON CONFLICT (user_id, metric, ts) DO UPDATE SET value = EXCLUDED.value",
            rows,
        )
    return len(rows), rejected


def emit_sleep_minutes(cur: Cur, user_id: UUID, stages: list[list[int]]) -> None:
    """Materialize per-minute `asleep` (1) + `sleep_stage` (type) samples from a
    session's hypnogram, so downstream SRI / stage reads have a per-minute
    stream. `stages`: [[startMs, endMs, type], …]; type 7 = awake."""
    for st in stages:
        start = epoch_to_utc(st[0]).replace(second=0, microsecond=0)
        end = epoch_to_utc(st[1])
        if end <= start:
            continue
        last = end - timedelta(seconds=60)
        cur.execute(
            "INSERT INTO sample (user_id, ts, metric, value) "
            "SELECT %s, g, 'sleep_stage', %s FROM generate_series(%s, %s, interval '1 minute') g "
            "ON CONFLICT (user_id, metric, ts) DO UPDATE SET value = EXCLUDED.value",
            (user_id, float(st[2]), start, last),
        )
        if st[2] != 7:  # 7 = awake; only actual sleep marks `asleep`
            cur.execute(
                "INSERT INTO sample (user_id, ts, metric, value) "
                "SELECT %s, g, 'asleep', 1 FROM generate_series(%s, %s, interval '1 minute') g "
                "ON CONFLICT (user_id, metric, ts) DO NOTHING",
                (user_id, start, last),
            )


def upsert_sleep(
    cur: Cur, user_id: UUID, sessions: list[SleepIn], should_emit: Callable[[SleepIn], bool]
) -> int:
    """Upsert typed sleep sessions; emit per-minute rows only for fresh MAIN
    sleep (`should_emit`). Naps never feed the per-minute stream — daytime
    minutes must not pollute the night-only SRI/regularity reads."""
    for s in sessions:
        cur.execute(
            "INSERT INTO sleep_session "
            "(user_id, start_ts, end_ts, kind, score, avg_hr, rem_min, light_min, deep_min, "
            "wake_min, stages) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb) "
            "ON CONFLICT (user_id, start_ts) DO UPDATE SET "
            "end_ts = EXCLUDED.end_ts, kind = EXCLUDED.kind, score = EXCLUDED.score, "
            "avg_hr = EXCLUDED.avg_hr, rem_min = EXCLUDED.rem_min, "
            "light_min = EXCLUDED.light_min, deep_min = EXCLUDED.deep_min, "
            "wake_min = EXCLUDED.wake_min, stages = EXCLUDED.stages",
            (
                user_id,
                epoch_to_utc(s.start_ts),
                epoch_to_utc(s.end_ts),
                s.kind,
                s.score,
                s.avg_hr,
                s.rem_min,
                s.light_min,
                s.deep_min,
                s.wake_min,
                json.dumps(s.stages),
            ),
        )
        if s.kind != "nap" and should_emit(s):
            emit_sleep_minutes(cur, user_id, s.stages)
    return len(sessions)


def upsert_workouts(cur: Cur, user_id: UUID, workouts: list[WorkoutIn]) -> int:
    """Upsert typed workouts with device-measured HR/calories/distance."""
    for w in workouts:
        cur.execute(
            "INSERT INTO workout "
            "(user_id, start_ts, sport, duration_s, calories, distance_m, avg_hr, max_hr, min_hr) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) "
            "ON CONFLICT (user_id, start_ts) DO UPDATE SET "
            "sport = EXCLUDED.sport, duration_s = EXCLUDED.duration_s, "
            "calories = EXCLUDED.calories, distance_m = EXCLUDED.distance_m, "
            "avg_hr = EXCLUDED.avg_hr, max_hr = EXCLUDED.max_hr, min_hr = EXCLUDED.min_hr",
            (
                user_id,
                epoch_to_utc(w.start_ts),
                w.sport,
                w.duration_s,
                w.calories,
                w.distance_m,
                w.avg_hr,
                w.max_hr,
                w.min_hr,
            ),
        )
    return len(workouts)


def upsert_profile(cur: Cur, profile: ProfileIn) -> None:
    """Upsert the single-user profile row (id fixed at 1). `name` is preserved
    when the push omits it (COALESCE); weight is handled by `upsert_weight`."""
    dob = epoch_to_utc(profile.dob).date() if profile.dob else None
    cur.execute(
        "INSERT INTO profile (id, name, height_cm, sex, dob, updated_at) "
        "VALUES (1, %s, %s, %s, %s, now()) "
        "ON CONFLICT (id) DO UPDATE SET "
        "name = COALESCE(EXCLUDED.name, profile.name), height_cm = EXCLUDED.height_cm, "
        "sex = EXCLUDED.sex, dob = EXCLUDED.dob, updated_at = now()",
        (profile.name, profile.height_cm, profile.sex, dob),
    )


def upsert_weight(cur: Cur, user_id: UUID, weight_kg: float) -> None:
    """Record body weight, deduped to one row per local day and only when it
    actually changed — otherwise every profile push would spam a new row."""
    kg = float(weight_kg)
    cur.execute(
        "SELECT ts, kg FROM weight_log "
        "WHERE user_id = %s AND (ts AT TIME ZONE %s)::date = (now() AT TIME ZONE %s)::date "
        "ORDER BY ts DESC LIMIT 1",
        (user_id, USER_TZ_NAME, USER_TZ_NAME),
    )
    row = cur.fetchone()
    if row is None:
        cur.execute(
            "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, now(), %s)", (user_id, kg)
        )
    elif abs(float(row[1]) - kg) > 0.01:  # unchanged today → skip; else update
        cur.execute(
            "UPDATE weight_log SET kg = %s WHERE user_id = %s AND ts = %s", (kg, user_id, row[0])
        )


def _upsert_derived(
    cur: Cur, user_id: UUID, day: date, metric: str, value: float, flags: dict
) -> None:
    """Write one materialized derived-daily cell (ingest's own override write)."""
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
        "VALUES (%s, %s, %s, %s, %s::jsonb) "
        "ON CONFLICT (user_id, day, metric) DO UPDATE SET "
        "value = EXCLUDED.value, flags = EXCLUDED.flags",
        (user_id, day, metric, round(float(value), 4), json.dumps(flags)),
    )


def apply_daily_totals(cur: Cur, user_id: UUID, totals: list[DailyTotalIn]) -> int:
    """Override `steps_total` (+ `distance_m_daily`) in derived_daily with the
    strap's live 0x0016 totals. MUST run AFTER derive, which recomputes
    steps_total from the (possibly frozen/incomplete) per-minute sum — the strap
    counter is authoritative. Returns the number of days overridden."""
    applied = 0
    for total in totals:
        if total.steps is None:
            continue
        _upsert_derived(
            cur, user_id, total.day, "steps_total", float(total.steps), {"source": "strap_0x16"}
        )
        _apply_distance(cur, user_id, total)
        applied += 1
    return applied


def _apply_distance(cur: Cur, user_id: UUID, total: DailyTotalIn) -> None:
    """Set distance_m_daily from the reported metres, else recompute from the
    real step total × the stride stored on the derived row (steps changed)."""
    if total.distance_m is not None:
        _upsert_derived(
            cur,
            user_id,
            total.day,
            "distance_m_daily",
            float(total.distance_m),
            {"source": "strap_0x16"},
        )
        return
    cur.execute(
        "SELECT (flags->>'stride_m')::float FROM derived_daily "
        "WHERE user_id = %s AND day = %s AND metric = 'distance_m_daily'",
        (user_id, total.day),
    )
    stride = cur.fetchone()
    if stride and stride[0] and total.steps is not None:
        _upsert_derived(
            cur,
            user_id,
            total.day,
            "distance_m_daily",
            float(total.steps) * stride[0],
            {"source": "strap_0x16", "stride_m": stride[0]},
        )


def build_fresh_predicate(
    cur: Cur, user_id: UUID, sessions: list[SleepIn]
) -> Callable[[SleepIn], bool]:
    """A predicate that answers "is this session fresh?" — new, or within
    FRESH_WINDOW_DAYS of the batch's latest night. Captures the already-existing
    starts up front (one query) so re-pushed history is cheap to gate."""
    main_sleep = [s for s in sessions if s.kind != "nap"]
    existing: set[datetime] = set()
    if main_sleep:
        starts = [epoch_to_utc(s.start_ts) for s in main_sleep]
        cur.execute(
            "SELECT start_ts FROM sleep_session WHERE user_id = %s AND start_ts = ANY(%s)",
            (user_id, starts),
        )
        existing = {r[0] for r in cur.fetchall()}
    latest = max((epoch_to_utc(s.end_ts) for s in main_sleep), default=None)
    cutoff = (latest - timedelta(days=FRESH_WINDOW_DAYS)) if latest else None

    def _fresh(s: SleepIn) -> bool:
        start, end = epoch_to_utc(s.start_ts), epoch_to_utc(s.end_ts)
        return not (start in existing and cutoff is not None and end < cutoff)

    return _fresh
