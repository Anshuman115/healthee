"""WP-C3c through the pipeline: the ranking is instructed AND enforced.

CHALLENGES.md §5.1b. ``test_levers`` pins the ordering itself; this pins that generation
actually uses it — that the lever table reaches the model, and that a proposal on a metric
the ranking took off the menu dies at the gate rather than relying on the model to have
read the instruction. The two halves matter separately: legacy told itself in prose to
route around abandoned challenges and never checked, which is exactly the failure mode
"instruct AND enforce" exists to close.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from tests.challenges import _seed
from tests.challenges._gen import (
    ESTABLISHED_ID,
    TODAY,
    proposal,
    response,
    run_generation,
    suggested,
)
from tests.insights._stub import StubLLM

from healthee.core.db import tenant_transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration

WEEK = [TODAY - timedelta(days=i) for i in range(1, 8)]


@pytest.fixture
def sedentary_owner(db: None):  # noqa: ARG001 — gates on DB reachability
    """35 MVPA min/week and 3,000 steps a day: two real gaps, MVPA the larger."""
    migrate.apply_migrations()
    _seed.reset()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "mvpa_min", dict.fromkeys(WEEK, 5.0))
        _seed.seed_metric(cur, _seed.OWNER, "steps_total", dict.fromkeys(WEEK, 3000.0))
        _seed.seed_metric(cur, _seed.OWNER, "cardio_load", dict.fromkeys(WEEK, 40.0))
    yield
    _seed.reset()


def _prompt(stub: StubLLM) -> str:
    """Everything the model was actually asked, as one string."""
    return "\n".join(message["content"] for message in stub.messages[0])


# ── instructed: the ranking reaches the model ─────────────────────────────────


def test_the_lever_ranking_is_put_in_front_of_the_model(sedentary_owner: None) -> None:  # noqa: ARG001
    stub = StubLLM([response(proposal(metric="mvpa_min", cadence="weekly", target_value=60.0))])
    run_generation(stub)
    prompt = _prompt(stub)

    assert "YOUR BIGGEST LEVERS" in prompt
    assert "| 1 | mvpa_min |" in prompt
    assert "steepest at the bottom [mvpa_minutes_mortality]" in prompt
    # The gap and the target are SHOWN, because an ordering nobody can read back is a
    # score wearing a table (`levers`' module docstring).
    assert "150 [mvpa_minutes_mortality]" in prompt
    assert "+115" in prompt


def test_a_metric_with_no_dose_response_evidence_is_named_as_unplaceable(
    sedentary_owner: None,  # noqa: ARG001
) -> None:
    """`cardio_load` has a usable baseline and no population target — say so, don't hide it."""
    stub = StubLLM([response(proposal(metric="mvpa_min", cadence="weekly", target_value=60.0))])
    run_generation(stub)
    prompt = _prompt(stub)

    assert "NOT RANKED" in prompt
    assert "`cardio_load`" in prompt
    assert "do not imply a health payoff we cannot cite" in prompt


# ── enforced: off the menu means rejected, not discouraged ────────────────────


def test_a_proposal_on_an_abandoned_metric_is_rejected_however_well_written(
    sedentary_owner: None,  # noqa: ARG001
) -> None:
    """They walked away from steps last week. The model proposes steps anyway."""
    with tenant_transaction(_seed.OWNER) as cur:
        challenge_id = _seed.seed_challenge(cur, _seed.OWNER, status="abandoned")
        _seed.seed_outcome(
            cur,
            _seed.OWNER,
            challenge_id,
            status="abandoned",
            ended_at=datetime(2026, 7, 10, 6, 0, tzinfo=UTC),
        )
    result = run_generation(StubLLM([response(proposal(target_value=4000.0))]))

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert "not on this owner's menu" in result["rejected"][0]
    assert "abandoned on 2026-07-10" in result["rejected"][0]
    assert suggested() == []


def test_an_under_recovered_owner_cannot_be_handed_a_hard_training_lever(
    sedentary_owner: None,  # noqa: ARG001
) -> None:
    """[[recovery_readiness]] D8 as a GATE, not a paragraph the model may weigh.

    A week in the `low` band, and a perfectly grounded, perfectly in-band MVPA challenge
    still does not ship. The steps challenge in the same batch does — the rule withholds
    intensity, not movement.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "recovery_score", dict.fromkeys(WEEK, 20.0))
    intense = proposal(
        metric="mvpa_min",
        cadence="weekly",
        target_value=60.0,
        category="fitness",
        why=f"More weekly movement minutes may support fitness [{ESTABLISHED_ID}].",
    )
    result = run_generation(StubLLM([response(intense, proposal(target_value=4000.0))]))

    assert result["generated"] == 1
    assert suggested()[0]["metric"] == "steps_total"
    assert len(result["rejected"]) == 1
    assert "hard training lever withheld" in result["rejected"][0]


def test_the_off_menu_metrics_are_also_named_in_the_prompt(sedentary_owner: None) -> None:  # noqa: ARG001
    """Enforcement without instruction burns a whole batch on a rule nobody was told."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "recovery_score", dict.fromkeys(WEEK, 20.0))
    stub = StubLLM([response(proposal(target_value=4000.0))])
    run_generation(stub)
    prompt = _prompt(stub)

    assert "OFF THE MENU" in prompt
    assert "`mvpa_min`: a hard training lever withheld" in prompt
    assert "recovery band `low`" in prompt


def test_generation_still_works_for_an_owner_with_no_rankable_lever(db: None) -> None:  # noqa: ARG001
    """A caffeine-only owner: no population target anywhere, and a challenge still ships.

    The ranking is a steer, never a precondition — an owner the corpus cannot place must
    not lose the feature, only the sentence about where the returns are largest.
    """
    migrate.apply_migrations()
    _seed.reset()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(
            cur,
            _seed.OWNER,
            "caffeine",
            [
                (datetime(2026, 7, 8, 6, 0, tzinfo=UTC) + timedelta(days=i), 200.0, "mg")
                for i in range(7)
            ],
        )
    stub = StubLLM(
        [
            response(
                proposal(
                    metric="caffeine_mg",
                    comparator="<=",
                    target_value=150.0,
                    category="sleep",
                    why=f"Lower evening caffeine may protect sleep [{ESTABLISHED_ID}].",
                )
            )
        ]
    )
    result = run_generation(stub)

    assert result["generated"] == 1
    # The heading still renders — the task text points at it — but it claims nothing.
    assert "NOTHING COULD BE RANKED for this owner" in _prompt(stub)
    assert "| 1 |" not in _prompt(stub)
    _seed.reset()
