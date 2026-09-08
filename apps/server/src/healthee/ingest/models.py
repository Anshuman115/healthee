"""Pydantic request models for POST /ingest/helio.

These mirror the mobile client's push body **exactly** (see the legacy Flutter
`helio_api.dart` `push()`), so the endpoint is wire-compatible with the app that
is already installed on the device. Every list defaults to empty and every
optional field defaults to `None` — a normal sync omits sections it has no data
for (e.g. no `profile` unless the profile is complete, no `daily_totals` unless
the strap reported them).

Metric-name policy (ported from the legacy ingest): the whitelist is enforced in
the upsert layer, NOT here — an unknown metric is coerce-dropped and counted
(`samples_rejected`), never a 422. That keeps a newer app that adds a metric
from failing its whole push against an older server.

## What these models REFUSE, and why a refusal beats a stored value

A metric NAME we do not know is dropped and counted, on purpose (above). A
metric VALUE that is not a number, or an instant that is not an instant, is a
**422 for the whole push** — the opposite treatment, for the opposite reason. An
unknown name is forward compatibility: the payload is well-formed and a newer app
is allowed to be ahead of us. A NaN is not ahead of anything. It reaches
`sample.value` as-is (`ingest/upsert.upsert_samples` casts and stores), and from
there into every baseline, TRIMP, recovery and VO2max window over that day, each
of which becomes NaN — with nothing in the row saying it was never a measurement.
The device can retry a refused upload; nobody can un-poison a stored one.

`read/gps_request.py` is the model this file was brought up to: a phone-supplied
payload bounded to the millimetre — `allow_inf_nan=False`, `max_length` on the
point list, ranges on the coordinates, and a validator requiring the points to lie
inside the window the caller declared. The strap payload is the product's PRIMARY
data source and had none of it.

The bounds themselves live in `core.bounds`, one definition each, because
`read/logs.py` writes into the same `weight_log` column from a different router.
"""

from __future__ import annotations

from datetime import date

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from healthee.core.bounds import (
    MAX_MAGNITUDE,
    MeasurementError,
    assert_plausible_weight_kg,
    event_instant,
)
from healthee.core.dob import assert_plausible_dob

# Canonical metric whitelist — the exact set the app maps its device series onto
# (`helio_api.dart` `_metricMap`). Anything else is dropped + counted by the
# upsert. Kept here because it is part of the payload contract.
ALLOWED_METRICS: frozenset[str] = frozenset(
    {
        "hr",
        "hrv",
        "spo2",
        "skin_temp_c",
        "respiratory_rate",
        "stress",
        "steps_per_minute",
    }
)


# ── the caps on the payload's lists ──────────────────────────────────────────
#
# Read off what the CLIENT actually sends, then given room, so no bound here can
# refuse a push the app makes: `apps/mobile/lib/data/store/push_reader.dart` pages
# samples at `kPushSampleLimit = 4000` and sends the other three unpaged because the
# 60-day local horizon holds "a few dozen of each". The caps are multiples of that,
# not guesses, and they exist because `HelioPayload`'s lists had no `max_length` at
# all while `emit_sleep_minutes` materialises one ROW PER MINUTE from the hypnogram.
_MAX_SAMPLES = 20_000
_MAX_SLEEP_SESSIONS = 200
_MAX_WORKOUTS = 500
_MAX_DAILY_TOTALS = 400

# A hypnogram is tens of segments; two thousand is far above any night and bounds the
# `generate_series` LOOP. `_MAX_SESSION_STAGE_MINUTES` bounds what that loop can
# EMIT — the two together are what turn "one request, tens of millions of rows" into
# a number an operator can hold in their head, and neither alone would: a cap on the
# loop count says nothing about a single enormous stage, and a cap on the minutes says
# nothing about ten thousand one-minute stages.
_MAX_STAGES = 2_000
_STAGE_ARITY = 3  # [startMs, endMs, type]

# One session's stages may not sum to more than a day of per-minute rows. A long night
# is ~12 h and a nap is minutes, so this is roughly double the largest real value and
# cannot refuse a recorded night.
#
# ⚠ There WAS a second bound here — a 24 h cap on any single stage — and it was
# removed as dead code, which is worth recording because it looked like defence in
# depth and was not. A stage's own span is added to `emitted`, so a stage longer than a
# day already pushes the session total past 1,440 on its own: the per-stage check could
# not fire on any payload the session check would let through. Its mutation survived,
# which is exactly what a guard that cannot fail looks like from the outside. One bound
# that binds beats two where one is decoration (standards, "Dead code").
_MAX_SESSION_STAGE_MINUTES = 1_440


