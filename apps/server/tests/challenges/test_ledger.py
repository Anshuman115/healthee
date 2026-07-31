"""The outcome ledger: what we claim, what we refuse to claim, and how we say so.

This is the honesty-critical surface of the whole track — the point where a week of
someone's life becomes a stored claim that generation, the coach and the Insights
rollup will all read instead of the week. So these tests are mostly about what does
NOT get asserted:

* the challenge's own metric gets a before/after (fair — same estimator, same window
  length, one either side);
* every other metric is recorded as co-occurring, with the concurrency count attached
  so the number cannot be lifted out of its caveat;
* a comparison built from too few days is LABELLED, not published and not dropped;
* a `good="down"` metric that fell is an IMPROVEMENT, not a negative result.

Auto-skips without a reachable TimescaleDB (the suite-wide policy).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges import ledger, lifecycle
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.db import migrate

pytestmark = pytest.mark.integration

IST = SENTINEL_TZ
_START = date(2026, 3, 1)
_AFTER_WINDOW = date(2026, 3, 8)
_ADOPTED = datetime(2026, 3, 1, 6, 0, tzinfo=UTC)  # 11:30 IST on 03-01


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _days(cur, owner, metric: str, first: date, values: list[float]) -> None:
    _seed.seed_metric(
        cur, owner, metric, {first + timedelta(days=i): v for i, v in enumerate(values)}
    )


def _outcome(cur, owner, challenge_id: int | None = None) -> dict:
    """The owner's frozen outcome — the only one, or the one for ``challenge_id``."""
    rows = ledger.recent(cur, owner)
    if challenge_id is not None:
        rows = [r for r in rows if r["challenge_id"] == challenge_id]
    assert len(rows) == 1, f"expected exactly one frozen outcome, got {len(rows)}"
    return rows[0]


def _finish(cur, owner, tz: str = IST, today: date = _AFTER_WINDOW, **overrides) -> int:
    """Seed an active challenge, run it to its end, and return its id."""
    cid = _seed.seed_challenge(cur, owner, status="active", adopted_at=_ADOPTED, **overrides)
    lifecycle.finalize_due(cur, owner, tz, today)
    return cid


# ── the one claim we make: the challenge's own metric ────────────────────────


