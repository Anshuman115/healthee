"""Seeded-DB tests for the three reasons a ladder WAITS instead of advancing (WP-C4).

Split from ``test_ladder_advance`` on the seam the questions already have: that suite is
about what a settled rung MEANS (promote, deload, stop), this one is about whether the
next one may start at all.

A hold is not a failure and not an ending. The program stays active, the next nightly
tick asks the same question, and the ladder resumes by itself when the answer changes —
which is why every test here has a "and then it clears" counterpart. A pause the owner is
never released from would be worse than a refusal.

All three rules are READ from where they already live, never restated:
``recovery_guard.hold_reason`` (the one definition of "do not push this owner harder"),
``lifecycle.MAX_ACTIVE`` (the per-owner commitment cap) and ``commitment.clashing``
(#72's one-commitment-per-behaviour rule).

Auto-skips without a reachable TimescaleDB.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import date, timedelta

import pytest
from tests.challenges import _ladder, _seed
from tests.challenges._ladder import IST

from healthee.challenges import ladder, lifecycle, rung
from healthee.core.db import tenant_transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration

_STARTED = date(2026, 7, 1)
_AFTER = date(2026, 7, 8)


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


# ── 4. recovery-awareness, and resuming when it clears ──────────────────────


def _mvpa_ladder(cur) -> tuple[int, list[int]]:
    """A live program whose FIRST rung is done and whose next asks for more MVPA.

    ``mvpa_min`` is one of ``recovery_guard.HARD_TRAINING_LEVERS`` — the metrics whose
    target IS a training stimulus, and therefore the only ones an under-recovered owner's
    own data can contradict.
    """
    program_id = _ladder.seed_program(cur)
    first = _ladder.seed_rung(cur, program_id, 0, 100.0, metric="mvpa_min", status="completed")
    second = _ladder.seed_rung(cur, program_id, 1, 130.0, metric="mvpa_min")
    cur.execute(
        "UPDATE program SET status = 'active', adopted_at = %s WHERE user_id = %s AND id = %s",
        (_ladder.adopted_at(_STARTED), _seed.OWNER, program_id),
    )
    return program_id, [first, second]


def test_advancement_is_held_while_an_illness_flag_is_active(clean_db: None) -> None:  # noqa: ARG001
    """A ladder that advances through poor recovery is the ratchet the guard exists to stop.

    [[recovery_readiness]] D7 — a safety input is a hard override, not a vote. The rule is
    ``recovery_guard.hold_reason``, the SAME one that withholds the lever from the
    generation menu and stops the adapter raising an adopted one; a second copy here is
    how those two surfaces came to disagree in the first place.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 30.0, 14, ending=_AFTER, owner=_seed.OWNER)
        _seed.seed_metric(
            cur, _seed.OWNER, "mvpa_min", {_AFTER - timedelta(days=i): 30.0 for i in range(1, 8)}
        )
        _seed.seed_illness(cur, _seed.OWNER, _AFTER)
        program_id, rungs = _mvpa_ladder(cur)
        events = ladder.advance_due(cur, _seed.OWNER, IST, _AFTER)
        held = _ladder.rung_row(cur, rungs[1])
        program = _ladder.program_row(cur, program_id)
    assert [event["event"] for event in events] == [ladder.ADVANCEMENT_HELD]
    assert events[0]["reason"] == rung.UNDER_RECOVERED
    assert held["status"] == "locked"  # not started, not failed — waiting
    assert "illness signal is active" in program["hold_reason"]
    assert program["status"] == "active"  # a hold is a pause, never an ending


