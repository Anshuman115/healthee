"""The shared bed for the two windowed-challenge suites: one owner, one evening habit.

Not a pytest module (underscore-prefixed). The constants live here rather than in either
suite because both assert against the SAME hand-computed band, and a second copy of
[84, 95] is a second thing to update when the calibration rule changes.
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import UTC, date, datetime, timedelta

from tests.challenges import _gen, _seed

from healthee.challenges import levers
from healthee.challenges.gen_context import owner_calibrations
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ

IST = SENTINEL_TZ
TODAY: date = _gen.TODAY  # 2026-07-15
WINDOW = "caffeine_after_16"

# Seven days of a real evening habit: 90 mg before noon and 120 mg at 21:30 IST, so the
# window's own baseline is 120 mg/day and the daily total's is 210.
MORNING = 90.0
EVENING = 120.0
# `bounds.band_for` on a `good="down"` baseline of 120 with a rounding step of 25:
# near = max(12, 25) = 25, far = max(36, 25) = 36 => [120-36, 120-25] = [84, 95].
BAND_LOW, BAND_HIGH = 84.0, 95.0
IN_BAND = 90.0


def seed_evening_habit() -> None:
    """Seven days of morning + evening caffeine, in the OWNER's clock.

    06:30 IST = 01:00 UTC, 21:30 IST = 16:00 UTC — both on the same IST day, one either
    side of a 16:00 IST cutoff.
    """
    entries: list[tuple[datetime, float, str | None]] = []
    for i in range(1, 8):
        day = TODAY - timedelta(days=i)
        base = datetime(day.year, day.month, day.day, tzinfo=UTC)
        entries.append((base + timedelta(hours=1), MORNING, "mg"))
        entries.append((base + timedelta(hours=16), EVENING, "mg"))
    seed_caffeine(entries)


def seed_caffeine(entries: Sequence[tuple[datetime, float, str | None]]) -> None:
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(cur, _seed.OWNER, "caffeine", entries)


def analyse(active: set[str] | None = None) -> levers.LeverAnalysis:
    with tenant_transaction(_seed.OWNER) as cur:
        calibrations = owner_calibrations(cur, _seed.OWNER, IST, TODAY)
        return levers.analyse(cur, _seed.OWNER, IST, TODAY, calibrations, active or set())


def by_metric(analysis: levers.LeverAnalysis) -> dict[str, levers.Lever]:
    return {lever.metric: lever for lever in analysis.levers}
