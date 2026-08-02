"""GPS-track derivation tests: the HR interpolator (pure) + the plumbing (seeded DB).

The submaximal VO2max SCIENCE is parity-checked exactly in ``test_pure.py`` (against
the legacy self-test track). Here we cover the DB wiring in ``gps.py``: the shared
HR interpolator's edge/gap behaviour (pure), and an end-to-end run of
``derive_vo2max_submax`` (derive/gps.py) + ``gps_track_detail`` (derive/gps_detail.py)
over a seeded synthetic run.

The track sits over ocean coordinates so the terrain DEM has no tile and the code
falls back to GPS elevation — keeping the integration test hermetic (no network
dependency on the result). It asserts a coherent, plausible fit rather than an exact
number, since DEM availability is environmental.
"""

from __future__ import annotations

import math
from datetime import UTC, datetime, timedelta

import pytest
from tests.derive._gps_seed import (
    OCEAN_LAT,
    OCEAN_LNG,
    STAGES,
    insert_hr,
    insert_track,
    synthetic_run,
)

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.derive.gps import (
    METHOD_GRADED,
    METHOD_RESERVE,
    derive_vo2max_submax,
    make_hr_interpolator,
)
from healthee.derive.gps_detail import gps_track_detail
from healthee.derive.vo2max_reserve import WITHHOLD_WALKING_ONLY
from healthee.derive.vo2max_submax import VO2MAX_HI, VO2MAX_LO

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


def _seed_track(cur) -> str:
    cur.execute("DELETE FROM gps_point")
    cur.execute("DELETE FROM gps_track")
    cur.execute("DELETE FROM derived_daily")
    cur.execute("DELETE FROM sample")
    cur.execute("DELETE FROM weight_log")
    cur.execute("DELETE FROM profile")
    cur.execute(
        "INSERT INTO profile (user_id, height_cm, sex, dob, srpa) "
        "VALUES (%s, 175, 'male', '1990-01-01', 0)",
        (SENTINEL_USER_ID,),
    )
    cur.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, now() - interval '1 day', 72)",
        (SENTINEL_USER_ID,),
    )
    points, hr_rows = synthetic_run(_START_EPOCH)
    track_id = insert_track(cur, SENTINEL_USER_ID, points)
    insert_hr(cur, SENTINEL_USER_ID, hr_rows)
    return track_id


@pytest.mark.integration
def test_derive_vo2max_submax_end_to_end(db: None) -> None:  # noqa: ARG001 — DB gate
    migrate.apply_migrations()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        track_id = _seed_track(cur)
        result = derive_vo2max_submax(cur, SENTINEL_USER_ID, SENTINEL_TZ, track_id)
    assert result["ok"] is True, result
    assert VO2MAX_LO <= result["vo2max_submax"] <= VO2MAX_HI
    assert result["r2"] >= 0.5
    assert result["grade_source"] in ("dem", "gps_elevation")
    assert result["method"] == METHOD_GRADED  # the graded fit wins whenever it fires


# ── The reserve fallback and its precedence (#114) ───────────────────────────


def _flat_run(hr_lo: float, hr_hi: float, speed_ms: float, dur_s: int) -> tuple[list, list]:
    """A CONSTANT-speed effort with drifting HR.

    The workload axis never moves, so the graded fit cannot find a slope — the exact
    shape that made 7 of the owner's 8 real tracks unusable. HR drifts so the session
    still clears ``MIN_HR_RANGE`` and the failure is the SLOPE, not the range.
    """
    points: list[tuple[float, float, float, float]] = []
    hr_rows: list[tuple[float, float]] = []
    t, lng = _START_EPOCH, OCEAN_LNG
    for i in range(dur_s):
        lng += speed_ms / (111_320 * math.cos(math.radians(OCEAN_LAT)))
        points.append((t, OCEAN_LAT, lng, 100.0))
        hr_rows.append((t, hr_lo + (hr_hi - hr_lo) * i / dur_s))
        t += 1.0
    return points, hr_rows


