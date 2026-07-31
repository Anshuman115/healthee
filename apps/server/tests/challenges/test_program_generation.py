"""WP-C4b — the gating split that makes a ladder authorable at all.

The one test that matters most is :func:`test_a_legitimate_ascending_ladder_survives`,
and it is the whole reason this WP exists: rungs 2-4 sit ABOVE the owner's current band
on purpose, so the naive design — Gate A on every rung — rejects every real program.
:func:`test_a_per_rung_gate_a_would_have_rejected_this_very_ladder` pins that by running
the rejected rule against the same ladder, so the split cannot be "simplified" back into
the bug without a test failing.

Everything else here is the shape gates that take Gate A's place at design time, plus the
one capability limit stated rather than papered over: a `<=` cap ladder is refused.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta

import pytest
from tests.challenges import _program_gen, _seed
from tests.challenges._gen import BAND_LOW, IN_BAND, TODAY, steps_history
from tests.challenges._program_gen import (
    ASCENDING,
    EVIDENCE_TARGET,
    RUNG_DAYS,
    program,
    response,
    run_generation,
    rung,
)
from tests.insights._ids import ESTABLISHED_ID
from tests.insights._stub import StubLLM

from healthee.challenges import (
    bounds,
    program_generate,
    program_screen,
    program_store,
    programs,
    screen,
    store,
)
from healthee.core.db import tenant_transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration


def _stored_program(owner=None) -> dict | None:
    owner = owner or _seed.OWNER
    with tenant_transaction(owner) as cur:
        found = program_store.by_status(cur, owner, ("suggested",))
        if not found:
            return None
        return found[0] | {"rungs": program_store.rungs(cur, owner, int(found[0]["id"]))}


# ── the split: Gate A on rung 1, the shape everywhere ─────────────────────────


def test_a_legitimate_ascending_ladder_survives(owner_with_history: None) -> None:  # noqa: ARG001
    """THE test. Rung 1 in band, rungs 2-4 above it — accepted, stored, climbable.

    A ladder is a climb, so every rung after the first is *meant* to be out of reach
    today. What protects the owner is not refusing to design it: it is
    ``rung.recalibrated_target`` re-reading ``bounds.calibrate`` at the moment each rung
    actually starts, so no rung is ever RUN outside their then-current band.
    """
    result = run_generation(StubLLM([response()]))

    assert (result["ok"], result["generated"], result["rejected"]) == (True, 1, [])
    stored = _stored_program()
    assert stored is not None
    assert [float(r["target_value"]) for r in stored["rungs"]] == list(ASCENDING)
    assert [r["status"] for r in stored["rungs"]] == ["locked"] * len(ASCENDING)
    assert [r["rung_index"] for r in stored["rungs"]] == list(range(len(ASCENDING)))
    assert stored["status"] == "suggested"  # designing is not starting


def test_a_per_rung_gate_a_would_have_rejected_this_very_ladder(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """The rejected design, run against the accepted ladder — so the split cannot rot.

    This is the pin for the deferral's actual finding. If somebody "tidies" the
    ``bind_target`` flag away and applies Gate A to every rung, the test above starts
    failing and this one explains why: the band the ladder is climbing OUT of is exactly
    what rungs 2-4 are outside.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        calibration = bounds.calibrate(
            cur, _seed.OWNER, _program_gen.IST, "steps_total", "daily", _program_gen.DAY
        )
    calibrations = {("steps_total", "daily"): calibration}
    merged = program_screen.merged_rungs(program())

    verdicts = [screen.proposal_issue(r, calibrations, set(), {}, bind_target=True) for r in merged]

    assert verdicts[0] is None, "rung 1 must be in band — Gate A still binds it"
    assert all(v is not None for v in verdicts[1:]), (
        "rungs 2-4 are out of band by construction; a per-rung Gate A kills the ladder"
    )
    assert all("progressive-overload band" in str(v) for v in verdicts[1:])


def test_rung_one_is_still_bound_by_gate_a(owner_with_history: None) -> None:  # noqa: ARG001
    """The split relaxes nothing for the rung that starts within days of adopting.

    A ladder whose FIRST step is already beyond the owner is the "12,000 steps on a
    3,000 baseline" failure with three more rungs stapled to it.
    """
    result = run_generation(StubLLM([response(BAND_LOW * 3, BAND_LOW * 4, BAND_LOW * 5)] * 2))

    assert result["generated"] == 0
    assert "rung 1" in result["rejected"][0]
    assert "progressive-overload band" in result["rejected"][0]
    assert _stored_program() is None


# ── the shape gates that replace design-time Gate A ───────────────────────────


