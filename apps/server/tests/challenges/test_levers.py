"""WP-C3c — the lever ranking: who gets pointed at what, and what is withheld.

CHALLENGES.md §5.1b. The ordering is deterministic, so it is tested as an ordering:
every case below states an owner and asserts which metric comes FIRST, plus the rule
that put it there. A test that only counted levers would keep passing with the tiers
shuffled.

Seeded against the real DB because every input is a read — the calibration table, the
`finding` rows, the frozen ledger, and the recovery series — and a stubbed version of any
of them would be testing the stub.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges import levers
from healthee.challenges.gen_context import owner_calibrations
from healthee.challenges.targets import STEEPEST_AT_LOW
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.db import migrate

pytestmark = pytest.mark.integration

IST = SENTINEL_TZ
TODAY = date(2026, 7, 15)
WEEK = [TODAY - timedelta(days=i) for i in range(1, 8)]


def _analyse(active: set[str] | None = None) -> levers.LeverAnalysis:
    with tenant_transaction(_seed.OWNER) as cur:
        calibrations = owner_calibrations(cur, _seed.OWNER, IST, TODAY)
        return levers.analyse(cur, _seed.OWNER, IST, TODAY, calibrations, active or set())


def _by_metric(analysis: levers.LeverAnalysis) -> dict[str, levers.Lever]:
    return {lever.metric: lever for lever in analysis.levers}


@pytest.fixture
def owner(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    """A clean owner with nothing seeded; each test states its own history."""
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _seed_series(**metrics: float) -> None:
    """Seven flat days of each named metric, ending the day before ``TODAY``.

    Named by the DERIVE layer's metric (``sleep_regularity_index``), not the challenge
    registry's shorthand (``sri``) — the registry's source binding is what the engine
    reads, and a test that seeded the shorthand would seed a row nothing looks at.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        for metric, value in metrics.items():
            _seed.seed_metric(cur, _seed.OWNER, metric, dict.fromkeys(WEEK, value))


# ── the core claim: rank the metric where this owner has the most to gain ─────


def test_the_metric_they_are_worst_at_is_ranked_above_the_one_they_are_strong_at(
    owner: None,  # noqa: ARG001
) -> None:
    """Sedentary on MVPA (35 of 150 min/wk), nearly at the steps plateau (7,500 of 8,000).

    Both metrics sit on a curve the corpus calls steepest at the bottom, so they land in
    the same tier and the ORDERING is doing the work: the gap fraction decides, and it is
    the number the prompt shows beside the lever.
    """
    _seed_series(mvpa_min=5.0, steps_total=7500.0)
    analysis = _analyse()

    first = analysis.ranked()[0]
    assert first.metric == "mvpa_min"
    assert first.tier == levers.STEEP_GAP  # the corpus calls this curve steepest at the bottom
    assert first.curve == STEEPEST_AT_LOW and first.curve_note == "mvpa_minutes_mortality"
    assert (first.cadence, first.baseline, first.target) == ("weekly", 35.0, 150.0)
    assert first.gap == 115.0
    assert first.target_note == "mvpa_minutes_mortality"

    steps = _by_metric(analysis)["steps_total"]
    assert steps.rank is not None and steps.rank > first.rank  # type: ignore[operator]
    assert steps.gap_fraction is not None and steps.gap_fraction < first.gap_fraction  # type: ignore[operator]


