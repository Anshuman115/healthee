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

from datetime import UTC, date, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

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


# The plausibility window for a birth date. Nobody alive was born before this,
# and nobody is born in the future — anything outside is a mis-scaled or corrupt
# value, not a person. `dob` feeds `_age()` → biological age, VO2max (Jurca) and
# sleep need/debt, so an out-of-range value must be REJECTED, never stored.
DOB_MIN_DATE = date(1900, 1, 1)


def dob_ms_to_date(dob_ms: int) -> date:
    """Epoch **milliseconds** → birth date, per the `ProfileIn.dob` contract.

    Do NOT route a dob through `ingest.upsert.epoch_to_utc`: its magnitude guess
    can only disambiguate instants after 2001-09-09, so it reads every earlier
    birth date (a small ms number) as seconds — 1970-02-03 became 2060-05-08,
    stored silently, poisoning every age-dependent science output.

    There is deliberately **no seconds fallback**, because the ambiguity is
    unresolvable by construction: 1_470_000_000 is a plausible birth date both as
    ms (1970-01-18) and as seconds (2016-08-01). No magnitude test can separate
    those, so any guess would silently pick a wrong age for a real person. The
    contract says milliseconds; we parse milliseconds, validate the outcome, and
    reject what is not a possible human birth date.

    Raises ValueError if the value is out of range (→ 422 at the boundary).
    """
    try:
        parsed = datetime.fromtimestamp(dob_ms / 1000, tz=UTC).date()
    except (ValueError, OverflowError, OSError) as exc:
        raise ValueError(f"dob must be epoch milliseconds; {dob_ms} is out of range") from exc
    today = datetime.now(UTC).date()
    if parsed < DOB_MIN_DATE or parsed > today:
        raise ValueError(
            f"dob must be epoch milliseconds between {DOB_MIN_DATE.isoformat()} and today; "
            f"{dob_ms} parses to {parsed.isoformat()}"
        )
    return parsed


class ProfileIn(BaseModel):
    """The single user's profile. `dob` is epoch ms; `weight_kg` feeds the
    one-per-day weight log. All optional — the app only sends a complete
    profile, but the server upserts whatever is present.

    `dob` is validated HERE, at the data boundary, so an implausible value is a
    422 (a client error, which it is) rather than a 500 or a silently-wrong age.
    """

    model_config = ConfigDict(extra="ignore")

    name: str | None = None
    height_cm: float | None = None
    sex: str | None = None
    dob: int | None = None  # epoch milliseconds — see dob_ms_to_date()
    weight_kg: float | None = None

    @field_validator("dob")
    @classmethod
    def _dob_is_a_plausible_birth_date(cls, dob_ms: int | None) -> int | None:
        if dob_ms is not None:
            dob_ms_to_date(dob_ms)  # raises ValueError → pydantic 422
        return dob_ms


class HelioPayload(BaseModel):
    """The full POST /ingest/helio body. Matches `helio_api.dart` push()."""

    model_config = ConfigDict(extra="ignore")

    samples: list[SampleIn] = Field(default_factory=list)
    sleep: list[SleepIn] = Field(default_factory=list)
    workouts: list[WorkoutIn] = Field(default_factory=list)
    daily_totals: list[DailyTotalIn] = Field(default_factory=list)
    profile: ProfileIn | None = None
