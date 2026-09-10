"""The free reads keep serving — with their AI fields OMITTED, not nulled (§12.7).

``/api/today`` and ``/api/sleep/consistency`` are free-tier endpoints that each carry
one LLM-authored field. §12.7's closure for "sniff the response for the AI fields the
app hides" is that *the data is not in the response at all*, so the assertions here are
about ABSENCE — and they are made against the raw response TEXT as well as the parsed
dict.

That belt-and-braces is deliberate and was earned: a prior agent's mutation showed that
key-and-type snapshots cannot see a value flip. A parsed-dict assertion (`"action" not
in payload`) is the same shape of blind spot one level down — it would pass against a
payload that serialised the key with a null, depending on how it got there. Asserting on
the bytes is the only form that cannot.
"""

from __future__ import annotations

from collections.abc import Callable

import pytest
from fastapi.testclient import TestClient
from tests.premium.conftest import AUTH

from healthee.api.gate_fields import SLEEP_CONSISTENCY_AI_FIELDS, TODAY_AI_FIELDS

pytestmark = pytest.mark.integration


def test_a_free_owners_today_has_no_action_or_recommendations_key_at_all(
    bed: TestClient, make_free: Callable[[], None]
) -> None:
    make_free()
    response = bed.get("/api/today", headers=AUTH)
    assert response.status_code == 200  # the page still renders — nothing is 402 here

    for field in TODAY_AI_FIELDS:
        assert f'"{field}"' not in response.text, f"{field} is still on the wire"
    payload = response.json()
    assert set(TODAY_AI_FIELDS).isdisjoint(payload)


def test_a_free_owners_today_still_carries_every_free_metric(
    bed: TestClient, make_free: Callable[[], None]
) -> None:
    """The other half of the promise: we lock the interpretation, never the numbers.

    A gate that stripped the whole payload would pass the absence test above and break
    the product's central claim (PRICING.md §1a: "never paywall data or safety").
    """
    make_free()
    payload = bed.get("/api/today", headers=AUTH).json()
    for key in (
        "metrics",
        "recovery_score",
        "sleep_health",
        "vo2max",
        "cardio_load",
        "illness_flag",
        "top_findings",
        "data_health",
    ):
        assert key in payload, f"{key} is free tier and must still be served"


def test_a_free_owners_today_says_what_was_withheld(
    bed: TestClient, make_free: Callable[[], None]
) -> None:
    """Omission without a marker would be indistinguishable from "nothing generated yet"."""
    make_free()
    locked = bed.get("/api/today", headers=AUTH).json()["locked"]
    assert locked["locked"] is True
    assert locked["feature"] == "daily_action"
    assert "upgrade" in locked


def test_a_premium_owners_today_carries_the_ai_fields_and_no_marker(bed: TestClient) -> None:
    """The premium payload is byte-shape-identical to the pre-6.6a one — no `locked` key.

    Which is what keeps the committed contract snapshot honest: it is taken as owner A,
    who `seed_all` entitles, so the snapshot pins the FULL payload rather than the
    locked one.
    """
    payload = bed.get("/api/today", headers=AUTH).json()
    for field in TODAY_AI_FIELDS:
        assert field in payload
    assert "locked" not in payload


def test_a_free_owners_sleep_consistency_omits_the_tonight_line(
    bed: TestClient, make_free: Callable[[], None]
) -> None:
    """The second AI field on a free surface — one §12 never enumerates (see api.gate)."""
    make_free()
    response = bed.get("/api/sleep/consistency", headers=AUTH)
    assert response.status_code == 200
    for field in SLEEP_CONSISTENCY_AI_FIELDS:
        assert f'"{field}"' not in response.text
    payload = response.json()
    assert "tonight" not in payload
    assert payload["locked"]["locked"] is True
    # …and the regularity numbers, which are free, are all still there.
    assert "sri" in payload or "nights" in payload or "bedtime_sd_min" in payload


def test_a_premium_owners_sleep_consistency_keeps_it(bed: TestClient) -> None:
    payload = bed.get("/api/sleep/consistency", headers=AUTH).json()
    assert "tonight" in payload
    assert "locked" not in payload