def test_the_target_metric_gets_a_like_for_like_before_and_after(clean_db: None) -> None:  # noqa: ARG001
    """4000 before, 6000 during ⇒ +50 %. Both sides are a 7-day mean.

    Same estimator, same number of days, one ending the day before the challenge and
    one ending the day it finished. A different window on either side would measure
    the estimator rather than the person.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=7), [4000.0] * 7)
        _days(cur, _seed.OWNER, "steps_total", _START, [6000.0] * 7)
        _finish(cur, _seed.OWNER, baseline_value=4000.0)
        outcome = _outcome(cur, _seed.OWNER)
    assert (outcome["baseline"], outcome["final"]) == (4000.0, 6000.0)
    assert outcome["improvement_pct"] == 50.0
    assert outcome["improved"] is True
    assert outcome["data_confidence"] == "ok"


def test_a_downward_metric_that_fell_is_an_improvement(clean_db: None) -> None:  # noqa: ARG001
    """7 units before, 3.5 during. The RAW delta is −50 %; the improvement is +50 %.

    Filed as a negative result, this would teach WP-C3's generation that the alcohol
    cap failed and to stop offering it — the exact opposite of what happened. The
    direction comes from the registry's `good`, so it is the same direction every
    other surface uses.
    """
    before = [
        (datetime(2026, 2, 22, 20, 0, tzinfo=UTC) + timedelta(days=i), 1.0, "units")
        for i in range(7)
    ]
    during = [
        (datetime(2026, 3, 1, 20, 0, tzinfo=UTC) + timedelta(days=i), 0.5, "units")
        for i in range(7)
    ]
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(cur, _seed.OWNER, "alcohol", before + during)
        _finish(
            cur,
            _seed.OWNER,
            tz="UTC",
            metric="alcohol_units",
            cadence="weekly",
            comparator="<=",
            target_value=5.0,
            baseline_value=7.0,
        )
        outcome = _outcome(cur, _seed.OWNER)
    assert (outcome["baseline"], outcome["final"]) == (7.0, 3.5)
    assert outcome["improvement_pct"] == 50.0, "a cap that worked is a POSITIVE improvement"
    assert outcome["improved"] is True


def test_the_terminal_status_never_calls_an_unmet_window_a_success(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Two of seven days hit ⇒ `unmet_timed_out`, and `improved` is False, not absent.

    Legacy recorded a timed-out rung as "completed"; a ledger that files failures as
    successes teaches the generation layer to keep prescribing what did not work.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=7), [8000.0] * 7)
        _days(
            cur,
            _seed.OWNER,
            "steps_total",
            _START,
            [9000.0, 9000.0, 100.0, 100.0, 100.0, 100.0, 100.0],
        )
        _finish(cur, _seed.OWNER, baseline_value=8000.0)
        outcome = _outcome(cur, _seed.OWNER)
    assert outcome["status"] == "unmet_timed_out"
    assert outcome["improved"] is False


def test_abandoning_still_freezes_an_outcome(clean_db: None) -> None:  # noqa: ARG001
    """Giving up is a result. WP-C3 can only route around it if it is recorded."""
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=7), [4000.0] * 7)
        _days(cur, _seed.OWNER, "steps_total", _START, [4000.0] * 3)
        cid = _seed.seed_challenge(
            cur, _seed.OWNER, status="active", adopted_at=_ADOPTED, baseline_value=4000.0
        )
        lifecycle.abandon(cur, _seed.OWNER, IST, cid, today=date(2026, 3, 3))
        outcome = _outcome(cur, _seed.OWNER)
    assert outcome["status"] == "abandoned"
    assert outcome["days_active"] == 3


# ── adherence is the BEHAVIOUR rate, split from the metric move (§2.6) ───────


def test_adherence_counts_days_met_not_whether_the_metric_moved(clean_db: None) -> None:  # noqa: ARG001
    """Five of seven days at target ⇒ 0.714, independently of the metric's delta.

    Legacy's single `adherence` answered both questions, so "they showed up every day
    and it did nothing" was indistinguishable from "they barely showed up and it
    worked anyway" — opposite lessons.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=7), [4000.0] * 7)
        _days(
            cur,
            _seed.OWNER,
            "steps_total",
            _START,
            [9000.0, 9000.0, 100.0, 9000.0, 9000.0, 100.0, 9000.0],
        )
        _finish(cur, _seed.OWNER, baseline_value=4000.0)
        outcome = _outcome(cur, _seed.OWNER)
    assert outcome["adherence"] == round(5 / 7, 3)
    assert outcome["improvement_pct"] is not None, "the two are independent numbers"


def test_a_cumulative_rule_has_no_adherence_rather_than_an_invented_one(
    clean_db: None,  # noqa: ARG001
) -> None:
    """A weekly total makes no per-day commitment, so there are no days it was met.

    A number here would be a composite score with no methodology (CLAUDE.md).
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "mvpa_min", _START - timedelta(days=7), [20.0] * 7)
        _days(cur, _seed.OWNER, "mvpa_min", _START, [30.0] * 7)
        _finish(
            cur,
            _seed.OWNER,
            metric="mvpa_min",
            cadence="weekly",
            target_value=200.0,
            baseline_value=140.0,
        )
        outcome = _outcome(cur, _seed.OWNER)
    assert outcome["adherence"] is None
    assert outcome["improvement_pct"] == 50.0  # 210 vs 140, both 7-day sums


# ── the data-sufficiency gate: labelled, never silently dropped ──────────────


def test_a_thin_baseline_is_labelled_not_dropped(clean_db: None) -> None:  # noqa: ARG001
    """Two days of history ⇒ an outcome that EXISTS and says why to distrust it.

    Legacy's `_result` returned None here and the outcome vanished — no record and no
    reason, which is worse than either alone.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=2), [4000.0] * 2)
        _days(cur, _seed.OWNER, "steps_total", _START, [9000.0] * 7)
        _finish(cur, _seed.OWNER, baseline_value=4000.0)
        outcome = _outcome(cur, _seed.OWNER)
    assert outcome["data_confidence"] == "insufficient_data"
    assert outcome["improvement_pct"] is not None, "the number is kept, with its caveat"


def test_a_thin_final_window_is_labelled_too(clean_db: None) -> None:  # noqa: ARG001
    """The gate is symmetric: a thin "after" misleads exactly as much as a thin "before"."""
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=7), [4000.0] * 7)
        _days(cur, _seed.OWNER, "steps_total", _START, [9000.0] * 2)
        _finish(cur, _seed.OWNER, baseline_value=4000.0)
        outcome = _outcome(cur, _seed.OWNER)
    assert outcome["data_confidence"] == "insufficient_data"


