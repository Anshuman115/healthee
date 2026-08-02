"""A recorded GPS track is scored by the ROUTINE derivation, not only on upload (#111).

## What this file exists to prevent

``derive.gps.derive_vo2max_submax`` was reachable from exactly one place: the upload
endpoint, once, at the instant the track arrived. That is the worst moment to ask. The
phone uploads the track when the workout ends, while the strap's heart rate for the same
window is still sitting on the strap unsynced — so the estimator correctly answers "no
HR for this window", nothing ever retries, and the session is never scored again.

Measured in production on 2026-08-02: **8 GPS tracks, zero ``vo2max_submax`` rows**, for
weeks. Nothing failed; the upload returned 200 with an honest refusal inside it, and no
surface existed to notice the refusal was permanent.

2067 tests covered the estimator's science, its DB plumbing, both instruments and both
refusals — and not one covered *track → scored*. That gap is the whole reason this file
exists, so its assertions are about REACHABILITY: a track present in the database ends up
with a ``derived_daily`` row, through the paths the running system actually takes.

## Why the assertions are what they are

``test_a_track_uploaded_before_its_hr_arrives_is_scored_by_the_next_push`` is the direct
regression net, and it reproduces the production sequence exactly: upload first (no HR
yet, refused), strap syncs second, row exists. It fails if ``derive_day`` stops scoring
the day's tracks.

``test_a_scored_track_is_not_re_scored`` is the cost property. Scoring re-reads every fix
and re-runs the DEM, so a day pass that re-scored everything it saw would put that on the
ingest path's < 5 s budget on every push, forever.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest
from tests.derive._gps_seed import TrackPoint, insert_hr, synthetic_run

from healthee.core.db import admin_connection, tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate, rederive
from healthee.derive.gps_scoring import unscored_tracks
from healthee.ingest import HelioPayload, ingest_helio
from healthee.read.gps import GpsTrackIn, ingest_gps_track

pytestmark = pytest.mark.integration

_TABLES = "sample, sleep_session, workout, derived_daily, weight_log, profile, gps_point, gps_track"

_IST = ZoneInfo(SENTINEL_TZ)

# A morning run in the OWNER's own zone, on a fixed date — so the local day this track
# belongs to is the same under TZ=UTC and TZ=Asia/Kolkata. The whole derive chain anchors
# on the owner's zone, and a test that drifted with the runner's would hide that.
_RUN_START = datetime(2026, 6, 20, 6, 0, tzinfo=_IST)
_RUN_DAY = date(2026, 6, 20)

# The strap emits roughly one HR sample a minute; 5 s here keeps the payload small while
# staying far inside the interpolator's 180 s gap limit.
_HR_STEP_S = 5

_PROFILE = {"height_cm": 175.0, "sex": "male", "dob": "1990-06-15", "weight_kg": 70.0}


def _reset() -> None:
    migrate.apply_migrations()
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(f"TRUNCATE {_TABLES}")


def _run(start: datetime) -> tuple[list[TrackPoint], list[tuple[float, float]]]:
    return synthetic_run(start.timestamp())


def _upload(points: list[TrackPoint]) -> dict:
    """The real upload path: POST /api/workout/gps' service, in its own transaction."""
    req = GpsTrackIn(
        start_iso=datetime.fromtimestamp(points[0][0], UTC).isoformat(),
        end_iso=datetime.fromtimestamp(points[-1][0], UTC).isoformat(),
        points=[[p[0], p[1], p[2], p[3]] for p in points],
    )
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        return ingest_gps_track(cur, SENTINEL_USER_ID, SENTINEL_TZ, req)


def _push_hr(hr_rows: list[tuple[float, float]]) -> None:
    """The strap sync that arrives AFTER the upload, carrying the window's heart rate."""
    payload = HelioPayload.model_validate(
        {
            "samples": [
                {"metric": "hr", "ts": int(ts * 1000), "value": hr}
                for ts, hr in hr_rows[::_HR_STEP_S]
            ],
            "profile": _PROFILE,
        }
    )
    ingest_helio(payload, SENTINEL_USER_ID, SENTINEL_TZ)


def _seed_profile() -> None:
    """Profile + weight, without any HR — everything the estimator needs but the HR."""
    ingest_helio(HelioPayload.model_validate({"profile": _PROFILE}), SENTINEL_USER_ID, SENTINEL_TZ)


def _submax(day: date) -> tuple[float, dict] | None:
    """The day's ``vo2max_submax`` cell as (value, flags), read as the ADMIN.

    Independent of the RLS scoping the path under test relies on — the observer posture
    ``test_ingest_derive_chain._derived`` documents.
    """
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT value, flags FROM derived_daily "
            "WHERE user_id = %s AND day = %s AND metric = 'vo2max_submax'",
            (SENTINEL_USER_ID, day),
        )
        row = cur.fetchone()
    return (float(row[0]), row[1] or {}) if row else None


def _denormalised(track_id: str) -> float | None:
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT vo2max_submax FROM gps_track WHERE user_id = %s AND id = %s",
            (SENTINEL_USER_ID, track_id),
        )
        row = cur.fetchone()
    return None if row is None or row[0] is None else float(row[0])


def _pending(day: date) -> list[str]:
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        return unscored_tracks(cur, SENTINEL_USER_ID, SENTINEL_TZ, day)


# ── the routine seam ─────────────────────────────────────────────────────────