def test_a_ladder_that_does_not_climb_is_refused(owner_with_history: None) -> None:  # noqa: ARG001
    """Monotone in the improving direction, strictly. A flat rung asks for nothing.

    A step DOWN is a deload, and only the engine may insert one — after a real failure,
    with the ledger recording that it happened (``challenges/ladder.py``). A model
    designing one at the outset would be filing a failure that never occurred.
    """
    result = run_generation(StubLLM([response(IN_BAND, 7000.0, 7000.0)] * 2))

    assert result["generated"] == 0
    assert "not a step up" in result["rejected"][0]
    assert _stored_program() is None


def test_a_ladder_climbing_past_the_evidence_target_is_refused(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """Past 8,000 steps/day the corpus says nothing about what the extra is worth.

    A ladder that keeps climbing past it is selling a benefit we cannot cite — the same
    overclaim ``bounds`` caps a single challenge's band at.
    """
    result = run_generation(
        StubLLM([response(IN_BAND, 7000.0, EVIDENCE_TARGET, EVIDENCE_TARGET + 1000)] * 2)
    )

    assert result["generated"] == 0
    assert "past the evidence target" in result["rejected"][0]
    assert _stored_program() is None


def test_a_cap_ladder_is_refused_as_not_ladderable(owner_with_history: None) -> None:  # noqa: ARG001
    """The known limit, stated rather than quietly made to work.

    A ladder's failure branch is the adapter's ease and the adapter leaves ``<=`` caps
    alone, because the corpus supplies no rule for loosening one. So a cap rung is a step
    whose failure could not be answered — a progressive caffeine-cut ladder is not
    expressible today, and making it work needs a grounded easing rule first.
    """
    _seed_caffeine()
    result = run_generation(
        StubLLM([response(175.0, 160.0, 150.0, metric="caffeine_mg", comparator="<=")] * 2)
    )

    assert result["generated"] == 0
    assert result["rejected"][0].startswith(f"{program_screen.NOT_LADDERABLE}: ")
    assert "cannot be a ladder rung" in result["rejected"][0]
    assert _stored_program() is None


def test_the_refusal_is_the_same_rule_adopt_enforces(owner_with_history: None) -> None:  # noqa: ARG001
    """Generation reads ``programs.rung_shape_issue``, it does not restate it.

    The property that buys: anything generation ships, ``adopt`` accepts. Two copies of
    this rule is exactly how ``levers`` and ``adapt`` once came to disagree about a
    withheld lever.
    """
    cap = program_screen.merged_rungs(program(175.0, 160.0, 150.0, comparator="<="))[0]

    assert programs.rung_shape_issue(cap) is not None
    assert "cannot be a ladder rung" in str(programs.rung_shape_issue(cap))


def test_a_metric_with_no_citable_goal_cannot_be_a_ladder(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """``active_calories`` has no evidence target, so there is nothing to climb toward.

    A standalone challenge on it is still generatable — bounded by the owner's own
    baseline, which is an honest bound. A four-week climb toward an uncited number is not.
    """
    _seed_active_calories()
    result = run_generation(StubLLM([response(700.0, 800.0, 900.0, metric="active_calories")] * 2))

    assert result["generated"] == 0
    assert "no evidence target we can cite" in result["rejected"][0]
    assert _stored_program() is None


def test_every_rungs_prose_must_pass_gate_b_or_nothing_ships(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """One fabricated note id in ONE rung, and the whole ladder dies at the choke point.

    Gate B is the blocking validator, and it does not know about rungs: it sees a
    ladder's user-facing strings (``insights.json_shapes``) and fails the batch. Legacy
    dropped bad citations and shipped the challenge anyway (§2.2).
    """
    poisoned = program()
    poisoned["rungs"][2] = rung(ASCENDING[2], why="This will help [not_a_real_note].")
    result = run_generation(StubLLM([_json(poisoned)]))

    assert result == {
        "ok": False,
        "reason": "no_grounded_output",
        "error": "the evidence base could not ground a program",
    }
    assert _stored_program() is None


def test_a_rung_without_a_citation_is_refused_by_the_screen(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """The per-rung half of cite-or-refuse: real ids, and an inline one in every `why`.

    Distinct from the test above — that one is the validator blocking a fabricated id,
    this is the screen dropping a rung whose ``why`` carries no inline ``[note_id]`` even
    though its declared ids are real.
    """
    uncited = program()
    uncited["rungs"][1] = rung(ASCENDING[1], why="More walking each week.")
    result = run_generation(StubLLM([_json(uncited)] * 2))

    assert result["generated"] == 0
    assert "rung 2" in result["rejected"][0]
    assert "no inline [note_id]" in result["rejected"][0]


def test_a_rungs_copy_may_not_name_a_number_the_row_does_not_hold(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """``bounds.copy_issue`` runs on EVERY rung, above the band as well as inside it.

    It only needs the band's low end as a numeral threshold, so it works on rung 4 exactly
    as it does on rung 1 — and a rung whose prose promises 8,000 while the row says 7,500
    is the same lie whichever rung it is.
    """
    lying = program()
    lying["rungs"][2] = rung(
        ASCENDING[2], expected_outcome=f"Reaching 8000 a day may pay off [{ESTABLISHED_ID}]."
    )
    result = run_generation(StubLLM([_json(lying)] * 2))

    assert result["generated"] == 0
    assert "rung 3" in result["rejected"][0]
    assert "the number the user reads must be the number we store" in result["rejected"][0]


def test_the_derived_fields_are_ours_and_not_the_models(owner_with_history: None) -> None:  # noqa: ARG001
    """``goal``, ``goal_metric`` and ``weeks`` are computed, never authored.

    The goal is the corpus's evidence target in the ladder's own units, carrying the note
    it came from; the weeks are the rung windows added up. A model writing either would be
    writing a number nobody checked.
    """
    run_generation(StubLLM([response()]))

    stored = _stored_program()
    assert stored is not None
    assert stored["goal"] == "8000 steps a day [steps_mortality]"
    assert stored["goal_metric"] == "steps_total"
    assert stored["weeks"] == len(ASCENDING) * RUNG_DAYS // 7


# ── the invariants around the gates ───────────────────────────────────────────


def test_an_owner_already_climbing_is_refused_before_the_model_is_asked(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """One ladder per owner, and the refusal costs no tokens (the endpoint refunds it)."""
    with tenant_transaction(_seed.OWNER) as cur:
        cur.execute(
            "INSERT INTO program (user_id, title, why, status) VALUES (%s,'Live','w','active')",
            (_seed.OWNER,),
        )
    stub = StubLLM([response()])
    result = run_generation(stub)

    assert result["reason"] == "program_active"
    assert result["reason"] in program_generate.PRE_LLM_REFUSALS
    assert stub.calls == 0


def test_a_ladder_on_a_metric_they_already_run_is_refused(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """A live steps challenge and a steps ladder is one commitment scored twice (#72)."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_challenge(
            cur,
            _seed.OWNER,
            status="active",
            metric="steps_total",
            adopted_at=datetime(2026, 7, 14, 6, 0, tzinfo=UTC),
        )
    result = run_generation(StubLLM([response()] * 2))

    assert result["generated"] == 0
    assert "already has a live or proposed challenge" in result["rejected"][0]


def test_a_successful_design_replaces_the_stale_one_and_takes_its_rungs(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """A regeneration replaces what was on offer — rungs included.

    ``challenge.program_id`` has no foreign key, so an orphaned rung is a real
    possibility and the delete has to be explicit (``program_store``).
    """
    run_generation(StubLLM([response()]))
    first = _stored_program()
    assert first is not None

    run_generation(StubLLM([response()]))

    second = _stored_program()
    assert second is not None and second["id"] != first["id"]
    with tenant_transaction(_seed.OWNER) as cur:
        surviving = {
            int(r["program_id"] or 0) for r in store.list_by_status(cur, _seed.OWNER, ("locked",))
        }
    assert surviving == {int(second["id"])}


def test_a_failed_design_leaves_the_existing_offer_alone(
    owner_with_history: None,  # noqa: ARG001
) -> None:
    """The delete is the first half of a replacement, and there is nothing to replace with."""
    run_generation(StubLLM([response()]))
    kept = _stored_program()
    assert kept is not None

    run_generation(StubLLM([response(IN_BAND, 7000.0, 7000.0)] * 2))

    still = _stored_program()
    assert still is not None and still["id"] == kept["id"]


def test_designing_for_one_owner_leaves_another_untouched(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    _seed.reset()
    _seed.ensure_owner_b()
    try:
        for owner in (_seed.OWNER, _seed.OTHER_OWNER):
            with tenant_transaction(owner) as cur:
                _seed.seed_metric(cur, owner, "steps_total", steps_history())

        assert run_generation(StubLLM([response()]))["generated"] == 1

        assert _stored_program(_seed.OTHER_OWNER) is None
        assert _stored_program() is not None
    finally:
        _seed.reset()
        _seed.remove_owner_b()


# ── helpers ───────────────────────────────────────────────────────────────────


def _json(design: dict) -> str:
    return json.dumps({"program": design})


def _seed_caffeine() -> None:
    """Seven days at 200 mg — a `good="down"` baseline, so a cap band exists to refuse."""
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


def _seed_active_calories() -> None:
    """A calibratable baseline on a metric the corpus gives no target for."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur,
            _seed.OWNER,
            "active_calories",
            {TODAY - timedelta(days=i): 600.0 for i in range(1, 8)},
        )
