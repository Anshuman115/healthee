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
from datetime import date, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from psycopg import Cursor
from psycopg.rows import TupleRow

from healthee.core.bounds import assert_plausible_weight_kg, event_instant
from healthee.core.dob import parse_dob
from healthee.core.logging import get_logger
from healthee.ingest.models import (
    ALLOWED_METRICS,
    ProfileIn,
    SampleIn,
    SleepIn,
    WorkoutIn,
)

Cur = Cursor[TupleRow]

log = get_logger(__name__)

# A main-sleep session is "fresh" (worth the per-minute emit) if it is new or
# within this many days of the batch's latest night. Re-emitting per-minute rows
# for old, unchanged sessions on every push is pure waste (idempotent inserts
# that already exist) and was a big chunk of the legacy push time.
FRESH_WINDOW_DAYS = 3


def epoch_to_utc(ts: int) -> datetime:
    """Event epoch milliseconds (or seconds) → aware UTC datetime, RANGE-CHECKED.

    EVENT TIMESTAMPS ONLY. The ms/seconds magnitude guess can only disambiguate
    instants after 2001-09-09; below that it silently reads milliseconds as seconds.
    That is safe for device events, which are always recent, and WRONG for any
    historical date. NEVER call this on a birth date — use `core.dob.parse_dob`, which
    parses the documented contract in the OWNER's timezone (a birth date is a calendar
    date, and the app anchors it at local midnight).

    This is now a one-line delegation to `core.bounds.event_instant`, which is where
    the conversion AND its range check live. It used to be the conversion alone, with
    the docstring careful and correct about the ms/seconds ambiguity and silent about
    range: a value outside the platform's `datetime` range raised out of an ingest
    handler as a 500 (blaming the server for a client's number), and a value inside it
    but far from now wrote a `sample` row dated centuries away that every window and
    baseline downstream then had to cope with. Kept as a named function because it is
    what the whole ingest layer already calls — moving the check under it is what makes
    the guarantee structural instead of a rule five call sites have to remember.
    """
    return event_instant(ts)


