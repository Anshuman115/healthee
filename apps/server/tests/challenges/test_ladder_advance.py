"""Seeded-DB tests for the advancement machine (WP-C4, CHALLENGES.md §2.3).

Every one of these is a legacy defect, held down:

1. **A rung that timed out unmet is `expired`, and the ledger says `unmet_timed_out`.**
   Legacy passed `"completed"` regardless of whether the target was hit and promoted the
   owner anyway (`_advance_program`, :1100) — a system that records failures as successes
   cannot learn from either.
2. **The deload path exists and the ledger can tell the story afterwards.** Legacy had no
   way back at all.
3. **A ladder that keeps failing stops**, honestly and with a reason, instead of easing
   forever.

The fourth fix — advancement is recovery-aware, and resumes when the reason clears —
lives in ``test_ladder_holds``: whether the next rung may START is a different question
from what a settled rung MEANS, and they were split when this file outgrew the size gate.

Auto-skips without a reachable TimescaleDB (the suite-wide policy).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import date, timedelta

import pytest
from tests.challenges import _ladder, _seed
from tests.challenges._ladder import IST

from healthee.challenges import ladder, lifecycle, program_store, programs, rung
from healthee.core.db import tenant_transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration

_STARTED = date(2026, 7, 1)
_AFTER = date(2026, 7, 8)  # day 8 of a 7-day rung — the window has run out
_AFTER_SECOND = date(2026, 7, 15)  # …and again, one rung later


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _running_ladder(cur, targets: list[float], baseline: float = 5000.0) -> tuple[int, list[int]]:
    """A live program whose first rung is active from ``_STARTED`` — the normal state.

    The rung is seeded active with a pinned ``adopted_at`` rather than adopted through
    the API, because the whole subject here is what happens when a window RUNS OUT, and
    that is a statement about the calendar (``_seed``'s fixed-dates rule).
    """
    program_id, rungs = _ladder.seed_ladder(cur, targets)
    cur.execute(
        "UPDATE program SET status = 'active', adopted_at = %s WHERE user_id = %s AND id = %s",
        (_ladder.adopted_at(_STARTED), _seed.OWNER, program_id),
    )
    cur.execute(
        "UPDATE challenge SET status = 'active', adopted_at = %s, baseline_value = %s "
        "WHERE user_id = %s AND id = %s",
        (_ladder.adopted_at(_STARTED), baseline, _seed.OWNER, rungs[0]),
    )
    return program_id, rungs


def _backdate(cur, rung_id: int, started: date) -> None:
    """Move a just-activated rung's start into the past.

    ``rung.start_rung`` stamps ``adopted_at`` with the real instant, which is right in
    production and useless to a test that has to watch a window elapse. This is the one
    thing these tests fake, and they fake only the clock.
    """
    cur.execute(
        "UPDATE challenge SET adopted_at = %s WHERE user_id = %s AND id = %s",
        (_ladder.adopted_at(started), _seed.OWNER, rung_id),
    )


def _settle(cur, today: date) -> list[dict]:
    """One nightly tick: close whatever ended, then move the ladder on.

    Exactly what ``jobs.chain.step_challenges`` does, in the same order and the same
    transaction — so these tests exercise the wiring rather than a private path.
    """
    lifecycle.finalize_due(cur, _seed.OWNER, IST, today)
    return ladder.advance_due(cur, _seed.OWNER, IST, today)


# ── 1. a rung that ran out UNMET is not a completed rung ─────────────────────


def test_an_unmet_rung_is_expired_and_recorded_unmet_timed_out(clean_db: None) -> None:  # noqa: ARG001
    """Seven days at 5,000 against a 6,000 target: zero hit days, so the window ran out.

    The legacy bug in one assertion. `_advance_program` recorded `"completed"` whenever
    `days_left <= 0`, so this rung — failed on every single day — became a success in the
    ledger and the owner was pushed up the staircase they were falling off.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_STARTED + timedelta(days=6))
        _, rungs = _running_ladder(cur, [6000.0, 7000.0])
        lifecycle.finalize_due(cur, _seed.OWNER, IST, _AFTER)
        failed = _ladder.rung_row(cur, rungs[0])
        outcome = programs.list_programs(cur, _seed.OWNER, IST, _AFTER)
    assert failed["status"] == "expired"
    assert failed["completed_at"] is None  # never completed, so never stamped
    frozen = outcome["active"]["rungs"][0]["outcome"]
    assert frozen["status"] == "unmet_timed_out"
    assert frozen["target"] == 6000.0


