"""Cross-tenant leakage proof across the real read surface (Phase 6.3c, §10).

The isolation guarantee this whole phase exists to establish, asserted where it
actually matters: the service functions the routers call. Two owners are seeded at
the SAME natural keys (`seed_all` for A, `seed_owner_b` for B), so only `user_id`
separates their rows — every surface is then called AS OWNER A and asserted to
return A's numbers and never B's.

Why two owners is the whole point: with one tenant an unscoped `SELECT` returns
exactly the right rows, so a single-tenant suite passes against a completely unscoped
read layer. B's values are impossible for A (22k steps, 88 rhr, 12 recovery), so a
leak surfaces as a physiologically absurd NUMBER, not a subtly wrong row count.

Coverage: today · sleep · activity · fitness · logs · gps · workout · history ·
findings · recovery · profile, plus the job/chain path (recs context + the per-owner
dedup marker).

NOT here — HTTP-level leakage (authenticate as A, request B's ids → 404/empty): the
routers still share one `require_token` and hardwire the sentinel, so there is no
second identity to authenticate as yet. That lands with the auth flip in 6.4
(MULTI_USER.md §11); until then the service layer IS the tenant boundary and is where
the guarantee can be proven.

Auto-skips without a reachable TimescaleDB (same policy as the other integration
tests).
"""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from tests.contracts import seed
from tests.contracts.seed_owner_b import (
    B_NAME,
    B_RECOVERY,
    B_RHR,
    B_STEPS,
    OWNER_B,
    OWNER_B_TZ,
    seed_owner_b,
)

from healthee.core.db import transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, active_users
from healthee.jobs.chain import _chain_done, _mark_chain_done
from healthee.jobs.recs_context import build_recs_signals
from healthee.read.activity import activity_snapshot
from healthee.read.findings import top_findings
from healthee.read.fitness import cardio_load_payload, mvpa_payload, vo2max_payload, workouts_list
from healthee.read.gps import list_gps_tracks
from healthee.read.history import history
from healthee.read.history import profile as read_profile
from healthee.read.logs import log_recent
from healthee.read.recovery import data_health_payload, recovery_score_payload
from healthee.read.sleep_page import sleep_page
from healthee.read.today import today_snapshot
from healthee.read.workout import workout_detail

pytestmark = pytest.mark.integration

_A_STEPS = 8200.0
_A_RECOVERY = 72.0


