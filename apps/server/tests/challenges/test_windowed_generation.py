"""The windowed challenge through the WP-C3 pipeline, and what the corpus lets it say.

The other half of ``test_windowed_levers``: that one decides which windows reach the
menu, this one runs a menu'd window all the way to a stored row and pins the invariants
the registry and the corpus impose on it.

The end-to-end case is the feature in one test — finding → lever → band → both gates → a
persisted challenge — and everything is asserted against the number the BAND allows
rather than the number the stub proposed, because Gate A rejects rather than clamps.

Auto-skips without a reachable TimescaleDB.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from datetime import UTC, datetime

import pytest
from tests.challenges import _gen, _seed
from tests.challenges._windowed_bed import (
    BAND_HIGH,
    BAND_LOW,
    IN_BAND,
    IST,
    TODAY,
    WINDOW,
    seed_evening_habit,
)
from tests.insights._ids import ESTABLISHED_ID
from tests.insights._stub import StubLLM

from healthee.challenges.adapt import suggest_adaptation
from healthee.challenges.ledger import _improvement_pct
from healthee.core.db import tenant_transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration


@pytest.fixture
def owner(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _cutoff_proposal(**overrides) -> dict:
    """A proposal the model could plausibly write for this owner, in band."""
    fields = {
        "title": "Draw a line under your last coffee",
        "why": f"Caffeine in the evening measurably shortens sleep [{ESTABLISHED_ID}], and "
        f"your own logs place the line at 16:00 [personal_finding:{WINDOW}].",
        "expected_outcome": "Cutting the late dose should give the night back some of its "
        f"length [{ESTABLISHED_ID}].",
        "how_to": "Last coffee before 16:00; switch to decaf after that; keep logging every "
        "cup so the streak can be scored.",
        "category": "sleep",
        "metric": WINDOW,
        "comparator": "<=",
        "target_value": IN_BAND,
        "cadence": "daily",
        "window_days": 14,
    }
    return _gen.proposal(**(fields | overrides))


def test_a_personal_cutoff_becomes_a_stored_challenge_end_to_end(
    owner: None,  # noqa: ARG001
) -> None:
    """Finding → lever → band → both gates → a row. The feature, in one test.

    Everything the pipeline persists is asserted against the number the band allows, not
    against the number the stub proposed, because Gate A rejects rather than clamps: if
    the two ever diverged the row would be the one that shipped.
    """
    seed_evening_habit()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_finding(cur, _seed.OWNER)
    stub = StubLLM([json.dumps({"challenges": [_cutoff_proposal()]})])

    result = _gen.run_generation(stub, intent="stop my late coffees")

    assert result["ok"] is True, result
    assert result["generated"] == 1, result["rejected"]
    stored = result["challenges"][0]
    assert (stored["metric"], stored["comparator"]) == (WINDOW, "<=")
    assert stored["target_value"] == IN_BAND
    assert BAND_LOW <= float(stored["target_value"]) <= BAND_HIGH


def test_the_window_is_offered_to_the_model_only_when_it_is_on_the_menu(
    owner: None,  # noqa: ARG001
) -> None:
    """Same proposal, same owner, no finding ⇒ rejected by the same gate that blocks it.

    Instructed AND enforced: the prompt says the window is off the menu and ``screen``
    refuses it anyway, so a model that ignores the instruction still cannot ship one.
    """
    seed_evening_habit()
    stub = StubLLM([json.dumps({"challenges": [_cutoff_proposal()]})] * 2)

    result = _gen.run_generation(stub, intent="stop my late coffees")

    assert result["generated"] == 0
    assert any("not on this owner's menu" in issue for issue in result["rejected"])
    assert any("has not found one" in issue for issue in result["rejected"])


def test_an_out_of_band_cutoff_target_is_rejected_like_any_other(
    owner: None,  # noqa: ARG001
) -> None:
    """A window is an ORDINARY metric to Gate A — no separate path, no separate mercy."""
    seed_evening_habit()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_finding(cur, _seed.OWNER)
    stub = StubLLM([json.dumps({"challenges": [_cutoff_proposal(target_value=5.0)]})] * 2)

    result = _gen.run_generation(stub, intent="stop my late coffees")

    assert result["generated"] == 0
    assert any("progressive-overload band" in issue for issue in result["rejected"])


def test_the_calibration_table_shows_the_window_in_its_own_units(
    owner: None,  # noqa: ARG001
) -> None:
    """The model is shown the band it will be judged against — the "instruct" half.

    Asserted on the prompt the stub actually received, not on the renderer, so a section
    that stopped being included would fail here rather than pass on a unit test.
    """
    seed_evening_habit()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_finding(cur, _seed.OWNER)
    stub = StubLLM([json.dumps({"challenges": [_cutoff_proposal()]})])

    _gen.run_generation(stub, intent="stop my late coffees")

    prompt = "\n".join(message["content"] for message in stub.messages[0])
    assert f"| {WINDOW} | daily | mg | 120 (7d) | 84–95 |" in prompt
    assert "TIME WINDOW" in prompt


def test_the_ledger_reads_a_cut_as_an_improvement_not_a_loss(owner: None) -> None:  # noqa: ARG001
    """A ``good="down"`` window: drinking less late is a POSITIVE ``improvement_pct``.

    Inherited from the registry direction rather than restated — the same rule the daily
    caps already had — but asserted because a sign error here would teach generation that
    the challenge failed every time it worked.
    """
    assert _improvement_pct(WINDOW, 120.0, 60.0) == 50.0
    assert _improvement_pct(WINDOW, 120.0, 180.0) == -50.0


def test_a_window_is_never_adapted_because_a_cap_is_never_adapted(
    owner: None,  # noqa: ARG001
) -> None:
    """``suggest_adaptation`` leaves every ``<=`` challenge alone, windows included.

    Not a new rule and deliberately not a new exception: tightening a cap on a good week
    punishes compliance and loosening one hands back the allowance they committed to cut.
    """
    seed_evening_habit()
    challenge = {
        "metric": WINDOW,
        "comparator": "<=",
        "target_value": IN_BAND,
        "cadence": "daily",
        "window_days": 14,
        "adopted_at": datetime(2026, 7, 8, 6, 0, tzinfo=UTC),
        "baseline_value": 120.0,
    }
    with tenant_transaction(_seed.OWNER) as cur:
        adaptation = suggest_adaptation(
            cur, _seed.OWNER, IST, challenge, {"complete": False}, today=TODAY
        )

    assert adaptation is None


def test_every_window_hour_is_one_the_finder_can_actually_produce() -> None:
    """A window at an hour the cutoff search never tests could never be justified.

    Pinned as a set comparison because the two lists are the same list: the registry keys
    are generated from ``analytics.cutoffs.CUTOFF_HOURS``, and this is what fails if
    somebody ever writes a second one.
    """
    from healthee.analytics.cutoffs import CUTOFF_HOURS, SUBSTANCE_CONFIG
    from healthee.challenges.metrics import CHALLENGE_METRICS
    from healthee.challenges.windowed import metric_key

    expected = {
        metric_key(substance, hour) for substance in SUBSTANCE_CONFIG for hour in CUTOFF_HOURS
    }
    assert expected <= set(CHALLENGE_METRICS)
    assert {m for m in CHALLENGE_METRICS if "_after_" in m} == expected


def test_the_finder_and_the_registry_agree_on_the_metric_name() -> None:
    """The link is a string comparison, so the two strings must be built the same way.

    ``analytics.cutoffs._cutoff_finding`` writes ``f"{substance}_after_{h:02d}"`` onto the
    finding; the registry key is ``windowed.metric_key``. Retyped by hand here rather than
    called, so that a change to either side fails instead of agreeing with itself.
    """
    from healthee.challenges.windowed import metric_key

    assert metric_key("caffeine", 16) == "caffeine_after_16"
    assert metric_key("alcohol", 8) == "alcohol_after_08"


def test_a_seeded_cutoff_finding_names_a_window_that_exists() -> None:
    """The fixture is the shape a real finder run produces — asserted, not assumed.

    ``_seed.seed_finding`` used to default to ``caffeine_after_15``, an hour the search
    never tests, which was invisible until the registry grew a metric per hour.
    """
    from healthee.challenges.metrics import CHALLENGE_METRICS

    assert WINDOW in CHALLENGE_METRICS
    assert "caffeine_after_15" not in CHALLENGE_METRICS


def test_the_window_carries_no_evidence_target_and_no_meaningful_step() -> None:
    """The corpus evidences the TIMING, never an hour and never a safe late dose.

    Both absences are load-bearing: a target would cap the band at a number no note
    states, and a floor would set the smallest worthwhile cut from a study nobody ran.
    """
    from healthee.challenges.targets import EVIDENCE_TARGET, MEANINGFUL_STEP, unranked_metrics

    assert WINDOW not in EVIDENCE_TARGET
    assert WINDOW not in MEANINGFUL_STEP
    assert WINDOW in unranked_metrics()


def test_the_timing_notes_are_strong_enough_to_ground_a_commitment() -> None:
    """Gate B's floor is Probable; the two intake notes are Established.

    This is the difference the window makes to grounding: WP-C3c found the corpus supplies
    no cap for a daily TOTAL, and it does supply a graded claim about late intake — so a
    cutoff challenge can cite something a total cap never honestly could.
    """
    from healthee.insights import manifest

    for note in ("caffeine_sleep", "alcohol_sleep"):
        assert note in manifest.note_ids()
        rank = manifest.GRADE_RANK.get(manifest.grade_of(note) or "", 0)
        assert rank >= manifest.MIN_ACTIONABLE_RANK, f"{note} is too weak to drive a commitment"
