"""The ONE HR-validity definition — its boundary, and that every site agrees on it.

Two things are pinned here:

  * the boundary itself (29 / 30 / 220 / 221), for both the Python predicate and
    the SQL one — a deliberate behaviour change, so it gets known-value tests;
  * that the daily and per-session HR readers return the SAME verdict on the SAME
    sample. That is the defect this module exists to kill: ``read/workout`` and
    ``read/today_series`` filtered ``value > 30 AND value < 220`` while
    ``derive/rhr``, ``derive/gps`` and ``derive/cardio_load`` filtered
    ``value BETWEEN 30 AND 220``, so a sample at exactly 30 or 220 bpm counted
    toward the day's cardio_load and vanished from the workout HR profile — two
    screens quoting the same TRIMP currency, disagreeing about the same minute.
"""

from __future__ import annotations

from datetime import UTC, datetime

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.derive.hr_validity import (
    HR_VALID_BOUNDS,
    HR_VALID_MAX_BPM,
    HR_VALID_MIN_BPM,
    HR_VALID_SQL,
    hr_is_valid,
)
from healthee.read.workout import _hr_profile

# The boundary table both the Python and the SQL predicate are held to. Inclusive:
# 30 and 220 are attainable human values (an endurance athlete's true RHR; the
# ceiling of the classic 220-age HRmax formula), not artefacts.
_BOUNDARY: list[tuple[float, bool]] = [
    (29.0, False),  # below the floor -> artefact
    (29.9, False),
    (30.0, True),  # exactly the floor -> VALID (was excluded by workout/today_series)
    (30.1, True),
    (220.0, True),  # exactly the ceiling -> VALID (was excluded by workout/today_series)
    (219.9, True),
    (220.1, False),
    (221.0, False),  # above the ceiling -> artefact
]


# ── the predicate itself (pure, known-value) ────────────────────────────────


def test_bounds_are_the_documented_values() -> None:
    assert (HR_VALID_MIN_BPM, HR_VALID_MAX_BPM) == (30, 220)
    assert HR_VALID_BOUNDS == (HR_VALID_MIN_BPM, HR_VALID_MAX_BPM)


@pytest.mark.parametrize(("bpm", "valid"), _BOUNDARY)
def test_hr_is_valid_boundary(bpm: float, valid: bool) -> None:
    assert hr_is_valid(bpm) is valid


# ── the SQL predicate agrees with the Python one, value for value ───────────


@pytest.mark.integration
@pytest.mark.parametrize(("bpm", "valid"), _BOUNDARY)
def test_sql_predicate_matches_python_predicate(db: None, bpm: float, valid: bool) -> None:  # noqa: ARG001
    """The DB's verdict on a value must equal ``hr_is_valid``'s — one definition, two engines."""
    migrate.apply_migrations()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        # The predicate verbatim, over a one-row scan standing in for `sample`. The
        # bound params follow the placeholders' TEXTUAL order: the predicate's two
        # bounds appear before the sub-select's value.
        cur.execute(
            f"SELECT {HR_VALID_SQL} FROM (SELECT %s::float AS value) s",
            (*HR_VALID_BOUNDS, bpm),
        )
        row = cur.fetchone()
    assert row is not None
    assert row[0] is hr_is_valid(bpm) is valid


# ── the sites agree: the defect reproducer ─────────────────────────────────

_WINDOW_START = datetime(2026, 5, 4, 6, 0, tzinfo=UTC)


def _seed_hr(cur, values: list[float]) -> None:
    """One HR sample per minute from ``_WINDOW_START``, in order."""
    cur.execute("DELETE FROM sample WHERE user_id = %s AND metric = 'hr'", (SENTINEL_USER_ID,))
    for i, v in enumerate(values):
        cur.execute(
            "INSERT INTO sample (user_id, metric, ts, value) "
            "VALUES (%s, 'hr', %s, %s) ON CONFLICT DO NOTHING",
            (SENTINEL_USER_ID, _WINDOW_START.replace(minute=i), v),
        )


def _daily_hr_values(cur) -> list[float]:
    """The HR values the DAILY readers (rhr / gps / cardio_load) accept over the window."""
    cur.execute(
        f"SELECT value FROM sample WHERE user_id = %s AND metric='hr' AND {HR_VALID_SQL} "
        "AND ts >= %s AND ts <= %s ORDER BY ts",
        (SENTINEL_USER_ID, *HR_VALID_BOUNDS, _WINDOW_START, _WINDOW_START.replace(minute=59)),
    )
    return [float(r[0]) for r in cur.fetchall()]


@pytest.mark.integration
def test_workout_and_daily_readers_agree_on_the_boundary(db: None) -> None:  # noqa: ARG001
    """The same boundary sample must be valid for BOTH the session and the day.

    Pre-fix this failed: ``_hr_profile`` dropped the 30 and the 220 that the daily
    HR window kept, so the session TRIMP and the day's cardio_load disagreed about
    the very same minute.
    """
    migrate.apply_migrations()
    seeded = [30.0, 100.0, 220.0, 29.0, 221.0]
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed_hr(cur, seeded)
        session_hrs, _series = _hr_profile(
            cur,
            SENTINEL_USER_ID,
            SENTINEL_TZ,
            _WINDOW_START,
            _WINDOW_START.replace(minute=59),
        )
        daily_hrs = _daily_hr_values(cur)

    expected = [v for v in seeded if hr_is_valid(v)]
    assert sorted(daily_hrs) == sorted(expected)  # the daily side was already inclusive
    assert sorted(float(h) for h in session_hrs) == sorted(expected)  # the side that changed
    assert sorted(float(h) for h in session_hrs) == sorted(daily_hrs)  # ...and they agree
