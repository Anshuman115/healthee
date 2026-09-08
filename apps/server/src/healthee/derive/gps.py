"""VO2max measured from one recorded GPS session — the DB wiring, and the precedence.

Reads a recorded outdoor workout (gps_track + gps_point) plus the strap HR over the
same window, replaces the phone's barometer-less GPS elevation with a terrain DEM
(dem.py), interpolates the sparse strap HR (~1/min) across the track, and hands the
result to the pure science modules. Ported verbatim from legacy v2
``derive_vo2max_submax`` — the SQL, math and rounding are unchanged; the duplicated
HR-interpolation closure is now the shared ``make_hr_interpolator``. The route-map read
that used to share this file now lives in ``derive/gps_detail.py`` (#114 split it: two
reasons to change, and the second estimator took the file past 400 lines). Knowledge:
[[submaximal_vo2max]], [[hr_reserve_vo2max]].

``vo2max_submax`` is the SESSION record — "what did this effort measure" — and since
#117 it is no longer a parallel answer to "what is this person's VO2max". That question
has one answer, ``vo2max_estimate``, and ``derive/vo2max_tier.py`` assembles it from
these rows (primary) or the Jurca model (fallback). Sessions are the observations; the
canonical metric is the statement.

Since #114 two instruments can read a session, and this module is the only place that
knows the precedence between them WITHIN a session — the two science modules are pure and
neither imports the other's decision.
"""

from __future__ import annotations

import bisect
from collections.abc import Callable
from datetime import date, datetime
from uuid import UUID
from zoneinfo import ZoneInfo

from healthee.derive._common import Cur, _age, _load_profile, _upsert_daily
from healthee.derive.dem import elevations
from healthee.derive.hr_validity import HR_VALID_BOUNDS, HR_VALID_SQL
from healthee.derive.robust import median
from healthee.derive.vo2max import rhr_week
from healthee.derive.vo2max_reserve import (
    METHOD_RESERVE,
    RESERVE_WITHHOLD_MESSAGES,
    ReserveResult,
    vo2max_from_reserve,
)
from healthee.derive.vo2max_submax import (
    METHOD_GRADED,
    SubmaxResult,
    steady_windows,
    vo2max_from_track,
)
from healthee.derive.vo2max_tier import outranks, submax_method_of

Point = tuple[float, float, float, float | None]  # (ts_epoch_s, lat, lng, ele_m|None)
HrAt = Callable[[float], float | None]  # ts_epoch_s -> interpolated strap HR

# The two estimators that can write ``vo2max_submax``, and which one wins.
#
# ## Which INSTRUMENT read this session — not which metric it belongs to (#114, #117)
#
# ``vo2max_submax`` is the SESSION-LEVEL record: what one recorded effort measured, on the
# day it was recorded. It is not a second answer to "what is this person's VO2max" — that
# question has exactly one answer, ``vo2max_estimate``, assembled by
# ``derive/vo2max_tier.py`` (#117). Every row here says which instrument read it in
# ``flags.method``, and the ids belong to the instruments themselves
# (``vo2max_submax.METHOD_GRADED``, ``vo2max_reserve.METHOD_RESERVE``).
#
# The graded fit wins whenever it fires. It is the more rigorous method when load
# genuinely varies: it measures the VO2-HR relationship on this person in this session
# instead of assuming the population equivalence that ``vo2max_reserve`` inverts. The
# reserve inversion is the fallback precisely because its assumption is the thing that
# can be wrong, and on this owner's walking data it IS wrong by 17-30 ml/kg/min — which
# is why it refuses walking rather than deferring. The SAME order governs the tier module,
# because it is the same argument one layer up ([[hr_reserve_vo2max]] Directive 2).

_HR_INTERP_EDGE_S = 120  # accept an edge HR sample within 2 min of the query time
_HR_INTERP_GAP_S = 180  # a gap >3 min between HR samples is too large to interpolate
_MIN_HR_SAMPLES_VO2 = 5  # need >=5 HR samples over the window to attempt VO2max


def make_hr_interpolator(
    hr_ts: list[float], hr_val: list[float]
) -> Callable[[float], float | None]:
    """Build a HR(t) lookup that linearly interpolates between sparse strap samples.

    Returns None outside a 2-min edge tolerance or across a >3-min sample gap, so a
    missing HR stays distinct from an interpolated one.
    """

    def hr_at(t: float) -> float | None:
        if not hr_ts:
            return None
        i = bisect.bisect_left(hr_ts, t)
        if i == 0:
            return hr_val[0] if abs(hr_ts[0] - t) <= _HR_INTERP_EDGE_S else None
        if i >= len(hr_ts):
            return hr_val[-1] if abs(hr_ts[-1] - t) <= _HR_INTERP_EDGE_S else None
        t0, t1 = hr_ts[i - 1], hr_ts[i]
        if t1 - t0 > _HR_INTERP_GAP_S:
            return None
        f = (t - t0) / (t1 - t0)
        return hr_val[i - 1] + f * (hr_val[i] - hr_val[i - 1])

    return hr_at


