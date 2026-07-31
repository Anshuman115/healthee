"""Seeded-DB tests for §2.3 fix (3): a rung is calibrated when it STARTS.

Legacy froze every rung's target at design time, so rung 4 — authored today, reached in
four weeks — was calibrated against a person who no longer existed. Here the band comes
from ``bounds.calibrate`` at activation: the SAME Gate A band generation is bounded by,
read at the moment the number actually starts meaning something.

The bed is the one the generation suites already use: seven days at 5,000 steps, so the
daily band is a known ``[6000, 6500]`` — ``5000 + max(500, 1000 floor, 250 step)`` up to
``5000 + max(1500, 1000)`` — and every assertion below is arithmetic a reader can check.

Auto-skips without a reachable TimescaleDB.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import timedelta

import pytest
from tests.challenges import _ladder, _seed
from tests.challenges._ladder import BAND_HIGH, BAND_LOW, IST, TODAY

from healthee.challenges import program_store, rung
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


def _recalibrate(cur, designed: float, *, kind: str = "standard", **rung_kwargs) -> tuple:
    program_id = _ladder.seed_program(cur)
    rung_id = _ladder.seed_rung(cur, program_id, 0, designed, kind=kind, **rung_kwargs)
    return rung.recalibrated_target(cur, _seed.OWNER, IST, _ladder.rung_row(cur, rung_id), TODAY)


def test_a_target_still_inside_todays_band_is_left_alone(clean_db: None) -> None:  # noqa: ARG001
    """6,250 sits in [6000, 6500] — the designed number is still a fair ask, so it stands.

    "No change" is reported rather than silent: a surface that cannot tell "we checked and
    it holds" from "we never checked" is a surface that can imply the wrong one.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, _ladder.BASELINE_STEPS, 7, ending=_YESTERDAY)
        target, recalibration = _recalibrate(cur, 6250.0)
    assert target == 6250.0
    assert recalibration == {
        "applied": False,
        "reason": rung.IN_BAND,
        "target": 6250.0,
        "designed": 6250.0,
        "baseline": 5000.0,
    }


def test_a_target_the_owner_has_already_passed_rises_to_todays_band(clean_db: None) -> None:  # noqa: ARG001
    """A rung designed at 4,000 for somebody now averaging 5,000 is a lap of honour.

    **This is the case the brief asks about, and the answer is: say so, and move the
    number.** The owner having outgrown a rung is information — it is not a reason to run
    the rung anyway. The target rises to the GENTLE end of today's band (6,000, the
    smallest ask the corpus calls a real dose above this baseline), not the demanding end:
    the ladder's design intent for this step was modest, and recalibration corrects for
    staleness rather than re-authoring ambition.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, _ladder.BASELINE_STEPS, 7, ending=_YESTERDAY)
        target, recalibration = _recalibrate(cur, 4000.0)
    assert target == BAND_LOW
    assert (recalibration["applied"], recalibration["reason"]) == (True, rung.WITHIN_REACH)
    assert recalibration["designed"] == 4000.0  # what the ladder asked for is not erased


def test_a_target_beyond_todays_band_comes_down_to_it(clean_db: None) -> None:  # noqa: ARG001
    """20,000 steps for a 5,000-step owner is the ratchet §2.3 exists to remove.

    A ladder that keeps its design-time ambition after the owner regressed — or that was
    ambitious in the first place — is exactly the staircase somebody falls off. The target
    lands on the band's demanding end, which is still a real stretch and is still bounded
    by the rule Gate A would apply to a freshly generated challenge.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, _ladder.BASELINE_STEPS, 7, ending=_YESTERDAY)
        target, recalibration = _recalibrate(cur, 20000.0)
    assert target == BAND_HIGH
    assert (recalibration["applied"], recalibration["reason"]) == (True, rung.TOO_FAR)


