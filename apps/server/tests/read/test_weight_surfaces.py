"""#85 — the two surfaces that read a weight and presented it as current.

``read/today_series.py::_weight_card`` sat in the Today row beside steps and calories
and rendered the newest ``weight_log`` value with no date attached, so a March weigh-in
read as "Weight 79.9 kg" in August. ``read/history.py::profile`` did the same for
``/api/profile``, which matters twice over: the app re-pushes what that endpoint serves.

The two get DIFFERENT treatments, and the difference is the point:

* the Today card answers "what do you weigh **now**", so past the horizon it withholds;
* ``/api/profile`` answers "what should I restore after a reinstall", so it keeps the
  value and grows a date — blanking it there would break the restore it exists for.
"""

from __future__ import annotations

from datetime import timedelta
from uuid import UUID

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.derive.freshness import WEIGHT_MAX_AGE_DAYS, WEIGHT_STALE, WEIGHT_STALE_MESSAGE
from healthee.read.history import profile
from healthee.read.today_series import secondary_cards

pytestmark = pytest.mark.integration


def _seed(cur, days_ago: int, kg: float = 79.9) -> None:
    cur.execute("DELETE FROM weight_log")
    cur.execute("DELETE FROM profile")
    cur.execute(
        "INSERT INTO profile (user_id, name, height_cm, sex, dob) "
        "VALUES (%s, 'Owner', 175, 'male', '1990-01-01')",
        (SENTINEL_USER_ID,),
    )
    cur.execute(
        "INSERT INTO weight_log (user_id, ts, kg) "
        "VALUES (%s, now() - (%s || ' days')::interval, %s)",
        (SENTINEL_USER_ID, days_ago, kg),
    )


def _weight_card(cur, user_id: UUID) -> dict:
    cards = {c["metric"]: c for c in secondary_cards(cur, user_id, SENTINEL_TZ)}
    return cards["weight_kg"]


@pytest.mark.usefixtures("db")
def test_a_recent_weigh_in_still_shows_a_number_and_now_carries_its_date() -> None:
    """Weight changes slowly, so a few days old is still this person's mass.

    ``as_of_date`` ships even when the value does — a weight two days old is honest
    ONLY if the card says which day it came from, and a card that dates itself solely
    when it is refusing teaches a reader that undated means today.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur, days_ago=3)
        card = _weight_card(cur, SENTINEL_USER_ID)
    assert card["value"] == pytest.approx(79.9)
    assert card["withheld"] is None
    assert card["as_of_date"] == (user_today(SENTINEL_TZ) - timedelta(days=3)).isoformat()


@pytest.mark.usefixtures("db")
def test_a_weight_at_the_horizon_is_still_reported() -> None:
    # The boundary is inclusive; see the evidence on `freshness.WEIGHT_MAX_AGE_DAYS`.
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur, days_ago=WEIGHT_MAX_AGE_DAYS)
        card = _weight_card(cur, SENTINEL_USER_ID)
    assert card["value"] == pytest.approx(79.9)
    assert card["withheld"] is None


@pytest.mark.usefixtures("db")
def test_a_weight_past_the_horizon_is_withheld_from_the_today_card() -> None:
    """THE fix, in the shape ``read/vo2max.py`` established.

    ``value`` is null — not a dated number, not a flagged number — because "a date in a
    field the UI may not render does not undo a confident current-looking number". The
    reading itself is not deleted; it moves inside ``withheld``, where nothing can read
    it as today's.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur, days_ago=60)
        card = _weight_card(cur, SENTINEL_USER_ID)
    assert card["value"] is None
    withheld = card["withheld"]
    assert withheld["reason"] == WEIGHT_STALE
    assert withheld["message"] == WEIGHT_STALE_MESSAGE
    assert withheld["age_days"] == 60
    assert withheld["last_kg"] == pytest.approx(79.9)
    assert withheld["last_as_of_date"] == card["as_of_date"]


@pytest.mark.usefixtures("db")
def test_no_logged_weight_at_all_is_still_no_card() -> None:
    # "No data" and "too old" are different states (standards §1) and must not collapse:
    # an owner who never logged a weight gets no card, not a withheld one.
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur, days_ago=1)
        cur.execute("DELETE FROM weight_log")
        cards = {c["metric"] for c in secondary_cards(cur, SENTINEL_USER_ID, SENTINEL_TZ)}
    assert "weight_kg" not in cards


@pytest.mark.usefixtures("db")
def test_the_profile_endpoint_keeps_the_value_but_stops_shipping_it_undated() -> None:
    """``/api/profile`` restores a reinstall, so the value stays — dated.

    It is also half of the loop that made every weight look fresh: the app pushes back
    what it reads here, and ``ingest.upsert.upsert_weight`` used to stamp that echo as a
    new measurement. The dates are what let a client tell a restore from a weigh-in.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur, days_ago=60)
        payload = profile(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload["weight_kg"] == pytest.approx(79.9)
    assert payload["weight_age_days"] == 60
    assert payload["weight_as_of"] == (user_today(SENTINEL_TZ) - timedelta(days=60)).isoformat()


@pytest.mark.usefixtures("db")
def test_the_profile_endpoint_survives_an_owner_with_no_weight() -> None:
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur, days_ago=1)
        cur.execute("DELETE FROM weight_log")
        payload = profile(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload["weight_kg"] is None
    assert payload["weight_as_of"] is None
    assert payload["weight_age_days"] is None
