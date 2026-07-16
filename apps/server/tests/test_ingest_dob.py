"""Known-value tests for the `dob` epoch parse — the input to the age science.

`dob` is a science INPUT: it feeds `_age()` → biological age, VO2max (Jurca) and
sleep need/debt. These tests pin the contract (`ProfileIn.dob` is epoch
milliseconds), the plausibility bound, and — most importantly — the two cases the
old magnitude guess (`epoch_to_utc`) got wrong: it raised on 1990-05-01 and
silently turned 1970-02-03 into 2060-05-08. Reverting the fix fails every
`test_dob_*` case below.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from healthee.api.app import create_app
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.derive._common import _age
from healthee.ingest.models import DOB_MIN_DATE, ProfileIn, dob_ms_to_date
from healthee.ingest.upsert import _MS_THRESHOLD, epoch_to_utc, upsert_profile


def _ms(d: date) -> int:
    """The dob wire value for a date: UTC midnight in epoch ms (the exact shape
    `read.history.profile` hands back to the app, so this round-trips)."""
    return int(datetime(d.year, d.month, d.day, tzinfo=UTC).timestamp() * 1000)


class RecordingCursor:
    """Records executes so a test can prove a write did / did not happen."""

    def __init__(self) -> None:
        self.executed: list[tuple[str, Any]] = []

    def execute(self, sql: str, params: Any = None) -> None:
        self.executed.append((sql, params))


# --- known values: the two cases the magnitude guess got wrong ---------------


def test_dob_1990_parses_exactly() -> None:
    # 641_520_000_000 ms <= 10**12 → the old guess read it as SECONDS → year
    # 22298 → ValueError → 500 on every profile push.
    assert _ms(date(1990, 5, 1)) == 641_520_000_000
    assert dob_ms_to_date(641_520_000_000) == date(1990, 5, 1)


def test_dob_1970_parses_exactly_and_is_not_2060() -> None:
    # 2_851_200_000 ms <= 10**12 → the old guess read it as SECONDS → 2060-05-08,
    # stored SILENTLY: a 56-year-old scored as an unborn child, no error raised.
    parsed = dob_ms_to_date(2_851_200_000)
    assert parsed == date(1970, 2, 3)
    assert parsed.year != 2060


def test_dob_post_2001_still_parses() -> None:
    # The side the old guess already got right — no regression.
    assert dob_ms_to_date(_ms(date(2005, 6, 15))) == date(2005, 6, 15)


# --- the 2001-09-09 boundary itself -----------------------------------------


def test_dob_at_and_around_the_ms_threshold() -> None:
    # _MS_THRESHOLD ms after the epoch is 2001-09-09 — the exact point where the
    # heuristic flips. dob parses as plain milliseconds on BOTH sides of it.
    assert dob_ms_to_date(_MS_THRESHOLD) == date(2001, 9, 9)  # at (was: seconds)
    assert dob_ms_to_date(_MS_THRESHOLD - 86_400_000) == date(2001, 9, 8)  # below
    assert dob_ms_to_date(_MS_THRESHOLD + 86_400_000) == date(2001, 9, 10)  # above
    # And this is exactly why: at/below the threshold epoch_to_utc reads seconds
    # (year 33658 → it raises); one ms above, it reads milliseconds.
    with pytest.raises(ValueError):
        epoch_to_utc(_MS_THRESHOLD)
    assert epoch_to_utc(_MS_THRESHOLD + 1).date() == date(2001, 9, 9)


# --- implausible values are rejected, loudly --------------------------------

# A dob 1000x too large: 1990-05-01's ms value shifted up a scale. Read as ms it
# lands in year 22298 — the shape that used to reach `datetime.fromtimestamp` and
# raise a bare ValueError → 500.
_DOB_YEAR_22298_MS = 641_520_000_000_000


def test_dob_mis_scaled_far_future_value_is_rejected() -> None:
    with pytest.raises(ValueError, match="epoch milliseconds"):
        dob_ms_to_date(_DOB_YEAR_22298_MS)


def test_ambiguous_band_is_trusted_as_milliseconds_not_guessed() -> None:
    # The documented unresolvable band: 1_470_000_000 is plausible as ms
    # (1970-01-18) AND as seconds (2016-08-01). The contract says ms, so it is
    # ms — no magnitude guess, no silent 2016.
    assert dob_ms_to_date(1_470_000_000) == date(1970, 1, 18)


def test_dob_before_1900_is_rejected() -> None:
    with pytest.raises(ValueError, match="epoch milliseconds"):
        dob_ms_to_date(_ms(DOB_MIN_DATE) - 86_400_000)  # 1899-12-31


def test_dob_in_the_future_is_rejected() -> None:
    tomorrow = datetime.now(UTC).date() + timedelta(days=1)
    with pytest.raises(ValueError, match="epoch milliseconds"):
        dob_ms_to_date(_ms(tomorrow))


def test_profile_in_rejects_implausible_dob_at_the_boundary() -> None:
    with pytest.raises(ValidationError):
        ProfileIn(dob=_DOB_YEAR_22298_MS)


def test_bad_dob_is_a_4xx_not_a_500(env: None) -> None:  # noqa: ARG001 — sets token
    client = TestClient(create_app())
    resp = client.post(
        "/ingest/helio",
        json={"profile": {"dob": _DOB_YEAR_22298_MS}},
        headers={"Authorization": "Bearer unit-test-token"},
    )
    assert resp.status_code == 422  # client error, and no DB work was reached


def test_implausible_dob_writes_nothing() -> None:
    cur = RecordingCursor()
    with pytest.raises(ValueError):
        upsert_profile(cur, SENTINEL_USER_ID, ProfileIn.model_construct(dob=_DOB_YEAR_22298_MS))  # type: ignore[arg-type]
    assert cur.executed == []  # nothing stored


# --- optional field + the write path ----------------------------------------


def test_dob_none_is_still_fine() -> None:
    cur = RecordingCursor()
    upsert_profile(cur, SENTINEL_USER_ID, ProfileIn(name="Ashish", height_cm=178.0))  # type: ignore[arg-type]
    assert len(cur.executed) == 1
    assert cur.executed[0][1][4] is None  # dob param


def test_upsert_profile_stores_the_contract_date() -> None:
    cur = RecordingCursor()
    profile = ProfileIn(name="Ashish", height_cm=178.0, sex="male", dob=_ms(date(1990, 5, 1)))
    upsert_profile(cur, SENTINEL_USER_ID, profile)  # type: ignore[arg-type]
    assert cur.executed[0][1][4] == date(1990, 5, 1)  # not year 22298, not 2060


# --- the actual science linkage: dob → age ----------------------------------


def test_parsed_dob_yields_the_right_age_downstream() -> None:
    # The real consequence: `_age()` over the parsed dob is what Jurca VO2max,
    # biological age and sleep need consume.
    on = date(2026, 7, 16)
    assert _age(dob_ms_to_date(_ms(date(1990, 5, 1))), on) == 36  # birthday passed
    assert _age(dob_ms_to_date(_ms(date(1990, 12, 25))), on) == 35  # not yet
    # Under the old parse this dob became 2060-05-08 → age -34, silently.
    assert _age(dob_ms_to_date(2_851_200_000), on) == 56


# --- event timestamps are untouched -----------------------------------------


def test_event_timestamps_parse_identically() -> None:
    # Samples / sleep / workouts keep the tolerant guess: recent ms values sit
    # far above the threshold, and a seconds-sized event still means seconds.
    assert epoch_to_utc(1_718_000_000_000) == datetime(2024, 6, 10, 6, 13, 20, tzinfo=UTC)
    assert epoch_to_utc(1_718_000_000) == datetime(2024, 6, 10, 6, 13, 20, tzinfo=UTC)