def _seed_flat(cur, hr_lo: float, hr_hi: float, speed_ms: float, rhr: float) -> str:
    """Seed a constant-speed track plus the resting-HR week the reserve method needs."""
    track_id = _seed_track(cur)
    cur.execute("DELETE FROM gps_point WHERE user_id = %s", (SENTINEL_USER_ID,))
    cur.execute("DELETE FROM sample WHERE user_id = %s", (SENTINEL_USER_ID,))
    points, hr_rows = _flat_run(hr_lo, hr_hi, speed_ms, 900)
    cur.execute(
        "UPDATE gps_track SET start_ts = %s, end_ts = %s WHERE user_id = %s",
        (
            datetime.fromtimestamp(points[0][0], UTC),
            datetime.fromtimestamp(points[-1][0], UTC),
            SENTINEL_USER_ID,
        ),
    )
    cur.executemany(
        "INSERT INTO gps_point (user_id, track_id, ts, lat, lng, ele_m) "
        "VALUES (%s, %s, %s, %s, %s, %s)",
        [
            (SENTINEL_USER_ID, track_id, datetime.fromtimestamp(p[0], UTC), p[1], p[2], p[3])
            for p in points
        ],
    )
    insert_hr(cur, SENTINEL_USER_ID, hr_rows)
    day = datetime.fromtimestamp(_START_EPOCH, UTC).date()
    cur.executemany(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
        "VALUES (%s, %s, 'rhr_daily', %s, '{}'::jsonb) "
        "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
        [(SENTINEL_USER_ID, day - timedelta(days=i), rhr) for i in range(5)],
    )
    return track_id


@pytest.mark.integration
def test_reserve_fallback_scores_a_flat_run_the_graded_fit_cannot(db: None) -> None:  # noqa: ARG001
    """A steady run: no load range, so no slope — and the reserve method still reads it.

    This is what #114 buys. The graded fit refuses (its x-axis does not move); the
    reserve inversion needs no slope, so the session produces a number, tagged with the
    instrument that produced it and with the graded method's refusal recorded alongside.
    """
    migrate.apply_migrations()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        track_id = _seed_flat(cur, hr_lo=158.0, hr_hi=175.0, speed_ms=3.0, rhr=55.0)
        result = derive_vo2max_submax(cur, SENTINEL_USER_ID, SENTINEL_TZ, track_id)
    assert result["ok"] is True, result
    assert result["method"] == METHOD_RESERVE
    assert VO2MAX_LO <= result["vo2max_submax"] <= VO2MAX_HI
    assert result["graded_why_not"]  # why the more rigorous method declined
    assert result["hrr_median"] > 0.35


@pytest.mark.integration
def test_a_flat_walk_produces_nothing_from_either_method(db: None) -> None:  # noqa: ARG001
    """The finding, end to end: a real-shaped walk yields NO fitness number.

    Same constant-speed session at walking pace and a plausible walking heart rate.
    Both methods refuse, and the payload names both refusals — the graded fit's because
    the workload never moved, the reserve method's because walking cannot measure this.
    """
    migrate.apply_migrations()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        track_id = _seed_flat(cur, hr_lo=115.0, hr_hi=132.0, speed_ms=1.6, rhr=55.0)
        result = derive_vo2max_submax(cur, SENTINEL_USER_ID, SENTINEL_TZ, track_id)
        cur.execute(
            "SELECT count(*) FROM derived_daily WHERE user_id = %s AND metric='vo2max_submax'",
            (SENTINEL_USER_ID,),
        )
        row = cur.fetchone()
    assert result["ok"] is False
    assert result["reserve_reason"] == WITHHOLD_WALKING_ONLY
    assert row is not None and row[0] == 0  # nothing was written


@pytest.mark.integration
def test_gps_track_detail_summary(db: None) -> None:  # noqa: ARG001 — DB gate
    migrate.apply_migrations()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        track_id = _seed_track(cur)
        detail = gps_track_detail(cur, SENTINEL_USER_ID, track_id)
    assert detail is not None
    summary = detail["summary"]
    assert summary["n_points"] == len(detail["points"]) > 100
    assert summary["distance_km"] > 1.0
    assert summary["avg_hr"] is not None and summary["max_hr"] is not None
    assert summary["duration_s"] == pytest.approx(sum(d for _, d in STAGES) - 1, abs=1)