def test_no_baseline_means_no_improvement_claim(clean_db: None) -> None:  # noqa: ARG001
    """Nothing to divide by ⇒ `improvement_pct` is None, and the row still exists.

    A percentage change from an unknown (or zero) starting point is undefined, not
    100 % and not infinite.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START, [9000.0] * 7)
        _finish(cur, _seed.OWNER, baseline_value=None)
        outcome = _outcome(cur, _seed.OWNER)
    assert (outcome["improvement_pct"], outcome["improved"]) == (None, None)
    assert outcome["data_confidence"] == "insufficient_data"


# ── other metrics are co-occurring, never caused ─────────────────────────────


def test_other_metrics_are_recorded_without_a_causal_claim(clean_db: None) -> None:  # noqa: ARG001
    """HRV moved 20 % during the window. We store that, and claim nothing from it.

    Legacy fed exactly this number back into generation as the challenge's
    "downstream" effect. Under concurrency that attribution is unknowable, so the
    number lives under `co_occurring` with `attribution: "none"` and the concurrency
    count beside it — and the target metric is NOT duplicated here, because that one
    IS a claim and belongs in `improvement_pct`.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=7), [4000.0] * 14)
        _days(cur, _seed.OWNER, "hrv_sleep_avg", _START - timedelta(days=7), [50.0] * 7)
        _days(cur, _seed.OWNER, "hrv_sleep_avg", _START, [60.0] * 7)
        _finish(cur, _seed.OWNER, baseline_value=4000.0)
        outcome = _outcome(cur, _seed.OWNER)
    metrics = outcome["co_occurring"]["metrics"]
    assert metrics["hrv_sleep_avg"] == {"before": 50.0, "after": 60.0, "delta_pct": 20.0}
    assert "steps_total" not in metrics, "the target metric is a claim, not a co-occurrence"
    assert metrics["rhr_daily"] is None, "no data ⇒ no delta, not a zero"


# ── idempotence ──────────────────────────────────────────────────────────────


def test_freezing_twice_does_not_rewrite_history(clean_db: None) -> None:  # noqa: ARG001
    """An outcome records what was true when a commitment ended. It does not update.

    The second freeze runs against DIFFERENT data on purpose: if it overwrote, the
    stored improvement would move, and a ledger whose past changes is not a ledger.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=7), [4000.0] * 7)
        _days(cur, _seed.OWNER, "steps_total", _START, [6000.0] * 7)
        cid = _finish(cur, _seed.OWNER, baseline_value=4000.0)
        first = _outcome(cur, _seed.OWNER)
        _days(cur, _seed.OWNER, "steps_total", _START, [12000.0] * 7)
        challenge = _seed.stored(cur, _seed.OWNER, cid)
        ledger.freeze(cur, _seed.OWNER, IST, challenge, {}, "completed", _START, _AFTER_WINDOW)
        second = _outcome(cur, _seed.OWNER)
    assert first["improvement_pct"] == 50.0
    assert second == first, "the stored outcome must not have moved"


# ── owner isolation ──────────────────────────────────────────────────────────


def test_the_ledger_never_mixes_owners(clean_db: None) -> None:  # noqa: ARG001
    """Both owners finish an identically-shaped challenge with DIFFERENT results.

    Identical shapes on purpose: a leak surfaces as the wrong NUMBER in someone's
    personal history — which is the shape this whole system exists to prevent — not
    as a row-count wobble anyone would notice.
    """
    _seed.ensure_owner_b()
    try:
        for owner, during in ((_seed.OWNER, 6000.0), (_seed.OTHER_OWNER, 2000.0)):
            with tenant_transaction(owner) as cur:
                _days(cur, owner, "steps_total", _START - timedelta(days=7), [4000.0] * 7)
                _days(cur, owner, "steps_total", _START, [during] * 7)
                _finish(cur, owner, baseline_value=4000.0)
        with tenant_transaction(_seed.OWNER) as cur:
            mine = _outcome(cur, _seed.OWNER)
        with tenant_transaction(_seed.OTHER_OWNER) as cur:
            theirs = _outcome(cur, _seed.OTHER_OWNER)
    finally:
        _seed.remove_owner_b()
    assert mine["improvement_pct"] == 50.0
    assert theirs["improvement_pct"] == -50.0
    assert mine["confounds"]["concurrent_challenges"] == 0, "B's challenge is not A's confound"
