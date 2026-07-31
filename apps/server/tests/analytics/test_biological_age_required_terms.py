"""EVERY biological-age term is required — the rule is not about which term matters.

#70/A1's open question. Fitness earned "required" partly because
[[biological_age_estimate]] calls it dominant, but dominance is why the composite is
SENSITIVE to a term, not why omitting one is a lie. The composite is
``chrono + Σ ΔAge_i``, so a term left out asserts ``HR_term = 1.0`` — "this owner sits
exactly on the reference for that lever" — and that is a claim about them at any size.
Regularity's is not small: the Cribb anchors span −1.2 y (SRI 75) to +4.7 y (SRI 41),
and dropping it asserts SRI ≈ 68.

So these tests pin the rule stated ONCE over all three terms: each withholds the
composite on its own, the reason is the input metric's own (never re-worded here), and
two absent at once are BOTH named — telling an owner to fix one thing and leaving them
stuck would be the same silence in a different place.

The stale-VO₂max cases live in ``test_biological_age_freshness``; both files share
``_bio_age_bed`` so they cannot drift into testing different owners.
"""

from __future__ import annotations

from datetime import timedelta

import pytest
from tests.analytics._bio_age_bed import (
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

from healthee.analytics.biological_age import REQUIRED_TERMS_MESSAGE, compute_biological_age
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.derive.freshness import NO_NIGHTS_IN_WINDOW, NOT_DERIVED_YET
from healthee.derive.sleep_score import SRI_MESSAGES, SRI_WINDOW_TOO_SHORT
from healthee.derive.vo2max import WITHHOLD_RHR_TOO_NOISY

pytestmark = pytest.mark.integration


@pytest.mark.usefixtures("db")
def test_a_stale_sri_withholds_the_composite_exactly_as_a_stale_vo2max_does() -> None:
    """THE regularity half of the class. A 90-day-old SRI describes a week 90 days ago.

    Dropping the term instead would assert ``HR_SRI = 1.0`` — SRI ≈ 68, the neutral point
    of the Cribb log-linear — which for an irregular sleeper silently subtracts years.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        cur.execute("DELETE FROM sleep_session")
        seed_owner(cur, today)
        dd(cur, today, "vo2max_estimate", VO2MAX)
        # Move the ONLY SRI row 90 days back, and give today a complete 7-night window so
        # the gate cannot blame a short week: the sole reason left is that it is not today's.
        cur.execute(
            "UPDATE derived_daily SET day = %s WHERE metric = 'sleep_regularity_index'",
            (today - timedelta(days=90),),
        )
        seed_nights(cur, today, 7)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert result["biological_age"] is None
    assert result["delta_years"] is None
    assert result["data_confidence"] == "insufficient_data"
    assert absent(result) == {"regularity": NOT_DERIVED_YET}
    assert result["withheld"]["terms"][0]["message"] == SRI_MESSAGES[NOT_DERIVED_YET]
    # The honest terms survive, and the composite that WOULD have shipped is nowhere:
    # 40 + (−1.8) + 0.6 = 38.8 is the two-lever number this test refuses.
    assert set(terms(result)) == {"fitness", "sleep duration"}
    assert 38.8 not in [v for v in result.values() if isinstance(v, float)]


@pytest.mark.usefixtures("db")
def test_an_sri_from_a_short_week_names_the_directive_not_the_sync() -> None:
    """<7 nights is the note's own withhold (Directive 4), not "we haven't computed it".

    The two states send an owner to different actions — "wear the strap for the rest of
    the week" vs "sync" — so conflating them would make the message useless.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        cur.execute("DELETE FROM sleep_session")
        seed_owner(cur, today)
        dd(cur, today, "vo2max_estimate", VO2MAX)
        cur.execute(
            "UPDATE derived_daily SET day = %s WHERE metric = 'sleep_regularity_index'",
            (today - timedelta(days=3),),
        )
        seed_nights(cur, today, 4)  # four of the seven nights
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert absent(result) == {"regularity": SRI_WINDOW_TOO_SHORT}
    assert result["withheld"]["terms"][0]["message"] == SRI_MESSAGES[SRI_WINDOW_TOO_SHORT]


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
    assert set(terms(result)) == {"fitness", "regularity"}


@pytest.mark.usefixtures("db")
def test_two_absent_terms_are_both_named() -> None:
    """Naming only the first would tell an owner to fix one thing and leave them stuck."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        cur.execute("DELETE FROM sleep_session")
        seed_owner(cur, today)
        dd(cur, today - timedelta(days=1), "vo2max_estimate", VO2MAX)
        rhr(cur, today, NOISY)  # fitness: the gate refuses today
        cur.execute("DELETE FROM derived_daily WHERE metric = 'sleep_regularity_index'")
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert absent(result) == {
        "fitness": WITHHOLD_RHR_TOO_NOISY,
        "regularity": SRI_WINDOW_TOO_SHORT,
    }
    assert result["withheld"]["consequence"] == REQUIRED_TERMS_MESSAGE
    assert set(terms(result)) == {"sleep duration"}
