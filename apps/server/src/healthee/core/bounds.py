"""The plausibility gates the HTTP boundary applies to a *measured* value.

Standards section 2: "Request bodies are ALWAYS pydantic models — validation at the
boundary is what keeps a bad value out of the science layer." This module is the
canonical set of those checks for the three things a device or a phone sends us that
are numbers rather than text: a magnitude, an instant, and a body mass. One definition
each, so `ingest/` and `read/` cannot disagree about what is physically possible.

## Why REJECT and not sanitise

A rejected upload is retried by the device; a sanitised one is stored, and once it is
stored nobody can tell it from a measurement. That asymmetry is the whole argument.
A NaN reaching `sample.value` propagates: every mean, baseline, TRIMP and VO2max
window that touches the day becomes NaN, and it serialises back out as invalid JSON.
There is no downstream layer that can undo it, because there is no marker saying the
row was never real.

`core.dob` is the sibling this is modelled on — `assert_plausible_dob` exists so an
impossible birth date is a 422 naming the field rather than a 500 or a silently wrong
age. Same shape, same reason, for the values that arrive every minute instead of once.

## What these bounds are NOT

They are **not** physiological ranges, and deliberately so. "Is 210 bpm a real heart
rate" is a science question, it belongs in `packages/knowledge` with a note behind it,
and a range invented here would be an un-cited claim about human physiology enforced
in code — exactly what the honesty contract forbids. What is enforced here is only
what no measurement of anything can be: not a number at all, outside the range the
conversion can even represent, or a mass no human body has. A value inside these
bounds and outside physiology is still stored, and that is correct: it is the science
layer's job to judge it, and `derive/` can see the row it is judging.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

# ── magnitude ────────────────────────────────────────────────────────────────
#
# Every metric in `ingest.models.ALLOWED_METRICS` is a small number: heart rate and
# HRV in the tens, SpO2 a percentage, skin temperature in degrees Celsius, respiratory
# rate in the tens, stress a score, steps-per-minute at a human maximum near 300. A
# million is four orders of magnitude above the largest of them, so this cannot refuse
# a measurement of anything the strap reports — and it does stop the two values that
# have no honest reading at all: a magnitude that dominates every mean it enters, and
# (via `allow_inf_nan=False` on the models) NaN and the infinities.
MAX_MAGNITUDE = 1e6


class MeasurementError(ValueError):
    """A value at the boundary that no measurement can have.

    A `ValueError`, so a pydantic validator turns it into a 422 naming the field.
    Named as its own type so `api.app` can map it to a 422 even when it is raised
    below the model — the same reason `core.dob.DobError` exists.
    """


# ── event instants ───────────────────────────────────────────────────────────
#
# Above this an integer is read as epoch MILLISECONDS, at or below it as SECONDS.
_MS_THRESHOLD = 10**12

# The floor is not a policy, it is the exact point at which the ms/seconds magnitude
# guess INVERTS — DERIVED from the threshold rather than written out, so the two cannot
# drift apart. `_MS_THRESHOLD` ms after the epoch is 2001-09-09T01:46:40Z; any earlier
# instant expressed in milliseconds is a small enough integer to be read as seconds.
# An event before it therefore cannot be parsed unambiguously, and the honest answer to
# an unparseable instant is to refuse it, not to guess — which is what storing it
# silently amounts to. A seconds-encoded RECENT timestamp (1.7e9, say) is far below the
# threshold as an integer and far above this floor as an instant, which is the whole
# point: the bound is on the resolved instant, never on the raw number.
EVENT_TS_MIN = datetime.fromtimestamp(_MS_THRESHOLD / 1000, tz=UTC)

# The ceiling is a device clock, not a calendar. Straps drift and phones hand us their
# own idea of now, so a little slack is real; a week is far more than any skew we have
# seen and still refuses the row dated centuries ahead that every window and baseline
# downstream then has to cope with. `core.dob._TZ_SLACK` makes the same argument at a
# day, for a value that arrives once instead of every minute.
EVENT_TS_FUTURE_SLACK = timedelta(days=7)


def event_instant(ts: int, *, now: datetime | None = None) -> datetime:
    """Event epoch milliseconds (or seconds) → an aware UTC datetime, or raise.

    EVENT TIMESTAMPS ONLY. The magnitude guess can only disambiguate instants after
    `EVENT_TS_MIN`; below that it silently reads milliseconds as seconds. That is safe
    for device events, which are always recent, and WRONG for any historical date.
    NEVER call this on a birth date — use `core.dob.parse_dob`, which parses the
    documented contract in the OWNER's timezone.

    The range check is HERE rather than in each caller's model because this is the one
    conversion every ingest path shares, and a bound that has to be remembered at five
    call sites is a bound that is missing at the sixth. It is also what stops the raw
    `OverflowError`/`OSError`/`ValueError` that `datetime.fromtimestamp` raises for an
    out-of-range number — a 500 blaming the server for a client's value, the same lie
    `api.app._dob_error_is_a_client_error` was written to fix for `dob`.
    """
    seconds = ts / 1000 if ts > _MS_THRESHOLD else ts
    try:
        when = datetime.fromtimestamp(seconds, tz=UTC)
    except (OverflowError, OSError, ValueError) as exc:
        raise MeasurementError(f"timestamp {ts} is outside the representable range") from exc
    ceiling = (now or datetime.now(tz=UTC)) + EVENT_TS_FUTURE_SLACK
    if when < EVENT_TS_MIN or when > ceiling:
        raise MeasurementError(
            f"timestamp {ts} resolves to {when.isoformat()}, which is not a plausible "
            f"instant for a measured event (expected between {EVENT_TS_MIN.isoformat()} "
            f"and about a week from now)"
        )
    return when


def assert_finite_magnitude(value: float, field: str) -> float:
    """Return `value` if it is a number a measurement could be; raise otherwise.

    `float('nan') != float('nan')`, which is how the NaN test below reads: it is the
    one comparison NaN fails against itself, and it is deliberate rather than an
    idiom — pydantic's `allow_inf_nan=False` covers the models, and this covers every
    caller that reaches a bound without one.
    """
    if value != value or value in (float("inf"), float("-inf")):  # noqa: PLR0124 — NaN test
        raise MeasurementError(f"{field} must be a real number, not {value!r}")
    if abs(value) > MAX_MAGNITUDE:
        raise MeasurementError(
            f"{field} is {value!r}, which is beyond {MAX_MAGNITUDE:g} — no measurement "
            f"this API accepts has that magnitude"
        )
    return value


# ── body mass ────────────────────────────────────────────────────────────────
#
# `weight_log.kg` is `numeric(5,2)`, so 1000 kg is a database error — a 500 for a
# client's number — before it is anything else. These bounds sit inside that and are
# a plausibility gate of the same kind as `assert_plausible_dob`: the lightest and
# heaviest human masses ever recorded are comfortably inside them, so this refuses
# only what is not a person's weight. Weight feeds BMI, VO2max and biological age;
# `derive.freshness` already withholds biological age on a weight that is merely
# STALE, and a weight that is not a weight would be worse than stale.
MIN_WEIGHT_KG = 10.0
MAX_WEIGHT_KG = 700.0


def assert_plausible_weight_kg(kg: float) -> float:
    """Return `kg` if it could be a human body mass; raise `MeasurementError` if not."""
    assert_finite_magnitude(kg, "weight_kg")
    if not (MIN_WEIGHT_KG <= kg <= MAX_WEIGHT_KG):
        raise MeasurementError(
            f"weight {kg} kg is outside {MIN_WEIGHT_KG:g}–{MAX_WEIGHT_KG:g} kg, which is "
            f"not a body mass — it feeds BMI, VO2max and biological age"
        )
    return kg


__all__ = [
    "EVENT_TS_FUTURE_SLACK",
    "EVENT_TS_MIN",
    "MAX_MAGNITUDE",
    "MAX_WEIGHT_KG",
    "MIN_WEIGHT_KG",
    "MeasurementError",
    "assert_finite_magnitude",
    "assert_plausible_weight_kg",
    "event_instant",
]
