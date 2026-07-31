"""The confound flags — the structured reasons to distrust an outcome (§2.1).

Split from ``test_ledger`` because they answer a different question: not "is the
before/after right" but "is there a reason it means nothing". Legacy shipped this
as prose on top of a structure that implied the opposite, so each flag being
computed, stored, and — where it cannot be computed — reported UNANSWERED is the
whole point.

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


# ── confounds ────────────────────────────────────────────────────────────────


def test_illness_days_inside_the_window_are_counted(clean_db: None) -> None:  # noqa: ARG001
    """Almost every metric here moves under illness, and none of it is the challenge.

    Two flags land inside the window and one the day before it — the outside one must
    not be counted, or the flag stops meaning "during this challenge".
    """
    with tenant_transaction(_seed.OWNER) as cur:
        for day in (
            _START - timedelta(days=1),
            _START + timedelta(days=2),
            _START + timedelta(days=3),
        ):
            cur.execute(
                "INSERT INTO illness_flag (user_id, date, severity, research_note_ids) "
                "VALUES (%s, %s, 'moderate', %s) ON CONFLICT (user_id, date) DO NOTHING",
                (_seed.OWNER, day, ["respiratory_rate_normal"]),
            )
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=7), [4000.0] * 14)
        _finish(cur, _seed.OWNER, baseline_value=4000.0)
        outcome = _outcome(cur, _seed.OWNER)
    assert outcome["confounds"]["illness_days"] == 2


def test_overlapping_challenges_are_counted_on_both_the_confound_and_the_deltas(
    clean_db: None,  # noqa: ARG001
) -> None:
    """THE §7.1 test. The count travels WITH the co-occurring numbers, by design.

    Two other commitments were live. That makes any delta on another metric
    unattributable, and the structure has to say so in the place the delta is read —
    not only in a sibling column somebody might not join.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=7), [4000.0] * 14)
        for _ in range(2):
            _seed.seed_challenge(
                cur, _seed.OWNER, status="active", adopted_at=_ADOPTED, metric="mvpa_min"
            )
        cid = _finish(cur, _seed.OWNER, baseline_value=4000.0)
        outcome = _outcome(cur, _seed.OWNER, cid)
    assert outcome["confounds"]["concurrent_challenges"] == 2
    assert outcome["co_occurring"]["concurrent_challenges"] == 2
    assert outcome["co_occurring"]["attribution"] == "none"


def test_a_challenge_that_did_not_overlap_is_not_counted(clean_db: None) -> None:  # noqa: ARG001
    """A commitment that ended before this one began confounds nothing."""
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=7), [4000.0] * 14)
        old = _seed.seed_challenge(
            cur, _seed.OWNER, status="completed", adopted_at=datetime(2026, 1, 1, tzinfo=UTC)
        )
        cur.execute(
            "UPDATE challenge SET completed_at = %s, ends_at = %s WHERE user_id = %s AND id = %s",
            (datetime(2026, 1, 8, tzinfo=UTC), datetime(2026, 1, 8, tzinfo=UTC), _seed.OWNER, old),
        )
        _finish(cur, _seed.OWNER, baseline_value=4000.0)
        outcome = _outcome(cur, _seed.OWNER)
    assert outcome["confounds"]["concurrent_challenges"] == 0


def test_a_baseline_that_was_itself_an_anomaly_is_flagged(clean_db: None) -> None:  # noqa: ARG001
    """People adopt a step challenge after a bad week — and then "improve" on their own.

    Ninety days at ~4000 with a flat-but-noisy history, and a frozen baseline of 1000:
    far below their own norm, so the metric would have climbed back with or without
    the challenge. Judged with the anomaly engine's own threshold.
    """
    history = [4000.0 + (i % 5) * 100 for i in range(90)]
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=90), history)
        _days(cur, _seed.OWNER, "steps_total", _START, [4000.0] * 7)
        _finish(cur, _seed.OWNER, baseline_value=1000.0)
        outcome = _outcome(cur, _seed.OWNER)
    regression = outcome["confounds"]["regression_to_mean"]
    assert regression["assessed"] is True
    assert regression["at_risk"] is True
    assert regression["baseline_z"] < -2.0


def test_a_typical_baseline_is_assessed_and_not_flagged(clean_db: None) -> None:  # noqa: ARG001
    """The flag has to be able to say "no" — otherwise it says nothing."""
    history = [4000.0 + (i % 5) * 100 for i in range(90)]
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=90), history)
        _days(cur, _seed.OWNER, "steps_total", _START, [4000.0] * 7)
        _finish(cur, _seed.OWNER, baseline_value=4200.0)
        outcome = _outcome(cur, _seed.OWNER)
    regression = outcome["confounds"]["regression_to_mean"]
    assert (regression["assessed"], regression["at_risk"]) == (True, False)


def test_too_little_history_reports_unassessed_rather_than_no_risk(
    clean_db: None,  # noqa: ARG001
) -> None:
    """An unassessed confound recorded as "no confound" reads as a check that passed.

    The ten pre-window days are deliberately NOISY. A flat history would also come
    back unassessed — for a different reason (MAD of 0, no spread to judge against) —
    and would pass this test with the day-count guard deleted. Mutation testing found
    exactly that, so the reason is now asserted too, not just the verdict.
    """
    history = [3000.0 + (i % 7) * 400 for i in range(10)]
    with tenant_transaction(_seed.OWNER) as cur:
        _days(cur, _seed.OWNER, "steps_total", _START - timedelta(days=10), history)
        _days(cur, _seed.OWNER, "steps_total", _START, [4000.0] * 7)
        _finish(cur, _seed.OWNER, baseline_value=4000.0)
        outcome = _outcome(cur, _seed.OWNER)
    regression = outcome["confounds"]["regression_to_mean"]
    assert regression["assessed"] is False
    assert regression["days"] == 10
    assert "10 days of history" in regression["reason"]
    assert "at_risk" not in regression, "an unanswered question must not carry an answer"