def _track_window(cur: Cur, user_id: UUID, track_id: str) -> tuple[datetime, datetime] | None:
    """(start_ts, end_ts) for one owner's track, or None if it does not exist."""
    cur.execute(
        "SELECT start_ts, end_ts FROM gps_track WHERE user_id = %s AND id=%s",
        (user_id, track_id),
    )
    tr = cur.fetchone()
    return (tr[0], tr[1]) if tr else None


def _load_points(cur: Cur, user_id: UUID, track_id: str) -> list[Point]:
    """All fixes for a track, time-ordered, as (ts_epoch_s, lat, lng, ele|None)."""
    cur.execute(
        "SELECT extract(epoch FROM ts), lat, lng, ele_m FROM gps_point "
        "WHERE user_id = %s AND track_id=%s ORDER BY ts",
        (user_id, track_id),
    )
    return [
        (float(r[0]), float(r[1]), float(r[2]), float(r[3]) if r[3] is not None else None)
        for r in cur.fetchall()
    ]


def _load_hr(
    cur: Cur, user_id: UUID, start_ts: datetime, end_ts: datetime
) -> tuple[list[float], list[float]]:
    """(timestamps, values) for bounded HR samples across the track window."""
    cur.execute(
        "SELECT extract(epoch FROM ts), value FROM sample "
        f"WHERE user_id = %s AND metric='hr' AND {HR_VALID_SQL} "
        "AND ts BETWEEN %s AND %s ORDER BY ts",
        (user_id, *HR_VALID_BOUNDS, start_ts, end_ts),
    )
    rows = cur.fetchall()
    return [float(r[0]) for r in rows], [float(r[1]) for r in rows]


def _dem_corrected(points: list[Point]) -> tuple[list[Point], str, int]:
    """Replace GPS elevation with DEM terrain elevation (per-point GPS fallback).

    Returns (points, grade_source, dem_hits): grade_source is "dem" when the DEM
    covered most points, else "gps_elevation".
    """
    dem, dem_hits = elevations([(p[1], p[2]) for p in points])
    corrected: list[Point] = [
        (p[0], p[1], p[2], (dem[i] if dem[i] is not None else p[3])) for i, p in enumerate(points)
    ]
    grade_source = "dem" if dem_hits > len(points) // 2 else "gps_elevation"
    return corrected, grade_source, dem_hits


def _graded_flags(res: SubmaxResult) -> dict:
    """The diagnostics that justify a GRADED estimate."""
    return {
        "method": METHOD_GRADED,
        "r2": res.r2,
        "n_windows": res.n_windows,
        "hr_range": res.hr_range,
        "speed_kmh": res.speed_kmh_mean,
    }


def _reserve_flags(res: ReserveResult, graded_reason: str) -> dict:
    """The diagnostics that justify a RESERVE estimate.

    ``graded_why_not`` is kept because a reserve row is, by construction, a row the more
    rigorous method declined to write — an operator comparing two owners' fitness needs
    to see that difference without re-deriving it.
    """
    return {
        "method": METHOD_RESERVE,
        "n_windows": res.n_windows,
        "hrr_median": res.hrr_median,
        "hrr_min": res.hrr_min,
        "spread": res.spread,
        "speed_kmh": res.speed_kmh_median,
        "graded_why_not": graded_reason,
    }


def _reserve_attempt(
    cur: Cur, user_id: UUID, day: date, points: list[Point], hr_at: HrAt, hrmax: float
) -> tuple[ReserveResult | None, str]:
    """The fallback estimator, over the same steady windows the graded fit just used."""
    rhrs = rhr_week(cur, user_id, day)
    return vo2max_from_reserve(steady_windows(points, hr_at), median(rhrs) if rhrs else None, hrmax)


