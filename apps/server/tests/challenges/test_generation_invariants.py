"""WP-C3's structural invariants, tenancy, the bounds retry, and the WP-C5 seam.

The gates themselves are ``test_generation_gates``; these pin the rules around them —
a challenge must bind to a metric we can measure, one owner's generation must never
touch another's rows, the per-owner cap must hold even when the world moves while the
model is thinking, and the intent parameter WP-C5's ``create_challenge`` will pass must
reach the model without buying a way past Gate A.
"""

from __future__ import annotations

from datetime import UTC, datetime

import pytest
from tests.challenges import _seed
from tests.challenges._gen import (
    ESTABLISHED_ID,
    IN_BAND,
    ClaimsMetricMidFlight,
    proposal,
    response,
    run_generation,
    seed_caffeine_habit,
    steps_history,
    suggested,
)
from tests.insights._stub import StubLLM

from healthee.core.db import tenant_transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration

# ── structural invariants ─────────────────────────────────────────────────────


def test_an_unmeasurable_metric_is_refused(owner_with_history: None) -> None:  # noqa: ARG001
    """A challenge we cannot measure is a promise we cannot keep — refused by NAME.

    The reason is asserted because the calibration lookup would also refuse an unknown
    metric (nothing calibrates a key that is not in the registry); a test that only
    counted the rejection would survive deleting the registry check itself.
    """
    result = run_generation(StubLLM([response(proposal(metric="happiness"))]))

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert "not a trackable challenge metric" in result["rejected"][0]
    assert suggested() == []


def test_an_ungeneratable_cadence_is_refused(owner_with_history: None) -> None:  # noqa: ARG001
    """`total` has no honest band (its baseline and its target are in different units).

    ``series.recent_value`` builds a `total` baseline from the trailing SEVEN days while
    ``evaluate`` scores a `total` over the whole window, so the two disagree for any
    window that is not 7 — the pair is refused rather than calibrated against a
    mismatched number.
    """
    result = run_generation(StubLLM([response(proposal(cadence="total"))]))

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert "not a calibratable pair" in result["rejected"][0]


