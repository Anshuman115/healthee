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
"""

from __future__ import annotations

from datetime import date

from pydantic import BaseModel, ConfigDict, Field, field_validator

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


class SampleIn(BaseModel):
    """One raw time-series point: {metric, ts (epoch ms), value}."""

    model_config = ConfigDict(extra="ignore")

    metric: str
    ts: int  # epoch milliseconds (seconds also tolerated downstream)
    value: float


class SleepIn(BaseModel):
    """One sleep session. `stages` is the hypnogram [[startMs, endMs, type], …]
    (type 7 = awake); the per-minute stage/asleep stream is materialized from it
    for main sleep only."""

    model_config = ConfigDict(extra="ignore")

    start_ts: int
    end_ts: int
    kind: str = "main"  # 'main' night sleep | 'nap'
    score: int | None = None
    avg_hr: int | None = None
    rem_min: int = 0
    light_min: int = 0
    deep_min: int = 0
    wake_min: int = 0
    stages: list[list[int]] = Field(default_factory=list)


class WorkoutIn(BaseModel):
    """One typed workout with device-measured HR/calories. `distance_m` is
    optional — the app's push omits it (schema keeps the column for other
    sources)."""

    model_config = ConfigDict(extra="ignore")

    start_ts: int
    sport: int = 0
    duration_s: int = 0
    calories: int | None = None
    distance_m: float | None = None
    avg_hr: int | None = None
    max_hr: int | None = None
    min_hr: int | None = None


class DailyTotalIn(BaseModel):
    """Live since-midnight totals the strap reports on BLE 0x0016 — the
    authoritative daily step count even when the per-minute stream is frozen.
    `day` is a local 'YYYY-MM-DD' date (the app formats it in the user's tz);
    pydantic parses the ISO string the app sends into a `date`."""

    model_config = ConfigDict(extra="ignore")

    day: date  # app sends 'YYYY-MM-DD'; parsed to a date here
    steps: int | None = None
    distance_m: float | None = None
    calories: float | None = None


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

    model_config = ConfigDict(extra="ignore")

    name: str | None = None
    height_cm: float | None = None
    sex: str | None = None
    dob: int | str | None = None  # ISO date, or epoch ms — see core.dob.parse_dob()
    weight_kg: float | None = None

    @field_validator("dob")
    @classmethod
    def _dob_is_a_plausible_birth_date(cls, dob: int | str | None) -> int | str | None:
        if dob is not None:
            assert_plausible_dob(dob)  # raises ValueError → pydantic 422
        return dob


class HelioPayload(BaseModel):
    """The full POST /ingest/helio body. Matches `helio_api.dart` push()."""

    model_config = ConfigDict(extra="ignore")

    samples: list[SampleIn] = Field(default_factory=list)
    sleep: list[SleepIn] = Field(default_factory=list)
    workouts: list[WorkoutIn] = Field(default_factory=list)
    daily_totals: list[DailyTotalIn] = Field(default_factory=list)
    profile: ProfileIn | None = None