@pytest.fixture
def two_owners(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    """The canonical fixture (owner A = sentinel) plus owner B layered on top."""
    seed.seed_all()
    seed_owner_b()
    yield
    with transaction() as cur:
        cur.execute("DELETE FROM app_user WHERE id = %s", (OWNER_B,))  # cascades B's rows


def _dumped(payload: object) -> str:
    """A payload flattened to text, for 'B's marker must appear nowhere in it' checks."""
    return repr(payload)


# ── the read surface, called as owner A ───────────────────────────────────────


def test_today_snapshot_is_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """The busiest surface: /api/today fans out over most of the read layer.

    Both owners are rendered, and each must see their OWN steps. A "B's value is
    absent from A's payload" check alone is not enough for a latest-row read: with
    the owner filter gone it still returns A's row whenever A's happens to sort
    first, and the test passes while nothing is scoped (verified by mutation).
    """
    with transaction() as cur:
        a = today_snapshot(cur, SENTINEL_USER_ID, SENTINEL_TZ)
        b = today_snapshot(cur, OWNER_B, OWNER_B_TZ)
    assert B_NAME not in _dumped(a), "owner B's name leaked into A's today payload"
    assert str(B_STEPS) not in _dumped(a), "owner B's steps leaked into A's today payload"
    assert str(_A_STEPS) not in _dumped(b), "owner A's steps leaked into B's today payload"


def test_todays_recommendations_are_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """Recs are user-facing AI text — B's action must never render on A's screen."""
    with transaction() as cur:
        payload = today_snapshot(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert "OWNER B ACTION" not in _dumped(payload)


def test_profile_read_is_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """BOTH owners are read, and each must get their OWN row.

    Asserting only A's side is not enough: an unscoped `SELECT … FROM profile` has no
    ORDER BY, so it returns whichever row Postgres reaches first — which is A's, and
    the test would pass while the filter was gone (verified by mutation). Demanding
    that A and B each see themselves cannot be satisfied by any single row.
    """
    with transaction() as cur:
        a = read_profile(cur, SENTINEL_USER_ID)
        b = read_profile(cur, OWNER_B)
    assert a["name"] == "Test"
    assert a["height_cm"] == pytest.approx(176.0)
    assert b["name"] == B_NAME, "owner B was served owner A's profile"
    assert b["height_cm"] == pytest.approx(150.0)


def test_recovery_is_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """A pooled recovery read would show A a stranger's score as their own readiness.

    Both owners are read: `latest_derived` is an `ORDER BY day DESC LIMIT 1`, and A
    and B hold recovery_score on the SAME days, so an unscoped version returns one
    arbitrary row to everybody. Asserting only A's side passed against exactly that
    mutation; requiring each owner to see their own score cannot.
    """
    with transaction() as cur:
        a = recovery_score_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
        b = recovery_score_payload(cur, OWNER_B, OWNER_B_TZ)
    assert a is not None and b is not None
    assert a["recovery"] == pytest.approx(_A_RECOVERY), f"expected A's {_A_RECOVERY}"
    assert b["recovery"] == pytest.approx(B_RECOVERY), "owner B was served owner A's recovery"


def test_history_series_is_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """A merged series would silently double A's points and pull their trend to B."""
    with transaction() as cur:
        payload = history(cur, SENTINEL_USER_ID, "steps_total", days=90)
    values = {point["value"] for point in payload["series"]}
    assert values == {_A_STEPS}, f"owner B's steps leaked into A's history: {values}"


def test_activity_snapshot_is_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """Each owner's activity must carry their own steps, not one shared latest row."""
    with transaction() as cur:
        a = activity_snapshot(cur, SENTINEL_USER_ID, SENTINEL_TZ)
        b = activity_snapshot(cur, OWNER_B, OWNER_B_TZ)
    assert str(B_STEPS) not in _dumped(a), "owner B's steps leaked into A's activity"
    assert str(_A_STEPS) not in _dumped(b), "owner A's steps leaked into B's activity"


def test_sleep_page_is_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """B's session shares A's start_ts exactly — only the owner filter separates them."""
    with transaction() as cur:
        payload = sleep_page(cur, SENTINEL_USER_ID, SENTINEL_TZ, days=30)
    dumped = _dumped(payload)
    assert "'score': 9," not in dumped, "owner B's sleep session leaked into A's sleep page"
    assert str(B_RHR) not in dumped


def test_fitness_payloads_are_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """VO₂max / cardio-load / MVPA are all latest-row reads — check BOTH owners.

    A and B hold these metrics on the same days, so an unscoped latest-row read hands
    one arbitrary owner's number to everyone. Only asserting that each owner gets
    their own value can detect that.
    """
    with transaction() as cur:
        a_vo2 = vo2max_payload(cur, SENTINEL_USER_ID)
        a_cardio = cardio_load_payload(cur, SENTINEL_USER_ID)
        a_mvpa = mvpa_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
        b_vo2 = vo2max_payload(cur, OWNER_B)
        b_cardio = cardio_load_payload(cur, OWNER_B)
        b_mvpa = mvpa_payload(cur, OWNER_B, OWNER_B_TZ)
    assert a_vo2 is not None and a_vo2["estimate"] == pytest.approx(41.5)
    assert a_cardio is not None and a_cardio["load"] == pytest.approx(55.0)
    assert a_mvpa is not None and a_mvpa["today_min"] == 32
    assert b_vo2 is not None and b_vo2["estimate"] == pytest.approx(20.0), "B got A's VO2max"
    assert b_cardio is not None and b_cardio["load"] == pytest.approx(200.0), "B got A's load"
    assert b_mvpa is not None and b_mvpa["today_min"] == 99, "B got A's MVPA"


def test_workouts_list_is_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """B's workout sits at A's start_ts with absurd values — a leak doubles the list."""
    with transaction() as cur:
        workouts = workouts_list(cur, SENTINEL_USER_ID, limit=100)
    assert len(workouts) == 1, f"owner B's workout leaked into A's list: {workouts}"
    assert workouts[0]["calories"] == pytest.approx(250.0)


def test_workout_detail_is_owner_as(two_owners: None) -> None:  # noqa: ARG001
    with transaction() as cur:
        start = workouts_list(cur, SENTINEL_USER_ID, limit=1)[0]["start_iso"]
        detail = workout_detail(cur, SENTINEL_USER_ID, SENTINEL_TZ, start)
    # B's workout sits within the detail lookup's ±3s window of A's start_ts, so only
    # the owner filter keeps A's session from being served to A's request.
    assert detail["workout"]["calories"] == pytest.approx(250.0), "owner B's workout served to A"
    assert detail["workout"]["avg_hr"] == 135, "owner B's HR served as A's workout"


def test_logs_are_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """B logged 999 mg of caffeine; A's log summary must not inherit it."""
    with transaction() as cur:
        payload = log_recent(cur, SENTINEL_USER_ID, days=7)
    assert "999" not in _dumped(payload), "owner B's manual entry leaked into A's logs"


def test_gps_tracks_are_owner_as(two_owners: None) -> None:  # noqa: ARG001
    with transaction() as cur:
        payload = list_gps_tracks(cur, SENTINEL_USER_ID, limit=30)
    assert len(payload["tracks"]) == 1, "owner B's GPS track leaked into A's list"
    assert payload["tracks"][0]["distance_km"] == pytest.approx(4.2)  # not B's 99999 m


def test_findings_are_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """Findings are personal statistics — B's would be a claim about A's body."""
    payload = top_findings(SENTINEL_USER_ID, limit=5)
    assert "OWNER B FINDING" not in _dumped(payload)


def test_data_health_is_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """Feed freshness is per-owner: B's sample must not make A's dead feed look alive."""
    with transaction() as cur:
        cur.execute("DELETE FROM sample WHERE user_id = %s AND metric = 'hr'", (SENTINEL_USER_ID,))
        payload = data_health_payload(cur, SENTINEL_USER_ID)
    hr = next(item for item in payload["items"] if item["metric"] == "hr")
    assert hr["last_iso"] is None, "owner B's hr sample leaked into owner A's data-health"


# ── the job / chain path ──────────────────────────────────────────────────────


def test_recs_context_is_owner_as(two_owners: None) -> None:  # noqa: ARG001
    """The LLM prompt is the highest-stakes leak: B's numbers would become A's advice."""
    signals = build_recs_signals(SENTINEL_USER_ID, SENTINEL_TZ)
    assert B_NAME not in signals
    assert str(B_STEPS) not in signals, "owner B's steps reached owner A's LLM context"


def test_chain_dedup_marker_is_per_owner(two_owners: None) -> None:  # noqa: ARG001
    """A's completed chain must not mark B's as done — B would silently lose their day."""
    from datetime import date

    day = date(2999, 3, 3)
    _mark_chain_done(SENTINEL_USER_ID, day)
    try:
        assert _chain_done(SENTINEL_USER_ID, day) is True
        assert _chain_done(OWNER_B, day) is False, "A's chain marker deduped B's chain away"
    finally:
        with transaction() as cur:
            cur.execute("DELETE FROM kv WHERE key = %s", (f"job:chain_done:{day.isoformat()}",))


def test_active_users_sees_both_owners(two_owners: None) -> None:  # noqa: ARG001
    """The sweep must actually discover B — otherwise B never gets a nightly chain."""
    tenants = {t.id: t.tz for t in active_users()}
    assert SENTINEL_USER_ID in tenants
    assert tenants.get(OWNER_B) == "America/Chicago", "B's own timezone must drive their day"
