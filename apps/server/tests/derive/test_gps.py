"""GPS-track derivation tests: the HR interpolator (pure) + the plumbing (seeded DB).

The submaximal VO2max SCIENCE is parity-checked exactly in ``test_pure.py`` (against
the legacy self-test track). Here we cover the DB wiring in ``gps.py``: the shared
HR interpolator's edge/gap behaviour (pure), and an end-to-end run of
``derive_vo2max_submax`` + ``gps_track_detail`` over a seeded synthetic run.

The track sits over ocean coordinates so the terrain DEM has no tile and the code
falls back to GPS elevation — keeping the integration test hermetic (no network
dependency on the result). It asserts a coherent, plausible fit rather than an exact
number, since DEM availability is environmental.
"""

from __future__ import annotations

import math
from datetime import UTC, datetime

import pytest

from healthee.core.db import transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.derive.gps import derive_vo2max_submax, gps_track_detail, make_hr_interpolator
from healthee.derive.vo2max_submax import VO2MAX_HI, VO2MAX_LO, _vo2_speed_grade

# ── make_hr_interpolator — pure edge/gap logic ───────────────────────────────


def test_hr_interpolator_linear_midpoint() -> None:
    hr_at = make_hr_interpolator([100.0, 160.0], [50.0, 80.0])
    assert hr_at(130.0) == pytest.approx(65.0)  # halfway -> mean


def test_hr_interpolator_edge_tolerance() -> None:
    hr_at = make_hr_interpolator([100.0, 160.0], [50.0, 80.0])
    assert hr_at(90.0) == 50.0  # 10 s before first, within 120 s edge -> clamp
    assert hr_at(250.0) == 80.0  # 90 s after last, within edge -> clamp
    assert hr_at(-100.0) is None  # 200 s before first -> beyond edge
    assert hr_at(400.0) is None  # 240 s after last -> beyond edge


def test_hr_interpolator_gap_and_empty() -> None:
    assert make_hr_interpolator([], [])(123.0) is None  # no samples
    gapped = make_hr_interpolator([100.0, 400.0], [50.0, 80.0])  # 300 s gap > 180
    assert gapped(200.0) is None


# ── derive_vo2max_submax + gps_track_detail — seeded plumbing ────────────────

_START_EPOCH = 1_700_000_000.0
_OCEAN_LAT, _OCEAN_LNG = 0.0, -30.0  # mid-Atlantic: no SRTM tile -> GPS-ele fallback
_STAGES = ((3.0, 480), (3.4, 480), (3.8, 480))  # (speed m/s, seconds) progressive run


def _synthetic_run() -> tuple[list[tuple[float, float, float, float]], list[tuple[float, float]]]:
    """A noise-free progressive flat run: perfectly linear VO2<->HR (fit recovers ~50)."""
    hrmax = 208 - 0.7 * 30
    slope = (50.0 - 3.5) / (hrmax - 60)
    intercept = 3.5 - slope * 60
    points: list[tuple[float, float, float, float]] = []
    hr_rows: list[tuple[float, float]] = []
    t, lng = _START_EPOCH, _OCEAN_LNG
    for speed, dur in _STAGES:
        hr = (_vo2_speed_grade(speed, 0.0) - intercept) / slope
        for _ in range(dur):
            lng += speed / (111_320 * math.cos(math.radians(_OCEAN_LAT)))
            points.append((t, _OCEAN_LAT, lng, 100.0))
            hr_rows.append((t, hr))
            t += 1.0
    return points, hr_rows


def _seed_track(cur) -> str:
    cur.execute("DELETE FROM gps_point")
    cur.execute("DELETE FROM gps_track")
    cur.execute("DELETE FROM derived_daily")
    cur.execute("DELETE FROM sample")
    cur.execute("DELETE FROM weight_log")
    cur.execute("DELETE FROM profile")
    cur.execute("INSERT INTO profile (height_cm, sex, dob) VALUES (175, 'male', '1990-01-01')")
    cur.execute("INSERT INTO weight_log (ts, kg) VALUES ('2026-01-01T00:00:00+00', 72)")
    points, hr_rows = _synthetic_run()
    start = datetime.fromtimestamp(points[0][0], UTC)
    end = datetime.fromtimestamp(points[-1][0], UTC)
    cur.execute(
        "INSERT INTO gps_track (start_ts, end_ts) VALUES (%s, %s) RETURNING id", (start, end)
    )
    row = cur.fetchone()
    assert row is not None
    track_id = str(row[0])
    cur.executemany(
        "INSERT INTO gps_point (track_id, ts, lat, lng, ele_m) VALUES (%s, %s, %s, %s, %s)",
        [(track_id, datetime.fromtimestamp(p[0], UTC), p[1], p[2], p[3]) for p in points],
    )
    cur.executemany(
        "INSERT INTO sample (ts, metric, value) VALUES (%s, 'hr', %s) "
        "ON CONFLICT (user_id, metric, ts) DO NOTHING",
        [(datetime.fromtimestamp(ts, UTC), hr) for ts, hr in hr_rows],
    )
    return track_id


@pytest.mark.integration
def test_derive_vo2max_submax_end_to_end(db: None) -> None:  # noqa: ARG001 — DB gate
    migrate.apply_migrations()
    with transaction() as cur:
        track_id = _seed_track(cur)
        result = derive_vo2max_submax(cur, SENTINEL_USER_ID, SENTINEL_TZ, track_id)
    assert result["ok"] is True, result
    assert VO2MAX_LO <= result["vo2max_submax"] <= VO2MAX_HI
    assert result["r2"] >= 0.5
    assert result["grade_source"] in ("dem", "gps_elevation")


@pytest.mark.integration
def test_gps_track_detail_summary(db: None) -> None:  # noqa: ARG001 — DB gate
    migrate.apply_migrations()
    with transaction() as cur:
        track_id = _seed_track(cur)
        detail = gps_track_detail(cur, SENTINEL_USER_ID, track_id)
    assert detail is not None
    summary = detail["summary"]
    assert summary["n_points"] == len(detail["points"]) > 100
    assert summary["distance_km"] > 1.0
    assert summary["avg_hr"] is not None and summary["max_hr"] is not None
    assert summary["duration_s"] == pytest.approx(sum(d for _, d in _STAGES) - 1, abs=1)
