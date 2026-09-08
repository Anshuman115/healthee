"""Three client-supplied bounds that reached the SQL unclamped (`PERF_AUDIT.md` B4).

The standards: *"Unbounded data is windowed — every list endpoint paginates; every chart
query has a range."* Where a bound is clamped it is clamped in the READ layer, and the
pattern was good — it just was not everywhere:

* `challenges/ledger.recent` took `limit` from `/api/challenges/outcomes`'s query string
  straight into `LIMIT %s`;
* `read/logs.log_recent` took `days` straight into a SQL `interval`;
* `read/gps.gps_detail` had **no read-side bound at all** — every stored fix, capped only
  by the ingest limit of 28,800 points, on a p95 < 100 ms endpoint.

The third is the one with a payload consequence, and it gets most of this file. Thinning
what the map draws is free; thinning what the RESPONSE claims about the recording is not,
because the app prints "Phone GPS · N fixes" and "This route has N matched heart-rate
points". Both counts must keep meaning *what the strap recorded*, so both are asserted
against the full track while the array is asserted against the cap.

The two clamps are asserted by ROW COUNT and by the SQL the query actually carries: a
clamp that quietly failed open would still return the right rows on any reasonable input,
which is exactly the kind of guard that passes while protecting nothing.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import psycopg
import pytest

from healthee.challenges.ledger import MAX_RECENT_OUTCOMES, recent
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.read.gps import MAX_MAP_POINTS, gps_detail
from healthee.read.logs import MAX_LOG_DAYS, log_recent

pytestmark = pytest.mark.integration

# Comfortably past the cap, and not a round multiple of it, so an off-by-one in the
# thinner shows up as a wrong count rather than as a plausible one.
_BIG_TRACK_POINTS = 5_003
_HR_EVERY = 10


def _seed_track(cur) -> str:
    """One long track with a heart rate on every tenth second of its window."""
    cur.execute("DELETE FROM gps_point")
    cur.execute("DELETE FROM gps_track")
    cur.execute("DELETE FROM sample WHERE metric = 'hr'")
    track_id = uuid4()
    start = datetime.now(tz=UTC) - timedelta(seconds=_BIG_TRACK_POINTS + 60)
    cur.execute(
        "INSERT INTO gps_track (id, user_id, start_ts, end_ts, distance_m, duration_s) "
        "VALUES (%s, %s, %s, %s, 5000, %s)",
        (
            track_id,
            SENTINEL_USER_ID,
            start,
            start + timedelta(seconds=_BIG_TRACK_POINTS),
            _BIG_TRACK_POINTS,
        ),
    )
    cur.executemany(
        "INSERT INTO gps_point (user_id, track_id, ts, lat, lng, ele_m) "
        "VALUES (%s, %s, %s, %s, %s, %s)",
        [
            (
                SENTINEL_USER_ID,
                track_id,
                start + timedelta(seconds=i),
                51.5 + i * 0.00001,
                -0.12 + i * 0.00001,
                20.0 + (i % 50),
            )
            for i in range(_BIG_TRACK_POINTS)
        ],
    )
    cur.executemany(
        "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, 'hr', %s) "
        "ON CONFLICT DO NOTHING",
        [
            (SENTINEL_USER_ID, start + timedelta(seconds=i), 120.0 + (i % 30))
            for i in range(0, _BIG_TRACK_POINTS, _HR_EVERY)
        ],
    )
    return str(track_id)


@pytest.mark.usefixtures("db")
def test_a_long_track_is_thinned_to_the_cap_keeping_both_ends() -> None:
    """The array is bounded, and the first and last FIXES are still the first and last.

    Both ends are the guarantee the start ring and the finish dot depend on, and the
    app's own `RouteMap.displayPoints` makes the same promise for the same reason. A
    thinner that dropped either would move where the route began.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        track_id = _seed_track(cur)
        detail = gps_detail(cur, SENTINEL_USER_ID, track_id)
        cur.execute(
            "SELECT extract(epoch FROM min(ts)), extract(epoch FROM max(ts)) "
            "FROM gps_point WHERE user_id = %s AND track_id = %s",
            (SENTINEL_USER_ID, track_id),
        )
        bounds = cur.fetchone()
        assert bounds is not None
        first_ts, last_ts = bounds

    assert detail is not None
    points = detail["points"]
    assert len(points) == MAX_MAP_POINTS, (
        f"{len(points)} points on the wire against a cap of {MAX_MAP_POINTS}. The only "
        "bound on this endpoint used to be the 28,800-point INGEST limit."
    )
    assert points[0]["t"] == round(first_ts)
    assert points[-1]["t"] == round(last_ts)


