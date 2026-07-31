"""Seeded-DB tests for the program lifecycle and its tenancy (WP-C4).

What these exist to catch, in order of how badly it would hurt:

1. **A ladder that leaks across owners.** Legacy had zero `user_id` anywhere; a cap or a
   rung read that ignored the tenant would show one person another's program.
2. **A rung adopted on its own.** A `locked` rung must not be snappable out of the middle
   of a ladder and run as a standalone challenge — that is what the status is FOR.
3. **A ladder shape whose failure could not be answered** — a `<=` rung, which has no
   evidenced ease rule, would silently reintroduce legacy's forward-only behaviour.
4. **A read that writes.** `list_programs` must never advance anything.

Auto-skips without a reachable TimescaleDB.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import timedelta

import pytest
from tests.challenges import _ladder, _seed
from tests.challenges._ladder import BAND_LOW, IST, TODAY

from healthee.challenges import ladder, lifecycle, program_store, programs, rung, store
from healthee.core.db import tenant_transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration

_YESTERDAY = TODAY - timedelta(days=1)


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


@pytest.fixture
def two_owners(clean_db: None) -> Iterator[None]:  # noqa: ARG001
    _seed.ensure_owner_b()
    yield
    _seed.remove_owner_b()


def _history(cur, owner=_seed.OWNER) -> None:
    _ladder.seed_steps(cur, _ladder.BASELINE_STEPS, 7, ending=_YESTERDAY, owner=owner)


# ── adopt ────────────────────────────────────────────────────────────────────


def test_adopting_a_ladder_starts_its_first_rung_recalibrated(clean_db: None) -> None:  # noqa: ARG001
    """Rung 0 was designed at 4,000; this owner now averages 5,000, so it starts at 6,000.

    There is no special first-rung path — ``adopt`` calls the same ``rung.start_rung``
    every later rung goes through, because a special path is a second one.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _history(cur)
        program_id, rungs = _ladder.seed_ladder(cur, [4000.0, 7000.0])
        result = programs.adopt(cur, _seed.OWNER, IST, program_id, TODAY)
        first, second = _ladder.rung_row(cur, rungs[0]), _ladder.rung_row(cur, rungs[1])
    assert result["ok"] is True
    assert result["program"]["status"] == "active"
    assert result["started"]["recalibration"]["reason"] == rung.WITHIN_REACH
    assert (first["status"], first["target_value"]) == ("active", BAND_LOW)
    assert first["baseline_value"] == _ladder.BASELINE_STEPS
    assert second["status"] == "locked"  # the rest of the ladder waits its turn


def test_a_second_ladder_is_refused_while_one_is_running(clean_db: None) -> None:  # noqa: ARG001
    """One multi-week arc per owner (``ladder.MAX_ACTIVE_PROGRAMS``).

    Two would put two arcs over one person's weeks and hand the outcome ledger two
    overlapping before/afters to attribute — §2.1's problem in its most avoidable form.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _history(cur)
        first, _ = _ladder.seed_ladder(cur, [6250.0])
        second, _ = _ladder.seed_ladder(cur, [6250.0])
        programs.adopt(cur, _seed.OWNER, IST, first, TODAY)
        refusal = programs.adopt(cur, _seed.OWNER, IST, second, TODAY)
    assert refusal == {
        "ok": False,
        "reason": "program_active",
        "error": "you are already running a program",
    }


def test_a_ladder_containing_a_cap_rung_is_refused(clean_db: None) -> None:  # noqa: ARG001
    """A ``<=`` rung has no evidenced ease, so its failure could not be answered.

    ``adapt`` leaves caps alone because the corpus supplies no rule for loosening one
    (§5.2), and a rung that cannot be deloaded is legacy's forward-only ladder wearing a
    new column. Refusing the SHAPE is honest; inventing a cap-easing rule to support it
    would not be. **Stated as a real capability limit: a progressive caffeine-cut ladder
    is not expressible today.**
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _history(cur)
        program_id = _ladder.seed_program(cur)
        _ladder.seed_rung(cur, program_id, 0, 6250.0)
        _ladder.seed_rung(
            cur, program_id, 1, 150.0, metric="caffeine_mg", comparator="<=", cadence="daily"
        )
        refusal = programs.adopt(cur, _seed.OWNER, IST, program_id, TODAY)
        stored = _ladder.program_row(cur, program_id)
    assert refusal["reason"] == "not_ladderable"
    assert "could not be deloaded" in refusal["error"]
    assert stored["status"] == "suggested"  # refused before anything was written


def test_a_ladder_with_an_inexpressible_rung_is_refused(clean_db: None) -> None:  # noqa: ARG001
    """#67's rule, applied to every rung: a weekly SRI is seven scores added into ~490."""
    with tenant_transaction(_seed.OWNER) as cur:
        _history(cur)
        program_id = _ladder.seed_program(cur)
        _ladder.seed_rung(cur, program_id, 0, 75.0, metric="sri", cadence="weekly")
        refusal = programs.adopt(cur, _seed.OWNER, IST, program_id, TODAY)
    assert refusal["reason"] == "not_ladderable"
    assert "cannot be a weekly challenge" in refusal["error"]