def test_a_vocabulary_value_is_refused_not_silently_defaulted(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """Legacy rewrote a bad difficulty to "standard" — filing a label nobody chose."""
    result = run_generation(StubLLM([response(proposal(difficulty="brutal"))]))

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert suggested() == []


def test_a_window_outside_the_instructed_range_is_refused(owner_with_history: None) -> None:  # noqa: ARG001
    """Legacy accepted 1-90 days while INSTRUCTING 3-30 — an instruction nobody checks.

    Under three days measures nothing; beyond thirty is a program (WP-C4), not a
    challenge somebody can hold in their head.
    """
    result = run_generation(StubLLM([response(proposal(window_days=90))]))

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert "window_days 90 is outside 3-30" in result["rejected"][0]
    assert suggested() == []


def test_a_duplicate_of_an_active_challenge_is_refused(owner_with_history: None) -> None:  # noqa: ARG001
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_challenge(
            cur,
            _seed.OWNER,
            status="active",
            adopted_at=datetime(2026, 7, 14, 6, 0, tzinfo=UTC),
        )
    result = run_generation(StubLLM([response()]))

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert "already has a live or proposed challenge" in result["rejected"][0]
    assert suggested() == []


def test_a_full_cap_refuses_before_the_model_is_asked(owner_with_history: None) -> None:  # noqa: ARG001
    with tenant_transaction(_seed.OWNER) as cur:
        for i in range(3):
            _seed.seed_challenge(
                cur,
                _seed.OWNER,
                status="active",
                metric="steps_total",
                title=f"Live {i}",
                adopted_at=datetime(2026, 7, 14, 6, 0, tzinfo=UTC),
            )
    stub = StubLLM([response()])
    result = run_generation(stub)

    assert result["reason"] == "too_many_active"
    assert stub.calls == 0


def test_twoproposals_on_one_metric_keep_only_the_first(owner_with_history: None) -> None:  # noqa: ARG001
    result = run_generation(StubLLM([response(proposal(), proposal(title="Walk even more"))]))

    assert (result["generated"], len(result["rejected"])) == (1, 1)
    assert "already has a live or proposed challenge" in result["rejected"][0]
    assert len(suggested()) == 1


def test_a_challenge_adopted_mid_flight_still_blocks_its_duplicate(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    result = run_generation(ClaimsMetricMidFlight([response()]))

    assert result["generated"] == 0
    assert any("by the time the model finished thinking" in r for r in result["rejected"])
    assert suggested() == []


def test_a_slot_taken_mid_flight_still_bounds_the_batch(owner_with_history: None) -> None:  # noqa: ARG001
    """The cap is re-read at write time, so a slot lost mid-flight is a slot lost.

    Two slots free when the context was built, two valid proposals on two different
    metrics — and one more challenge adopted while the model answered. Only one may land.
    """
    seed_caffeine_habit()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_challenge(
            cur,
            _seed.OWNER,
            status="active",
            metric="mvpa_min",
            title="Already running",
            adopted_at=datetime(2026, 7, 14, 6, 0, tzinfo=UTC),
        )
    cap = proposal(
        metric="caffeine_mg",
        comparator="<=",
        target_value=150.0,
        category="sleep",
        why=f"Lower evening caffeine may protect sleep [{ESTABLISHED_ID}].",
    )
    stub = ClaimsMetricMidFlight([response(proposal(), cap)], metric="sri")

    result = run_generation(stub)

    assert result["generated"] == 1
    assert len(suggested()) == 1


# ── the bounds retry, and what a failed refresh must NOT destroy ──────────────


def test_a_rejected_batch_is_re_asked_once_and_the_correction_ships(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    stub = StubLLM([response(proposal(target_value=12000.0)), response()])
    result = run_generation(stub)

    assert (result["generated"], stub.calls) == (1, 2)
    assert suggested()[0]["target_value"] == IN_BAND


def test_a_refresh_that_produces_nothing_leaves_the_existing_feed_alone(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    with tenant_transaction(_seed.OWNER) as cur:
        kept = _seed.seed_challenge(cur, _seed.OWNER, title="Yesterday's suggestion")
    result = run_generation(StubLLM([response(proposal(target_value=12000.0))]))

    assert result["generated"] == 0
    assert [row["id"] for row in suggested()] == [kept]


def test_a_successful_refresh_replaces_the_stale_feed(owner_with_history: None) -> None:  # noqa: ARG001
    with tenant_transaction(_seed.OWNER) as cur:
        stale = _seed.seed_challenge(cur, _seed.OWNER, title="Yesterday's suggestion")
    run_generation(StubLLM([response()]))

    ids = [row["id"] for row in suggested()]
    assert stale not in ids and len(ids) == 1


# ── the WP-C5 seam ────────────────────────────────────────────────────────────


def test_an_intent_reaches_the_model_and_still_passes_both_gates(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """`create_challenge(intent)` must reuse THIS pipeline, so the intent is a parameter."""
    stub = StubLLM([response()])
    result = run_generation(stub, intent="make me a walking challenge", max_new=1)

    assert result["generated"] == 1
    assert "make me a walking challenge" in stub.messages[0][-1]["content"]


def test_adding_to_the_feed_leaves_the_existing_suggestions_alone(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """``replace_feed=False`` is the coach's mode — a chat turn must not wipe the menu."""
    with tenant_transaction(_seed.OWNER) as cur:
        kept = _seed.seed_challenge(
            cur, _seed.OWNER, title="Steadier bedtimes", metric="sri", target_value=60.0
        )
    result = run_generation(StubLLM([response()]), replace_feed=False, max_new=1)

    assert result["generated"] == 1
    assert kept in [row["id"] for row in suggested()]


def test_adding_to_the_feed_still_refuses_to_duplicate_a_suggested_metric(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """Keeping the feed widens the dedup, or the menu ends up with two of one metric."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_challenge(cur, _seed.OWNER, title="An existing steps suggestion")
    result = run_generation(StubLLM([response()]), replace_feed=False, max_new=1)

    assert (result["generated"], len(result["rejected"])) == (0, 1)
    assert "already has a live or proposed challenge" in result["rejected"][0]
    assert len(suggested()) == 1


def test_a_suggestion_written_mid_flight_still_blocks_its_duplicate(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """The kept feed can move while the model thinks, so ``_persist`` re-reads it too.

    The pre-LLM read cannot see a suggestion that did not exist yet — a second coach turn
    landing in the same window is exactly the case — so the widened dedup has to be in
    BOTH places or the menu gets two challenges on one metric.
    """
    result = run_generation(
        ClaimsMetricMidFlight([response()], status="suggested"), replace_feed=False, max_new=1
    )

    assert result["generated"] == 0
    assert any("by the time the model finished thinking" in r for r in result["rejected"])
    assert len(suggested()) == 1


def test_replacing_the_feed_is_still_the_default(owner_with_history: None) -> None:  # noqa: ARG001
    """The app's refresh keeps its old behaviour: stale suggestions go (`_persist`)."""
    with tenant_transaction(_seed.OWNER) as cur:
        stale = _seed.seed_challenge(
            cur, _seed.OWNER, title="Steadier bedtimes", metric="sri", target_value=60.0
        )
    run_generation(StubLLM([response()]), max_new=1)

    assert stale not in [row["id"] for row in suggested()]


def test_an_intent_does_not_buy_a_way_past_gate_a(owner_with_history: None) -> None:  # noqa: ARG001
    result = run_generation(
        StubLLM([response(proposal(target_value=12000.0))]),
        intent="give me a 12000 step challenge",
    )

    assert result["generated"] == 0
    assert suggested() == []


# ── tenancy ───────────────────────────────────────────────────────────────────


def test_generating_for_one_owner_leaves_another_untouched(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    _seed.reset()
    _seed.ensure_owner_b()
    try:
        for owner in (_seed.OWNER, _seed.OTHER_OWNER):
            with tenant_transaction(owner) as cur:
                _seed.seed_metric(cur, owner, "steps_total", steps_history())
        with tenant_transaction(_seed.OTHER_OWNER) as cur:
            b_kept = _seed.seed_challenge(cur, _seed.OTHER_OWNER, title="B's own suggestion")

        result = run_generation(StubLLM([response()]))

        assert result["generated"] == 1
        assert [row["id"] for row in suggested(_seed.OTHER_OWNER)] == [b_kept]
        assert [row["id"] for row in suggested()] != [b_kept]
    finally:
        _seed.reset()
        _seed.remove_owner_b()