@pytest.mark.usefixtures("db")
def test_the_summary_still_counts_the_whole_recording() -> None:
    """`n_points` and `n_hr_points` describe the RUN; `points_returned` the response.

    This is the honesty half. The route card prints the fix count and the withheld-VO2max
    notice prints the matched-HR count, and both used to be counted off the points array
    by the app — correct only while the array was the whole track. A thinned array with
    unchanged counts would have made a 5,003-fix run read as a 2,000-fix one.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        track_id = _seed_track(cur)
        detail = gps_detail(cur, SENTINEL_USER_ID, track_id)

    assert detail is not None
    summary = detail["summary"]
    assert summary["n_points"] == _BIG_TRACK_POINTS, (
        "`n_points` is the number of fixes RECORDED, not the number returned — the app "
        "prints it as 'Phone GPS · N fixes'"
    )
    # Every fix got a heart rate off the interpolator at this sample density, so the
    # count over the whole recording is the whole recording — and the count the app used
    # to take off the returned array would now be MAX_MAP_POINTS. Both numbers are stated
    # rather than one, because the gap between them IS the defect this key closes.
    drawn_with_hr = len([p for p in detail["points"] if p["hr"] is not None])
    assert summary["n_hr_points"] == _BIG_TRACK_POINTS
    assert drawn_with_hr == MAX_MAP_POINTS
    assert summary["n_hr_points"] != drawn_with_hr, (
        "the fixture no longer distinguishes the two counts, so it cannot fail on the "
        "defect: a matched-HR count taken off the thinned array"
    )
    assert summary["points_returned"] == MAX_MAP_POINTS
    assert summary["points_decimated"] is True


@pytest.mark.usefixtures("db")
def test_a_short_track_is_not_thinned_and_says_so() -> None:
    """Under the cap nothing is sampled, and the flag is False rather than absent.

    A key that appears only on the decimated case is one a client learns to ignore.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute("DELETE FROM gps_point")
        cur.execute("DELETE FROM gps_track")
        track_id = uuid4()
        start = datetime.now(tz=UTC) - timedelta(minutes=10)
        cur.execute(
            "INSERT INTO gps_track (id, user_id, start_ts, end_ts, distance_m, duration_s) "
            "VALUES (%s, %s, %s, %s, 300, 60)",
            (track_id, SENTINEL_USER_ID, start, start + timedelta(seconds=60)),
        )
        cur.executemany(
            "INSERT INTO gps_point (user_id, track_id, ts, lat, lng, ele_m) "
            "VALUES (%s, %s, %s, %s, %s, %s)",
            [
                (SENTINEL_USER_ID, track_id, start + timedelta(seconds=i), 51.5, -0.12, 20.0)
                for i in range(30)
            ],
        )
        detail = gps_detail(cur, SENTINEL_USER_ID, str(track_id))

    assert detail is not None
    assert len(detail["points"]) == 30
    assert detail["summary"]["points_returned"] == 30
    assert detail["summary"]["points_decimated"] is False


def _seed_outcomes(cur, n: int) -> None:
    cur.execute("DELETE FROM challenge_outcome")
    cur.execute("DELETE FROM challenge")
    now = datetime.now(tz=UTC)
    for i in range(n):
        cur.execute(
            "INSERT INTO challenge (user_id, title, why, metric, comparator, cadence, "
            "target_value, window_days, status, category, difficulty) "
            "VALUES (%s, 'walk more', 'because', 'steps_total', '>=', 'daily', 8000, 7, "
            "'completed', 'movement', 'moderate') RETURNING id",
            (SENTINEL_USER_ID,),
        )
        challenge_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO challenge_outcome (user_id, challenge_id, metric, cadence, target, "
            "status, days_active, ended_at) VALUES (%s, %s, 'steps_total', 'daily', 8000, "
            "'met', 7, %s)",
            (SENTINEL_USER_ID, challenge_id, now - timedelta(days=i)),
        )