def test_a_ladder_with_no_rungs_is_refused(clean_db: None) -> None:  # noqa: ARG001
    """A program is its rungs. An empty one would go active and never do anything."""
    with tenant_transaction(_seed.OWNER) as cur:
        program_id = _ladder.seed_program(cur)
        refusal = programs.adopt(cur, _seed.OWNER, IST, program_id, TODAY)
    assert refusal["reason"] == "no_rungs"


def test_adopting_is_refused_rather_than_starting_a_ladder_already_paused(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Under-recovered on day one ⇒ "not this week", not a program that begins held.

    The same ``rung.hold_for`` advancement asks on every later rung, so a ladder cannot
    be adopted under conditions that would immediately hold it. Reported with the reason
    that produced it, so a client can tell "your recovery says no" from "you are full".
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur, _seed.OWNER, "mvpa_min", {_YESTERDAY - timedelta(days=i): 30.0 for i in range(7)}
        )
        _seed.seed_illness(cur, _seed.OWNER, TODAY)
        program_id = _ladder.seed_program(cur)
        _ladder.seed_rung(cur, program_id, 0, 40.0, metric="mvpa_min")
        refusal = programs.adopt(cur, _seed.OWNER, IST, program_id, TODAY)
        stored = _ladder.program_row(cur, program_id)
    assert refusal["reason"] == rung.UNDER_RECOVERED
    assert stored["status"] == "suggested"


def test_adopting_is_refused_when_the_challenge_cap_is_full(clean_db: None) -> None:  # noqa: ARG001
    """A rung takes a slot, so a ladder cannot be started without one to take."""
    with tenant_transaction(_seed.OWNER) as cur:
        _history(cur)
        for metric in ("mvpa_min", "tst_min", "sri"):
            _seed.seed_challenge(
                cur,
                _seed.OWNER,
                status="active",
                metric=metric,
                adopted_at=_ladder.adopted_at(_YESTERDAY),
            )
        program_id, _ = _ladder.seed_ladder(cur, [6250.0])
        refusal = programs.adopt(cur, _seed.OWNER, IST, program_id, TODAY)
    assert refusal["reason"] == rung.TOO_MANY_ACTIVE
    assert f"{lifecycle.MAX_ACTIVE} challenges" in refusal["error"]


# ── abandon ──────────────────────────────────────────────────────────────────


def test_abandoning_a_ladder_freezes_its_live_rungs_outcome(clean_db: None) -> None:  # noqa: ARG001
    """Giving up is a result. The rung goes through ``lifecycle.abandon`` unchanged, so
    the ledger records how far they actually got rather than losing the week entirely.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _history(cur)
        program_id, rungs = _ladder.seed_ladder(cur, [6250.0, 7000.0])
        programs.adopt(cur, _seed.OWNER, IST, program_id, TODAY)
        result = programs.abandon(cur, _seed.OWNER, IST, program_id, TODAY)
        live = _ladder.rung_row(cur, rungs[0])
    assert result["ok"] is True
    assert result["program"]["status"] == "abandoned"
    assert result["program"]["ended_reason"] == "you stopped this ladder."
    assert result["program"]["completed_at"] is None
    assert live["status"] == "abandoned"
    assert result["program"]["rungs"][0]["outcome"]["status"] == "abandoned"


def test_a_suggested_ladder_cannot_be_abandoned(clean_db: None) -> None:  # noqa: ARG001
    """Declining an offer and stopping a commitment are different acts with different
    records; only the second one belongs in the ledger."""
    with tenant_transaction(_seed.OWNER) as cur:
        program_id, _ = _ladder.seed_ladder(cur, [6250.0])
        refusal = programs.abandon(cur, _seed.OWNER, IST, program_id, TODAY)
    assert refusal["reason"] == "not_active"


# ── a locked rung is not a suggestion ────────────────────────────────────────


def test_a_locked_rung_cannot_be_adopted_as_a_standalone_challenge(clean_db: None) -> None:  # noqa: ARG001
    """The whole reason `locked` is a STATUS and not a flag.

    ``lifecycle.adopt`` already refuses anything that is not ``suggested``, so snapping
    rung 3 out of the middle of a ladder and running it alone is impossible without a new
    rule — the check that was already there does the work.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        program_id = _ladder.seed_program(cur)
        rung_id = _ladder.seed_rung(cur, program_id, 2, 9000.0)
        refusal = lifecycle.adopt(cur, _seed.OWNER, IST, rung_id, TODAY)
    assert refusal["reason"] == "not_suggested"
    assert "is locked" in refusal["error"]