def test_an_unmet_rung_does_not_promote_the_owner(clean_db: None) -> None:  # noqa: ARG001
    """The rung above it stays LOCKED — the ladder answers the failure, it does not skip it.

    The `rung_index` assertion is the load-bearing half: the designed second rung is
    pushed from 1 to 2 to make room for the deload, so "still locked" and "no longer the
    next thing" are one fact.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_STARTED + timedelta(days=6))
        _, rungs = _running_ladder(cur, [6000.0, 7000.0])
        _settle(cur, _AFTER)
        designed_second = _ladder.rung_row(cur, rungs[1])
    assert designed_second["status"] == "locked"
    assert designed_second["target_value"] == 7000.0
    assert designed_second["rung_index"] == 2


# ── 2. the deload path, and the story the ledger tells afterwards ────────────


def test_a_failed_rung_inserts_a_deload_at_the_adapters_eased_target(clean_db: None) -> None:  # noqa: ARG001
    """6,000 failed on a 5,000 baseline ⇒ a deload rung at 5,250, activated immediately.

    Known value, all of it ``adapt``'s: ``max(6000 × 0.85, 5000 × 1.05) = 5250``, which
    is more than 3 % below 6,000 so there IS room to give. The number is the adapter's
    floor rule and not a second one — that reuse is the point of ``deload_target``.

    A deload keeps that target when it activates (``rung.recalibrated_target``). It has
    to: the band's low end for steps is ``baseline + 1000`` while the ease floors at
    ``baseline × 1.05``, so recalibrating a deload would snap it back ABOVE the number
    just failed and cancel every deload this metric could ever have.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_STARTED + timedelta(days=6))
        program_id, _ = _running_ladder(cur, [6000.0, 7000.0])
        events = _settle(cur, _AFTER)
        rungs = program_store.rungs(cur, _seed.OWNER, program_id)
    assert [event["event"] for event in events] == [ladder.RUNG_DELOADED, ladder.RUNG_ACTIVATED]
    assert events[0]["target"] == 5250.0
    deload = rungs[1]
    assert (deload["kind"], deload["status"], deload["target_value"]) == (
        "deload",
        "active",
        5250.0,
    )
    assert events[1]["recalibration"] == {
        "applied": False,
        "reason": rung.DELOAD_KEEPS_ITS_TARGET,
        "target": 5250.0,
    }


def test_a_deload_rung_authors_no_new_prose(clean_db: None) -> None:  # noqa: ARG001
    """It reuses the failed rung's grounded copy verbatim — there is no LLM in this path.

    The honesty rail on the whole failure branch. Any sentence written here would be
    ungrounded text entering through a door that has no Gate B behind it, so the deload
    carries the copy that already passed one and lets ``kind`` say it is a step back.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_STARTED + timedelta(days=6))
        program_id, rungs = _running_ladder(cur, [6000.0, 7000.0])
        _settle(cur, _AFTER)
        failed = _ladder.rung_row(cur, rungs[0])
        deload = program_store.rungs(cur, _seed.OWNER, program_id)[1]
    for field in ("title", "why", "how_to", "expected_outcome", "research_note_ids", "difficulty"):
        assert deload[field] == failed[field], field


def test_the_ledger_reads_back_as_the_story_that_actually_happened(clean_db: None) -> None:  # noqa: ARG001
    """met? no — `unmet_timed_out`, then a `deload` that was `met`, then the rung above it.

    The tiebreak that decided insert-vs-repeat, exercised end to end. A repeat could not
    produce this sequence at all: `challenge_outcome` is keyed on `challenge_id` and
    written `ON CONFLICT DO NOTHING`, so a second run of the same row would either record
    nothing or overwrite the first attempt — and the deload would vanish from the history
    of a ladder whose whole point is that it happened.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_STARTED + timedelta(days=6))
        program_id, _ = _running_ladder(cur, [6000.0, 7000.0])
        deload_id = _settle(cur, _AFTER)[1]["rung_id"]
        # The owner clears the eased target every day of its window, then the tick runs.
        _backdate(cur, deload_id, _AFTER)
        _ladder.seed_steps(cur, 5500.0, 7, ending=_AFTER + timedelta(days=6))
        _settle(cur, _AFTER_SECOND)
        program = programs.list_programs(cur, _seed.OWNER, IST, _AFTER_SECOND)["active"]
    told = [(r["kind"], r["status"], (r["outcome"] or {}).get("status")) for r in program["rungs"]]
    assert told == [
        ("standard", "expired", "unmet_timed_out"),
        ("deload", "completed", "met"),
        ("standard", "active", None),
    ]
    assert program["settled_rungs"] == 2


