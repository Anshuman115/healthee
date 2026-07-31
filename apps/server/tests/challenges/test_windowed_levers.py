"""A discovered cutoff, made actionable — which windows reach this owner's menu.

The point of the whole feature. CHALLENGES.md §5.1 calls a challenge built on the owner's
own discovered cause-and-effect ("cut caffeine after 16:00 — on your data that is worth
~40 min of sleep") the most motivating and most honest thing the product can offer, and
until the registry grew a clock it was the one thing it could not express.

This half pins the BAND and the MENU; ``test_windowed_generation`` pins what the pipeline
then does with them. Two claims are load-bearing here and they pull in opposite
directions, which is why they are tested together:

* **With a finding, the window is expressible and it ranks FIRST.** It reaches tier 0 —
  the only tier a metric with no population target can reach (§5.1b).
* **Without a finding, the window is OFF THE MENU entirely.** The hour is the claim, and
  the corpus refuses to name one ([caffeine_sleep]'s own honesty policy). Offering a
  window nobody's data chose would be inventing exactly the number the evidence declines
  to state, so it is blocked rather than merely ranked last.

Auto-skips without a reachable TimescaleDB.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta

import pytest
from tests.challenges import _seed
from tests.challenges._windowed_bed import (
    BAND_HIGH,
    BAND_LOW,
    EVENING,
    IST,
    MORNING,
    TODAY,
    WINDOW,
    analyse,
    by_metric,
    seed_evening_habit,
)

from healthee.challenges import levers
from healthee.challenges.bounds import calibrate
from healthee.core.db import tenant_transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration


@pytest.fixture
def owner(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


# ── the band: the owner's own evening intake, and nothing else ────────────────


def test_the_window_calibrates_against_the_owners_own_evening_intake(
    owner: None,  # noqa: ARG001
) -> None:
    """Hand-computed: a 120 mg evening habit gives a band of 84-95 mg, tightening.

    The band is a fraction of what they drink LATE, not of what they drink — which is the
    point of the window. Calibrating a cutoff challenge against the daily total would ask
    a heavy morning drinker for a cut they could make without touching the evening.
    """
    seed_evening_habit()

    with tenant_transaction(_seed.OWNER) as cur:
        windowed = calibrate(cur, _seed.OWNER, IST, WINDOW, "daily", TODAY)
        total = calibrate(cur, _seed.OWNER, IST, "caffeine_mg", "daily", TODAY)

    assert (windowed.baseline, windowed.baseline_days) == (120.0, 7)
    assert windowed.band is not None
    assert (windowed.band.low, windowed.band.high) == (BAND_LOW, BAND_HIGH)
    assert windowed.target is None, "the corpus states no safe late dose — no cap to cite"
    assert total.baseline == 210.0


def test_an_owner_who_never_drinks_late_has_nothing_to_cut(owner: None) -> None:  # noqa: ARG001
    """Baseline 0 on seven MEASURED days ⇒ ``no_baseline_signal``, not a starter target.

    They log every day and none of it is late: the honest answer is that this window has
    no challenge in it, not a number invented from a rounding constant.
    """
    entries = [
        (datetime(2026, 7, 15, tzinfo=UTC) - timedelta(days=i, hours=-1), MORNING, "mg")
        for i in range(1, 8)
    ]
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(cur, _seed.OWNER, "caffeine", entries)
        calibration = calibrate(cur, _seed.OWNER, IST, WINDOW, "daily", TODAY)

    assert (calibration.baseline, calibration.baseline_days) == (0.0, 7)
    assert (calibration.band, calibration.refusal) == (None, "no_baseline_signal")


def test_an_owner_who_barely_logs_cannot_be_calibrated_at_all(owner: None) -> None:  # noqa: ARG001
    """Three logged days of seven ⇒ ``thin_baseline``. Silence is not a low number.

    This is the zero-vs-unlogged decision reaching generation: the window reports only the
    days it measured, so the same ``MIN_COMPARISON_DAYS`` line that stops the ledger
    publishing a thin before/after stops the model being handed a band built on three days.
    """
    entries = [
        (datetime(2026, 7, 15, tzinfo=UTC) - timedelta(days=i, hours=-16), EVENING, "mg")
        for i in (2, 4, 6)
    ]
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(cur, _seed.OWNER, "caffeine", entries)
        calibration = calibrate(cur, _seed.OWNER, IST, WINDOW, "daily", TODAY)

    assert (calibration.band, calibration.refusal) == (None, "thin_baseline")
    assert calibration.baseline_days == 3


# ── the menu: the hour has to come from THEIR data ────────────────────────────


def test_a_window_with_no_personal_cutoff_behind_it_is_off_the_menu(
    owner: None,  # noqa: ARG001
) -> None:
    """A calibratable window is still refused when their own data never found that hour.

    The distinction being asserted is exactly the one that matters: the band EXISTS (they
    drink late, we could compute a target), and the metric is blocked anyway — because the
    doubtful number is not the target, it is the 16:00.
    """
    seed_evening_habit()
    analysis = analyse()
    lever = by_metric(analysis)[WINDOW]

    assert lever.tier == levers.BLOCKED
    assert lever.rank is None
    assert lever.blocked is not None
    assert "their own data has not found one" in lever.blocked
    assert "caffeine_sleep" in lever.blocked
    assert WINDOW in analysis.blocked_metrics()


def test_only_the_hour_their_finding_names_is_opened(owner: None) -> None:  # noqa: ARG001
    """A cutoff at 16:00 says nothing about 12:00 or 22:00 — those stay blocked.

    Matched by equality on the finding's own ``metric_a``, not by a prefix: a prefix rule
    would open every window on the substance and let the model pick an hour their data
    never tested.
    """
    seed_evening_habit()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_finding(cur, _seed.OWNER)  # metric_a = caffeine_after_16
    levers_by_metric = by_metric(analyse())

    assert levers_by_metric[WINDOW].blocked is None
    assert levers_by_metric["caffeine_after_12"].blocked is not None
    assert levers_by_metric["caffeine_after_22"].blocked is not None


def test_their_own_cutoff_ranks_the_window_first(owner: None) -> None:  # noqa: ARG001
    """Tier 0, above every population gap — the only tier a targetless metric can reach.

    The owner is also sedentary here (MVPA 5 min/day against a 150 min/week target, the
    largest population gap the corpus offers), so the ordering is doing real work: their
    OWN measured evidence outranks the textbook one.
    """
    seed_evening_habit()
    week = [TODAY - timedelta(days=i) for i in range(1, 8)]
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "mvpa_min", dict.fromkeys(week, 5.0))
        _seed.seed_finding(cur, _seed.OWNER)
    analysis = analyse()

    first = analysis.ranked()[0]
    assert (first.metric, first.tier) == (WINDOW, levers.PERSONAL_FINDING)
    assert first.finding == WINDOW
    assert first.target is None
    assert by_metric(analysis)["mvpa_min"].rank is not None


def test_a_live_challenge_on_the_daily_total_takes_the_window_off_the_menu(
    owner: None,  # noqa: ARG001
) -> None:
    """One behaviour, one commitment: the window is a slice of the total's own rows."""
    seed_evening_habit()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_finding(cur, _seed.OWNER)
    blocked = analyse(active={"caffeine_mg"}).blocked_metrics()

    assert "the same behaviour is already a live challenge as `caffeine_mg`" in blocked[WINDOW]


def test_a_second_owners_cutoff_does_not_open_this_owners_window(
    owner: None,  # noqa: ARG001
) -> None:
    """Findings are owner-scoped, and so is the menu built from them (MULTI_USER §3.3)."""
    seed_evening_habit()
    _seed.ensure_owner_b()
    try:
        with tenant_transaction(_seed.OTHER_OWNER) as cur:
            _seed.seed_finding(cur, _seed.OTHER_OWNER)
        assert by_metric(analyse())[WINDOW].tier == levers.BLOCKED
    finally:
        _seed.remove_owner_b()