def test_locked_rungs_never_appear_in_the_standalone_suggestion_feed(clean_db: None) -> None:  # noqa: ARG001
    """A rung is not on the menu, and regenerating the menu does not delete one.

    Both halves matter: the feed would otherwise offer a ladder's steps as loose
    challenges, and ``store.delete_suggestions`` would eat a ladder somebody adopted the
    first time they hit Refresh (its `program_id IS NULL` predicate was written for this).
    """
    with tenant_transaction(_seed.OWNER) as cur:
        program_id = _ladder.seed_program(cur)
        rung_id = _ladder.seed_rung(cur, program_id, 0, 6250.0)
        _seed.seed_challenge(cur, _seed.OWNER, metric="mvpa_min")
        feed = lifecycle.list_challenges(cur, _seed.OWNER, IST, TODAY)
        deleted = store.delete_suggestions(cur, _seed.OWNER)
        survivor = _ladder.rung_row(cur, rung_id)
    assert [c["metric"] for c in feed["suggested"]] == ["mvpa_min"]
    assert deleted == 1
    assert survivor["status"] == "locked"


# ── reads are pure ───────────────────────────────────────────────────────────


def test_listing_programs_never_advances_one(clean_db: None) -> None:  # noqa: ARG001
    """A GET that writes is not idempotent, races itself, and only helps the owner who
    happens to be looking — which is never the owner whose ladder is quietly stuck."""
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_YESTERDAY)
        program_id = _ladder.seed_program(cur)
        _ladder.seed_rung(cur, program_id, 0, 6000.0, status="expired")
        _ladder.seed_rung(cur, program_id, 1, 7000.0)
        cur.execute(
            "UPDATE program SET status = 'active' WHERE user_id = %s AND id = %s",
            (_seed.OWNER, program_id),
        )
        before = programs.list_programs(cur, _seed.OWNER, IST, TODAY)
        after = programs.list_programs(cur, _seed.OWNER, IST, TODAY)
    assert before == after
    assert [r["status"] for r in before["active"]["rungs"]] == ["expired", "locked"]


# ── tenancy ──────────────────────────────────────────────────────────────────


def test_one_owners_ladder_is_invisible_and_untouchable_to_another(two_owners: None) -> None:  # noqa: ARG001
    """Not found, not forbidden: a 404 that becomes a 409 for the rows that exist would
    confirm another tenant's ids (MULTI_USER.md §10)."""
    with tenant_transaction(_seed.OWNER) as cur:
        _history(cur)
        program_id, _ = _ladder.seed_ladder(cur, [6250.0])
    with tenant_transaction(_seed.OTHER_OWNER) as cur:
        assert program_store.fetch(cur, _seed.OTHER_OWNER, program_id) is None
        assert program_store.rungs(cur, _seed.OTHER_OWNER, program_id) == []
        assert programs.adopt(cur, _seed.OTHER_OWNER, IST, program_id, TODAY)["reason"] == (
            "not_found"
        )
        assert programs.list_programs(cur, _seed.OTHER_OWNER, IST, TODAY)["suggested"] == []


def test_one_owners_running_ladder_does_not_block_anothers(two_owners: None) -> None:  # noqa: ARG001
    """The one-program cap counts the caller's own rows and nobody else's.

    Legacy's caps were global because legacy had one user; leaked here, the first owner to
    start a program would lock every other owner out of starting one.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _history(cur)
        mine, _ = _ladder.seed_ladder(cur, [6250.0])
        assert programs.adopt(cur, _seed.OWNER, IST, mine, TODAY)["ok"] is True
    with tenant_transaction(_seed.OTHER_OWNER) as cur:
        _history(cur, owner=_seed.OTHER_OWNER)
        theirs, _ = _ladder.seed_ladder(cur, [6250.0], owner=_seed.OTHER_OWNER)
        assert programs.adopt(cur, _seed.OTHER_OWNER, IST, theirs, TODAY)["ok"] is True
        assert program_store.count_active_programs(cur, _seed.OTHER_OWNER) == 1


def test_advancement_only_ever_touches_the_callers_own_ladder(two_owners: None) -> None:  # noqa: ARG001
    """Owner B's failed rung must not be deloaded by a tick run for owner A."""
    with tenant_transaction(_seed.OTHER_OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_YESTERDAY, owner=_seed.OTHER_OWNER)
        theirs = _ladder.seed_program(cur, owner=_seed.OTHER_OWNER)
        _ladder.seed_rung(cur, theirs, 0, 6000.0, owner=_seed.OTHER_OWNER, status="expired")
        _ladder.seed_rung(cur, theirs, 1, 7000.0, owner=_seed.OTHER_OWNER)
        cur.execute(
            "UPDATE program SET status = 'active' WHERE user_id = %s AND id = %s",
            (_seed.OTHER_OWNER, theirs),
        )
    with tenant_transaction(_seed.OWNER) as cur:
        assert ladder.advance_due(cur, _seed.OWNER, IST, TODAY) == []
    with tenant_transaction(_seed.OTHER_OWNER) as cur:
        untouched = program_store.rungs(cur, _seed.OTHER_OWNER, theirs)
    assert [r["kind"] for r in untouched] == ["standard", "standard"]
    assert [r["status"] for r in untouched] == ["expired", "locked"]
