"""#67 — a (metric, cadence) pair whose days do not add up must not exist.

A ``weekly`` or ``total`` rule SUMS the days in its period, in ``evaluate._period_total``
when it scores and in ``series.recent_window`` when it builds the baseline that target
is calibrated against. ``sri`` is the one registry metric for which that sum means
nothing: a Sleep Regularity Index is a 0–100 SCORE of how alike consecutive days are, so
seven of them added together is ~490 of no quantity at all.

``targets._LEVEL`` already refused to convert the SRI target into weekly units for
exactly this reason — which is what left ``(sri, weekly)`` *calibratable* against a ~490
baseline with **no population cap to bound the band**: a target the model could invent
and Gate A would wave through.

The registry now declares which cadences each metric can take, and this suite pins that
the pair is **unrepresentable** rather than merely unreached — refused at Gate A, at
adopt, and at scoring. Three layers because they are three different doors: generation
proposes, the API adopts, and a row that arrived by any other route still gets scored.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import date, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges import lifecycle
from healthee.challenges.bounds import GENERATABLE_CADENCES, calibrate
from healthee.challenges.evaluate import evaluate_challenge
from healthee.challenges.metrics import (
    CADENCES,
    CHALLENGE_METRICS,
    allows_cadence,
    validate_cadence,
)
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.db import migrate

IST = SENTINEL_TZ
_TODAY = date(2026, 3, 8)
_WEEK = [_TODAY - timedelta(days=i) for i in range(1, 8)]


# ── the declaration ──────────────────────────────────────────────────────────


def test_every_metric_declares_a_non_empty_subset_of_the_vocabulary() -> None:
    """The field has no default, so a new metric must decide — this pins that it did.

    A metric that inherited "all three" from whoever wrote the dataclass is exactly the
    silence this defect lived in.
    """
    for metric, entry in CHALLENGE_METRICS.items():
        assert entry.cadences, f"{metric} declares no cadence at all"
        assert entry.cadences <= CADENCES, f"{metric} declares a cadence outside the vocabulary"
        assert "daily" in entry.cadences, f"{metric} cannot even be a per-day rule"


def test_sri_is_the_only_score_and_takes_no_cumulative_cadence() -> None:
    """Seven SRI scores added together is ~490 of nothing; every other metric sums fine.

    Stated as an exhaustive claim rather than a spot check: the failure mode is a
    *second* score joining the registry without anyone noticing it is one.
    """
    assert CHALLENGE_METRICS["sri"].cadences == frozenset({"daily"})
    summable = {m for m, e in CHALLENGE_METRICS.items() if e.cadences == CADENCES}
    assert summable == set(CHALLENGE_METRICS) - {"sri"}


@pytest.mark.parametrize("cadence", ["weekly", "total"])
def test_validate_cadence_raises_for_the_pair_and_names_it(cadence: str) -> None:
    """A raise, never a silent score — the same choice ``spec`` makes for a bad metric.

    A pair like this does not produce a slightly-wrong number, it produces a number in
    no unit at all, and legacy's habit of scoring the unscoreable as 0 % is what made
    "cannot be tracked" indistinguishable from "no progress".
    """
    assert allows_cadence("sri", cadence) is False
    with pytest.raises(ValueError, match="sri"):
        validate_cadence("sri", cadence)
    assert validate_cadence("sri", "daily") == "daily"


# ── the three doors ──────────────────────────────────────────────────────────


@pytest.fixture
def owner(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "sleep_regularity_index", dict.fromkeys(_WEEK, 60.0))
    yield
    _seed.reset()


@pytest.mark.integration
def test_gate_a_refuses_to_calibrate_the_pair_and_says_why(owner: None) -> None:  # noqa: ARG001
    """Seven days at SRI 60 would otherwise sum to a 420 baseline with no cap on it.

    The daily pair is asserted alongside so the refusal is provably about the CADENCE
    and not about the owner's data being thin.
    """
    assert "weekly" in GENERATABLE_CADENCES  # otherwise this proves nothing
    with tenant_transaction(_seed.OWNER) as cur:
        weekly = calibrate(cur, _seed.OWNER, IST, "sri", "weekly", _TODAY)
        daily = calibrate(cur, _seed.OWNER, IST, "sri", "daily", _TODAY)
    assert (weekly.band, weekly.refusal) == (None, "cadence_not_expressible")
    assert weekly.baseline is None  # the ~490 sum is never even computed
    assert daily.band is not None and daily.baseline == 60.0


@pytest.mark.integration
def test_adopt_refuses_a_stored_pair_by_name(owner: None) -> None:  # noqa: ARG001
    """A row in the table is not proof the pair is expressible — the door checks.

    ``POST /api/challenges/{id}/adopt`` accepts any *suggested* row, so this is the
    reachable path, and a rule outcome (not an exception) is the honest HTTP answer.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        cid = _seed.seed_challenge(
            cur, _seed.OWNER, metric="sri", cadence="weekly", target_value=420.0
        )
        result = lifecycle.adopt(cur, _seed.OWNER, IST, cid, today=_TODAY)
        stored = _seed.stored(cur, _seed.OWNER, cid)
    assert (result["ok"], result["reason"]) == (False, "not_expressible")
    assert stored["status"] == "suggested" and stored["baseline_value"] is None


@pytest.mark.integration
def test_scoring_the_pair_raises_rather_than_reporting_a_number(owner: None) -> None:  # noqa: ARG001
    """The last door: a row that arrived by some other route is still never scored.

    ``evaluate`` is what every surface reads through, so refusing here is what makes
    the pair unrepresentable rather than merely un-adoptable.
    """
    with tenant_transaction(_seed.OWNER) as cur, pytest.raises(ValueError, match="sri"):
        evaluate_challenge(
            cur,
            _seed.OWNER,
            IST,
            {
                "metric": "sri",
                "comparator": ">=",
                "target_value": 420.0,
                "cadence": "weekly",
                "window_days": 7,
                "adopted_at": None,
            },
            today=_TODAY,
        )