def local_date(ts: int, tz: str) -> date:
    """The owner-local calendar date an epoch-ms timestamp falls on."""
    return epoch_to_utc(ts).astimezone(ZoneInfo(tz)).date()


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
    minutes must not pollute the night-only SRI/regularity reads.

    ## Every optional measurement is COALESCEd, so a partial re-push cannot erase one

    The conflict branch was a plain `col = EXCLUDED.col` on every column. A re-push of an
    existing key that omitted a field therefore replaced a measured value with the model's
    default — which, before `0018`, was `0` for all four stage minutes. The shipped client
    always sends complete records, so this was latent rather than live; it is fixed anyway
    because `/ingest/helio` is reachable by any device token including an older app build,
    and because it is the mechanism by which A5's zeros could overwrite a night that had
    been recorded correctly.

    The team had already identified and fixed this exact class one table over —
    `upsert_profile` COALESCEs `srpa` "so a plain assignment would let the next routine
    sync from an un-updated app NULL out an answer the owner had given" — and did not carry
    it across. It is carried across now, here and in `upsert_workouts` and
    `upsert_daily_totals`.

    `end_ts` and `kind` are NOT coalesced: they are required on the model, so `EXCLUDED`
    always carries a real value and coalescing would only hide a future mistake.
    """
    for s in sessions:
        cur.execute(
            "INSERT INTO sleep_session "
            "(user_id, start_ts, end_ts, kind, score, avg_hr, rem_min, light_min, deep_min, "
            "wake_min, stages) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb) "
            "ON CONFLICT (user_id, start_ts) DO UPDATE SET "
            "end_ts = EXCLUDED.end_ts, kind = EXCLUDED.kind, "
            "score = COALESCE(EXCLUDED.score, sleep_session.score), "
            "avg_hr = COALESCE(EXCLUDED.avg_hr, sleep_session.avg_hr), "
            "rem_min = COALESCE(EXCLUDED.rem_min, sleep_session.rem_min), "
            "light_min = COALESCE(EXCLUDED.light_min, sleep_session.light_min), "
            "deep_min = COALESCE(EXCLUDED.deep_min, sleep_session.deep_min), "
            "wake_min = COALESCE(EXCLUDED.wake_min, sleep_session.wake_min), "
            # The hypnogram is NOT NULL DEFAULT '[]', so an omitted `stages` arrives as an
            # empty array rather than a null and COALESCE cannot see it. Tested for
            # emptiness instead: a re-push carrying no hypnogram keeps the stored one.
            "stages = CASE WHEN jsonb_array_length(EXCLUDED.stages) > 0 "
            "THEN EXCLUDED.stages ELSE sleep_session.stages END",
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
    """Upsert typed workouts with device-measured HR/calories/distance.

    Every nullable measurement is COALESCEd for the reason `upsert_sleep` gives: a partial
    re-push must not replace a recorded figure with the model's default. `sport` and
    `duration_s` default to `0` on `WorkoutIn` rather than to None, so they cannot be
    distinguished from a genuine zero here and are assigned; the fix for that is a model
    change, not a COALESCE that would silently pin the first value ever pushed.
    """
    for w in workouts:
        cur.execute(
            "INSERT INTO workout "
            "(user_id, start_ts, sport, duration_s, calories, distance_m, avg_hr, max_hr, min_hr) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) "
            "ON CONFLICT (user_id, start_ts) DO UPDATE SET "
            "sport = EXCLUDED.sport, duration_s = EXCLUDED.duration_s, "
            "calories = COALESCE(EXCLUDED.calories, workout.calories), "
            "distance_m = COALESCE(EXCLUDED.distance_m, workout.distance_m), "
            "avg_hr = COALESCE(EXCLUDED.avg_hr, workout.avg_hr), "
            "max_hr = COALESCE(EXCLUDED.max_hr, workout.max_hr), "
            "min_hr = COALESCE(EXCLUDED.min_hr, workout.min_hr)",
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


def upsert_profile(cur: Cur, user_id: UUID, tz: str, profile: ProfileIn) -> None:
    """Upsert `user_id`'s profile row. `name` is preserved when the push omits it.

    The OWNER is the conflict target (0005 re-keyed the table to `user_id`), which is
    what makes this write tenant-safe: the old target was `(id)` against the single
    `id = 1` row, so any owner's push updated the demographics of whoever held that
    row — B silently overwriting A's height/sex/dob while the row stayed owned by A.
    Conflicting on the owner means a push can only ever reach that owner's own row.

    Weight is handled by `upsert_weight` (it is a time series, not a profile field).

    `dob` is converted HERE, not at the boundary, because this is the first point
    that knows `tz` — the owner's timezone, which is what the app's epoch-ms dob
    is anchored to (local midnight). Resolving it in UTC instead is what stored
    the owner's birthday one day early in prod. `parse_dob` is the one canonical
    conversion (it also handles the ISO form and rejects implausible values, so a
    non-HTTP caller that skipped `ProfileIn`'s gate still cannot store a wrong
    age); it is NOT `epoch_to_utc`, whose magnitude guess inverts for pre-2001
    birth dates.
    """
    dob = parse_dob(profile.dob, tz) if profile.dob is not None else None
    cur.execute(
        "INSERT INTO profile (user_id, name, height_cm, sex, dob, srpa, updated_at) "
        "VALUES (%s, %s, %s, %s, %s, %s, now()) "
        "ON CONFLICT (user_id) DO UPDATE SET "
        "name = COALESCE(EXCLUDED.name, profile.name), height_cm = EXCLUDED.height_cm, "
        # `srpa` is COALESCEd like `name`, not overwritten like the demographics (#108).
        # Every existing client builds this payload without the field, so a plain
        # assignment would let the next routine sync from an un-updated app NULL out an
        # answer the owner had given — silently withdrawing their own VO₂max. Clearing it
        # deliberately is not a thing any surface offers, so nothing loses by this.
        "sex = EXCLUDED.sex, dob = EXCLUDED.dob, "
        "srpa = COALESCE(EXCLUDED.srpa, profile.srpa), updated_at = now()",
        (user_id, profile.name, profile.height_cm, profile.sex, dob, profile.srpa),
    )


# Below this, two weights are the same reading: `weight_log.kg` is numeric(5,2) and the
# app sends one decimal, so this is a float-comparison epsilon, not a tolerance.
_WEIGHT_SAME_KG = 0.01


def upsert_weight(cur: Cur, user_id: UUID, tz: str, weight_kg: float) -> None:
    """Record body weight — a new row only when the value actually CHANGED.

    ## Why this compares against the newest row ever, not the newest row today

    The app's profile push carries whatever weight it currently holds, on every sync,
    and `read/history.py::profile` hands that weight straight back so a reinstall can
    restore it. So an unchanged weight is re-pushed indefinitely. This function used to
    dedupe within the local day only, which meant each new day's first sync INSERTED the
    same number again at `now()`.

    That is not a cosmetic duplicate — it is a laundry. It resets the weight's age to
    zero every day, so a mass the owner last actually measured months ago reads as
    measured today, and any freshness gate downstream (`derive.freshness.weight_is_stale`
    → BMI → VO₂max → biological age) can never fire. **Measured in the 2026-07-15 prod
    dump**: 41 `weight_log` rows across six weeks, every one of them 79.9 kg except a
    single 79.8, one per sync day. The owner weighed themselves about twice; the table
    claims they weighed themselves daily.

    The cost of the fix, stated plainly: an owner who genuinely re-weighs and lands on
    the identical number does not refresh their weight's age, so the gate can fire on a
    weight that IS current. That failure is rare, visible, and cleared by logging any
    different value. The one it replaces was silent, universal and permanent — and it
    errs toward refusing rather than toward a confident stale number, which is the
    direction this product errs on purpose.
    """
    # Re-asserted here, not only on `ProfileIn`: this function is the ONE writer of
    # `weight_log.kg` from the ingest path, and a non-HTTP caller that skipped the model
    # must not be able to store a mass that is not one. Same argument `upsert_profile`
    # makes for re-parsing `dob` canonically rather than trusting the boundary.
    kg = assert_plausible_weight_kg(float(weight_kg))
    cur.execute(
        "SELECT ts, kg, (ts AT TIME ZONE %s)::date = (now() AT TIME ZONE %s)::date "
        "FROM weight_log WHERE user_id = %s ORDER BY ts DESC LIMIT 1",
        (tz, tz, user_id),
    )
    row = cur.fetchone()
    if row is not None and abs(float(row[1]) - kg) <= _WEIGHT_SAME_KG:
        return  # not a new measurement; re-stamping it would launder the weight's age
    if row is not None and row[2]:  # a real correction to today's entry
        cur.execute(
            "UPDATE weight_log SET kg = %s WHERE user_id = %s AND ts = %s", (kg, user_id, row[0])
        )
    else:
        cur.execute(
            "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, now(), %s)", (user_id, kg)
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