def test_a_track_uploaded_before_its_hr_arrives_is_scored_by_the_next_push(db: None) -> None:
    """The production sequence: upload with no HR, strap syncs later, row exists.

    Fails without ``derive_day`` scoring the day's tracks — which is the state prod ran
    in: 8 tracks, zero rows, an honest refusal at upload that nothing ever revisited.
    """
    _reset()
    _seed_profile()
    points, hr_rows = _run(_RUN_START)

    uploaded = _upload(points)
    assert uploaded["ok"] is True  # the TRACK stored fine
    assert uploaded["vo2max"]["ok"] is False  # the ESTIMATE could not be made yet
    assert _submax(_RUN_DAY) is None

    _push_hr(hr_rows)

    cell = _submax(_RUN_DAY)
    assert cell is not None, "the strap sync that touched this day never scored its track"
    assert cell[1]["track_id"] == uploaded["track_id"]
    assert _denormalised(uploaded["track_id"]) == pytest.approx(cell[0])


def test_the_upload_path_still_scores_a_track_whose_hr_is_already_there(db: None) -> None:
    """The immediate answer survives the rewiring — the endpoint still returns a number.

    The upload no longer OWNS the scoring, it calls the same ``score_track`` the day pass
    does. A user who records a run after the strap synced still gets their estimate in
    the POST response rather than waiting for the next push.
    """
    _reset()
    _seed_profile()
    points, hr_rows = _run(_RUN_START)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        insert_hr(cur, SENTINEL_USER_ID, hr_rows)

    uploaded = _upload(points)

    assert uploaded["vo2max"]["ok"] is True, uploaded
    assert _submax(_RUN_DAY) is not None
    assert _pending(_RUN_DAY) == []


def test_a_scored_track_is_not_re_scored(db: None) -> None:
    """Idempotence: a track with an estimate is no longer pending, and re-pushing is a no-op.

    Scoring re-reads every fix and re-runs the DEM correction, so a day pass that scored
    everything it saw would charge that to the ingest path's < 5 s budget on every push
    for as long as the day keeps receiving data.
    """
    _reset()
    _seed_profile()
    points, hr_rows = _run(_RUN_START)
    _upload(points)
    _push_hr(hr_rows)

    first = _submax(_RUN_DAY)
    assert first is not None
    assert _pending(_RUN_DAY) == []  # the gate is closed

    _push_hr(hr_rows)  # a second sync touching the same day

    assert _submax(_RUN_DAY) == first
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM derived_daily WHERE user_id = %s AND metric = 'vo2max_submax'",
            (SENTINEL_USER_ID,),
        )
        row = cur.fetchone()
    assert row is not None and row[0] == 1  # one day, one row — never duplicated


def test_a_track_that_cannot_be_scored_stays_pending(db: None) -> None:
    """A refused track is retried while its day still receives data — not marked done.

    The distinction the gate has to keep: "no estimate yet" is not "no estimate
    possible". A track whose HR has not arrived must come back around on the next push;
    marking it scored on the refusal would rebuild the original bug in a new shape.
    """
    _reset()
    _seed_profile()
    points, _ = _run(_RUN_START)

    uploaded = _upload(points)

    assert uploaded["vo2max"]["ok"] is False
    assert _pending(_RUN_DAY) == [uploaded["track_id"]]


# ── the repair path ──────────────────────────────────────────────────────────


def _recent_run() -> tuple[list[TrackPoint], list[tuple[float, float]], date]:
    """A run that ended a few hours ago, plus the owner-local day it belongs to.

    ``rederive`` walks a window ending on the owner's today, so this one has to be
    now-relative; the expected day is derived through the same zone conversion the
    derivation uses, so the assertion holds under either runner TZ.
    """
    start = datetime.now(UTC).replace(microsecond=0) - timedelta(hours=3)
    points, hr_rows = _run(start)
    return points, hr_rows, start.astimezone(_IST).date()


def test_the_repair_tool_backfills_a_track_no_push_ever_scored(db: None) -> None:
    """``python -m healthee.db.rederive`` reaches GPS tracks — via the same day pass.

    The repair path gets this for free precisely because the scoring lives in
    ``derive_day``: ``rederive`` routes through the same ``derive_batch`` the push does,
    so it cannot disagree with the live path about when a track is scored (#107's rule).
    """
    _reset()
    _seed_profile()
    points, hr_rows, run_day = _recent_run()
    _upload(points)  # refused — no HR yet
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        insert_hr(cur, SENTINEL_USER_ID, hr_rows)  # HR lands with nothing to derive it
    assert _submax(run_day) is None

    assert rederive.main(["--user", str(SENTINEL_USER_ID), "--days", "2"]) == 0

    assert _submax(run_day) is not None


def test_a_day_without_a_track_derives_exactly_as_before(db: None) -> None:
    """The seam adds nothing to a day that has no GPS track — no row, no work."""
    _reset()
    _seed_profile()
    noon = datetime(2026, 6, 20, 12, 0, tzinfo=_IST)
    payload = HelioPayload.model_validate(
        {"samples": [{"metric": "hr", "ts": int(noon.timestamp() * 1000), "value": 61.0}]}
    )

    ingest_helio(payload, SENTINEL_USER_ID, SENTINEL_TZ)

    assert _submax(_RUN_DAY) is None
    assert _pending(_RUN_DAY) == []
