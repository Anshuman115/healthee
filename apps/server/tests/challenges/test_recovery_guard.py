"""The adapter's recovery guard — a raise is a claim the owner's data can refuse.

The defect this pins: WP-C3c made GENERATION refuse to offer a hard training lever to
an under-recovered owner, and the adapter would raise one already adopted under exactly
the same conditions. So an owner beating their MVPA target *because* they are
overtraining got ratcheted further in — the safety rule existed, the adapter did not
consult it.

Four properties are asserted here, and every one of them is the guard being *narrow*
rather than merely present:

* a raise on a training-load metric is blocked, with a reason, when recovery is low
  AND when an illness flag is active;
* an EASE is still offered in both states — [[recovery_readiness]] D8 says recovery
  eases or holds, it never escalates, and easing an under-recovered owner's target is
  the correct behaviour, not collateral damage;
* a non-training metric is untouched — steps are the recovery-friendly ALTERNATIVE to
  intensity, so blocking them would be the guard doing harm;
* a healthy owner sees no change at all.

Seeded against the real DB: the recovery band and the illness flag are both reads, and
stubbing either would test the stub rather than the definition ``levers`` shares.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges import levers, lifecycle
from healthee.challenges.adapt import WITHHELD, suggest_adaptation
from healthee.challenges.recovery_guard import HARD_TRAINING_LEVERS, hold_reason
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.db import migrate

pytestmark = pytest.mark.integration

IST = SENTINEL_TZ
_START = date(2026, 3, 1)
_TODAY = date(2026, 3, 7)  # day seven — past the five-day signal gate
_ADOPTED = datetime(2026, 3, 1, 6, 0, tzinfo=UTC)  # 11:30 IST on 03-01
_WEEK = [_START + timedelta(days=i) for i in range(7)]

_RUNNING = {"complete": False}

# `read.recovery_guidance` bands a score below 34 as `low` and 67+ as `high`. Seeded as
# flat weeks so the trailing-week MEDIAN the guard reads is unambiguous.
_LOW_RECOVERY = 20.0
_HIGH_RECOVERY = 85.0


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _challenge(**overrides) -> dict:
    """60 MVPA min a day for a fortnight — a hard training lever, halfway through.

    ``daily`` rather than ``weekly`` on purpose: a ``>=`` cumulative rule is *complete*
    the moment the total is reached, and a completed challenge is never adapted, so a
    weekly one cannot reach a raise through the real progress dict at all. The daily
    shape is the one an owner can actually be over-performing on mid-window.
    """
    return {
        "metric": "mvpa_min",
        "comparator": ">=",
        "target_value": 60.0,
        "cadence": "daily",
        "window_days": 14,
        "adopted_at": _ADOPTED,
        "baseline_value": 30.0,
    } | overrides


def _seed_week(cur, **metrics: float) -> None:
    """Seven flat days of each named metric, starting on the adoption day."""
    for metric, value in metrics.items():
        _seed.seed_metric(cur, _seed.OWNER, metric, dict.fromkeys(_WEEK, value))


def _adapt(challenge: dict) -> dict | None:
    """The adaptation the engine offers for ``challenge`` as of ``_TODAY``."""
    with tenant_transaction(_seed.OWNER) as cur:
        return suggest_adaptation(cur, _seed.OWNER, IST, challenge, _RUNNING, today=_TODAY)


# ── the guard fires: performance earns a raise, recovery refuses it ───────────


def test_a_raise_is_withheld_while_the_weeks_recovery_is_low(clean_db: None) -> None:  # noqa: ARG001
    """90 MVPA min/day against a 60 target is ratio 1.5 — the rule earns a +20 % raise.

    Unguarded that is ``up`` / 70 (60 × 1.2 = 72, rounded to the metric's 5-minute step,
    under the 150 ceiling) — and the last test in this file asserts exactly that for a
    healthy owner, so the two differ only in the recovery week. With recovery at 20 all
    week the same performance is evidence of somebody digging a hole, so the number is
    withheld and the REASON travels: "not raising this while your recovery is low" is a
    better answer than an empty banner.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, mvpa_min=90.0, recovery_score=_LOW_RECOVERY)
    result = _adapt(_challenge())
    assert result is not None
    assert (result["direction"], result["suggested"]) == (WITHHELD, None)
    assert result["current"] == 60.0
    assert "recovery has been low all week" in result["reason"]
    assert "[recovery_readiness]" in result["reason"]


def test_a_raise_is_withheld_while_an_illness_flag_is_active(clean_db: None) -> None:  # noqa: ARG001
    """Recovery reads HIGH all week; the illness flag overrides it anyway.

    [[recovery_readiness]] D7 — a safety input is a hard override, not a vote. This is
    the case a "recovery band only" guard would get wrong, and it is the case that
    matters most: the score has not caught up with the infection yet.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, mvpa_min=90.0, recovery_score=_HIGH_RECOVERY)
        _seed.seed_illness(cur, _seed.OWNER, _TODAY - timedelta(days=1))
    result = _adapt(_challenge())
    assert result is not None
    assert (result["direction"], result["suggested"]) == (WITHHELD, None)
    assert "an illness signal is active" in result["reason"]


# ── the guard stays narrow: eases, other metrics, healthy owners ─────────────


@pytest.mark.parametrize("ill", [False, True])
def test_an_ease_is_still_offered_to_an_under_recovered_owner(
    clean_db: None,  # noqa: ARG001
    ill: bool,
) -> None:
    """30 MVPA min/day against a 60 target is ratio 0.5 — so −15 %: 51, rounded to 50.

    The floor (baseline 30 × 1.05 = 31.5) does not bind here, so this is the ordinary
    ease and nothing about it may change. Easing is the kind answer AND the
    evidence-backed one (D8: recovery eases or holds), so a guard that blocked every
    adaptation would take the one move an under-recovered owner actually needs. Both
    under-recovered states are asserted, not just one.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, mvpa_min=30.0, recovery_score=_LOW_RECOVERY)
        if ill:
            _seed.seed_illness(cur, _seed.OWNER, _TODAY - timedelta(days=1))
    result = _adapt(_challenge())
    assert result is not None
    assert (result["direction"], result["suggested"]) == ("down", 50.0)


