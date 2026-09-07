"""``day=YYYY-MM-DD`` on the wire: what the three endpoints accept, and what they refuse.

``tests/read/test_as_of_day.py`` proves the read layer cannot leak the future. This file
proves the parameter reaches it, that every payload names the day it answers for, and
that the two ways of asking a question we cannot answer are REFUSALS rather than
confident-looking empties — which is the same distinction the whole product turns on
("no data" and "we could not answer" are different states, standards §1).

It rides the contract bed's seeded owner, so the assertions are about the day the
payload names rather than about particular numbers; the numbers are pinned in
``test_contracts.py`` and the bounding is pinned service-side.
"""

from __future__ import annotations

from datetime import timedelta

import pytest

from healthee.core.tenancy import SENTINEL_TZ, user_today

pytestmark = pytest.mark.integration

_ENDPOINTS = ("/api/today", "/api/activity", "/api/sleep")


@pytest.mark.parametrize("path", _ENDPOINTS)
def test_each_endpoint_answers_for_the_day_it_was_asked_for(seeded_client: tuple, path) -> None:
    """Rule 5, on the wire: the payload names its own day, and says it is not today."""
    client, headers = seeded_client
    day = user_today(SENTINEL_TZ) - timedelta(days=3)

    resp = client.get(path, params={"day": day.isoformat()}, headers=headers)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["date"] == day.isoformat()
    assert body["as_of"]["day"] == day.isoformat()
    assert body["as_of"]["is_today"] is False


@pytest.mark.parametrize("path", _ENDPOINTS)
def test_omitting_the_day_still_answers_for_today(seeded_client: tuple, path) -> None:
    """The default is unchanged behaviour — the half every leak test is blind to."""
    client, headers = seeded_client

    body = client.get(path, headers=headers).json()

    assert body["date"] == user_today(SENTINEL_TZ).isoformat()
    assert body["as_of"]["is_today"] is True


@pytest.mark.parametrize("path", _ENDPOINTS)
def test_a_malformed_day_is_refused_not_quietly_answered_as_today(
    seeded_client: tuple, path
) -> None:
    """Falling back to today under a date nobody asked for is stale-as-current arriving
    through the front door. 422 says which parameter was wrong."""
    client, headers = seeded_client

    resp = client.get(path, params={"day": "2026-07-3"}, headers=headers)

    assert resp.status_code == 422
    assert "day" in resp.text


@pytest.mark.parametrize("path", _ENDPOINTS)
def test_a_day_in_the_owners_future_is_refused(seeded_client: tuple, path) -> None:
    """Every window is bounded by the day, so a future day would answer with a page of
    withholds — technically honest, and read as "you have no data" when the truth is
    "that day has not happened". Two different states, kept distinguishable."""
    client, headers = seeded_client
    tomorrow = user_today(SENTINEL_TZ) + timedelta(days=1)

    resp = client.get(path, params={"day": tomorrow.isoformat()}, headers=headers)

    assert resp.status_code == 422
    assert "future" in resp.text


def test_the_daily_action_is_absent_on_a_past_day(seeded_client: tuple) -> None:
    """The LLM surfaces are out of scope BY DESIGN (``docs/AS_OF_DAY.md`` section 6).

    The cache is keyed on the owner's current day, so an older one has no stored line —
    and writing one now would be authoring a new claim under an old date rather than
    replaying a record. Absent is the honest default, and it is what the app shows.
    """
    client, headers = seeded_client
    day = user_today(SENTINEL_TZ) - timedelta(days=3)

    body = client.get("/api/today", params={"day": day.isoformat()}, headers=headers).json()

    assert body.get("action") is None