def test_a_recalibrated_target_lands_on_the_metrics_rounding_step(clean_db: None) -> None:  # noqa: ARG001
    """An MVPA band of [66, 78] on a 60-min baseline snaps INWARD to 70, never to 65.

    Rounding to-nearest would put 65 outside the band and hand back a number Gate A
    itself would reject, which is the whole reason the snap is directional. 5 is
    ``scales.ROUND_STEP['mvpa_min']``; the band is
    ``60 + max(6, no floor, 5)`` … ``60 + max(18, 6)``.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur,
            _seed.OWNER,
            "mvpa_min",
            {_YESTERDAY - timedelta(days=i): 60.0 for i in range(7)},
        )
        target, recalibration = _recalibrate(cur, 20.0, metric="mvpa_min")
    assert target == 70.0  # ceil(66 / 5) * 5, and 70 is inside [66, 78]
    assert recalibration["reason"] == rung.WITHIN_REACH


def test_a_deload_rung_is_never_recalibrated(clean_db: None) -> None:  # noqa: ARG001
    """Its target came from the owner's CURRENT data seconds ago — there is no staleness.

    And the two rules disagree systematically: the band's low end is
    ``baseline + MEANINGFUL_STEP`` (1,000 steps) while an ease floors at
    ``baseline × 1.05`` (250), so recalibrating a deload would snap it back ABOVE the
    number the owner had just failed — cancelling every deload for this metric and making
    the entire failure branch dead code. Found by composing the two rules on real numbers,
    which is why it is pinned rather than left to a docstring.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, _ladder.BASELINE_STEPS, 7, ending=_YESTERDAY)
        target, recalibration = _recalibrate(cur, 5250.0, kind="deload")
    assert target == 5250.0  # NOT snapped up to the band's 6,000 low end
    assert recalibration == {
        "applied": False,
        "reason": rung.DELOAD_KEEPS_ITS_TARGET,
        "target": 5250.0,
    }


def test_a_rung_we_cannot_calibrate_keeps_its_designed_target_and_says_so(
    clean_db: None,  # noqa: ARG001
) -> None:
    """No band ⇒ the designed number stands, carrying ``bounds``' own refusal.

    "Too little of your data to calibrate against" and "we checked and it holds" are
    different states, and a recalibration that reported neither would let a surface claim
    a check that never ran. The refusal string is ``bounds.calibrate``'s, unchanged, so
    there is one vocabulary for why a band does not exist.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        target, recalibration = _recalibrate(cur, 200.0, metric="cardio_load")
    assert target == 200.0
    assert recalibration == {"applied": False, "reason": "thin_baseline", "target": 200.0}


def test_activation_freezes_the_baseline_the_recalibrated_target_was_judged_against(
    clean_db: None,  # noqa: ARG001
) -> None:
    """End to end: the rung starts, at the recalibrated number, with its own frozen anchor.

    The two must come from the same read or the ledger's later before/after compares a
    target set against one baseline with a baseline measured against another.
    ``start_rung`` mirrors ``lifecycle.adopt`` step for step so they cannot diverge.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, _ladder.BASELINE_STEPS, 7, ending=_YESTERDAY)
        program_id = _ladder.seed_program(cur)
        rung_id = _ladder.seed_rung(cur, program_id, 0, 4000.0)
        started = rung.start_rung(cur, _seed.OWNER, IST, _ladder.rung_row(cur, rung_id), TODAY)
        stored = _ladder.rung_row(cur, rung_id)
    assert started["target"] == BAND_LOW
    assert stored["status"] == "active"
    assert stored["target_value"] == BAND_LOW
    assert stored["baseline_value"] == _ladder.BASELINE_STEPS
    assert stored["ends_at"] is not None


def test_a_rung_that_is_no_longer_locked_raises_rather_than_double_starting(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Two advancement runs racing on one ladder is a broken invariant, not a rule outcome.

    Restarting a live rung would reset the frozen baseline the whole before/after rests
    on — the exact damage ``store.mark_adopted``'s in-statement status predicate exists to
    prevent, applied to the ladder's door.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _ladder.seed_steps(cur, _ladder.BASELINE_STEPS, 7, ending=_YESTERDAY)
        program_id = _ladder.seed_program(cur)
        rung_id = _ladder.seed_rung(cur, program_id, 0, 6250.0)
        stale = _ladder.rung_row(cur, rung_id)
        rung.start_rung(cur, _seed.OWNER, IST, stale, TODAY)
        with pytest.raises(RuntimeError, match="no longer locked"):
            rung.start_rung(cur, _seed.OWNER, IST, stale, TODAY)
        assert program_store.rungs(cur, _seed.OWNER, program_id)[0]["status"] == "active"
