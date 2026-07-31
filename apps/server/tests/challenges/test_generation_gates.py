"""WP-C3 Gate A (baseline bounds) and Gate B (cite-or-refuse), end to end.

The two gates CHALLENGES.md §5.1 says the model cannot talk its way past. Gate B is the
legacy hole: ``_validate`` (:390) dropped a bad citation and persisted the challenge
anyway, so every case here that ends in "nothing shipped" is a challenge legacy would
have shown somebody.

Structure, tenancy and the retry live in ``test_generation_invariants``; the shared
seeding bed is ``_gen``.
"""

from __future__ import annotations

from datetime import timedelta

import pytest
from tests.challenges import _seed
from tests.challenges._gen import (
    BAND_HIGH,
    BASELINE_STEPS,
    ESTABLISHED_ID,
    IN_BAND,
    IST,
    TODAY,
    proposal,
    response,
    run_generation,
    seed_caffeine_habit,
    suggested,
)
from tests.insights._ids import CONTESTED_ID
from tests.insights._stub import StubLLM

from healthee.challenges import bounds, generate
from healthee.core.db import tenant_transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration

# ── the happy path, and the invariant that the stored number is the proposed one ──


def test_a_grounded_in_band_proposal_persists_verbatim(owner_with_history: None) -> None:  # noqa: ARG001
    result = run_generation(StubLLM([response()]))

    assert (result["ok"], result["generated"], result["rejected"]) == (True, 1, [])
    rows = suggested()
    assert len(rows) == 1
    row = rows[0]
    assert row["status"] == "suggested"
    assert row["target_value"] == IN_BAND  # byte-for-byte the proposal's number
    assert row["research_note_ids"] == [ESTABLISHED_ID]
    assert row["gen_date"] == TODAY
    assert row["baseline_value"] is None  # the baseline is frozen at ADOPT, not here


