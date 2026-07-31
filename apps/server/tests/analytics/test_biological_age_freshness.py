"""A withheld VO₂max must not be spent as a current term of the biological age.

``derive/vo2max.py`` writes NO row on a day whose inputs cannot carry the Jurca
estimate, and ``read/vo2max.py`` reports that day as ``insufficient_data``.
``_fitness_term`` read "the newest ``vo2max_estimate`` row" — a different claim — so
one ``/api/today`` payload could refuse to name a VO₂max in the fitness card and, three
keys away, spend a 40-day-old one inside a headline composite. Fitness is the note's
**dominant** term, so that is not a rounding error; it is years.

What these tests pin, and why each is a separate property:

1. **A current estimate is unaffected** — the arithmetic, as known values, so the fix
   cannot be "green because the number went away".
2. **A withheld today withholds the COMPOSITE**, not just the term. Leaving the term out
   would silently assert ``HR_fitness = 1.0`` ("this owner is exactly at the age/sex
   median"), which is a claim about them and would move the number by years with nothing
   about them having changed.
3. **The surviving terms are untouched and still shipped** — sleep duration and
   regularity are standalone hazard→years facts, and they carry the same values here as
   in the healthy case.
4. **One rule for both absences** — never derived and derived-but-stale are the same
   state to a reader, so they get the same treatment with different *reasons*.
5. **The two surfaces agree.** The strongest assertion in the file: on ONE cursor,
   ``vo2max_payload`` withholding and ``compute_biological_age`` withholding are the
   same event. This is what stops the two gates forking again.
"""

from __future__ import annotations

import json
from datetime import date, timedelta

import pytest

from healthee.analytics.biological_age import FITNESS_REQUIRED_MESSAGE, compute_biological_age
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.derive.vo2max import (
    NOT_DERIVED_YET,
    WITHHOLD_MESSAGES,
    WITHHOLD_RHR_TOO_NOISY,
)
from healthee.read.vo2max import vo2max_payload

pytestmark = pytest.mark.integration

# ── the fixture, chosen so every expected number is hand-derivable ────────────
#
# Identical inputs to `test_biological_age_math`'s composed case, so the two files pin
# the same arithmetic from opposite sides: that one through a stub, this one through a
# real database and the real withhold gate.
_CHRONO_AGE = 40
_VO2MAX = 41.5  # ml/kg/min — vs the note's 38.0 median for a 40 y male
_TST_MIN = 360.0  # 6.0 h/night across the 14-night window
_SRI = 58.0

# Hand-derived from [[biological_age_estimate]] (see test_biological_age_math for the
# full working): fitness −1.8054, sleep +0.6473, regularity +1.7752 → ΔAge +0.6171.
_FITNESS_YEARS = -1.8
_SLEEP_YEARS = 0.6
_REGULARITY_YEARS = 1.8
_BIO_AGE = 40.6

# median 56, MAD 4 → inside every gate: these seven days DERIVE.
_CALM = [50.0, 52.0, 54.0, 56.0, 58.0, 60.0, 62.0]
# median 56, MAD 12 → above the note's 8 bpm ceiling: this week is WITHHELD. Seven days
# on purpose — the gate reads a 7-day window, so a shorter noisy run would leave calm
# days in it and the MAD would be of the mixture (the same trap `test_vo2max_freshness`
# documents).
_NOISY = [40.0, 44.0, 47.0, 56.0, 65.0, 68.0, 72.0]


def _reset(cur) -> None:
    for table in ("derived_daily", "weight_log", "profile"):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names


def _dd(cur, day: date, metric: str, value: float, flags: dict | None = None) -> None:
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
        "VALUES (%s, %s, %s, %s, %s::jsonb) ON CONFLICT (user_id, day, metric) DO UPDATE "
        "SET value = EXCLUDED.value, flags = EXCLUDED.flags",
        (SENTINEL_USER_ID, day, metric, value, json.dumps(flags or {})),
    )


def _seed_owner(cur, today: date) -> None:
    """A profile at exactly ``_CHRONO_AGE``, plus the two non-fitness terms' inputs.

    The dob is anchored to the owner's OWN today (not the process date) and set to
    Jan 1, so the chronological age is 40 on every run date — ``(m, d) < (1, 1)`` is
    false for every day of the year.
    """
    cur.execute(
        "INSERT INTO profile (user_id, height_cm, sex, dob) VALUES (%s, 175, 'male', %s)",
        (SENTINEL_USER_ID, date(today.year - _CHRONO_AGE, 1, 1)),
    )
    cur.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, now() - interval '30 days', 72)",
        (SENTINEL_USER_ID,),
    )
    for n in range(14):
        _dd(cur, today - timedelta(days=n), "sleep_health_score_4dim", 2.0, {"tst_min": _TST_MIN})
    _dd(cur, today, "sleep_regularity_index", _SRI)


def _rhr(cur, day: date, values: list[float]) -> None:
    """One ``rhr_daily`` row per day of the 7-day window ENDING on ``day``."""
    for k, value in enumerate(values):
        _dd(cur, day - timedelta(days=len(values) - 1 - k), "rhr_daily", value)


def _terms(result: dict) -> dict[str, dict]:
    return {c["term"]: c for c in result["contributions"]}


# ── 1 · the healthy path, as known values ────────────────────────────────────


