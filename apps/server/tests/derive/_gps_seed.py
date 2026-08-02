"""One synthetic outdoor run, and the rows it becomes — shared GPS-track seeding.

Extracted from ``test_gps.py`` when a second file needed the same track
(``tests/integration/test_gps_track_scoring.py``, #111).

The route runs over OCEAN coordinates on purpose: the terrain DEM has no tile there, so
``derive.dem`` falls back to the caller's GPS elevation and these tests stay hermetic —
no network, and no result that depends on whether a tile happened to download.
"""

from __future__ import annotations

import math
from datetime import UTC, datetime
from uuid import UUID

from healthee.derive._common import Cur
from healthee.derive.vo2max_submax import _vo2_speed_grade

# (ts_epoch_s, lat, lng, ele_m) — one GPS fix, as the seeders pass it around.
TrackPoint = tuple[float, float, float, float]

OCEAN_LAT, OCEAN_LNG = 0.0, -30.0  # mid-Atlantic: no SRTM tile -> GPS-ele fallback
STAGES = ((3.0, 480), (3.4, 480), (3.8, 480))  # (speed m/s, seconds) progressive run

# The age the synthetic HR series is generated against. It only has to be PLAUSIBLE:
# the derivation recomputes HRmax from the seeded profile's real dob, so every assertion
# on this run is a range, never an exact VO2max.
_SYNTHETIC_AGE_Y = 30


def synthetic_run(start_epoch: float) -> tuple[list[TrackPoint], list[tuple[float, float]]]:
    """A noise-free progressive flat run: perfectly linear VO2<->HR (fit recovers ~50)."""
    hrmax = 208 - 0.7 * _SYNTHETIC_AGE_Y
    slope = (50.0 - 3.5) / (hrmax - 60)
    intercept = 3.5 - slope * 60
    points: list[TrackPoint] = []
    hr_rows: list[tuple[float, float]] = []
    t, lng = start_epoch, OCEAN_LNG
    for speed, dur in STAGES:
        hr = (_vo2_speed_grade(speed, 0.0) - intercept) / slope
        for _ in range(dur):
            lng += speed / (111_320 * math.cos(math.radians(OCEAN_LAT)))
            points.append((t, OCEAN_LAT, lng, 100.0))
            hr_rows.append((t, hr))
            t += 1.0
    return points, hr_rows


def insert_track(cur: Cur, user_id: UUID, points: list[TrackPoint]) -> str:
    """Store a track and its fixes directly — no scoring — and return the track id."""
    cur.execute(
        "INSERT INTO gps_track (user_id, start_ts, end_ts) VALUES (%s, %s, %s) RETURNING id",
        (
            user_id,
            datetime.fromtimestamp(points[0][0], UTC),
            datetime.fromtimestamp(points[-1][0], UTC),
        ),
    )
    row = cur.fetchone()
    assert row is not None
    track_id = str(row[0])
    cur.executemany(
        "INSERT INTO gps_point (user_id, track_id, ts, lat, lng, ele_m) "
        "VALUES (%s, %s, %s, %s, %s, %s)",
        [(user_id, track_id, datetime.fromtimestamp(p[0], UTC), p[1], p[2], p[3]) for p in points],
    )
    return track_id


def insert_hr(cur: Cur, user_id: UUID, hr_rows: list[tuple[float, float]]) -> None:
    """Store the strap HR samples covering a track's window."""
    cur.executemany(
        "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, 'hr', %s) "
        "ON CONFLICT (user_id, metric, ts) DO NOTHING",
        [(user_id, datetime.fromtimestamp(ts, UTC), hr) for ts, hr in hr_rows],
    )
