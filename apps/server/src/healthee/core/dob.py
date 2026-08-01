"""The `dob` wire contract — the ONE canonical conversion between a birth date
and the values a client may send for it.

**A date of birth is a calendar DATE, not an instant.** It has no time and no
timezone: "1994-07-01" is the same birthday in Kolkata and in New York. The
installed app nevertheless sends it as epoch milliseconds
(`helio_api.dart` — `'dob': profile.dob!.millisecondsSinceEpoch`), which forces
a date onto an instant and makes the anchor question unavoidable: *midnight
WHERE?*

The answer, established from the sender: a Dart `DateTime` from the app's date
picker is **local**, so `DateTime(1994, 7, 1)` on an IST device is
`1994-07-01T00:00+05:30` = 773001000000 ms = `1994-06-30T18:30Z`. The wire value
is **local midnight in the owner's timezone**, and resolving it in UTC lands one
day early — which is exactly what prod stored (owner's dob `1994-06-30`; true
value `1994-07-01`).

So the ms path resolves in the OWNER's timezone (`app_user.timezone`, live since
6.4). The encode half (`date_to_dob_ms`) is the exact inverse and MUST stay that
way: the app reads a dob back with `DateTime.fromMillisecondsSinceEpoch` (also
local) and re-pushes it, so an encoder anchored to a different zone than the
decoder makes the round-trip lossy — see the ratchet note on `date_to_dob_ms`.

The ISO path (`"1994-07-01"`) is the preferred contract and the one the Phase-2
app should speak: it carries no instant, so it cannot be anchored wrongly by
anyone. It is what the legacy system used end-to-end (`profile.py` —
`dob.isoformat()`) and it never had this bug. The epoch-ms path exists only for
the client already installed in prod.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

# The plausibility window for a birth date. Nobody alive was born before this,
# and nobody is born in the future — anything outside is a mis-scaled or corrupt
# value, not a person. `dob` feeds `_age()` → biological age, VO2max (Jurca) and
# sleep need/debt, so an out-of-range value must be REJECTED, never stored.
DOB_MIN_DATE = date(1900, 1, 1)


class DobError(ValueError):
    """A `dob` this contract cannot accept — always the CLIENT's error, never ours.

    A subclass rather than a bare `ValueError` for exactly one reason: it is the only
    thing that lets the HTTP layer answer 422 without a blanket `except ValueError`
    around the ingest, which would relabel every genuine internal failure as a client
    mistake. `api/app.py` registers the one handler; see `assert_plausible_dob` for the
    gap it closes (#57).

    It stays a `ValueError` so every existing caller and test that expects one — and
    pydantic's field validator, which converts `ValueError` into a 422 — is unaffected.
    """


# No IANA zone shifts a calendar date by more than one day either way (the real
# range is UTC-12..UTC+14). The HTTP-boundary check does not know the owner's
# timezone, so it widens the bounds by this much and lets the canonical parse
# apply the exact test once the owner IS known. See `assert_plausible_dob`.
_TZ_SLACK = timedelta(days=1)


def parse_dob(value: int | str, tz: str) -> date:
    """A client's `dob` → the owner's birth **date**. The canonical conversion.

    `value` is either an ISO `YYYY-MM-DD` string (preferred — unambiguous) or
    epoch **milliseconds** anchored at local midnight in `tz` (the installed
    app's contract).

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

    Raises ValueError if the value is malformed or out of range (→ 422 at the
    boundary).
    """
    parsed = _iso_to_date(value) if isinstance(value, str) else _ms_to_date(value, tz)
    return _reject_implausible(parsed, value)


def date_to_dob_ms(dob: date, tz: str) -> int:
    """A birth date → the epoch ms the installed app expects: **local midnight
    in `tz`**. The exact inverse of `parse_dob`'s ms path.

    Anchoring this to UTC instead is not a cosmetic mismatch, it corrupts data.
    The app does `DateTime.fromMillisecondsSinceEpoch` (LOCAL) on read and
    `.millisecondsSinceEpoch` on write, and `getProfile()` exists to restore the
    profile after a reinstall — so whatever we emit is re-pushed verbatim. Emit
    UTC midnight to a negative-offset owner (New York, -04:00) and the app
    resolves it to the PREVIOUS day 20:00, shows the wrong birthday, pushes it
    back, and the stored date moves one day earlier — again on every sync. It
    ratchets. Local midnight round-trips exactly, in every zone.
    """
    return int(datetime(dob.year, dob.month, dob.day, tzinfo=ZoneInfo(tz)).timestamp() * 1000)


def assert_plausible_dob(value: int | str) -> None:
    """Reject an impossible `dob` at the HTTP boundary, where the owner's
    timezone is not yet known (auth resolves the owner; the body is validated
    before the upsert ever sees it).

    This is the coarse gate: it catches mis-scaled and corrupt values (year
    22298, a silent 2060, anything pre-1900) so they are a 422 — a client error,
    which is what they are — rather than a 500 or a silently-wrong age.

    Only the **ms** path needs slack, and only because it is the anchored one: its
    date is not knowable without the owner's zone, so the bounds widen by
    `_TZ_SLACK` here and `parse_dob` applies the exact test in the upsert once the
    owner IS known — one canonical test, not two. The cost is a one-day gap: a ms
    dob implausible by less than a day (e.g. "tomorrow") passes here and raises in
    the upsert instead.

    That gap used to be a **500** (#57 — measured, not assumed: `_utc_ms(tomorrow)`
    from an IST owner returns 500 today). The slack is not the bug — it is load-
    bearing, because this gate cannot know the owner's zone and must not reject a
    value that is fine once the real zone is applied. The bug was the STATUS: a
    rejected client value reported as a server fault. `DobError` + the handler in
    `api/app.py` make it the 422 it always was, wherever the exact test runs.

    The **ISO** path carries no instant and so has nothing to be ambiguous about:
    it gets the exact bounds right here, and always 422s. One more reason it is
    the preferred contract.
    """
    if isinstance(value, str):
        _reject_implausible(_iso_to_date(value), value)
    else:
        _reject_implausible(_ms_to_date(value, "UTC"), value, slack=_TZ_SLACK)


def _ms_to_date(dob_ms: int, tz: str) -> date:
    """Epoch ms → the calendar date that instant falls on in `tz`."""
    try:
        return datetime.fromtimestamp(dob_ms / 1000, tz=ZoneInfo(tz)).date()
    except (ValueError, OverflowError, OSError) as exc:
        raise DobError(f"dob must be epoch milliseconds; {dob_ms} is out of range") from exc


def _iso_to_date(value: str) -> date:
    """An ISO `YYYY-MM-DD` string → date. No instant, so no anchor to get wrong.

    `date.fromisoformat` (not `datetime.fromisoformat`) on purpose: it accepts a
    date and nothing else, so a client cannot smuggle a time or an offset in and
    reintroduce the anchoring question this path exists to remove.
    """
    try:
        return date.fromisoformat(value)
    except ValueError as exc:
        raise DobError(f"dob must be an ISO date (YYYY-MM-DD); {value!r} is not") from exc


def _reject_implausible(parsed: date, raw: int | str, *, slack: timedelta = timedelta(0)) -> date:
    """The one plausibility test. `slack` widens the bounds for the tz-blind
    boundary check; the canonical parse passes none."""
    today = datetime.now(UTC).date()
    if parsed < DOB_MIN_DATE - slack or parsed > today + slack:
        raise DobError(
            f"dob must be epoch milliseconds or an ISO date between "
            f"{DOB_MIN_DATE.isoformat()} and today; {raw!r} parses to {parsed.isoformat()}"
        )
    return parsed