class SampleIn(BaseModel):
    """One raw time-series point: {metric, ts (epoch ms), value}.

    `allow_inf_nan=False` is the load-bearing line: pydantic v2 defaults it to True and
    Python's `json` module parses the bare `NaN` / `Infinity` / `-Infinity` literals out
    of a request body, so all three used to reach `sample.value` unexamined.
    """

    model_config = ConfigDict(extra="ignore", allow_inf_nan=False)

    metric: str = Field(max_length=64)
    ts: int  # epoch milliseconds (seconds also tolerated downstream)
    value: float = Field(ge=-MAX_MAGNITUDE, le=MAX_MAGNITUDE)

    @field_validator("ts")
    @classmethod
    def _ts_is_a_plausible_event_instant(cls, ts: int) -> int:
        event_instant(ts)  # raises MeasurementError (a ValueError) → pydantic 422
        return ts


class SleepIn(BaseModel):
    """One sleep session. `stages` is the hypnogram [[startMs, endMs, type], …]
    (type 7 = awake); the per-minute stage/asleep stream is materialized from it
    for main sleep only.

    ## The stage minutes default to None, not 0

    They defaulted to `0`, and a default of zero on a MEASUREMENT is a lie the boundary
    tells the rest of the system: a payload that omitted the breakdown became a session
    that measured no REM, no light and no deep sleep, and every layer downstream then
    read that as a night of zero sleep — `duration_min` summed the three to nothing, the
    stacked chart painted four zero-height bars, and the client's fallback replaced a
    correct server withhold with the same zero.

    Validation at the boundary is what keeps a bad value out of the science layer
    (standards section 2), and a fabricated zero is a bad value. `None` here says what the
    payload said, and `0018` gave the columns somewhere to put it.

    ## The hypnogram is bounded the way `GpsTrackIn` bounds a route

    `ingest.upsert.emit_sleep_minutes` runs `generate_series(start, end, '1 minute')` on
    each stage, with nothing between the payload's numbers and that statement: one stage
    declaring a span of years materialised tens of millions of rows from one request.
    `read/gps_request.py` had already answered this exact shape for the phone's route
    upload — a capped list, and a validator requiring every point to lie inside the window
    the caller declared. Two checks do it here: an arity check (so `stages: [[]]` is a
    422 naming the field rather than an `IndexError` → 500), and a cap on the minutes
    one session may materialise in total.
    """

    model_config = ConfigDict(extra="ignore", allow_inf_nan=False)

    start_ts: int
    end_ts: int
    kind: str = Field(default="main", max_length=32)  # 'main' night sleep | 'nap'
    score: int | None = None
    avg_hr: int | None = None
    rem_min: int | None = None
    light_min: int | None = None
    deep_min: int | None = None
    wake_min: int | None = None
    stages: list[list[int]] = Field(default_factory=list, max_length=_MAX_STAGES)

    @field_validator("start_ts", "end_ts")
    @classmethod
    def _bounds_are_plausible_event_instants(cls, ts: int) -> int:
        event_instant(ts)
        return ts

    @model_validator(mode="after")
    def _the_hypnogram_is_bounded(self) -> SleepIn:
        emitted = 0
        for stage in self.stages:
            if len(stage) != _STAGE_ARITY:
                raise MeasurementError(
                    f"a hypnogram stage is [startMs, endMs, type]; got {len(stage)} value(s)"
                )
            start, end = event_instant(stage[0]), event_instant(stage[1])
            if end <= start:
                continue  # `emit_sleep_minutes` skips these; nothing is materialised
            emitted += int((end - start).total_seconds() // 60)
        if emitted > _MAX_SESSION_STAGE_MINUTES:
            raise MeasurementError(
                f"this session's stages would materialise {emitted} per-minute rows, over "
                f"the {_MAX_SESSION_STAGE_MINUTES} a single session may hold"
            )
        return self


class WorkoutIn(BaseModel):
    """One typed workout with device-measured HR/calories. `distance_m` is
    optional — the app's push omits it (schema keeps the column for other
    sources)."""

    model_config = ConfigDict(extra="ignore", allow_inf_nan=False)

    start_ts: int
    sport: int = 0
    # A workout cannot run for more than a week, and cannot run backwards; the derive
    # layer divides by this.
    duration_s: int = Field(default=0, ge=0, le=7 * 24 * 3600)
    calories: int | None = None
    distance_m: float | None = Field(default=None, ge=0, le=MAX_MAGNITUDE)
    avg_hr: int | None = None
    max_hr: int | None = None
    min_hr: int | None = None

    @field_validator("start_ts")
    @classmethod
    def _start_is_a_plausible_event_instant(cls, ts: int) -> int:
        event_instant(ts)
        return ts


class DailyTotalIn(BaseModel):
    """Live since-midnight totals the strap reports on BLE 0x0016 — the
    authoritative daily step count even when the per-minute stream is frozen.
    `day` is a local 'YYYY-MM-DD' date (the app formats it in the user's tz);
    pydantic parses the ISO string the app sends into a `date`.

    This is a RAW measurement and since #121 it has a raw home: `upsert_daily_totals`
    stores it in `device_daily_total` and `derive/device_totals.py` decides what
    `steps_total` becomes from it. Before that it went from this model straight into a
    derived cell and nowhere else, so the next derive pass over the day erased it.

    ## `read_at` — WHEN the counter was read, and why absent must stay absent

    A since-midnight counter is a claim about the interval from local midnight to the
    moment it was READ. The phone has always known that instant (`readAtMs`, and its own
    table comment says why: *"a counter read at 09:00 is a claim about nine hours"*) and
    this model had no field for it, so `ingest/upsert.py` supplied `now()` — the ARRIVAL
    instant — and the owner-facing partial-day caveat quoted that. Worse, the caveat's
    gate compared the arrival against the day's end, so a push crossing local midnight
    suppressed a true caveat entirely (write-path audit A1).

    It is OPTIONAL and must remain optional. An older app build does not send it, and the
    honest reading of a missing `read_at` is **unknown**, never "now" and never "after the
    day closed". `derive/device_totals.partial_day_caveats` says so on the wire rather
    than guessing, which is the whole point of adding the field."""

    model_config = ConfigDict(extra="ignore", allow_inf_nan=False)

    day: date  # app sends 'YYYY-MM-DD'; parsed to a date here
    # A since-midnight accumulator cannot run backwards, and the magnitude cap is the
    # generic one: none of the three is a physiological claim, they are counters.
    steps: int | None = Field(default=None, ge=0, le=MAX_MAGNITUDE)
    distance_m: float | None = Field(default=None, ge=0, le=MAX_MAGNITUDE)
    calories: float | None = Field(default=None, ge=0, le=MAX_MAGNITUDE)
    # Epoch ms, range-checked by the one `event_instant` gate every other instant on this
    # wire goes through. Absent = unknown; see the class docstring.
    read_at: int | None = None

    @field_validator("read_at")
    @classmethod
    def _read_at_is_a_plausible_event_instant(cls, ts: int | None) -> int | None:
        if ts is not None:
            event_instant(ts)  # raises MeasurementError (a ValueError) → pydantic 422
        return ts


class ProfileIn(BaseModel):
    """The single user's profile. `weight_kg` feeds the one-per-day weight log.
    All optional — the app only sends a complete profile, but the server upserts
    whatever is present.

    `dob` is an ISO `YYYY-MM-DD` string (preferred) or epoch ms anchored at local
    midnight in the owner's timezone (the installed app's contract). It is kept
    RAW here and converted by `upsert_profile` via `core.dob.parse_dob`, because
    the ms→date answer depends on the owner's timezone and this model is built at
    the HTTP boundary, where the body is parsed before the owner is in scope.
    Converting here would have to guess a zone — that guess (UTC) is the bug this
    contract now exists to prevent.

    What DOES happen here is the coarse plausibility gate
    (`core.dob.assert_plausible_dob`), so an impossible value is a 422 — a client
    error, which it is — rather than a 500 or a silently-wrong age.
    """

    model_config = ConfigDict(extra="ignore", allow_inf_nan=False)

    name: str | None = Field(default=None, max_length=200)
    height_cm: float | None = Field(default=None, gt=0, le=300)
    sex: str | None = Field(default=None, max_length=32)
    dob: int | str | None = None  # ISO date, or epoch ms — see core.dob.parse_dob()
    weight_kg: float | None = None
    # Jurca 2005's five-level SELF-REPORTED physical-activity category, answered by the
    # owner (#108). Bounded here rather than only at the CHECK constraint so an
    # out-of-range value is a 422 naming the field, not a 500 from the database.
    srpa: int | None = Field(default=None, ge=0, le=4)

    @field_validator("dob")
    @classmethod
    def _dob_is_a_plausible_birth_date(cls, dob: int | str | None) -> int | str | None:
        if dob is not None:
            assert_plausible_dob(dob)  # raises ValueError → pydantic 422
        return dob

    @field_validator("weight_kg")
    @classmethod
    def _weight_is_a_body_mass(cls, kg: float | None) -> float | None:
        """The same gate `read/logs.py` applies — both write `weight_log.kg`.

        `numeric(5,2)` means an unbounded float is a database error before it is
        anything else, and weight feeds BMI, VO2max and biological age.
        """
        if kg is not None:
            assert_plausible_weight_kg(kg)  # raises MeasurementError → pydantic 422
        return kg


class HelioPayload(BaseModel):
    """The full POST /ingest/helio body. Matches `helio_api.dart` push().

    Every list is capped. They were not, and `emit_sleep_minutes` turns the `sleep`
    list into one database row per minute per stage, so "no cap" meant one authenticated
    request could spend unbounded disk and time. See the caps' own comment above for
    where each number comes from — the client's real page sizes, not a guess.
    """

    model_config = ConfigDict(extra="ignore")

    samples: list[SampleIn] = Field(default_factory=list, max_length=_MAX_SAMPLES)
    sleep: list[SleepIn] = Field(default_factory=list, max_length=_MAX_SLEEP_SESSIONS)
    workouts: list[WorkoutIn] = Field(default_factory=list, max_length=_MAX_WORKOUTS)
    daily_totals: list[DailyTotalIn] = Field(default_factory=list, max_length=_MAX_DAILY_TOTALS)
    profile: ProfileIn | None = None