def test_a_personal_finding_outranks_a_population_gap(owner: None) -> None:  # noqa: ARG001
    """Their own measured evidence beats a textbook gap, even a large one.

    The owner is sedentary (MVPA 35 of 150 — the biggest population gap available) AND
    has an FDR-significant caffeine cutoff. `caffeine_mg` has no population target at all,
    so tier 0 is the ONLY way it could ever be ranked — and it comes first.
    """
    _seed_series(mvpa_min=5.0, steps_total=7500.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_finding(cur, _seed.OWNER)
        _seed.seed_manual(
            cur,
            _seed.OWNER,
            "caffeine",
            [
                (datetime(2026, 7, 8, 6, 0, tzinfo=UTC) + timedelta(days=i), 200.0, "mg")
                for i in range(7)
            ],
        )
    analysis = _analyse()

    first = analysis.ranked()[0]
    assert (first.metric, first.tier) == ("caffeine_mg", levers.PERSONAL_FINDING)
    assert first.finding == "caffeine_after_15"
    assert first.finding_effect == 0.62
    assert first.target is None  # ranked with NO population target — the tier-0 property
    assert _by_metric(analysis)["mvpa_min"].tier == levers.STEEP_GAP


def test_the_outcome_side_of_a_cutoff_is_not_promoted_only_the_intervention(
    owner: None,  # noqa: ARG001
) -> None:
    """ "Caffeine after 15:00 costs you sleep" argues for a caffeine lever, not a sleep one.

    The finding names `tst_min` as its OUTCOME (`metric_b`). Reading that as an
    implication would rank sleep duration on the strength of evidence about caffeine.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_finding(cur, _seed.OWNER)
        _seed.seed_sleep(cur, _seed.OWNER, dict.fromkeys(WEEK, 300.0))
    assert _by_metric(_analyse())["tst_min"].tier != levers.PERSONAL_FINDING


# ── history: never re-push what they walked away from ─────────────────────────


def test_a_recently_abandoned_lever_is_not_re_suggested(owner: None) -> None:  # noqa: ARG001
    _seed_series(steps_total=3000.0)
    with tenant_transaction(_seed.OWNER) as cur:
        challenge_id = _seed.seed_challenge(cur, _seed.OWNER, status="abandoned")
        _seed.seed_outcome(
            cur,
            _seed.OWNER,
            challenge_id,
            status="abandoned",
            ended_at=datetime(2026, 7, 10, 6, 0, tzinfo=UTC),
        )
    analysis = _analyse()

    steps = _by_metric(analysis)["steps_total"]
    assert steps.rank is None and steps.tier == levers.BLOCKED
    assert "abandoned on 2026-07-10" in (steps.blocked or "")
    assert analysis.blocked_metrics()["steps_total"] == steps.blocked


def test_an_abandonment_older_than_the_cooldown_is_offerable_again(owner: None) -> None:  # noqa: ARG001
    """They dropped it in the spring; not re-offering it forever would be its own failure."""
    _seed_series(steps_total=3000.0)
    stale = datetime(2026, 7, 10, 6, 0, tzinfo=UTC) - timedelta(
        days=levers.ABANDON_COOLDOWN_DAYS + 5
    )
    with tenant_transaction(_seed.OWNER) as cur:
        challenge_id = _seed.seed_challenge(cur, _seed.OWNER, status="abandoned")
        _seed.seed_outcome(cur, _seed.OWNER, challenge_id, status="abandoned", ended_at=stale)

    assert _by_metric(_analyse())["steps_total"].rank is not None


def test_a_completed_challenge_does_not_block_the_metric_it_raised(owner: None) -> None:  # noqa: ARG001
    """Only an ABANDONMENT blocks: legacy's rule was to build ON wins, not route around them."""
    _seed_series(steps_total=3000.0)
    with tenant_transaction(_seed.OWNER) as cur:
        challenge_id = _seed.seed_challenge(cur, _seed.OWNER, status="completed")
        _seed.seed_outcome(cur, _seed.OWNER, challenge_id, status="met")

    assert _by_metric(_analyse())["steps_total"].blocked is None


def test_a_live_challenge_blocks_its_own_metric(owner: None) -> None:  # noqa: ARG001
    _seed_series(steps_total=3000.0)
    blocked = _analyse(active={"steps_total"}).blocked_metrics()
    assert "already running" in blocked["steps_total"]


# ── recovery: a hard training lever is not handed to an under-recovered owner ──


def test_an_under_recovered_owner_is_not_handed_a_hard_training_lever(owner: None) -> None:  # noqa: ARG001
    """A week in the `low` band withholds intensity and keeps movement. D7/D8.

    Steps and sleep are NOT withheld — [[recovery_readiness]] eases intensity, and
    legacy's own recovery-aware prescription named Zone-2 and daily steps as what to
    favour instead. Withholding those would be the rule misfiring, so both halves are
    asserted.
    """
    _seed_series(mvpa_min=5.0, steps_total=3000.0, cardio_load=40.0, recovery_score=20.0)
    analysis = _analyse()
    by_metric = _by_metric(analysis)

    assert analysis.recovery == "low"
    for hard in ("mvpa_min", "cardio_load"):
        assert by_metric[hard].rank is None
        assert "hard training lever withheld" in (by_metric[hard].blocked or "")
        assert "recovery_readiness" in (by_metric[hard].blocked or "")
    assert by_metric["steps_total"].blocked is None
    assert analysis.ranked()[0].metric == "steps_total"


def test_an_illness_flag_withholds_intensity_however_good_the_recovery_number_is(
    owner: None,  # noqa: ARG001
) -> None:
    """[[recovery_readiness]] D7: safety inputs are hard OVERRIDES, not votes.

    The owner's recovery score is high all week. A flagged illness withholds the hard
    lever anyway — the same rule ``read/recovery.py`` already applies to its push-style
    guidance, reading the same flag through the same function.
    """
    _seed_series(mvpa_min=5.0, steps_total=3000.0, recovery_score=85.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_illness(cur, _seed.OWNER, TODAY - timedelta(days=1))
    analysis = _analyse()

    assert (analysis.recovery, analysis.illness) == ("high", "moderate")
    assert "an illness signal is active" in (_by_metric(analysis)["mvpa_min"].blocked or "")
    assert analysis.ranked()[0].metric == "steps_total"


def test_a_stale_illness_flag_does_not_withhold_anything(owner: None) -> None:  # noqa: ARG001
    """ "Active" means within the flag's own window, resolved against the PINNED anchor.

    Two weeks old is cleared. This also pins that the read is anchored on the caller's
    ``today`` rather than the wall clock — with a wall-clock anchor this flag, dated
    relative to a fixed TODAY, would drift in and out of the window as the suite ages.
    """
    _seed_series(mvpa_min=5.0, recovery_score=85.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_illness(cur, _seed.OWNER, TODAY - timedelta(days=14))
    analysis = _analyse()

    assert analysis.illness is None
    assert _by_metric(analysis)["mvpa_min"].blocked is None


def test_a_well_recovered_owner_keeps_every_lever(owner: None) -> None:  # noqa: ARG001
    _seed_series(mvpa_min=5.0, steps_total=3000.0, recovery_score=80.0)
    analysis = _analyse()

    assert analysis.recovery == "high"
    assert analysis.ranked()[0].metric == "mvpa_min"


def test_unknown_recovery_withholds_nothing(owner: None) -> None:  # noqa: ARG001
    """ "We cannot tell" is not "you are under-recovered" — the optimistic guess, backwards.

    Three days of recovery scores is under ``MIN_COMPARISON_DAYS``, so the band is unknown
    and the training lever stays on the menu.
    """
    _seed_series(mvpa_min=5.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "recovery_score", dict.fromkeys(WEEK[:3], 10.0))
    analysis = _analyse()

    assert analysis.recovery is None
    assert _by_metric(analysis)["mvpa_min"].blocked is None


def test_one_bad_morning_does_not_withhold_anything(owner: None) -> None:  # noqa: ARG001
    """The unit of action is the multi-day trend (D3), so the MEDIAN decides, not the worst day."""
    _seed_series(mvpa_min=5.0, recovery_score=80.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "recovery_score", {WEEK[0]: 5.0})

    assert _analyse().recovery == "high"


# ── the honest outputs: at target, and not rankable at all ────────────────────


def test_a_metric_with_no_dose_response_evidence_is_unranked_and_says_so(owner: None) -> None:  # noqa: ARG001
    """Asserted, not incidental: `cardio_load` has no target, so it gets no rank."""
    _seed_series(cardio_load=40.0, steps_total=3000.0)
    load = _by_metric(_analyse())["cardio_load"]

    assert (load.rank, load.tier) == (None, levers.UNRANKED)
    assert (load.target, load.target_note, load.gap, load.curve_note) == (None, None, None, None)
    assert load.curve == "unknown"
    assert load.blocked is None  # unranked is not forbidden — just unplaceable


def test_an_owner_past_the_evidence_target_has_no_gap_left_on_that_metric(owner: None) -> None:  # noqa: ARG001
    """12,000 steps a day: ranked LAST, never hidden, and never a negative gap."""
    _seed_series(steps_total=12000.0, sleep_regularity_index=50.0)
    by_metric = _by_metric(_analyse())

    assert by_metric["steps_total"].tier == levers.AT_TARGET
    assert by_metric["steps_total"].gap == -4000.0
    assert by_metric["sri"].rank is not None
    assert by_metric["sri"].rank < by_metric["steps_total"].rank  # type: ignore[operator]


def test_sleeping_past_the_band_is_not_a_lever_to_pull_harder(owner: None) -> None:  # noqa: ARG001
    """The U-curve's long tail is read as a marker of illness, not a target to chase.

    ``tst_min``'s gap is floored at zero rather than going negative, because the registry
    cannot express "sleep less" and the note refuses to treat the long tail as causal.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_sleep(cur, _seed.OWNER, dict.fromkeys(WEEK, 620.0))
        _seed.seed_metric(cur, _seed.OWNER, "sleep_need_min", dict.fromkeys(WEEK, 480.0))
    sleep = _by_metric(_analyse())["tst_min"]

    assert (sleep.tier, sleep.gap) == (levers.AT_TARGET, 0.0)
    assert sleep.target == 480.0 and sleep.target_note == "sleep_need_debt"


def test_a_short_sleeper_gets_their_own_age_banded_need_as_the_target(owner: None) -> None:  # noqa: ARG001
    """The product's own owner: ~3.7 h against an NSF need read from THEIR profile."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_sleep(cur, _seed.OWNER, dict.fromkeys(WEEK, 222.0))
        _seed.seed_metric(cur, _seed.OWNER, "sleep_need_min", dict.fromkeys(WEEK, 480.0))
    sleep = _by_metric(_analyse())["tst_min"]

    assert (sleep.tier, sleep.target, sleep.gap) == (levers.GAP, 480.0, 258.0)
    assert sleep.curve == "u_shaped"  # a gap, but NOT the steep-bottom promotion


def test_an_owner_with_no_data_at_all_has_no_levers_and_no_crash(owner: None) -> None:  # noqa: ARG001
    analysis = _analyse()
    assert analysis.ranked() == ()
    assert all(lever.tier == levers.UNRANKED for lever in analysis.levers)