def test_nothing_between_the_gates_and_the_row_rewrites_the_target(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """The copy/number invariant: no accept path clamps, so prose cannot go stale.

    A target at the ceiling is proposed alongside copy that names it; both the column
    and the sentence must still say 6500 after the round trip.
    """
    stretch = proposal(target_value=BAND_HIGH, why=f"Reaching 6500 may help [{ESTABLISHED_ID}].")
    result = run_generation(StubLLM([response(stretch)]))

    assert result["generated"] == 1
    row = suggested()[0]
    assert row["target_value"] == BAND_HIGH
    assert "6500" in row["why"]


# ── Gate B — cite-or-refuse (the legacy hole, pinned hard) ────────────────────


def test_a_fabricated_inline_citation_never_persists(owner_with_history: None) -> None:  # noqa: ARG001
    """Legacy's ``_validate`` dropped the bad citation and shipped the challenge anyway."""
    bad = proposal(
        why="Steps raise VO2max quickly [totally_made_up_note].",
        research_note_ids=["totally_made_up_note"],
    )
    stub = StubLLM([response(bad)])
    result = run_generation(stub)

    assert result == {
        "ok": False,
        "reason": "no_grounded_output",
        "error": "the evidence base could not ground a challenge",
    }
    assert suggested() == []
    assert stub.calls == 2  # the choke point's own nudged retry, then the honest fallback


def test_a_fabricated_id_in_the_note_array_alone_is_dropped(owner_with_history: None) -> None:  # noqa: ARG001
    """Inline cite valid (so the response validates) but the array names a ghost note.

    The REASON is asserted, not just the drop: several gates would refuse this proposal
    (an unresolvable id also proves no grade), and a test that only counts rejections
    would keep passing with the citability check deleted.
    """
    bad = proposal(research_note_ids=[ESTABLISHED_ID, "not_a_real_note"])
    result = run_generation(StubLLM([response(bad)]))

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert "do not exist in the manifest" in result["rejected"][0]
    assert suggested() == []


def test_aproposal_with_an_empty_note_array_does_not_persist(owner_with_history: None) -> None:  # noqa: ARG001
    """Purely descriptive copy passes the validator; cite-or-refuse still drops it."""
    bare = proposal(
        why="Walk a bit further each day.",
        expected_outcome="More steps by the end of the window.",
        research_note_ids=[],
    )
    result = run_generation(StubLLM([response(bare)]))

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert "no research_note_ids" in result["rejected"][0]
    assert suggested() == []


def test_a_why_with_no_inline_citation_does_not_persist(owner_with_history: None) -> None:  # noqa: ARG001
    """A real note in the array is not the same as a claim grounded in the sentence.

    Legacy shipped exactly this: an array of ids beside prose that cited none of them.
    """
    unlinked = proposal(
        why="Walk a bit further each day.",
        expected_outcome="More steps by the end of the window.",
    )
    result = run_generation(StubLLM([response(unlinked)]))

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert "no inline [note_id]" in result["rejected"][0]
    assert suggested() == []


def test_evidence_weaker_than_probable_cannot_drive_a_commitment(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    weak = proposal(
        why=f"The science is mixed on whether steps help here [{CONTESTED_ID}].",
        expected_outcome="A steadier week of movement.",
        research_note_ids=[CONTESTED_ID],
    )
    result = run_generation(StubLLM([response(weak)]))

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert suggested() == []


# ── Gate A — baseline bounds, in BOTH directions ──────────────────────────────


def test_an_out_of_band_up_target_is_rejected_never_clamped(owner_with_history: None) -> None:  # noqa: ARG001
    stub = StubLLM([response(proposal(target_value=12000.0))])
    result = run_generation(stub)

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert suggested() == []
    assert stub.calls == 2  # the bounds retry: asked again with the violation named


def test_a_cap_target_above_the_baseline_is_rejected(owner_with_history: None) -> None:  # noqa: ARG001
    """The direction trap. A "+10-30 %" band would ACCEPT a bigger caffeine allowance.

    Seeded with a 200 mg-a-day habit, so the cap band is [140, 175]; 240 is the model
    proposing MORE caffeine and calling it progress.
    """
    seed_caffeine_habit()
    cap = proposal(
        metric="caffeine_mg",
        comparator="<=",
        target_value=240.0,
        category="sleep",
        why=f"Lower evening caffeine may protect sleep [{ESTABLISHED_ID}].",
    )
    result = run_generation(StubLLM([response(cap)]))

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert suggested() == []


def test_an_in_band_cap_target_is_accepted(owner_with_history: None) -> None:  # noqa: ARG001
    seed_caffeine_habit()
    cap = proposal(
        metric="caffeine_mg",
        comparator="<=",
        target_value=150.0,
        category="sleep",
        why=f"Lower evening caffeine may protect sleep [{ESTABLISHED_ID}].",
    )
    result = run_generation(StubLLM([response(cap)]))

    assert result["generated"] == 1
    assert suggested()[0]["target_value"] == 150.0


def test_a_thin_baseline_owner_gets_nothing_and_costs_no_tokens(db: None) -> None:  # noqa: ARG001
    """An owner with no history at all: refused BEFORE the model is ever asked."""
    migrate.apply_migrations()
    _seed.reset()
    stub = StubLLM([response()])
    result = generate.generate_challenges(_seed.OWNER, IST, client=stub, today=TODAY)

    assert result["reason"] == "no_calibratable_metric"
    assert stub.calls == 0
    _seed.reset()


def test_three_measured_days_are_not_a_baseline(db: None) -> None:  # noqa: ARG001
    """The honest answer for a nearly-new owner: refuse the metric, don't calibrate on noise.

    Three days of a seven-day estimator is below ``series.MIN_COMPARISON_DAYS`` — the same
    line the ledger refuses to publish a before/after under. A mean over three days would
    produce a band that looks exactly like a real one.
    """
    migrate.apply_migrations()
    _seed.reset()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur,
            _seed.OWNER,
            "steps_total",
            {TODAY - timedelta(days=i): BASELINE_STEPS for i in range(1, 4)},
        )
    stub = StubLLM([response()])
    result = generate.generate_challenges(_seed.OWNER, IST, client=stub, today=TODAY)

    assert result["reason"] == "no_calibratable_metric"
    assert stub.calls == 0
    _seed.reset()


def test_a_week_of_measured_zeros_is_a_reading_not_a_baseline(db: None) -> None:  # noqa: ARG001
    """Seven days, every one of them zero: enough data, no signal to stretch from.

    A percentage band around zero is undefined, and the step-widening would otherwise
    manufacture a 250-step "target" out of the rounding constant.
    """
    migrate.apply_migrations()
    _seed.reset()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur,
            _seed.OWNER,
            "steps_total",
            {TODAY - timedelta(days=i): 0.0 for i in range(1, 8)},
        )
    stub = StubLLM([response(proposal(target_value=250.0))])
    result = generate.generate_challenges(_seed.OWNER, IST, client=stub, today=TODAY)

    assert result["reason"] == "no_calibratable_metric"
    assert stub.calls == 0
    # The REASON is user- and log-facing, and "we have your data, it says zero" is a
    # different statement from "we have nothing" or "there is nothing left to cap".
    with tenant_transaction(_seed.OWNER) as cur:
        calibration = bounds.calibrate(cur, _seed.OWNER, IST, "steps_total", "daily", TODAY)
    assert (calibration.baseline, calibration.baseline_days) == (0.0, 7)
    assert calibration.refusal == "no_baseline_signal"
    _seed.reset()


# ── the copy may not disagree with the stored number ──────────────────────────


def test_copy_restating_a_different_number_is_rejected(owner_with_history: None) -> None:  # noqa: ARG001
    """The brief's example: an in-band target with prose about a different one."""
    lying = proposal(
        why=f"Walk 12,000 steps — a stretch on your 10,000 baseline [{ESTABLISHED_ID}]."
    )
    result = run_generation(StubLLM([response(lying)]))

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert suggested() == []