def test_a_second_tick_over_a_running_deload_does_nothing(clean_db: None) -> None:  # noqa: ARG001
    """Advancement is idempotent: with a rung live there is nothing settled to act on."""
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_STARTED + timedelta(days=6))
        program_id, _ = _running_ladder(cur, [6000.0, 7000.0])
        _settle(cur, _AFTER)
        again = _settle(cur, _AFTER)
        rungs = program_store.rungs(cur, _seed.OWNER, program_id)
    assert again == []  # the deload is already running, so nothing has settled
    assert [r["kind"] for r in rungs] == ["standard", "deload", "standard"]


def test_a_deload_that_cannot_start_is_not_inserted_again(clean_db: None) -> None:  # noqa: ARG001
    """The idempotency guard, in the one state that reaches it: a HELD deload.

    While a deload is running there is nothing settled and advancement returns early, so
    the guard is never consulted — which is exactly why that easier test does not stand
    in for this one. The state that reaches it is real and reachable: an earlier request's
    ``lifecycle.adopt`` ran ``finalize_due`` and closed the failed rung, the owner then
    filled all three slots with standalone challenges, and the nightly tick arrives to
    find a failure it must answer and no room to run the answer in.

    Without the guard the ladder grows a NEW deload on every tick — one per night, each
    renumbering the rungs behind it, until the program is mostly dead rows. The guard
    needs no column: a deload is only ever inserted directly after the rung it eases, so
    "the rung at index + 1 is a deload" already records that we have been here.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_STARTED + timedelta(days=6))
        program_id, _ = _running_ladder(cur, [6000.0, 7000.0])
        lifecycle.finalize_due(cur, _seed.OWNER, IST, _AFTER)
        for metric in ("mvpa_min", "tst_min", "sri"):
            _seed.seed_challenge(
                cur,
                _seed.OWNER,
                status="active",
                metric=metric,
                adopted_at=_ladder.adopted_at(_STARTED),
            )
        first = ladder.advance_due(cur, _seed.OWNER, IST, _AFTER)
        second = ladder.advance_due(cur, _seed.OWNER, IST, _AFTER)
        rungs = program_store.rungs(cur, _seed.OWNER, program_id)
    assert [e["event"] for e in first] == [ladder.RUNG_DELOADED, ladder.ADVANCEMENT_HELD]
    assert [e["event"] for e in second] == [ladder.ADVANCEMENT_HELD]
    assert [r["kind"] for r in rungs] == ["standard", "deload", "standard"]
    assert [r["status"] for r in rungs] == ["expired", "locked", "locked"]


# ── 3. giving up ─────────────────────────────────────────────────────────────


def test_a_ladder_with_no_room_left_to_ease_stops_and_says_why(clean_db: None) -> None:  # noqa: ARG001
    """A 5,100 target on a 5,000 baseline: the ease floor (5,250) is already above it.

    The first give-up trigger, and it is ``adapt``'s own floor doing the work — easing
    past it would hand back a target the owner had already beaten before the ladder
    started, which is the one thing that floor exists to forbid.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_STARTED + timedelta(days=6))
        program_id, _ = _running_ladder(cur, [5100.0, 7000.0])
        events = _settle(cur, _AFTER)
        program = _ladder.program_row(cur, program_id)
    assert [event["event"] for event in events] == [ladder.PROGRAM_ENDED]
    assert program["status"] == "stalled"
    assert "no easier version" in program["ended_reason"]
    assert program["completed_at"] is None  # stalled is not completed, ever