def derive_vo2max_submax(cur: Cur, user_id: UUID, tz: str, track_id: str) -> dict:
    """VO2max measured from one GPS track; stored as ``vo2max_submax``.

    Two instruments, one metric, a stated precedence (see :data:`METHOD_GRADED`): the
    graded HR-vs-workload fit when the session's load varied enough to fit a line, else
    the slope-free %HRR inversion when the session contains running. Returns
    {"ok": True, "method": ..., ...} with the estimate + the diagnostics of whichever
    method wrote it, or {"ok": False, "reason": ..., "reserve_reason": ...} naming why
    BOTH declined. [[submaximal_vo2max]], [[hr_reserve_vo2max]].
    """
    window = _track_window(cur, user_id, track_id)
    if not window:
        return {"ok": False, "reason": "track not found"}
    start_ts, end_ts = window
    points = _load_points(cur, user_id, track_id)
    if len(points) < 10:
        return {"ok": False, "reason": "too few GPS points"}
    points, grade_source, dem_hits = _dem_corrected(points)
    hr_ts, hr_val = _load_hr(cur, user_id, start_ts, end_ts)
    if len(hr_ts) < _MIN_HR_SAMPLES_VO2:
        return {"ok": False, "reason": "no HR for this window (was the strap worn?)"}
    day = start_ts.astimezone(ZoneInfo(tz)).date()
    prof = _load_profile(cur, user_id, tz, day)
    if not prof:
        return {"ok": False, "reason": "no profile"}
    hrmax = 208 - 0.7 * _age(prof["dob"], day)  # Tanaka 2001
    hr_at = make_hr_interpolator(hr_ts, hr_val)
    graded, status = vo2max_from_track(points, hr_at, hrmax)
    if graded:
        return _store(
            cur,
            user_id,
            day,
            track_id,
            graded.vo2max,
            _graded_flags(graded),
            hrmax,
            grade_source,
            dem_hits,
        )
    reserve, reserve_status = _reserve_attempt(cur, user_id, day, points, hr_at, hrmax)
    if reserve:
        return _store(
            cur,
            user_id,
            day,
            track_id,
            reserve.vo2max,
            _reserve_flags(reserve, status),
            hrmax,
            grade_source,
            dem_hits,
        )
    # Both declined. ``reason`` is the graded fit's (an operator-facing diagnostic);
    # ``message`` is the second-person sentence the OWNER sees, and it comes from the
    # reserve side because that is the gate with something actionable to say — "your
    # pace never varied enough to fit a line" is true but useless next to "walking
    # cannot measure this". [[hr_reserve_vo2max]].
    return {
        "ok": False,
        "reason": status,
        "reserve_reason": reserve_status,
        "message": RESERVE_WITHHOLD_MESSAGES[reserve_status],
    }


def _store(
    cur: Cur,
    user_id: UUID,
    day: date,
    track_id: str,
    vo2max: float,
    flags: dict,
    hrmax: float,
    grade_source: str,
    dem_hits: int,
) -> dict:
    """Write the winning estimate and echo it back with its method's diagnostics.

    ## Inside one day, precedence — not recency (write-path audit B1)

    ``derived_daily``'s key is ``(user_id, day, metric)``, so a day holds exactly ONE
    ``vo2max_submax`` cell. ``gps_scoring.score_day_tracks`` scores a day's pending tracks
    oldest-first and each call landed here, so **the last track of the day owned the cell**.
    That made recency beat precedence inside a day — the exact ordering
    ``vo2max_tier.select_measured_tier`` forbids across days, and which
    ``tests/derive/test_vo2max_tier.py::test_precedence_is_not_recency`` exists to prevent.

    Concretely: a graded fit at 09:00 and a reserve inversion at 18:00 left only the
    reserve row, and the tier — whose whole point is that *"a graded fit three days older
    than a reserve inversion still wins"* ([[hr_reserve_vo2max]] D2) — never saw the graded
    value at all. Nor did a repair reach it: ``unscored_tracks`` skips a track that already
    carries an estimate, and ``--rescore-tracks`` reproduces the same ordering.

    So the cell obeys the tier's own order, through the tier's own function
    (:func:`vo2max_tier.outranks`) rather than a second copy of it. Equal methods still
    overwrite, because a re-score has to be able to move a value.

    **What this does NOT fix, stated rather than implied.** Two sessions of the SAME
    instrument in one day still leave one cell, so the tier's median counts days rather
    than sessions there. Representing both would need a per-session home for the estimate
    with its method — ``gps_track`` carries ``vo2max_submax`` and ``r2`` but no ``method``
    or ``hrr_median`` — i.e. a schema change, for a case that costs precision rather than
    correctness. The precedence violation is the one that made the tier read the wrong
    instrument, and it is the one closed here.
    """
    common = {
        "hrmax_tanaka": round(hrmax, 1),
        "track_id": str(track_id),
        "grade_source": grade_source,
        "dem_hits": dem_hits,
    }
    if not _day_cell_outranks(cur, user_id, day, str(flags["method"])):
        _upsert_daily(cur, user_id, day, "vo2max_submax", vo2max, {**flags, **common})
    # The SESSION's own number is returned either way: it is what the upload endpoint
    # answers with, and `gps_scoring._denormalise_summary` writes it onto the track row —
    # which is also what closes the scoring gate, so declining the day cell must not make
    # this track look unscored and be retried forever.
    return {"ok": True, "vo2max_submax": vo2max, "grade_source": grade_source, **flags}


def _day_cell_outranks(cur: Cur, user_id: UUID, day: date, method: str) -> bool:
    """Does the day's stored ``vo2max_submax`` come from a BETTER instrument than ``method``?

    A day with no cell yet answers False, so the first session of a day always writes.
    """
    cur.execute(
        "SELECT flags FROM derived_daily "
        "WHERE user_id = %s AND day = %s AND metric = 'vo2max_submax'",
        (user_id, day),
    )
    row = cur.fetchone()
    return row is not None and outranks(submax_method_of(row[0]), method)
