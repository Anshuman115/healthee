"""The challenges half of the contract fixture (WP-C2).

Its own module for the same reason ``seed_owner_b`` is: ``seed.py`` is already at the
file gate, and this is one coherent slice — the three lifecycle states plus a frozen
outcome. Every row belongs to the sentinel owner, like the rest of the fixture.

Why all three states and a fully-populated outcome: the contract bed pins the SHAPE
the mobile client will parse, and empty lists or null JSONB pin nothing. The
``confounds`` / ``co_occurring`` / ``data_confidence`` fields ARE the contract here
(CHALLENGES.md §7 decision 1) — the app must never be able to render a co-occurring
delta without the concurrency count beside it, and a snapshot generated from nulls
would let exactly that ship.
"""

from __future__ import annotations

import json
from datetime import date, datetime, time, timedelta, tzinfo

from healthee.core.tenancy import SENTINEL_USER_ID

# Fixed copy, so the snapshot text is stable run to run. The "why" is deliberately
# written the way the honesty contract requires a real one to be — grounded in the
# owner's own baseline, not a population ideal (CHALLENGES.md §1).
_WHY = "Your own recent week averages 8,200 steps, so this is a small step up."
_HOW_TO = "Walk after dinner."
_EXPECTED = "About a tenth above your recent week."
_NOTE_IDS = ["steps_mortality"]

# The SUGGESTION is on a different metric from the live challenge, because a state where
# both sit on `steps_total` is one the engine cannot produce and (since #72) will not
# adopt: generation dedupes against the owner's active metrics, and `lifecycle.adopt`
# refuses a second commitment on the same behaviour. The bed used to encode that
# impossible state, so adopting from it exercised a path no real owner has.
_SUGGESTED_METRIC = "active_calories"
_SUGGESTED_TARGET = 700.0
_SUGGESTED_WHY = "Your own recent week averages 620 active calories, so this is a small step up."


def seed_challenges(cur, today: date, tz: tzinfo) -> None:
    """One suggestion, one live challenge, one completed one, and its frozen outcome.

    ``tz`` is passed in rather than imported from ``seed``: this module is imported BY
    that one, so reaching back for its constant is a real circular import (it failed
    on the first run). The owner's zone still has exactly one source — ``seed`` builds
    it from ``core.tenancy.SENTINEL_TZ`` and hands it down.
    """
    adopted_at = datetime.combine(today - timedelta(days=6), time(7, 0), tzinfo=tz)
    ends_at = datetime.combine(today + timedelta(days=1), time(0, 0), tzinfo=tz)
    _challenge(
        cur,
        "Move a little more",
        "suggested",
        None,
        None,
        metric=_SUGGESTED_METRIC,
        target=_SUGGESTED_TARGET,
        why=_SUGGESTED_WHY,
    )
    _challenge(cur, "Seven days above 9,000", "active", adopted_at, ends_at)
    _seed_outcome(cur, _finished(cur, today, tz))


def _challenge(  # noqa: PLR0913 — a fixture row states every column it pins
    cur,
    title: str,
    status: str,
    adopted_at,
    ends_at,
    *,
    metric: str = "steps_total",
    target: float = 9000.0,
    why: str = _WHY,
) -> int:
    """One ``challenge`` row in ``status``; returns its id.

    ``baseline_value`` is set even on the suggestion so the snapshot pins the field
    as a number rather than a null the shape checker would accept anything for. It is
    the STORED value on a seeded row; a real adopt recomputes it from the owner's own
    series, which is what ``test_challenge_endpoints`` asserts against.
    """
    cur.execute(
        "INSERT INTO challenge (user_id, title, why, category, metric, comparator, "
        "  target_value, cadence, window_days, expected_outcome, how_to, research_note_ids, "
        "  status, adopted_at, ends_at, baseline_value) "
        "VALUES (%s,%s,%s,'activity',%s,'>=',%s,'daily',7,%s,%s,%s,%s,%s,%s,8200) "
        "RETURNING id",
        (
            SENTINEL_USER_ID,
            title,
            why,
            metric,
            target,
            _EXPECTED,
            _HOW_TO,
            _NOTE_IDS,
            status,
            adopted_at,
            ends_at,
        ),
    )
    row = cur.fetchone()
    assert row is not None, "INSERT ... RETURNING id gave no row"
    return int(row[0])


def _finished(cur, today: date, tz: tzinfo) -> int:
    """A completed challenge from last month — the one the ledger row belongs to."""
    adopted_at = datetime.combine(today - timedelta(days=30), time(7, 0), tzinfo=tz)
    completed_at = datetime.combine(today - timedelta(days=23), time(7, 0), tzinfo=tz)
    challenge_id = _challenge(cur, "Last month's walk", "completed", adopted_at, completed_at)
    cur.execute(
        "UPDATE challenge SET completed_at = %s WHERE user_id = %s AND id = %s",
        (completed_at, SENTINEL_USER_ID, challenge_id),
    )
    return challenge_id


_CONFOUNDS = {
    "illness_days": 1,
    "concurrent_challenges": 1,
    "regression_to_mean": {
        "assessed": True,
        "baseline_z": -0.4,
        "long_run_median": 8300.0,
        "days": 90,
        "at_risk": False,
    },
}

