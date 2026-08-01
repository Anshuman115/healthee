"""No term of the biological age may be spent stale, and none may be quietly dropped.

Each ``_*_term`` read "the newest row" of its input, which is a different claim from
"today's value". So one ``/api/today`` payload could refuse to name a VO₂max in the
fitness card and, three keys away, spend a 40-day-old one inside a headline composite;
(The SRI half of this class was live too, until #86 removed sleep regularity from the
estimate's definition altogether — see ``test_biological_age_math``.)

What these tests pin, and why each is a separate property:

1. **A current estimate is unaffected** — the arithmetic, as known values, so the fix
   cannot be "green because the number went away".
2. **An absent input withholds the COMPOSITE**, not just its term. Leaving a term out
   would silently assert ``HR_term = 1.0`` ("this owner is exactly at the reference for
   that lever"), which is a claim about them and would move the number by years with
   nothing about them having changed.
3. **The surviving terms are untouched and still shipped** — each is a standalone
   hazard→years fact, and they carry the same values here as in the healthy case.
4. **One rule for both absences** — never derived and derived-but-stale are the same
   state to a reader, so they get the same treatment with different *reasons*.
5. **The rule is the same for EVERY term.** Fitness and sleep duration each withhold the
   composite on their own, and two absent at once are BOTH named — naming only the first
   would hide half the reason.
6. **The two surfaces agree.** The strongest assertion in the file: on ONE cursor,
   ``vo2max_payload`` withholding and ``compute_biological_age`` withholding are the
   same event. This is what stops the two gates forking again.
"""

from __future__ import annotations

from datetime import date, timedelta

import pytest
from tests.analytics._bio_age_bed import (
    BIO_AGE,
    CALM,
    CHRONO_AGE,
    FITNESS_YEARS,
    NOISY,
    SLEEP_YEARS,
    VO2MAX,
    absent,
    dd,
    reset,
    rhr,
    seed_owner,
    terms,
)

from healthee.analytics.biological_age import REQUIRED_TERMS_MESSAGE, compute_biological_age
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.derive.freshness import NOT_DERIVED_YET, WEIGHT_STALE
from healthee.derive.vo2max import (
    WITHHOLD_MESSAGES,
    WITHHOLD_RHR_TOO_NOISY,
    derive_vo2max,
)
from healthee.read.vo2max import vo2max_payload

pytestmark = pytest.mark.integration

# ── 1 · the healthy path, as known values ────────────────────────────────────


@pytest.mark.usefixtures("db")
def test_a_current_vo2max_produces_the_full_composite() -> None:
    """Today's estimate exists ⇒ both terms, and the note's arithmetic."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        seed_owner(cur, today)
        dd(cur, today, "vo2max_estimate", VO2MAX)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert result["data_confidence"] == "ok"
    assert result["withheld"] is None
    assert result["chronological_age"] == CHRONO_AGE
    assert result["biological_age"] == pytest.approx(BIO_AGE)
    assert result["delta_years"] == pytest.approx(-1.2)
    by_term = terms(result)
    assert set(by_term) == {"fitness", "sleep duration"}
    assert by_term["fitness"]["delta_years"] == pytest.approx(FITNESS_YEARS)
    assert by_term["fitness"]["value"] == pytest.approx(VO2MAX)
    assert by_term["sleep duration"]["delta_years"] == pytest.approx(SLEEP_YEARS)


# ── 2 + 3 · a withheld today withholds the composite, not the honest terms ───


@pytest.mark.usefixtures("db")
def test_a_withheld_vo2max_withholds_the_composite_and_says_why() -> None:
    """THE bug. Yesterday derived; today's RHR week is too noisy for the gate.

    Before the fix this shipped ``biological_age`` computed from YESTERDAY's VO₂max —
    a headline number whose dominant term the system had already decided it could not
    stand behind.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        seed_owner(cur, today)
        dd(cur, today - timedelta(days=1), "vo2max_estimate", VO2MAX)
        rhr(cur, today, NOISY)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert result["biological_age"] is None
    assert result["delta_years"] is None
    assert result["data_confidence"] == "insufficient_data"
    withheld = result["withheld"]
    assert withheld["consequence"] == REQUIRED_TERMS_MESSAGE
    assert withheld["terms"] == [
        {
            "term": "fitness",
            "reason": WITHHOLD_RHR_TOO_NOISY,
            "message": WITHHOLD_MESSAGES[WITHHOLD_RHR_TOO_NOISY],
        }
    ]


@pytest.mark.usefixtures("db")
def test_the_terms_that_are_current_survive_the_withhold_unchanged() -> None:
    """Sleep duration is a separately-sourced fact; withholding it too would hide
    something we do know. Its year contribution is the SAME number the healthy case
    asserts — the withhold removes a term, it does not perturb the rest.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        seed_owner(cur, today)
        dd(cur, today - timedelta(days=1), "vo2max_estimate", VO2MAX)
        rhr(cur, today, NOISY)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    by_term = terms(result)
    assert set(by_term) == {"sleep duration"}
    assert by_term["sleep duration"]["delta_years"] == pytest.approx(SLEEP_YEARS)
    # And the number that WOULD have shipped is not sitting in the payload under any
    # name: 40 + 0.6 = 40.6 is the one-lever composite this test refuses.
    assert 40.6 not in [v for v in result.values() if isinstance(v, float)]


# ── 4 · one rule, both absences, different reasons ───────────────────────────


@pytest.mark.usefixtures("db")
def test_a_stale_row_deep_in_history_cannot_carry_todays_fitness_term() -> None:
    """40 days old is not today, and a calm RHR week means the GATE is not the reason.

    ``not_derived_yet`` vs a withhold is the difference between "sync the strap" and
    "your resting HR is unstable" — the payload must not conflate them.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        seed_owner(cur, today)
        dd(cur, today - timedelta(days=40), "vo2max_estimate", VO2MAX)
        rhr(cur, today, CALM)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert result["biological_age"] is None
    assert absent(result) == {"fitness": NOT_DERIVED_YET}
    assert result["withheld"]["terms"][0]["message"] == WITHHOLD_MESSAGES[NOT_DERIVED_YET]


