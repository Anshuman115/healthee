"""AS_OF_DAY, on the one LLM-AUTHORED block served for a past day (A3).

``docs/AS_OF_DAY.md`` §6 puts the LLM surfaces out of scope for past days, and that
refusal is structural everywhere else: ``insights.context.build_context`` takes no day, so
there is no parameter by which a generated surface could be asked about one.

Stored recommendation rows are the exception the document itself makes in §7 — they "are
already written and already dated", so serving one is a record rather than a new claim.
``read/today.py::_recommendations_for`` therefore reaches back TWO days for the newest set
at or before the reference day.

``test_as_of_day.py`` had no case for any of it: ``grep -n recommendation`` over that file
returned nothing, so the only LLM-authored block served for a past day was the one block
the as-of-day suite did not test. These are that case, in their own file because that
suite is at the standards' 400-line ceiling and this is a different subject —
*the reach, and what has to be on the wire to make it honest.*
"""

from __future__ import annotations

from datetime import date, timedelta

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.read.today import today_snapshot

pytestmark = pytest.mark.integration

# The same far-back day the sibling suite uses, for the same reason: bigger than every
# horizon in the read layer, so "bounded by D" and "bounded by today" cannot agree by luck.
_DAYS_AGO = 40


def _as_of() -> date:
    return user_today(SENTINEL_TZ) - timedelta(days=_DAYS_AGO)


def _recommendation(cur, day: date, action: str) -> None:
    """One rec row filed under ``day`` — the LLM-authored block served for a past day."""
    cur.execute(
        "INSERT INTO recommendation (user_id, date, rank, action, rationale, category, "
        "evidence_grade, research_note_ids, signal_source) "
        "VALUES (%s, %s, 1, %s, 'because', 'activity', 3, %s, 'seeded') "
        "ON CONFLICT (user_id, date, rank) DO UPDATE SET action = EXCLUDED.action",
        (SENTINEL_USER_ID, day, action, ["steps_mortality"]),
    )


@pytest.fixture
def bed(db: None):  # noqa: ARG001 — gates on DB reachability
    """A clean owner with a profile, inside one tenant transaction per test."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        cur.execute(
            "INSERT INTO profile (user_id, height_cm, sex, dob, srpa) "
            "VALUES (%s, 175, 'male', '1990-01-01', 0)",
            (SENTINEL_USER_ID,),
        )
        yield cur
        _reset(cur)


def _reset(cur) -> None:
    for table in ("recommendation", "derived_daily", "profile"):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names


def test_a_recommendation_set_carries_the_day_it_was_written_for(bed) -> None:
    """A3. The one LLM-authored block served for a past day, and the one the suite missed.

    ``read/today.py::_recommendations_for`` selects the newest set dated at or before the
    reference day, reaching back TWO days, and keeps only the newest date found. That
    reach is deliberate and stated — a rec row is already written and already dated, so
    serving it is a record rather than a new claim (``docs/AS_OF_DAY.md`` §7) — but it
    means the block on screen is not always the day's own.

    So the wire has to carry the row's date, and this asserts it does. The app then names
    the day (``actions_section.dart``); without the date it drew a two-day-old action
    under a heading saying "today", which is the stale-as-current lie in prose.
    """
    written_for = _as_of() - timedelta(days=2)
    _recommendation(bed, written_for, "Walk 30 minutes.")

    payload = today_snapshot(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of())
    served = payload["recommendations"]

    assert len(served) == 1
    assert served[0]["action"] == "Walk 30 minutes."
    assert served[0]["date"] == written_for.isoformat(), (
        "the reach is only defensible if the row says which day it answers for"
    )
    assert payload["as_of"]["day"] == _as_of().isoformat()


def test_a_recommendation_dated_after_the_day_never_reaches_it(bed) -> None:
    """The future leak, on the block AS_OF_DAY's own §7 authorises serving."""
    _recommendation(bed, _as_of() - timedelta(days=1), "Walk 30 minutes.")
    _recommendation(bed, _as_of() + timedelta(days=1), "Run intervals.")

    served = today_snapshot(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of())["recommendations"]

    assert [r["action"] for r in served] == ["Walk 30 minutes."]


def test_the_newest_set_within_the_reach_wins_whole(bed) -> None:
    """Precedence is by date, and one day's set is never mixed with another's."""
    _recommendation(bed, _as_of() - timedelta(days=2), "Older action.")
    _recommendation(bed, _as_of() - timedelta(days=1), "Newer action.")

    served = today_snapshot(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of())["recommendations"]

    assert [r["action"] for r in served] == ["Newer action."]
    assert served[0]["date"] == (_as_of() - timedelta(days=1)).isoformat()


def test_nothing_older_than_the_two_day_reach_is_served(bed) -> None:
    """The reach is a bound, not a "most recent ever" — that would be unbounded staleness."""
    _recommendation(bed, _as_of() - timedelta(days=3), "Three days back.")

    assert today_snapshot(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of())["recommendations"] == []
