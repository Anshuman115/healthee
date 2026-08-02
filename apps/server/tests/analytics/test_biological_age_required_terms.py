"""EVERY biological-age term is required — the rule is not about which term matters.

#70/A1's open question. Fitness earned "required" partly because
[[biological_age_estimate]] calls it dominant, but dominance is why the composite is
SENSITIVE to a term, not why omitting one is a lie. The composite is
``chrono + Σ ΔAge_i``, so a term left out asserts ``HR_term = 1.0`` — "this owner sits
exactly on the reference for that lever" — and that is a claim about them at any size.

So these tests pin the rule stated ONCE over every term: each withholds the composite on
its own, the reason is the input metric's own (never re-worded here), and every absent
term is named — telling an owner to fix one thing and leaving them stuck would be the
same silence in a different place.

**The rule is about terms of the DEFINITION, and #86 narrowed the definition.** Sleep
regularity used to be a third term and is now excluded outright, so the first test below
is the inversion of the two it replaced: the SRI window is no longer allowed to move this
number at all. Removing a term and dropping one are opposite acts — the removal is
published in ``excluded`` and applies to everyone, the drop was silent and per-owner.

The stale-VO₂max cases live in ``test_biological_age_freshness``; both files share
``_bio_age_bed`` so they cannot drift into testing different owners.
"""

from __future__ import annotations

from datetime import timedelta

import pytest
from tests.analytics._bio_age_bed import (
    BIO_AGE,
    NOISY,
    VO2MAX,
    absent,
    dd,
    reset,
    rhr,
    seed_nights,
    seed_owner,
    terms,
)

from healthee.analytics.biological_age import compute_biological_age
from healthee.analytics.biological_age_terms import (
    REQUIRED_TERMS_MESSAGE,
    SRI_HAZARD_NOT_TRANSPORTABLE,
)
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.derive.freshness import NO_NIGHTS_IN_WINDOW
from healthee.derive.vo2max import WITHHOLD_RHR_TOO_NOISY

pytestmark = pytest.mark.integration


@pytest.mark.parametrize("nights", [7, 4, 0])
@pytest.mark.usefixtures("db")
def test_the_sri_window_no_longer_reaches_the_biological_age_at_all(nights: int) -> None:
    """#86 · regularity left the definition, so its data state cannot move this number.

    Two tests used to live here: a 90-day-old SRI and a 4-night week each withheld the
    whole composite, because regularity was a required term. It is not a term any more —
    the published SRI→mortality hazards are a property of the calculator that produced
    them (Czeisler et al. 2026, *Sleep* 49(4):zsaf299), and ours is a third calculator.

    So the assertion inverts, and it is worth having in this positive form: an owner
    whose sleep week is complete, short, or missing entirely gets the SAME biological
    age. Anything else would mean a lever we do not price is still moving the number.

    A CURRENT ``sleep_regularity_index`` row is seeded on purpose alongside the nights.
    Without it the case is vacuous — a re-added term would find nothing to read and the
    test would pass through the bug. 58.0 is the value the old Cribb term scored at
    +1.8 y, so the mutation this kills is a visible 1.8-year move, not a rounding.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        cur.execute("DELETE FROM sleep_session")
        seed_owner(cur, today)
        dd(cur, today, "vo2max_estimate", VO2MAX)
        dd(cur, today, "sleep_regularity_index", 58.0)
        seed_nights(cur, today, nights)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert result["withheld"] is None
    assert result["data_confidence"] == "ok"
    assert set(terms(result)) == {"fitness", "sleep duration"}
    # 40 + (−1.8054) + 0.6473 = 38.84 — the two-lever number, which an earlier revision
    # of this file refused as incomplete and #86 makes the definition.
    assert result["biological_age"] == pytest.approx(BIO_AGE)
    # And the absence is stated rather than left to be noticed.
    assert [e["reason"] for e in result["excluded"]] == [SRI_HAZARD_NOT_TRANSPORTABLE]


@pytest.mark.usefixtures("db")
def test_an_empty_sleep_window_withholds_through_the_duration_term() -> None:
    """No nights in 14 asserts "you average 7 h/night" — the same lie, reached from a
    windowed aggregate instead of a stale row, so it gets the same answer."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        cur.execute("DELETE FROM sleep_session")
        seed_owner(cur, today)
        dd(cur, today, "vo2max_estimate", VO2MAX)
        cur.execute("DELETE FROM derived_daily WHERE metric = 'sleep_health_score_4dim'")
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert result["biological_age"] is None
    assert absent(result) == {"sleep duration": NO_NIGHTS_IN_WINDOW}
    assert set(terms(result)) == {"fitness"}


@pytest.mark.usefixtures("db")
def test_every_absent_term_is_named_and_the_consequence_is_stated_once() -> None:
    """Naming only the first would tell an owner to fix one thing and leave them stuck.

    This used to be "two absent at once are BOTH named", exercised with fitness and
    regularity. #86 makes that scenario unreachable through this entry point: with two
    terms, *both* absent means no contribution at all, and a payload with nothing in it
    is ``None`` by the older rule the last test in this file pins. So the property is
    asserted where it is still reachable — one absent, one present, and the shared
    consequence sentence attached exactly once rather than repeated per term.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        cur.execute("DELETE FROM sleep_session")
        seed_owner(cur, today)
        dd(cur, today - timedelta(days=1), "vo2max_estimate", VO2MAX)
        rhr(cur, today, NOISY)  # fitness: the gate refuses today
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert absent(result) == {"fitness": WITHHOLD_RHR_TOO_NOISY}
    assert result["withheld"]["consequence"] == REQUIRED_TERMS_MESSAGE
    assert set(terms(result)) == {"sleep duration"}


@pytest.mark.usefixtures("db")
def test_when_neither_remaining_term_is_current_there_is_no_estimate_at_all() -> None:
    """The floor, and it moved: with three terms an owner missing two still saw a card.

    Two terms means "both absent" and "nothing to say" are the same state, and the rule
    for that state is unchanged — ``None``, no card to caveat. Worth an explicit test
    because narrowing the definition narrowed this too, quietly, and an empty card that
    still rendered a headline would be the worse failure.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        cur.execute("DELETE FROM sleep_session")
        seed_owner(cur, today)
        dd(cur, today - timedelta(days=1), "vo2max_estimate", VO2MAX)
        rhr(cur, today, NOISY)  # fitness: the gate refuses today
        cur.execute("DELETE FROM derived_daily WHERE metric = 'sleep_health_score_4dim'")
        assert compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ) is None