def test_advancement_resumes_by_itself_when_the_hold_clears(clean_db: None) -> None:  # noqa: ARG001
    """The other half, and the one that makes a hold honest rather than a quiet death.

    Nothing re-adopts and nothing is re-offered: the next tick simply asks the same
    question and gets a different answer, so the ladder picks up where it paused.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur, _seed.OWNER, "mvpa_min", {_AFTER - timedelta(days=i): 30.0 for i in range(1, 8)}
        )
        _seed.seed_illness(cur, _seed.OWNER, _AFTER)
        program_id, rungs = _mvpa_ladder(cur)
        ladder.advance_due(cur, _seed.OWNER, IST, _AFTER)
        cur.execute("DELETE FROM illness_flag WHERE user_id = %s", (_seed.OWNER,))
        events = ladder.advance_due(cur, _seed.OWNER, IST, _AFTER)
        resumed = _ladder.rung_row(cur, rungs[1])
        program = _ladder.program_row(cur, program_id)
    assert [event["event"] for event in events] == [ladder.RUNG_ACTIVATED]
    assert resumed["status"] == "active"
    assert program["hold_reason"] is None  # a stale hold would say "paused" of a live ladder


def test_a_deload_is_never_held_by_the_recovery_guard(clean_db: None) -> None:  # noqa: ARG001
    """Recovery *eases or holds* — it never escalates, so it must not block an ease.

    [[recovery_readiness]] D8, and the same asymmetry ``adapt`` keeps ("it blocks raises,
    never eases"). Withholding a deload from an under-recovered owner would withhold the
    one thing that helps: a smaller ask.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur, _seed.OWNER, "mvpa_min", {_AFTER - timedelta(days=i): 30.0 for i in range(1, 8)}
        )
        _seed.seed_illness(cur, _seed.OWNER, _AFTER)
        program_id, _ = _mvpa_ladder(cur)
        cur.execute(
            "UPDATE challenge SET kind = 'deload' WHERE user_id = %s AND program_id = %s "
            "AND status = 'locked'",
            (_seed.OWNER, program_id),
        )
        events = ladder.advance_due(cur, _seed.OWNER, IST, _AFTER)
    assert [event["event"] for event in events] == [ladder.RUNG_ACTIVATED]


# ── the capacity holds, which resume the same way ───────────────────────────


def test_advancement_waits_for_a_free_slot_under_the_per_owner_cap(clean_db: None) -> None:  # noqa: ARG001
    """A rung is a live commitment and is counted like one (``lifecycle.MAX_ACTIVE``).

    Adopting a program takes a slot and advancement is normally net-zero, but a standalone
    challenge adopted into the freed slot can fill it. The ladder waits rather than making
    this owner the one person holding four commitments at once.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_AFTER - timedelta(days=1))
        program_id = _ladder.seed_program(cur)
        _ladder.seed_rung(cur, program_id, 0, 6000.0, status="completed")
        _ladder.seed_rung(cur, program_id, 1, 7000.0)
        cur.execute(
            "UPDATE program SET status = 'active' WHERE user_id = %s AND id = %s",
            (_seed.OWNER, program_id),
        )
        for metric in ("mvpa_min", "tst_min", "sri"):
            _seed.seed_challenge(
                cur,
                _seed.OWNER,
                status="active",
                metric=metric,
                adopted_at=_ladder.adopted_at(_STARTED),
            )
        events = ladder.advance_due(cur, _seed.OWNER, IST, _AFTER)
        program = _ladder.program_row(cur, program_id)
    assert events[0]["reason"] == rung.TOO_MANY_ACTIVE
    assert f"{lifecycle.MAX_ACTIVE} challenges" in program["hold_reason"]


def test_advancement_waits_when_the_owner_runs_the_same_behaviour_separately(
    clean_db: None,  # noqa: ARG001
) -> None:
    """#72's rule, met through the ladder's door: one live commitment per behaviour.

    Two live rules over the same ``derived_daily`` rows is one commitment scored twice,
    and the outcome ledger would publish two before/afters over one behaviour change.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_AFTER - timedelta(days=1))
        program_id = _ladder.seed_program(cur)
        _ladder.seed_rung(cur, program_id, 0, 6000.0, metric="mvpa_min", status="completed")
        _ladder.seed_rung(cur, program_id, 1, 7000.0)
        cur.execute(
            "UPDATE program SET status = 'active' WHERE user_id = %s AND id = %s",
            (_seed.OWNER, program_id),
        )
        _seed.seed_challenge(
            cur, _seed.OWNER, status="active", adopted_at=_ladder.adopted_at(_STARTED)
        )
        events = ladder.advance_due(cur, _seed.OWNER, IST, _AFTER)
        program = _ladder.program_row(cur, program_id)
    assert events[0]["reason"] == rung.DUPLICATE_COMMITMENT
    assert "steps_total" in program["hold_reason"]
