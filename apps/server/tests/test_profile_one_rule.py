"""`profile` has two writers and ONE rule about absence (write-path audit B2).

The strap sync (`ingest/upsert.upsert_profile`) and the profile editor
(`read/profile_edit.edit_profile`) both write this table. They used to disagree: the
editor resolved each field against `model_fields_set` and preserved what the request
omitted, while the sync COALESCEd `name`/`srpa` and plainly ASSIGNED `height_cm`, `sex`
and `dob`. Every field on `ProfileIn` defaults to `None`, so **a sync whose profile block
omitted a demographic erased it**, and `profile` has no history table — nothing anywhere
else holds the owner's date of birth, so no re-derive brings it back.

The blast radius is the profile-dependent half of the derive layer: `_load_profile`
returns `None` when any of height/sex/dob is missing (calories, distance, cardio load,
the Jurca tier) and `_date_of_birth` gates sleep need and sleep debt.

These tests drive both writers over one table and assert the SAME rule of each, so a
future change that fixes one and forgets the other fails here.
"""

from __future__ import annotations

from datetime import UTC, date, datetime
from zoneinfo import ZoneInfo

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.ingest.models import ProfileIn
from healthee.ingest.upsert import upsert_profile
from healthee.read.profile_edit import ProfileEdit, edit_profile

pytestmark = pytest.mark.usefixtures("db")

_DOB = date(2002, 3, 4)
_FULL = {"name": "Owner", "height_cm": 176.0, "sex": "male", "dob": _DOB.isoformat(), "srpa": 3}


def _stored(cur) -> tuple:
    cur.execute(
        "SELECT name, height_cm, sex, dob, srpa FROM profile WHERE user_id = %s",
        (SENTINEL_USER_ID,),
    )
    return cur.fetchone()


def _seed(cur) -> None:
    cur.execute("DELETE FROM profile WHERE user_id = %s", (SENTINEL_USER_ID,))
    upsert_profile(cur, SENTINEL_USER_ID, SENTINEL_TZ, ProfileIn.model_validate(_FULL))


def test_a_sync_that_omits_the_demographics_preserves_every_one_of_them() -> None:
    """THE defect. A push carrying only a weight used to null height, sex AND the dob.

    The v02 client sends no profile at all and the legacy app sends one only when
    complete, so this was latent — the same standing the sleep-COALESCE defect had, and
    the same reason it is closed anyway: `/ingest/helio` is reachable by any device token,
    including an app build nobody here can inspect.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur)
        upsert_profile(
            cur,
            SENTINEL_USER_ID,
            SENTINEL_TZ,
            ProfileIn.model_validate({"weight_kg": 79.9}),
        )
        name, height, sex, dob, srpa = _stored(cur)

    assert (name, height, sex, dob, srpa) == ("Owner", 176.0, "male", _DOB, 3)


def test_a_sync_can_still_correct_a_field_it_does_send() -> None:
    """Preserving omissions must not become "the first value ever pushed wins"."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur)
        upsert_profile(
            cur, SENTINEL_USER_ID, SENTINEL_TZ, ProfileIn.model_validate({"height_cm": 181.0})
        )
        _, height, sex, dob, _ = _stored(cur)

    assert height == 181.0
    assert (sex, dob) == ("male", _DOB)


def test_an_explicit_null_from_the_sync_clears_the_answer() -> None:
    """Omitted and explicitly-null are different facts and the wire can say both.

    A COALESCE cannot express this — it reads both as "keep" — which is why the shared
    writer is a `CASE WHEN <supplied>` per column.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur)
        upsert_profile(cur, SENTINEL_USER_ID, SENTINEL_TZ, ProfileIn.model_validate({"srpa": None}))
        *_, dob, srpa = _stored(cur)

    assert srpa is None
    assert dob == _DOB, "clearing one answer must not touch another"


def test_the_editor_and_the_sync_answer_absence_identically() -> None:
    """One table, one rule — asserted by driving both writers over the same start state."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur)
        edit_profile(cur, SENTINEL_USER_ID, ProfileEdit.model_validate({"height_cm": 181.0}))
        after_edit = _stored(cur)

        _seed(cur)
        upsert_profile(
            cur, SENTINEL_USER_ID, SENTINEL_TZ, ProfileIn.model_validate({"height_cm": 181.0})
        )
        after_sync = _stored(cur)

    assert after_edit == after_sync


def test_the_sync_still_stores_a_dob_in_the_owners_timezone() -> None:
    """The one thing the shared writer must NOT have absorbed.

    `ProfileIn.dob` may be epoch ms anchored at local midnight in the owner's zone;
    resolving it in UTC is what stored the owner's birthday one day early in production.
    The conversion stays with the caller that knows the zone.
    """
    local_midnight = datetime(2002, 3, 4, 0, 0, tzinfo=ZoneInfo(SENTINEL_TZ))
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute("DELETE FROM profile WHERE user_id = %s", (SENTINEL_USER_ID,))
        upsert_profile(
            cur,
            SENTINEL_USER_ID,
            SENTINEL_TZ,
            ProfileIn.model_validate({"dob": int(local_midnight.timestamp() * 1000)}),
        )
        *_, dob, _ = _stored(cur)

    assert dob == _DOB
    assert local_midnight.astimezone(UTC).date() != _DOB, "the UTC answer must differ, or "
    "this test cannot fail on the bug it exists for"