_CO_OCCURRING = {
    "attribution": "none",
    "note": "moved during the same window; not attributed to this challenge",
    "concurrent_challenges": 1,
    "metrics": {
        "hrv_sleep_avg": {"before": 45.0, "after": 46.5, "delta_pct": 3.3},
        "rhr_daily": {"before": 55.0, "after": 54.0, "delta_pct": -1.8},
    },
}


def _seed_outcome(cur, challenge_id: int) -> None:
    """A frozen outcome carrying every honesty field the client has to render."""
    cur.execute(
        "INSERT INTO challenge_outcome (user_id, challenge_id, metric, category, difficulty, "
        "  cadence, target, baseline, final, improvement_pct, improved, adherence, days_active, "
        "  status, confounds, co_occurring, data_confidence) "
        "VALUES (%s,%s,'steps_total','activity','standard','daily',9000,8200,8900,8.5,true,"
        "  0.857,7,'met',%s,%s,'ok') ON CONFLICT (challenge_id) DO NOTHING",
        (SENTINEL_USER_ID, challenge_id, json.dumps(_CONFOUNDS), json.dumps(_CO_OCCURRING)),
    )


# ── the WP-C4 ladder ─────────────────────────────────────────────────────────
#
# One ACTIVE program, mid-climb, in the state the app has to be able to render: a first
# rung that was met, a second that timed out UNMET, the deload the ladder inserted in
# answer, and a locked rung still above them. That sequence IS the contract — a snapshot
# generated from a ladder with only a live rung would pin none of the honesty this WP
# exists for (a `kind: "deload"` row, an `unmet_timed_out` outcome, and a rung the owner
# has not reached carrying `progress: null` AND `outcome: null`).

_PROGRAM_WHY = "Stepping up a little at a time is what the evidence supports [steps_mortality]."
_RUNG_WHY = "More daily movement lowers all-cause mortality risk [steps_mortality]."


def seed_program(cur, today: date, tz: tzinfo) -> None:
    """One live ladder: met → unmet_timed_out → deload (running) → locked."""
    cur.execute(
        "INSERT INTO program (user_id, title, why, goal, goal_metric, category, weeks, "
        "  status, adopted_at) "
        "VALUES (%s,'Walk your way up',%s,'8,000 steps a day','steps_total','activity',4,"
        "  'active',%s) RETURNING id",
        (
            SENTINEL_USER_ID,
            _PROGRAM_WHY,
            datetime.combine(today - timedelta(days=21), time(7, 0), tzinfo=tz),
        ),
    )
    row = cur.fetchone()
    assert row is not None, "INSERT ... RETURNING id gave no row"
    program_id = int(row[0])
    met = _rung(cur, program_id, 0, 8600.0, "completed", today - timedelta(days=21), tz)
    unmet = _rung(cur, program_id, 1, 9200.0, "expired", today - timedelta(days=14), tz)
    _rung(cur, program_id, 2, 8900.0, "active", today - timedelta(days=6), tz, kind="deload")
    _rung(cur, program_id, 3, 9600.0, "locked", None, tz)
    _rung_outcome(cur, met, 8600.0, "met", 9.5)
    _rung_outcome(cur, unmet, 9200.0, "unmet_timed_out", -1.2)


def _rung(  # noqa: PLR0913 — a fixture row states every column it pins
    cur,
    program_id: int,
    rung_index: int,
    target: float,
    status: str,
    started: date | None,
    tz: tzinfo,
    kind: str = "standard",
) -> int:
    """One rung row; returns its id. ``started`` is None for a rung nobody has reached."""
    adopted_at = None if started is None else datetime.combine(started, time(7, 0), tzinfo=tz)
    ends_at = None if adopted_at is None else adopted_at + timedelta(days=7)
    cur.execute(
        "INSERT INTO challenge (user_id, title, why, category, difficulty, metric, comparator, "
        "  target_value, cadence, window_days, expected_outcome, how_to, research_note_ids, "
        "  status, adopted_at, ends_at, baseline_value, program_id, rung_index, kind) "
        "VALUES (%s,%s,%s,'activity','standard','steps_total','>=',%s,'daily',7,%s,%s,%s,%s,"
        "  %s,%s,8200,%s,%s,%s) RETURNING id",
        (
            SENTINEL_USER_ID,
            f"Rung {rung_index + 1}",
            _RUNG_WHY,
            target,
            _EXPECTED,
            _HOW_TO,
            _NOTE_IDS,
            status,
            adopted_at,
            ends_at,
            program_id,
            rung_index,
            kind,
        ),
    )
    row = cur.fetchone()
    assert row is not None, "INSERT ... RETURNING id gave no row"
    return int(row[0])


def _rung_outcome(cur, challenge_id: int, target: float, status: str, improvement: float) -> None:
    """A settled rung's frozen outcome — the row that makes the ladder tell its story."""
    cur.execute(
        "INSERT INTO challenge_outcome (user_id, challenge_id, metric, category, difficulty, "
        "  cadence, target, baseline, final, improvement_pct, improved, adherence, days_active, "
        "  status, confounds, co_occurring, data_confidence) "
        "VALUES (%s,%s,'steps_total','activity','standard','daily',%s,8200,8600,%s,%s,0.714,7,"
        "  %s,%s,%s,'ok') ON CONFLICT (challenge_id) DO NOTHING",
        (
            SENTINEL_USER_ID,
            challenge_id,
            target,
            improvement,
            improvement > 0,
            status,
            json.dumps(_CONFOUNDS),
            json.dumps(_CO_OCCURRING),
        ),
    )
