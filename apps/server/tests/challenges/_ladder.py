"""Shared bed for the WP-C4 program suites: one owner, one ladder, one pinned day.

Every rung here is a ``steps_total`` daily rule, so the whole ladder is scored by the
same reader the rest of the suite already trusts and every assertion is arithmetic
against a number the test can state.

Dates are FIXED and every function takes an explicit ``today`` — a suite anchored to the
wall clock cannot fail the way a timezone bug actually fails (``_seed``'s rule).

Not a pytest module (underscore-prefixed); imported by the test modules.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from uuid import UUID

from tests.challenges import _seed

from healthee.core.tenancy import SENTINEL_TZ

IST = SENTINEL_TZ
TODAY = date(2026, 7, 15)

# The rung window every ladder here uses. Short on purpose: a rung is settled by
# `elapsed > window_days`, and the tests move `today` rather than the clock.
RUNG_DAYS = 7

# The owner's standing baseline for the bed's default history — seven days at 5,000
# steps before `TODAY`, so `bounds.calibrate` gives the band [6000, 6500]
# (`5000 + max(500, 1000 floor, 250 step)` … `5000 + max(1500, 1000)`) exactly as
# `_gen` documents for the generation suites.
BASELINE_STEPS = 5000.0
BAND_LOW, BAND_HIGH = 6000.0, 6500.0


def seed_steps(cur, per_day: float, days: int, ending: date, owner: UUID = _seed.OWNER) -> None:
    """``days`` consecutive daily step rows at ``per_day``, the last of them on ``ending``."""
    _seed.seed_metric(
        cur,
        owner,
        "steps_total",
        {ending - timedelta(days=i): per_day for i in range(days)},
    )


def seed_program(cur, owner: UUID = _seed.OWNER, **overrides) -> int:
    """One ``suggested`` program owned by ``owner``; returns its id."""
    row = {
        "title": "Walk your way up",
        "why": "Stepping up gradually is what the evidence supports [steps_mortality].",
        "goal": "8,000 steps a day",
        "goal_metric": "steps_total",
        "category": "activity",
        "weeks": 4,
    } | overrides
    cur.execute(
        "INSERT INTO program (user_id, title, why, goal, goal_metric, category, weeks, status) "
        "VALUES (%s,%s,%s,%s,%s,%s,%s,'suggested') RETURNING id",
        (
            owner,
            row["title"],
            row["why"],
            row["goal"],
            row["goal_metric"],
            row["category"],
            row["weeks"],
        ),
    )
    found = cur.fetchone()
    assert found is not None, "INSERT ... RETURNING id gave no row"
    return int(found[0])


def seed_rung(  # noqa: PLR0913 — a fixture row states every column it pins
    cur,
    program_id: int,
    rung_index: int,
    target: float,
    *,
    owner: UUID = _seed.OWNER,
    metric: str = "steps_total",
    cadence: str = "daily",
    comparator: str = ">=",
    status: str = "locked",
    kind: str = "standard",
    window_days: int = RUNG_DAYS,
    adopted_at: datetime | None = None,
    baseline_value: float | None = None,
) -> int:
    """One ``locked`` rung of ``program_id``; returns its id.

    The copy is fixed and cites a real note, because a rung's ``why`` is what a deload
    rung REUSES — a fixture with placeholder prose would hide the fact that the deload
    path authors nothing (``program_store.insert_rung``).
    """
    cur.execute(
        "INSERT INTO challenge (user_id, title, why, category, difficulty, metric, "
        "  comparator, target_value, cadence, window_days, expected_outcome, how_to, "
        "  research_note_ids, status, program_id, rung_index, kind, adopted_at, "
        "  baseline_value) "
        "VALUES (%s,%s,%s,'activity','standard',%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) "
        "RETURNING id",
        (
            owner,
            f"Rung {rung_index}",
            "More daily movement lowers all-cause mortality risk [steps_mortality].",
            metric,
            comparator,
            target,
            cadence,
            window_days,
            "Steadier days, compounding [steps_mortality].",
            "Walk after lunch and after dinner.",
            ["steps_mortality"],
            status,
            program_id,
            rung_index,
            kind,
            adopted_at,
            baseline_value,
        ),
    )
    found = cur.fetchone()
    assert found is not None, "INSERT ... RETURNING id gave no row"
    return int(found[0])


def seed_ladder(cur, targets: list[float], owner: UUID = _seed.OWNER) -> tuple[int, list[int]]:
    """A suggested program with one locked rung per target, indexed from zero."""
    program_id = seed_program(cur, owner=owner)
    rungs = [
        seed_rung(cur, program_id, index, target, owner=owner)
        for index, target in enumerate(targets)
    ]
    return program_id, rungs


def adopted_at(day: date) -> datetime:
    """06:00 UTC on ``day`` — 11:30 IST, so the local date is unambiguously ``day``."""
    return datetime(day.year, day.month, day.day, 6, 0, tzinfo=UTC)


def rung_row(cur, rung_id: int, owner: UUID = _seed.OWNER) -> dict:
    """One rung as stored, asserted present — a missing row is a broken test setup."""
    return _seed.stored(cur, owner, rung_id)


def program_row(cur, program_id: int, owner: UUID = _seed.OWNER) -> dict:
    """One program as stored, asserted present."""
    from healthee.challenges import program_store

    program = program_store.fetch(cur, owner, program_id)
    assert program is not None, f"program {program_id} is not visible to {owner}"
    return program
