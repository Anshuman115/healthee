"""The outcome ledger as the coach's personal evidence — and what it refuses to carry.

COACH_ROADMAP C2. The audit's biggest single miss was that legacy BUILT this ledger and
never connected it to the coach; connecting it is only half the work, because the
ledger's caveats are structural for a reason (CHALLENGES.md §2.1, §7 decision 1).

So these tests are mostly about ABSENCE, and absence is the point: a caveat the model is
asked to respect can be dropped, while a number that is not in the prompt cannot be
quoted. Each one would still pass if the module merely *said* the right thing in prose —
so each asserts the number itself is missing, not that a warning is present.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime

import pytest
from tests.challenges import _seed

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.db import migrate
from healthee.insights.challenge_context import challenge_section
from healthee.insights.coach_context import build_coach_context

pytestmark = pytest.mark.integration

OWNER = _seed.OWNER

# The co-occurring block a real outcome carries: other metrics that moved in the same
# window, already stripped of the causal claim by `ledger._co_occurring`.
CO_OCCURRING = {
    "attribution": "none",
    "note": "moved during the same window; not attributed to this challenge",
    "concurrent_challenges": 2,
    "metrics": {"hrv_sleep_avg": {"before": 41.0, "after": 47.0, "delta_pct": 14.6}},
}


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _section() -> str:
    with tenant_transaction(OWNER) as cur:
        return challenge_section(cur, OWNER)


def _seed_outcome(**overrides) -> None:
    with tenant_transaction(OWNER) as cur:
        challenge_id = _seed.seed_challenge(
            cur,
            OWNER,
            status="completed",
            title=overrides.pop("title", "A finished commitment"),
            metric=overrides.get("metric", "steps_total"),
            adopted_at=datetime(2026, 7, 1, 6, 0, tzinfo=UTC),
        )
        _seed.seed_outcome(cur, OWNER, challenge_id, **overrides)


# ── the evidence half ─────────────────────────────────────────────────────────


def test_a_healthy_outcome_reaches_the_coach_as_a_citable_personal_finding(
    clean_db: None,  # noqa: ARG001
) -> None:
    _seed_outcome(improvement_pct=12.4, adherence=0.857, days_active=14, data_confidence="ok")

    section = _section()

    assert "WHAT HAS ACTUALLY WORKED FOR THIS PERSON" in section
    assert "[personal_finding:challenge_outcome]" in section
    assert "single-subject and observational" in section
    assert "+12.4%" in section
    assert "kept on 86% of days" in section


def test_the_confounds_ride_on_the_same_line_as_the_number_they_qualify(
    clean_db: None,  # noqa: ARG001
) -> None:
    """A caveat in its own block is a caveat a summary can leave behind."""
    _seed_outcome(
        improvement_pct=12.4,
        days_active=14,
        confounds={
            "illness_days": 2,
            "concurrent_challenges": 3,
            "regression_to_mean": {"assessed": True, "at_risk": True, "baseline_z": -2.4},
        },
    )

    line = next(ln for ln in _section().splitlines() if "+12.4%" in ln)

    assert "2 day(s) with an illness flag" in line
    assert "3 other commitment(s) ran alongside it" in line
    assert "starting point was itself abnormal" in line


def test_an_unassessed_confound_is_not_reported_as_a_clean_bill(clean_db: None) -> None:  # noqa: ARG001
    """ "We could not check" and "we checked and it is fine" are different states."""
    _seed_outcome(
        improvement_pct=8.0,
        confounds={
            "illness_days": 0,
            "concurrent_challenges": 0,
            "regression_to_mean": {"assessed": False, "reason": "only 4 days of history"},
        },
    )

    line = next(ln for ln in _section().splitlines() if "+8%" in ln)

    assert "could not be assessed" in line
    assert "only 4 days of history" in line


# ── the two refusals, enforced by absence ─────────────────────────────────────


def test_an_insufficient_data_outcome_is_never_offered_as_evidence(clean_db: None) -> None:  # noqa: ARG001
    """It is listed — hiding it invites invention — but WITHOUT a number to quote."""
    _seed_outcome(
        title="Two logged days",
        improvement_pct=61.3,
        adherence=1.0,
        data_confidence="insufficient_data",
    )

    section = _section()

    assert "NOT EVIDENCE" in section
    assert "WHAT HAS ACTUALLY WORKED FOR THIS PERSON" not in section
    assert "61.3" not in section  # the number is not in the prompt at all
    assert "insufficient_data" in section


def test_a_thin_outcome_cannot_ride_along_with_a_healthy_one(clean_db: None) -> None:  # noqa: ARG001
    """The two blocks are separated by CONFIDENCE, not by ordering luck."""
    _seed_outcome(metric="steps_total", improvement_pct=12.4, data_confidence="ok")
    _seed_outcome(
        metric="mvpa_min",
        title="Barely measured",
        improvement_pct=61.3,
        data_confidence="insufficient_data",
    )

    section = _section()
    evidence, _, unusable = section.partition("NOT EVIDENCE")

    assert "+12.4%" in evidence and "61.3" not in evidence
    assert "mvpa_min" in unusable and "61.3" not in unusable


def test_a_co_occurring_delta_never_reaches_the_prompt(clean_db: None) -> None:  # noqa: ARG001
    """§2.1's biggest fix mandate: the numbers are absent, so nothing can attribute them.

    Legacy fed exactly these per-challenge "downstream" deltas back into generation while
    four challenges ran at once. Asking a model not to attribute a number you handed it is
    the arrangement that produced the small confident lie; not handing it over is not.
    """
    _seed_outcome(improvement_pct=12.4, co_occurring=CO_OCCURRING, data_confidence="ok")

    section = _section()

    assert "+12.4%" in section  # the claim we DO make is there
    assert "hrv_sleep_avg" not in section
    assert "14.6" not in section
    assert "co_occurring" not in section
    assert "cannot be attributed" in section  # and the model is told why it is absent


# ── the commitments half (what ``adopt_challenge`` needs to exist) ────────────


def test_the_suggestions_carry_the_ids_adopt_challenge_takes(clean_db: None) -> None:  # noqa: ARG001
    with tenant_transaction(OWNER) as cur:
        suggested = _seed.seed_challenge(cur, OWNER, title="Walk a little more")
        active = _seed.seed_challenge(
            cur,
            OWNER,
            status="active",
            metric="sri",
            title="Steadier bedtimes",
            target_value=60.0,
            adopted_at=datetime(2026, 7, 1, 6, 0, tzinfo=UTC),
        )

    section = _section()

    assert f"#{suggested} Walk a little more" in section
    assert f"#{active} Steadier bedtimes" in section
    assert "SUGGESTED — built for them but NOT started" in section
    assert "`adopt_challenge`" in section


def test_the_ledger_actually_reaches_the_coachs_standing_context(clean_db: None) -> None:  # noqa: ARG001
    """The wire, end to end — INTELLIGENCE §4 recorded this block as "not present"."""
    _seed_outcome(improvement_pct=12.4, data_confidence="ok")

    context = build_coach_context("what has actually worked for me?", OWNER, SENTINEL_TZ, days=30)

    assert "[personal_finding:challenge_outcome]" in context
    assert "+12.4%" in context


def test_an_owner_with_no_challenges_gets_no_section_at_all(clean_db: None) -> None:  # noqa: ARG001
    """An empty heading is prompt weight that says nothing (and invites invention)."""
    assert _section() == ""


def test_the_section_is_owner_scoped(clean_db: None) -> None:  # noqa: ARG001
    _seed.ensure_owner_b()
    try:
        with tenant_transaction(_seed.OTHER_OWNER) as cur:
            _seed.seed_challenge(cur, _seed.OTHER_OWNER, title="B's private commitment")

        assert "B's private commitment" not in _section()
    finally:
        _seed.remove_owner_b()