@pytest.mark.usefixtures("db")
def test_a_current_vo2max_produces_the_full_composite() -> None:
    """Today's estimate exists ⇒ all three terms, and the note's arithmetic."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _seed_owner(cur, today)
        _dd(cur, today, "vo2max_estimate", _VO2MAX)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert result["data_confidence"] == "ok"
    assert result["withheld"] is None
    assert result["chronological_age"] == _CHRONO_AGE
    assert result["biological_age"] == pytest.approx(_BIO_AGE)
    assert result["delta_years"] == pytest.approx(0.6)
    terms = _terms(result)
    assert set(terms) == {"fitness", "sleep duration", "regularity"}
    assert terms["fitness"]["delta_years"] == pytest.approx(_FITNESS_YEARS)
    assert terms["fitness"]["value"] == pytest.approx(_VO2MAX)
    assert terms["sleep duration"]["delta_years"] == pytest.approx(_SLEEP_YEARS)
    assert terms["regularity"]["delta_years"] == pytest.approx(_REGULARITY_YEARS)


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
        _reset(cur)
        _seed_owner(cur, today)
        _dd(cur, today - timedelta(days=1), "vo2max_estimate", _VO2MAX)
        _rhr(cur, today, _NOISY)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert result["biological_age"] is None
    assert result["delta_years"] is None
    assert result["data_confidence"] == "insufficient_data"
    withheld = result["withheld"]
    assert withheld["term"] == "fitness"
    assert withheld["reason"] == WITHHOLD_RHR_TOO_NOISY
    assert withheld["message"] == WITHHOLD_MESSAGES[WITHHOLD_RHR_TOO_NOISY]
    assert withheld["consequence"] == FITNESS_REQUIRED_MESSAGE


@pytest.mark.usefixtures("db")
def test_the_terms_that_are_current_survive_the_withhold_unchanged() -> None:
    """Sleep and regularity are separately-sourced facts; withholding them too would
    hide something we do know. Their year contributions are the SAME numbers the
    healthy case asserts — the withhold removes a term, it does not perturb the rest.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _seed_owner(cur, today)
        _dd(cur, today - timedelta(days=1), "vo2max_estimate", _VO2MAX)
        _rhr(cur, today, _NOISY)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    terms = _terms(result)
    assert set(terms) == {"sleep duration", "regularity"}
    assert terms["sleep duration"]["delta_years"] == pytest.approx(_SLEEP_YEARS)
    assert terms["regularity"]["delta_years"] == pytest.approx(_REGULARITY_YEARS)
    # And the number that WOULD have shipped is not sitting in the payload under any
    # name: 40 + 0.6 + 1.8 = 42.4 is the two-lever composite this test refuses.
    assert 42.4 not in [v for v in result.values() if isinstance(v, float)]


# ── 4 · one rule, both absences, different reasons ───────────────────────────


@pytest.mark.usefixtures("db")
def test_a_stale_row_deep_in_history_cannot_carry_todays_fitness_term() -> None:
    """40 days old is not today, and a calm RHR week means the GATE is not the reason.

    ``not_derived_yet`` vs a withhold is the difference between "sync the strap" and
    "your resting HR is unstable" — the payload must not conflate them.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _seed_owner(cur, today)
        _dd(cur, today - timedelta(days=40), "vo2max_estimate", _VO2MAX)
        _rhr(cur, today, _CALM)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert result["biological_age"] is None
    assert result["withheld"]["reason"] == NOT_DERIVED_YET
    assert result["withheld"]["message"] == WITHHOLD_MESSAGES[NOT_DERIVED_YET]


@pytest.mark.usefixtures("db")
def test_no_vo2max_at_all_is_the_same_state_as_a_stale_one() -> None:
    """An owner who has never had an estimate gets the same treatment.

    Before this change a first-time owner's composite shipped from two levers, which
    is the identical unstated "assume median fitness" — the defect, arrived at from a
    different direction. ONE rule (CLAUDE.md §ONE canonical definition).
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _seed_owner(cur, today)
        result = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    assert result["biological_age"] is None
    assert result["data_confidence"] == "insufficient_data"
    assert set(_terms(result)) == {"sleep duration", "regularity"}


@pytest.mark.usefixtures("db")
def test_an_owner_with_no_inputs_at_all_still_gets_nothing() -> None:
    """The unchanged floor: no terms means no card to caveat, so ``None`` as before."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        cur.execute(
            "INSERT INTO profile (user_id, height_cm, sex, dob) VALUES (%s, 175, 'male', %s)",
            (SENTINEL_USER_ID, date(today.year - _CHRONO_AGE, 1, 1)),
        )
        assert compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ) is None


# ── 5 · the invariant: the fitness card and the composite tell one story ─────


@pytest.mark.usefixtures("db")
@pytest.mark.parametrize(
    ("vo2max_age_days", "rhrs"),
    [
        (0, _CALM),  # today's estimate exists
        (1, _NOISY),  # the gate withholds today
        (40, _CALM),  # nothing derived for today
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
        _reset(cur)
        _seed_owner(cur, today)
        _dd(cur, today - timedelta(days=vo2max_age_days), "vo2max_estimate", _VO2MAX)
        _rhr(cur, today, rhrs)
        card = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
        bio = compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert card is not None
    assert bio is not None
    assert (card["estimate"] is None) == (bio["biological_age"] is None)
    assert card["data_confidence"] == bio["data_confidence"]
    if card["withheld"] is not None:
        assert card["withheld"]["reason"] == bio["withheld"]["reason"]