def test_a_non_training_metric_is_raised_however_low_the_recovery_is(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Steps at 6000 against a 5000 daily target still raise to 6000 on a low week.

    Deliberate scope, not an oversight: [[recovery_readiness]] eases INTENSITY, and
    daily steps and Zone-2 movement are what it eases intensity *toward*. A blanket
    guard would withhold the recovery-friendly lever along with the risky one.
    """
    challenge = _challenge(metric="steps_total", cadence="daily", target_value=5000.0)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, steps_total=6000.0, recovery_score=_LOW_RECOVERY)
    result = _adapt(challenge)
    assert result is not None
    assert (result["direction"], result["suggested"]) == ("up", 6000.0)


def test_a_healthy_owner_is_completely_unaffected(clean_db: None) -> None:  # noqa: ARG001
    """The same over-performance with recovery high: the raise lands, unchanged at 70.

    60 × 1.2 = 72, rounded to the 5-minute step and under the 150-minute ceiling — the
    ported arithmetic, which the guard must not shave anything off.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, mvpa_min=90.0, recovery_score=_HIGH_RECOVERY)
    result = _adapt(_challenge())
    assert result is not None
    assert (result["direction"], result["suggested"]) == ("up", 70.0)


def test_unknown_recovery_does_not_withhold_anything(clean_db: None) -> None:  # noqa: ARG001
    """Three scored days is under ``MIN_COMPARISON_DAYS``, so the band is unknown.

    Unknown is not "under-recovered". Refusing a raise on absent data would be the
    optimistic guess run backwards — and the guard would then fire for every owner
    whose recovery pipeline has a gap.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, mvpa_min=90.0)
        _seed.seed_metric(
            cur, _seed.OWNER, "recovery_score", dict.fromkeys(_WEEK[:3], _LOW_RECOVERY)
        )
    result = _adapt(_challenge())
    assert result is not None
    assert (result["direction"], result["suggested"]) == ("up", 70.0)


# ── the endpoint refuses by name, and does not move the target ───────────────


def test_apply_refuses_a_withheld_raise_by_name_and_leaves_the_target(
    clean_db: None,  # noqa: ARG001
) -> None:
    """``POST …/adapt`` is where the ratchet actually happened — 60 must stay 60.

    A named refusal, not the generic "nothing is due": the owner's performance DID earn
    a raise, and the endpoint says why it is not being applied. The stored value is
    asserted separately from the refusal, because a service that reported the refusal
    and wrote the raise anyway would satisfy either assertion alone.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _seed_week(cur, mvpa_min=90.0, recovery_score=_LOW_RECOVERY)
        cid = _seed.seed_challenge(
            cur,
            _seed.OWNER,
            status="active",
            metric="mvpa_min",
            cadence="daily",
            target_value=60.0,
            window_days=14,
            adopted_at=_ADOPTED,
            baseline_value=30.0,
        )
        result = lifecycle.apply_adaptation(cur, _seed.OWNER, IST, cid, today=_TODAY)
        stored = _seed.stored(cur, _seed.OWNER, cid)
    assert (result["ok"], result["reason"]) == (False, "adaptation_withheld")
    assert "recovery has been low all week" in result["error"]
    assert stored["target_value"] == 60.0


# ── ONE definition, read by both surfaces ────────────────────────────────────


@pytest.mark.parametrize("metric", sorted(HARD_TRAINING_LEVERS))
def test_the_menu_and_the_adapter_hold_exactly_the_same_metrics(metric: str) -> None:
    """Whatever ``levers`` refuses to OFFER, ``adapt`` refuses to RAISE — same rule.

    Both surfaces are asserted against the SAME predicate, because that predicate is
    the shared definition: a second copy of "which levers, on what owner state" in
    ``adapt`` is precisely how the asymmetry got built, so this fails the moment
    either surface starts deciding for itself.
    """
    assert hold_reason(metric, "low", None) == "recovery has been low all week"
    assert hold_reason(metric, "high", "moderate") == "an illness signal is active"
    assert hold_reason(metric, "high", None) is None
    menu = levers._blocked_reason(metric, set(), {}, "low", None, None)
    assert menu is not None and "recovery has been low all week" in menu


@pytest.mark.parametrize("metric", ["steps_total", "active_calories", "tst_min", "sri"])
def test_the_recovery_supporting_and_movement_levers_are_never_held(metric: str) -> None:
    """Each absence from the set is a decision, and each is asserted rather than assumed.

    Steps and active calories are the ALTERNATIVE to intensity; sleep and regularity are
    what recovery is made of. Withholding any of them from an under-recovered owner
    would withhold the thing that helps.
    """
    assert hold_reason(metric, "low", "high") is None
