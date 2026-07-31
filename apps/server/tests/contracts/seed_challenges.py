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


def seed_challenges(cur, today: date, tz: tzinfo) -> None:
    """One suggestion, one live challenge, one completed one, and its frozen outcome.

    ``tz`` is passed in rather than imported from ``seed``: this module is imported BY
    that one, so reaching back for its constant is a real circular import (it failed
    on the first run). The owner's zone still has exactly one source — ``seed`` builds
    it from ``core.tenancy.SENTINEL_TZ`` and hands it down.
    """
    adopted_at = datetime.combine(today - timedelta(days=6), time(7, 0), tzinfo=tz)
    ends_at = datetime.combine(today + timedelta(days=1), time(0, 0), tzinfo=tz)
    _challenge(cur, "Walk a little further", "suggested", None, None)
    _challenge(cur, "Seven days above 9,000", "active", adopted_at, ends_at)
    _seed_outcome(cur, _finished(cur, today, tz))


def _challenge(cur, title: str, status: str, adopted_at, ends_at) -> int:
    """One ``challenge`` row in ``status``; returns its id.

    ``baseline_value`` is set even on the suggestion so the snapshot pins the field
    as a number rather than a null the shape checker would accept anything for.
    """
    cur.execute(
        "INSERT INTO challenge (user_id, title, why, category, metric, comparator, "
        "  target_value, cadence, window_days, expected_outcome, how_to, research_note_ids, "
        "  status, adopted_at, ends_at, baseline_value) "
        "VALUES (%s,%s,%s,'activity','steps_total','>=',9000,'daily',7,%s,%s,%s,%s,%s,%s,8200) "
        "RETURNING id",
        (
            SENTINEL_USER_ID,
            title,
            _WHY,
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
