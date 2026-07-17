"""Known-value tests for the `dob` conversion — the input to the age science.

`dob` is a science INPUT: it feeds `_age()` → biological age, VO2max (Jurca) and
sleep need/debt. These tests pin the contract (`core.dob` is the ONE conversion),
the plausibility bound, and the two classes of bug this path has actually shipped:

  * **The anchor bug (live in prod).** A birth date is a calendar DATE, not an
    instant. The app sends epoch ms at LOCAL midnight, and resolving that in UTC
    lands a day early — the owner's dob was stored `1994-06-30`, true value
    `1994-07-01`. Pinned by `test_the_prod_regression_*`.
  * **The magnitude bug (fixed in e4d1d00).** `epoch_to_utc`'s ms-vs-seconds guess
    read pre-2001 birth dates as seconds: it raised on 1990-05-01 and silently
    turned 1970-02-03 into 2060-05-08. Pinned by the `test_dob_*` cases below;
    there is deliberately no seconds fallback and these keep it that way.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import Any
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from healthee.api.app import create_app
from healthee.core.dob import DOB_MIN_DATE, date_to_dob_ms, parse_dob
from healthee.core.request_auth import ingest_user
from healthee.core.supabase_auth import RequestUser
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.derive._common import _age
from healthee.ingest.models import ProfileIn
from healthee.ingest.upsert import _MS_THRESHOLD, epoch_to_utc, upsert_profile

_IST = "Asia/Kolkata"
_NY = "America/New_York"
_KATHMANDU = "Asia/Kathmandu"  # +05:45 — a quarter-hour offset


def _local_ms(d: date, tz: str) -> int:
    """The wire value the app sends for `d` on a device in `tz`: a Dart
    `DateTime(y, m, d)` is LOCAL midnight, and `.millisecondsSinceEpoch` is that
    instant. Computed here from `zoneinfo` directly — NOT via `date_to_dob_ms` —
    so these tests pin the real arithmetic rather than agreeing with the code
    under test about it.
    """
    return int(datetime(d.year, d.month, d.day, tzinfo=ZoneInfo(tz)).timestamp() * 1000)


def _utc_ms(d: date) -> int:
    """`d` at UTC midnight — what a client that anchors to UTC would send."""
    return int(datetime(d.year, d.month, d.day, tzinfo=UTC).timestamp() * 1000)


class RecordingCursor:
    """Records executes so a test can prove a write did / did not happen."""

    def __init__(self) -> None:
        self.executed: list[tuple[str, Any]] = []

    def execute(self, sql: str, params: Any = None) -> None:
        self.executed.append((sql, params))


# --- THE PROD REGRESSION: the owner's real birthday ---------------------------


def test_the_prod_regression_ist_local_midnight_is_not_a_day_early() -> None:
    # The exact value the owner's IST device sent for 1994-07-01. Under the UTC
    # parse this returned 1994-06-30 and that is what prod stored.
    assert _local_ms(date(1994, 7, 1), _IST) == 773_001_000_000
    assert parse_dob(773_001_000_000, _IST) == date(1994, 7, 1)


def test_the_prod_regression_is_specifically_the_utc_anchor() -> None:
    # Why the bug existed at all: the same instant IS 1994-06-30 in UTC. The value
    # was never corrupt — it was resolved against the wrong calendar.
    assert datetime.fromtimestamp(773_001_000_000 / 1000, tz=UTC).date() == date(1994, 6, 30)
    assert parse_dob(773_001_000_000, "UTC") == date(1994, 6, 30)
    # And the discriminator that proves the sender anchors to LOCAL midnight: a
    # UTC-midnight sender would have produced a different number entirely.
    assert _utc_ms(date(1994, 7, 1)) == 773_020_800_000


# --- known values across the offset space ------------------------------------


@pytest.mark.parametrize(
    "tz",
    [
        "UTC",
        _IST,  # +05:30 — positive, half-hour
        _NY,  # -04:00 — NEGATIVE: the direction that breaks a UTC-midnight client
        _KATHMANDU,  # +05:45 — quarter-hour
        "Pacific/Auckland",  # +12:00 — the extreme positive AT this birth date
        "Pacific/Kiritimati",  # -10:00 in 1994 (see the date-line test below)
        "Pacific/Midway",  # -11:00 — the extreme negative
    ],
)
def test_local_midnight_round_trips_in_every_offset(tz: str) -> None:
    # The core property: for a device anchoring at local midnight, the date that
    # goes in is the date that comes out — in every zone, positive or negative.
    born = date(1994, 7, 1)
    assert parse_dob(_local_ms(born, tz), tz) == born


@pytest.mark.parametrize("tz", ["UTC", _IST, _NY, _KATHMANDU])
def test_encode_decode_is_an_exact_inverse(tz: str) -> None:
    # `date_to_dob_ms` (read path) and `parse_dob` (ingest) must be inverses, or
    # the app's read-modify-push cycle walks the date. See the ratchet test below.
    born = date(1994, 7, 1)
    assert parse_dob(date_to_dob_ms(born, tz), tz) == born
    assert date_to_dob_ms(born, tz) == _local_ms(born, tz)


def test_negative_offset_utc_anchored_read_would_ratchet_the_date_backwards() -> None:
    """The reason the READ path had to change too, not just the parse.

    The app restores its profile with `getProfile()` (`DateTime.fromMillisecondsSinceEpoch`
    — LOCAL) and re-pushes it. Emit UTC midnight to a New York owner and the app
    resolves it to the PREVIOUS day, pushes that back, and the stored date moves a
    day earlier every sync. This test pins the old encoder's failure and the new
    encoder's stability under exactly that loop.
    """
    born = date(1994, 7, 1)
    # The OLD read path emitted UTC midnight. One round-trip through a NY device:
    walked = parse_dob(_utc_ms(born), _NY)
    assert walked == date(1994, 6, 30), "UTC-anchored read is a day early in New York"
    # …and it does not stabilise: feed it back and it keeps walking.
    assert parse_dob(_utc_ms(walked), _NY) == date(1994, 6, 29)
    # The new encoder is a fixed point — re-pushing what we served changes nothing.
    stable = born
    for _ in range(3):
        stable = parse_dob(date_to_dob_ms(stable, _NY), _NY)
    assert stable == born


def test_asia_kolkata_offset_is_stable_at_the_owners_birth_date() -> None:
    # Checked, not assumed: tz databases move, and the owner's dob is the value
    # this whole fix is about. Asia/Kolkata has been +05:30 since 1945, so 1994
    # holds no surprise and 773_001_000_000 means the same thing then and now.
    assert datetime(1994, 7, 1, tzinfo=ZoneInfo(_IST)).utcoffset() == timedelta(hours=5, minutes=30)


def test_zoneinfo_uses_the_offset_at_the_birth_date_not_todays() -> None:
    """A zone's offset TODAY is not its offset at a 1994 birth date, and using
    today's would reintroduce the same one-day error for anyone born across a
    zone change. `zoneinfo` resolves at the instant, which is what we rely on.

    Pacific/Kiritimati is the sharp case: it is +14:00 today but was **-10:00**
    in 1994 — Kiribati jumped the date line on 1995-01-01 and skipped
    1994-12-31 entirely. A 24-hour swing in one zone's history, and the
    round-trip must still hold on both sides of it.
    """
    assert datetime(1994, 7, 1, tzinfo=ZoneInfo("Pacific/Kiritimati")).utcoffset() == timedelta(
        hours=-10
    )
    assert datetime(1996, 7, 1, tzinfo=ZoneInfo("Pacific/Kiritimati")).utcoffset() == timedelta(
        hours=14
    )
    for born in (date(1994, 7, 1), date(1996, 7, 1)):  # either side of the jump
        assert parse_dob(_local_ms(born, "Pacific/Kiritimati"), "Pacific/Kiritimati") == born
    # Zones that moved by ordinary amounts in the interval, across real dobs.
    for tz in (_IST, "Europe/Moscow", "Asia/Colombo", _NY):
        for born in (date(1994, 7, 1), date(1970, 2, 3), date(2005, 6, 15)):
            assert parse_dob(_local_ms(born, tz), tz) == born


# --- the ISO path: the contract that makes the bug unrepresentable -----------


def test_iso_string_needs_no_timezone_at_all() -> None:
    # The preferred contract (and what legacy used end-to-end). It carries no
    # instant, so every zone must agree — that is the entire point.
    for tz in ("UTC", _IST, _NY, "Pacific/Kiritimati", "Pacific/Midway"):
        assert parse_dob("1994-07-01", tz) == date(1994, 7, 1)


def test_iso_path_accepts_a_date_and_nothing_else() -> None:
    # No smuggling an instant back in through the path that exists to remove it.
    for bad in ("1994-07-01T00:00:00Z", "1994-07-01 00:00", "01/07/1994", "not-a-date", ""):
        with pytest.raises(ValueError, match="ISO date"):
            parse_dob(bad, _IST)


def test_profile_in_accepts_both_wire_forms() -> None:
    assert ProfileIn(dob="1994-07-01").dob == "1994-07-01"
    assert ProfileIn(dob=773_001_000_000).dob == 773_001_000_000


# --- known values: the magnitude bug (e4d1d00) must stay fixed ---------------


def test_dob_1990_parses_exactly() -> None:
    # 641_520_000_000 ms <= 10**12 → the old guess read it as SECONDS → year
    # 22298 → ValueError → 500 on every profile push.
    assert parse_dob(641_520_000_000, "UTC") == date(1990, 5, 1)


def test_dob_1970_parses_exactly_and_is_not_2060() -> None:
    # 2_851_200_000 ms <= 10**12 → the old guess read it as SECONDS → 2060-05-08,
    # stored SILENTLY: a 56-year-old scored as an unborn child, no error raised.
    parsed = parse_dob(2_851_200_000, "UTC")
    assert parsed == date(1970, 2, 3)
    assert parsed.year != 2060


def test_dob_post_2001_still_parses() -> None:
    # The side the old guess already got right — no regression.
    assert parse_dob(_local_ms(date(2005, 6, 15), _IST), _IST) == date(2005, 6, 15)


def test_dob_at_and_around_the_ms_threshold() -> None:
    # _MS_THRESHOLD ms after the epoch is 2001-09-09 — the exact point where the
    # heuristic flips. dob parses as plain milliseconds on BOTH sides of it.
    assert parse_dob(_MS_THRESHOLD, "UTC") == date(2001, 9, 9)  # at (was: seconds)
    assert parse_dob(_MS_THRESHOLD - 86_400_000, "UTC") == date(2001, 9, 8)  # below
    assert parse_dob(_MS_THRESHOLD + 86_400_000, "UTC") == date(2001, 9, 10)  # above
    # And this is exactly why: at/below the threshold epoch_to_utc reads seconds
    # (year 33658 → it raises); one ms above, it reads milliseconds.
    with pytest.raises(ValueError):
        epoch_to_utc(_MS_THRESHOLD)
    assert epoch_to_utc(_MS_THRESHOLD + 1).date() == date(2001, 9, 9)


def test_ambiguous_band_is_trusted_as_milliseconds_not_guessed() -> None:
    # The documented unresolvable band: 1_470_000_000 is plausible as ms
    # (1970-01-18) AND as seconds (2016-08-01). The contract says ms, so it is
    # ms — no magnitude guess, no silent 2016.
    assert parse_dob(1_470_000_000, "UTC") == date(1970, 1, 18)


# --- implausible values are rejected, loudly --------------------------------

# A dob 1000x too large: 1990-05-01's ms value shifted up a scale. Read as ms it
# lands in year 22298 — the shape that used to reach `datetime.fromtimestamp` and
# raise a bare ValueError → 500.
_DOB_YEAR_22298_MS = 641_520_000_000_000


def test_dob_mis_scaled_far_future_value_is_rejected() -> None:
    with pytest.raises(ValueError, match="epoch milliseconds"):
        parse_dob(_DOB_YEAR_22298_MS, _IST)


def test_dob_before_1900_is_rejected() -> None:
    with pytest.raises(ValueError, match="epoch milliseconds"):
        parse_dob(_local_ms(DOB_MIN_DATE, _IST) - 86_400_000, _IST)  # 1899-12-31


def test_dob_in_the_future_is_rejected() -> None:
    tomorrow = datetime.now(UTC).date() + timedelta(days=1)
    with pytest.raises(ValueError, match="epoch milliseconds"):
        parse_dob(_local_ms(tomorrow, _IST), _IST)
    with pytest.raises(ValueError, match="epoch milliseconds"):
        parse_dob(tomorrow.isoformat(), _IST)


def test_profile_in_rejects_implausible_dob_at_the_boundary() -> None:
    with pytest.raises(ValidationError):
        ProfileIn(dob=_DOB_YEAR_22298_MS)
    with pytest.raises(ValidationError):
        ProfileIn(dob="1899-12-31")
    with pytest.raises(ValidationError):
        ProfileIn(dob="1994-07-01T00:00:00Z")


def test_boundary_gate_slack_is_one_day_not_a_blank_cheque() -> None:
    # The gate is loosened by `_TZ_SLACK` because it cannot know the owner's zone.
    # That slack must stay at the width of the ambiguity it exists for: a dob a
    # month in the future is not a timezone question, it is a bad value, and it
    # must 422 here rather than reaching the upsert and 500ing.
    a_month_out = datetime.now(UTC).date() + timedelta(days=30)
    with pytest.raises(ValidationError):
        ProfileIn(dob=_utc_ms(a_month_out))


def test_boundary_gate_does_not_reject_across_a_timezone_shift() -> None:
    # The gate runs before the owner's tz is known, so it must not reject a value
    # that is plausible once the real zone is applied. A dob of "today" from an
    # extreme-offset device is the tightest real case in each direction.
    today = datetime.now(UTC).date()
    ProfileIn(dob=_local_ms(today, "Pacific/Kiritimati"))  # +14:00
    ProfileIn(dob=_local_ms(today, "Pacific/Midway"))  # -11:00


def test_bad_dob_is_a_4xx_not_a_500(env: None) -> None:  # noqa: ARG001 — sets token
    # The auth dependency is overridden with an already-resolved owner: since 6.4b it
    # reads the owner's timezone from `app_user`, and this test is about the BODY
    # contract (422, never a 500), not about identity — the override keeps it DB-free.
    app = create_app()
    app.dependency_overrides[ingest_user] = lambda: RequestUser(
        id=SENTINEL_USER_ID, timezone=SENTINEL_TZ
    )
    resp = TestClient(app).post(
        "/ingest/helio",
        json={"profile": {"dob": _DOB_YEAR_22298_MS}},
        headers={"Authorization": "Bearer unit-test-token"},
    )
    assert resp.status_code == 422  # client error, and no ingest work was reached


def test_implausible_dob_writes_nothing() -> None:
    cur = RecordingCursor()
    with pytest.raises(ValueError):
        upsert_profile(
            cur,  # type: ignore[arg-type]
            SENTINEL_USER_ID,
            SENTINEL_TZ,
            ProfileIn.model_construct(dob=_DOB_YEAR_22298_MS),
        )
    assert cur.executed == []  # nothing stored


# --- optional field + the write path ----------------------------------------


def test_dob_none_is_still_fine() -> None:
    cur = RecordingCursor()
    upsert_profile(cur, SENTINEL_USER_ID, SENTINEL_TZ, ProfileIn(name="Ashish", height_cm=178.0))  # type: ignore[arg-type]
    assert len(cur.executed) == 1
    assert cur.executed[0][1][4] is None  # dob param


def test_upsert_profile_stores_the_owner_local_date() -> None:
    # THE write-path regression: the exact prod value, the owner's real zone. The
    # UTC parse stored 1994-06-30 here.
    cur = RecordingCursor()
    profile = ProfileIn(name="Ashish", height_cm=178.0, sex="male", dob=773_001_000_000)
    upsert_profile(cur, SENTINEL_USER_ID, _IST, profile)  # type: ignore[arg-type]
    assert cur.executed[0][1][4] == date(1994, 7, 1)


def test_upsert_profile_accepts_the_iso_form() -> None:
    cur = RecordingCursor()
    profile = ProfileIn(name="Ashish", height_cm=178.0, sex="male", dob="1994-07-01")
    upsert_profile(cur, SENTINEL_USER_ID, _NY, profile)  # type: ignore[arg-type]
    assert cur.executed[0][1][4] == date(1994, 7, 1)


# --- the actual science linkage: dob → age ----------------------------------


def test_parsed_dob_yields_the_right_age_downstream() -> None:
    # The real consequence: `_age()` over the parsed dob is what Jurca VO2max,
    # biological age and sleep need consume.
    on = date(2026, 7, 16)
    assert _age(parse_dob(_local_ms(date(1990, 5, 1), _IST), _IST), on) == 36  # birthday passed
    assert _age(parse_dob(_local_ms(date(1990, 12, 25), _IST), _IST), on) == 35  # not yet
    # Under the old parse this dob became 2060-05-08 → age -34, silently.
    assert _age(parse_dob(2_851_200_000, "UTC"), on) == 56


def test_the_wrong_dob_reports_the_wrong_age_on_the_birthday() -> None:
    # Why one day matters for a health NUMBER, not just a display string: the
    # UTC-parsed dob (1994-06-30) turns a year older a day early, so on 2026-06-30
    # every age-dependent output — Jurca VO2max, biological age, sleep need — is
    # computed for a 32-year-old who is still 31.
    assert _age(parse_dob(773_001_000_000, _IST), date(2026, 6, 30)) == 31  # correct
    assert _age(parse_dob(773_001_000_000, "UTC"), date(2026, 6, 30)) == 32  # the shipped bug


# --- event timestamps are untouched -----------------------------------------


def test_event_timestamps_parse_identically() -> None:
    # Samples / sleep / workouts keep the tolerant guess: recent ms values sit
    # far above the threshold, and a seconds-sized event still means seconds.
    assert epoch_to_utc(1_718_000_000_000) == datetime(2024, 6, 10, 6, 13, 20, tzinfo=UTC)
    assert epoch_to_utc(1_718_000_000) == datetime(2024, 6, 10, 6, 13, 20, tzinfo=UTC)