def test_a_ladder_ground_down_by_repeated_deloads_stops(clean_db: None) -> None:  # noqa: ARG001
    """Three unmet rungs in a row, two of them already deloads ⇒ stalled, not a third ease.

    The second give-up trigger. A ladder that eases forever is its own failure mode: at
    some point the honest reading is that a smaller number is not the answer, and saying
    so beats grinding.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 3000.0, 14, ending=_AFTER)
        program_id, rungs = _running_ladder(cur, [6000.0, 9000.0], baseline=3000.0)
        # The run so far: the designed rung failed, and so did both eased retries.
        cur.execute(
            "UPDATE challenge SET status = 'expired' WHERE user_id = %s AND id = %s",
            (_seed.OWNER, rungs[0]),
        )
        program_store.shift_rungs_after(cur, _seed.OWNER, program_id, 0)
        for index, target in ((1, 5100.0), (2, 4300.0)):
            deload_id = _ladder.seed_rung(
                cur, program_id, index, target, kind="deload", status="expired"
            )
            program_store.shift_rungs_after(cur, _seed.OWNER, program_id, index)
            _backdate(cur, deload_id, _STARTED)
        events = ladder.advance_due(cur, _seed.OWNER, IST, _AFTER)
        program = _ladder.program_row(cur, program_id)
    assert [event["event"] for event in events] == [ladder.PROGRAM_ENDED]
    assert (program["status"], events[0]["status"]) == ("stalled", "stalled")
    assert "three rungs in a row" in program["ended_reason"]


# ── finishing, and the owner stopping a rung ────────────────────────────────


def test_a_ladder_whose_last_rung_was_met_completes(clean_db: None) -> None:  # noqa: ARG001
    """Nothing locked left ⇒ the program is completed, and `completed_at` is stamped."""
    with tenant_transaction(_seed.OWNER) as cur:
        program_id = _ladder.seed_program(cur)
        _ladder.seed_rung(cur, program_id, 0, 6000.0, status="completed")
        cur.execute(
            "UPDATE program SET status = 'active' WHERE user_id = %s AND id = %s",
            (_seed.OWNER, program_id),
        )
        events = ladder.advance_due(cur, _seed.OWNER, IST, _AFTER)
        program = _ladder.program_row(cur, program_id)
    assert events[0]["status"] == "completed"
    assert program["completed_at"] is not None and program["ended_reason"] is None


def test_abandoning_the_live_rung_ends_the_ladder_with_it(clean_db: None) -> None:  # noqa: ARG001
    """The owner can stop a rung from the challenges endpoint, and the ladder follows.

    Recorded as `abandoned` and not `stalled`: they quit, the system did not, and the two
    are opposite lessons for what to offer next.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, 5000.0, 7, ending=_STARTED + timedelta(days=6))
        program_id, rungs = _running_ladder(cur, [6000.0, 7000.0])
        lifecycle.abandon(cur, _seed.OWNER, IST, rungs[0], _AFTER)
        events = ladder.advance_due(cur, _seed.OWNER, IST, _AFTER)
        program = _ladder.program_row(cur, program_id)
        untouched = _ladder.rung_row(cur, rungs[1])
        frozen = programs.list_programs(cur, _seed.OWNER, IST, _AFTER)
    assert events[0]["status"] == "abandoned"
    assert program["status"] == "abandoned"
    # No deload, no promotion: an abandonment is not a failure to answer with a smaller
    # number, and the unreached rung stays a truthful record of a ladder not climbed.
    assert untouched["status"] == "locked"
    assert frozen["recent"][0]["rungs"][0]["outcome"]["status"] == "abandoned"
