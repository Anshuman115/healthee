"""What the HTTP boundary does with a `dob` — the STATUS half of the contract.

Split out of `test_ingest_dob.py` when #57's last case pushed that file past the
400-line gate, and it was the right seam anyway: everything there is about the
CONVERSION (which date does this wire value mean), everything here is about what a
client is told when the conversion refuses. A bad birth date is always the client's
error, so it is always a 4xx — and there are two gates that can decide so:

* `ingest.models.ProfileIn` (`core.dob.assert_plausible_dob`) — runs at the boundary,
  before the owner's timezone is known, so it carries one day of `_TZ_SLACK`;
* `core.dob.parse_dob` inside the upsert — the exact test, once the owner IS known.

The second one used to surface as a **500** for values inside that slack. That was
#57's residual, and `core.dob.DobError` plus the handler in `api/app.py` closes it.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from healthee.api.app import create_app
from healthee.core.dob import DobError
from healthee.core.request_auth import ingest_user
from healthee.core.supabase_auth import RequestUser
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.ingest.models import ProfileIn

_IST = "Asia/Kolkata"

# A dob 1000x too large: 1990-05-01's ms value shifted up a scale, landing in year
# 22298 — the shape that used to reach `datetime.fromtimestamp` and 500.
_DOB_YEAR_22298_MS = 641_520_000_000_000


def _local_ms(d: date, tz: str) -> int:
    """The wire value a device in `tz` sends for `d`: LOCAL midnight as epoch ms."""
    return int(datetime(d.year, d.month, d.day, tzinfo=ZoneInfo(tz)).timestamp() * 1000)


def _utc_ms(d: date) -> int:
    """`d` at UTC midnight — what a client that anchors to UTC would send."""
    return int(datetime(d.year, d.month, d.day, tzinfo=UTC).timestamp() * 1000)


def _post_profile(dob: int | str, tz: str) -> int:
    """POST a profile with this `dob` as an owner in `tz`; return the status.

    The auth dependency is overridden with an already-resolved owner: these tests are
    about the BODY contract, not identity, and `parse_dob` needs the owner's timezone.
    """
    app = create_app()
    app.dependency_overrides[ingest_user] = lambda: RequestUser(id=SENTINEL_USER_ID, timezone=tz)
    resp = TestClient(app, raise_server_exceptions=False).post(
        "/ingest/helio",
        json={"profile": {"dob": dob, "height_cm": 178.0, "sex": "male"}},
        headers={"Authorization": "Bearer unit-test-token"},
    )
    return resp.status_code


# --- the boundary gate: what it catches, and how wide its slack is -----------


def test_profile_in_accepts_both_wire_forms() -> None:
    assert ProfileIn(dob="1994-07-01").dob == "1994-07-01"
    assert ProfileIn(dob=773_001_000_000).dob == 773_001_000_000


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
    # month in the future is not a timezone question, it is a bad value.
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


# --- the status a client actually receives -----------------------------------


def test_bad_dob_is_a_4xx_not_a_500(env: None) -> None:  # noqa: ARG001 — sets token
    # Rejected by `ProfileIn`, so no ingest work is reached and no DB is needed.
    assert _post_profile(_DOB_YEAR_22298_MS, SENTINEL_TZ) == 422


@pytest.mark.integration
@pytest.mark.usefixtures("db")
def test_a_dob_inside_the_boundary_slack_is_a_422_not_a_500() -> None:
    """#57's residual — measured as a **500** before this fix, not assumed.

    `assert_plausible_dob` must carry its day of slack: it cannot know the owner's
    zone, and a dob that is fine once the real zone is applied must not be rejected
    there. So a value inside the slack is rejected LATER, by the canonical parse in the
    upsert. The slack was never the bug; the STATUS was. A rejected client value
    reported as a server fault is how a real incident gets mis-triaged.

    UTC midnight "tomorrow" is the tightest real instance: for an IST owner that
    instant is already tomorrow, so `parse_dob` refuses it after the boundary passed it.
    """
    tomorrow = datetime.now(UTC).date() + timedelta(days=1)
    ProfileIn(dob=_utc_ms(tomorrow))  # the boundary gate accepts it — by design
    assert _post_profile(_utc_ms(tomorrow), _IST) == 422


def test_only_a_dob_failure_becomes_a_422() -> None:
    # The handler is registered for `DobError`, NOT for `ValueError`: a blanket
    # ValueError→422 around the ingest would relabel every genuine internal failure as
    # the client's mistake. `DobError` stays a ValueError so pydantic's field validator
    # and every existing caller keep working; nothing else in the app is one.
    assert issubclass(DobError, ValueError)
    assert not isinstance(ValueError("not a dob"), DobError)