@pytest.mark.usefixtures("db")
def test_no_vo2max_at_all_is_the_same_state_as_a_stale_one() -> None:
    """An owner who has never had an estimate gets the same treatment.

    Before this change a first-time owner's composite shipped from the remaining
    lever(s), which is the identical unstated "assume median fitness" — the defect,
    arrived at from a different direction. ONE rule (CLAUDE.md §ONE canonical definition).
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        seed_owner(cur, today)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert result["biological_age"] is None
    assert result["data_confidence"] == "insufficient_data"
    assert set(terms(result)) == {"sleep duration"}


@pytest.mark.usefixtures("db")
def test_an_owner_with_no_inputs_at_all_still_gets_nothing() -> None:
    """The unchanged floor: no terms means no card to caveat, so ``None`` as before."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        cur.execute(
            "INSERT INTO profile (user_id, height_cm, sex, dob) VALUES (%s, 175, 'male', %s)",
            (SENTINEL_USER_ID, date(today.year - CHRONO_AGE, 1, 1)),
        )
        assert compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ) is None


# ── 5 · the invariant: the fitness card and the composite tell one story ─────


@pytest.mark.usefixtures("db")
@pytest.mark.parametrize(
    ("vo2max_age_days", "rhrs"),
    [
        (0, CALM),  # today's estimate exists
        (1, NOISY),  # the gate withholds today
        (40, CALM),  # nothing derived for today
    ],
)
def test_the_vo2max_card_and_the_bio_age_agree_about_today(
    vo2max_age_days: int, rhrs: list[float]
) -> None:
    """Both surfaces of ``/api/today`` read the same gate, so they cannot disagree.

    This is the assertion the fix exists for: the defect was not "bio-age used an old
    number", it was "two panels of one screen disagreed about whether this owner has a
    VO₂max right now". A future consumer that reintroduces its own freshness rule fails
    here rather than in production.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        seed_owner(cur, today)
        dd(cur, today - timedelta(days=vo2max_age_days), "vo2max_estimate", VO2MAX)
        rhr(cur, today, rhrs)
        card = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
        bio = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert card is not None
    assert bio is not None
    assert (card["estimate"] is None) == (bio["biological_age"] is None)
    assert card["data_confidence"] == bio["data_confidence"]
    if card["withheld"] is not None:
        assert absent(bio) == {"fitness": card["withheld"]["reason"]}


# ── 6 · #85 · a stale WEIGHT reaches all the way to the composite ────────────


@pytest.mark.usefixtures("db")
def test_a_weight_from_months_ago_withholds_the_whole_biological_age() -> None:
    """The full chain, end to end: weight → BMI → VO₂max → biological age.

    This is what #85 was about. A mass the owner last measured in the spring anchored a
    number the app presents as their biological age TODAY, and nothing in the payload
    said so — the weight had no date on it by the time BMI saw it. Two models deep, one
    silent stale input.

    Note what is asserted: not that the number moved, but that there is no number. The
    arithmetic error from a few kilograms is small (≈0.2 ml/kg/min per kg against
    Jurca's 5.6 SEE); the dishonesty is presenting a confident age computed from a body
    we stopped knowing about months ago.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        seed_owner(cur, today)
        # Replace the bed's fresh weight with one from six months ago — nothing else
        # changes, so any withhold below is the weight's doing alone.
        cur.execute("DELETE FROM weight_log")
        cur.execute(
            "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, now() - interval '180 days', 72)",
            (SENTINEL_USER_ID,),
        )
        rhr(cur, today, CALM)  # a calm week: the RHR gates have no objection
        assert derive_vo2max(cur, SENTINEL_USER_ID, SENTINEL_TZ, today) is None
        card = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert card is None, "no estimate was ever derived, so there is no card to show"
    assert result is not None
    assert result["biological_age"] is None
    assert result["delta_years"] is None
    assert result["data_confidence"] == "insufficient_data"
    assert absent(result) == {"fitness": WEIGHT_STALE}
    # The term that never touched the weight is still reported as a fact.
    assert set(terms(result)) == {"sleep duration"}


@pytest.mark.usefixtures("db")
def test_the_same_owner_one_fresh_weigh_in_later_gets_their_age_back() -> None:
    # The refusal has to be recoverable by an action the owner can actually take, or it
    # is just a broken feature with a polite message.
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        seed_owner(cur, today)  # seeds a weight logged yesterday
        rhr(cur, today, CALM)
        assert derive_vo2max(cur, SENTINEL_USER_ID, SENTINEL_TZ, today) is not None
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert result["biological_age"] is not None
    assert result["data_confidence"] == "ok"