@pytest.mark.usefixtures("db")
def test_the_outcome_ledger_clamps_a_client_supplied_limit() -> None:
    """A caller asking for a million gets the cap, and an ordinary 20 is untouched."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed_outcomes(cur, MAX_RECENT_OUTCOMES + 5)
        huge = recent(cur, SENTINEL_USER_ID, limit=1_000_000)
        normal = recent(cur, SENTINEL_USER_ID, limit=20)

    assert len(huge) == MAX_RECENT_OUTCOMES, (
        f"`limit` reached `LIMIT %s` unclamped: asked for 1,000,000, got {len(huge)}"
    )
    assert len(normal) == 20, "the clamp must not shrink an ordinary request"


@pytest.mark.usefixtures("db")
def test_the_outcome_ledger_floors_a_nonsense_limit() -> None:
    """Zero and negative floor at one ROW, checked on the value that reaches the SQL.

    On the parameter and not on the returned rows, because an unclamped negative is a
    `LIMIT -7` — PostgreSQL raises, and a test that goes red on a database error has
    proved the mutation was misspelled rather than that the guard works
    (`HOW_WE_VERIFY.md` section 2, the fictional mutation). The clamp is arithmetic; the
    parameter is where the arithmetic lands.
    """
    seen: list[tuple] = []
    real = psycopg.Cursor.execute

    def traced(self, query, params=None, **kw):  # noqa: ANN001, ANN003, ANN202
        if "challenge_outcome" in str(query) and "LIMIT" in str(query) and params:
            seen.append(tuple(params))
        return real(self, query, params, **kw)

    psycopg.Cursor.execute = traced  # type: ignore[method-assign]
    try:
        with tenant_transaction(SENTINEL_USER_ID) as cur:
            _seed_outcomes(cur, 3)
            recent(cur, SENTINEL_USER_ID, limit=0)
            recent(cur, SENTINEL_USER_ID, limit=-7)
    finally:
        psycopg.Cursor.execute = real  # type: ignore[method-assign]

    reached = [p[1] for p in seen]
    assert reached == [1, 1], (
        f"`limit` reached `LIMIT %s` as {reached} — zero and negative must floor at one row"
    )


@pytest.mark.usefixtures("db")
def test_the_log_feed_clamps_a_client_supplied_day_window() -> None:
    """The interval the SQL actually carries is the clamped one, not the asked one.

    Asserted on the PARAMETER rather than on the rows, because the endpoint's `LIMIT 80`
    already bounds the answer — so a clamp that failed open would return exactly the same
    entries and no assertion about content could tell. What changes is the size of the
    scan, and the parameter is where that is decided.
    """
    seen: list[tuple] = []
    real = psycopg.Cursor.execute

    def traced(self, query, params=None, **kw):  # noqa: ANN001, ANN003, ANN202
        if "manual_entry" in str(query) and "interval" in str(query) and params:
            seen.append(tuple(params))
        return real(self, query, params, **kw)

    psycopg.Cursor.execute = traced  # type: ignore[method-assign]
    try:
        with tenant_transaction(SENTINEL_USER_ID) as cur:
            log_recent(cur, SENTINEL_USER_ID, days=999_999)
            log_recent(cur, SENTINEL_USER_ID, days=0)
            log_recent(cur, SENTINEL_USER_ID, days=7)
    finally:
        psycopg.Cursor.execute = real  # type: ignore[method-assign]

    reached = [p[1] for p in seen]
    assert reached == [MAX_LOG_DAYS, 1, 7], (
        f"`days` reached the SQL interval as {reached} — it must be "
        f"clamped to [1, {MAX_LOG_DAYS}] and must leave an ordinary 7 alone"
    )
