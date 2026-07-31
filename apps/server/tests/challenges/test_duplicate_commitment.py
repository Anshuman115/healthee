"""#72 — adopt had no duplicate check, so one behaviour could be committed to twice.

Generation dedupes (``screen``, ``generate._persist``); ``lifecycle.adopt`` checked
status, cadence and the per-owner cap and did not. Two suggestions on one metric could
therefore both be adopted, which produces exactly CHALLENGES.md §2.1's own failure mode:
two before/afters over one behaviour change, and a ``concurrent_challenges`` confound
inflated on every other outcome whose window overlaps.

Reachable through ``POST /api/challenges/{id}/adopt`` and, since WP-C5, through the coach
tool — so the fix belongs in ``lifecycle.adopt``, beneath both.

What each test here is really pinning is a DISTINCTION: refused rather than 500, and
refused for a reason a surface can tell apart from "you are full". The ledger consequence
is asserted directly (one outcome per behaviour, not two), because that is the harm the
rule exists to prevent rather than a proxy for it.

Auto-skips without a reachable TimescaleDB.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges import ledger, lifecycle, store
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.db import migrate

pytestmark = pytest.mark.integration

IST = SENTINEL_TZ
TODAY = date(2026, 7, 15)


@pytest.fixture
def owner(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur,
            _seed.OWNER,
            "steps_total",
            {TODAY - timedelta(days=i): 5000.0 for i in range(1, 8)},
        )
    yield
    _seed.reset()


def _adopt(challenge_id: int, user_id=None) -> dict:
    user = user_id or _seed.OWNER
    with tenant_transaction(user) as cur:
        return lifecycle.adopt(cur, user, IST, challenge_id, today=TODAY)


def _suggest(user_id=None, **overrides) -> int:
    user = user_id or _seed.OWNER
    with tenant_transaction(user) as cur:
        return _seed.seed_challenge(cur, user, **overrides)


# ── the defect, closed ────────────────────────────────────────────────────────


def test_two_suggestions_on_one_metric_cannot_both_be_adopted(owner: None) -> None:  # noqa: ARG001
    """The bug, stated as the thing that must not happen.

    Both are legitimate suggestions and the first adopt is a legitimate adopt. What is
    refused is the second, and the owner is left with exactly one live commitment on the
    metric rather than two rows reading the same days.
    """
    first = _suggest(title="Walk a little more")
    second = _suggest(title="Walk quite a lot more", target_value=7000.0)

    assert _adopt(first)["ok"] is True
    result = _adopt(second)

    assert (result["ok"], result["reason"]) == (False, "duplicate_commitment")
    assert "steps_total" in result["error"]
    with tenant_transaction(_seed.OWNER) as cur:
        assert store.count_active(cur, _seed.OWNER) == 1
        assert _seed.stored(cur, _seed.OWNER, second)["status"] == "suggested"


def test_the_refusal_is_a_rule_outcome_not_a_failure(owner: None) -> None:  # noqa: ARG001
    """Refused in the package's own vocabulary — never an exception, never a 500.

    ``lifecycle`` reports every rule outcome as ``{ok, reason, error}`` so the API layer
    and the coach read one shape whichever rule said no; raising here would turn a
    perfectly ordinary "you are already doing that" into an error page.
    """
    first = _suggest()
    _adopt(first)
    result = _adopt(_suggest())

    assert set(result) == {"ok", "reason", "error"}
    assert result["error"] and isinstance(result["error"], str)


def test_a_duplicate_is_distinguishable_from_a_full_slate(owner: None) -> None:  # noqa: ARG001
    """Two refusals, two reasons — "you are full" and "you already do that" differ.

    They call for different things from the owner (abandon something, versus nothing at
    all), so a surface that could not tell them apart would give the wrong advice half the
    time. The cap's own refusal is asserted alongside to prove the two really are
    reachable separately.
    """
    _adopt(_suggest(metric="steps_total"))
    _adopt(_suggest(metric="mvpa_min"))
    _adopt(_suggest(metric="tst_min"))

    full = _adopt(_suggest(metric="sri"))
    duplicate = _adopt(_suggest(metric="steps_total"))

    assert full["reason"] == "too_many_active"
    assert duplicate["reason"] == "duplicate_commitment"
    assert full["reason"] != duplicate["reason"]


def test_the_duplicate_is_reported_before_the_cap(owner: None) -> None:  # noqa: ARG001
    """When both are true, the more specific answer wins.

    A full slate that already contains this metric is not a capacity problem — abandoning
    something else would not make the duplicate adoptable — so reporting the cap would
    send the owner to fix the wrong thing.
    """
    _adopt(_suggest(metric="steps_total"))
    _adopt(_suggest(metric="mvpa_min"))
    _adopt(_suggest(metric="tst_min"))

    assert _adopt(_suggest(metric="steps_total"))["reason"] == "duplicate_commitment"


def test_the_ledger_records_one_before_after_per_behaviour(owner: None) -> None:  # noqa: ARG001
    """The harm, measured where it would have landed.

    Two live challenges on one metric would freeze two outcomes over one behaviour change
    — §2.1's argument, and the reason the check is not merely tidy. Here the second never
    starts, so the ledger carries one row and every other outcome's
    ``concurrent_challenges`` count stays honest.
    """
    first = _suggest()
    _adopt(first)
    _adopt(_suggest())

    with tenant_transaction(_seed.OWNER) as cur:
        lifecycle.abandon(cur, _seed.OWNER, IST, first, today=TODAY)
        outcomes = ledger.recent(cur, _seed.OWNER)

    assert [o["metric"] for o in outcomes] == ["steps_total"]


# ── the rule's WIDTH: one behaviour, not one (metric, cadence) ────────────────


def test_a_different_cadence_on_the_same_metric_is_still_the_same_commitment(
    owner: None,  # noqa: ARG001
) -> None:
    """A daily and a weekly steps challenge are two rules over one behaviour change.

    Arguably two different commitments to a person; provably one to the ledger, which has
    no cadence-aware way to attribute two overlapping before/afters on ``steps_total`` to
    two causes. Refusing is also what keeps adopt from being more permissive than
    generation, which refuses the pair whatever its cadence.
    """
    _adopt(_suggest(cadence="daily"))
    result = _adopt(_suggest(cadence="weekly", target_value=40000.0))

    assert result["reason"] == "duplicate_commitment"


def test_a_time_window_is_the_same_commitment_as_the_total_it_slices(
    owner: None,  # noqa: ARG001
) -> None:
    """``caffeine_after_16`` reads a SUBSET of ``caffeine_mg``'s own rows.

    The sharpest case for the wide rule: the two series cannot move independently, so two
    outcomes over one week of drinking less coffee would be one change published twice.
    """
    _adopt(_suggest(metric="caffeine_mg", comparator="<=", target_value=180.0))
    result = _adopt(_suggest(metric="caffeine_after_16", comparator="<=", target_value=80.0))

    assert (result["reason"], "caffeine_mg" in result["error"]) == ("duplicate_commitment", True)


def test_two_windows_on_one_substance_are_one_commitment(owner: None) -> None:  # noqa: ARG001
    """Nested windows: everything after 20:00 is also after 16:00."""
    _adopt(_suggest(metric="caffeine_after_16", comparator="<=", target_value=80.0))
    result = _adopt(_suggest(metric="caffeine_after_20", comparator="<=", target_value=40.0))

    assert result["reason"] == "duplicate_commitment"


def test_unrelated_metrics_are_still_freely_adoptable(owner: None) -> None:  # noqa: ARG001
    """The rule must not become "one challenge at a time" by accident.

    Caffeine and alcohol are both logged kinds and both caps; they are different
    behaviours, and the commitment key is the source binding rather than "is a cap".
    """
    assert _adopt(_suggest(metric="caffeine_mg", comparator="<=", target_value=180.0))["ok"]
    assert _adopt(_suggest(metric="alcohol_units", comparator="<=", target_value=3.0))["ok"]
    assert _adopt(_suggest(metric="steps_total"))["ok"]


def test_a_finished_challenge_stops_blocking_the_metric(owner: None) -> None:  # noqa: ARG001
    """The check reads ACTIVE rows only — a commitment that ended is not in the way.

    Otherwise one completed challenge would lock its metric out forever, which would make
    the honest response to "that worked, do it again" impossible.
    """
    first = _suggest()
    _adopt(first)
    with tenant_transaction(_seed.OWNER) as cur:
        lifecycle.abandon(cur, _seed.OWNER, IST, first, today=TODAY)

    assert _adopt(_suggest())["ok"] is True


def test_an_expired_row_that_has_not_been_closed_yet_does_not_block(
    owner: None,  # noqa: ARG001
) -> None:
    """``adopt`` finalizes first, so a stale active row cannot masquerade as live.

    The same reason the cap check runs after ``finalize_due``: a challenge whose window
    ran out weeks ago must not be able to refuse its own successor.
    """
    stale = _suggest()
    _adopt(stale)
    with tenant_transaction(_seed.OWNER) as cur:
        cur.execute(
            "UPDATE challenge SET adopted_at = %s WHERE user_id = %s AND id = %s",
            (datetime(2026, 6, 1, 6, 0, tzinfo=UTC), _seed.OWNER, stale),
        )

    assert _adopt(_suggest())["ok"] is True


# ── tenancy ───────────────────────────────────────────────────────────────────


def test_a_second_owner_is_unaffected_by_the_first_owners_commitment(
    owner: None,  # noqa: ARG001
) -> None:
    """The check counts the CALLER's own active rows and nobody else's (MULTI_USER §2).

    A duplicate rule that leaked across tenants would be worse than the bug it replaces:
    one owner adopting a steps challenge would lock every other owner out of theirs.
    """
    _adopt(_suggest())
    _seed.ensure_owner_b()
    try:
        theirs = _suggest(user_id=_seed.OTHER_OWNER)
        result = _adopt(theirs, user_id=_seed.OTHER_OWNER)

        assert result["ok"] is True, result
        with tenant_transaction(_seed.OTHER_OWNER) as cur:
            assert store.count_active(cur, _seed.OTHER_OWNER) == 1
    finally:
        _seed.remove_owner_b()
