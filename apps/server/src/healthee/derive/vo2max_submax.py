"""Submaximal HR-vs-pace VO2max from a GPS track + strap HR — the "wearable method".

The accurate, research-grounded upgrade over the Jurca non-exercise estimate: over
the steady-state segments of an outdoor walk/run, fit the linear VO2<->HR
relationship and extrapolate it out to the age-predicted HRmax (Tanaka 2001). VO2
per segment = ACSM's validated LEVEL value scaled by the Minetti 2002 gradient-cost
ratio (correct uphill AND downhill), from GPS speed + grade. Grade comes from a
terrain DEM (dem.py) — the DB wiring in ``gps.py`` swaps the phone's noisy GPS
elevation for the SRTM lookup before calling here.

Pure + dependency-free so it unit-tests without the DB. Ported verbatim from legacy
v2 ``vo2max_submax`` — the algorithm, constants, and rounding are unchanged; it is
split into per-stage helpers only to satisfy the function-length/complexity gates,
and the ``__main__`` self-test now lives in the parity test. Knowledge:
[[submaximal_vo2max]].
"""

from __future__ import annotations

import math
from collections.abc import Callable
from dataclasses import dataclass

from healthee.derive.robust import median

# ``derive/robust`` is pure (no DB, no I/O), so importing it keeps this module
# unit-testable without a database — it held a byte-identical private ``_median``
# until 2026-07-31, which was a second definition of the statistic for no gain.

# ── Tunables ──────────────────────────────────────────────────────────────────
WINDOW_S = 30  # bin GPS+HR into 30 s windows before regressing
SMOOTH_S = 25  # rolling-median half-window for elevation (kills GPS noise)
SMOOTH_SPEED_S = 15  # +/- window to smooth interval speed (kills GPS speed jitter)
WARMUP_DROP_S = 180  # drop the first 3 min (HR lags load at the start)
RUN_SPEED_MS = 2.0  # >= ~2 m/s (~7.2 km/h) -> use the ACSM running equation
MIN_WINDOWS = 6  # need at least this many steady windows to trust a line
MIN_HR_RANGE = 15  # steady windows must span >=15 bpm or the slope is unreliable
MIN_R2 = 0.5  # regression must explain >=50% of the variance
SPEED_CV_MAX = 0.20  # a window is "steady" if its SMOOTHED speed CV (std/mean) <20%
GRADE_CLAMP = 0.35  # clamp |grade| (trek descents are steep; Minetti valid to 0.45)
VO2MAX_LO, VO2MAX_HI = 20.0, 85.0  # plausibility guard on the output

_MINETTI_CLAMP = 0.45  # Minetti 2002 gradient validity range
_MIN_WINDOW_INTERVALS = 3  # a window needs this many intervals to be scored
_MIN_WINDOW_HR = 3  # and this many valid HR samples
_HR_LO, _HR_HI = 60, 220  # plausible exercise-HR bounds per window sample
_MAX_HUMAN_SPEED_MS = 12.0  # >43 km/h between fixes = GPS glitch
_MAX_GAP_S = 30  # gaps >30 s break steadiness
_MIN_STEADY_SPEED_MS = 0.5  # below this a window is "essentially stopped"
_MIN_GRADE_DIST_M = 10  # need >10 m of travel to trust a window grade

# Interval tuple layout: (i, j, mid_ts, speed_ms, dist_m).
_MID, _SPEED, _DIST = 2, 3, 4

# (slope, intercept, r2, vo2max) from the VO2<->HR regression.
_FitResult = tuple[float, float, float, float]


def _haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance in metres."""
    radius = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * radius * math.asin(math.sqrt(a))


def _vo2_speed_grade(speed_ms: float, grade: float) -> float:
    """VO2 (ml/kg/min) from speed + grade.

    ACSM gives the validated LEVEL value; the GRADIENT effect uses the Minetti 2002
    energy-cost-of-locomotion ratio — a U-shaped polynomial that correctly handles
    uphill AND downhill (cost minimum ~-10% grade, rising both ways), unlike the
    plain ACSM linear grade term which goes negative on descents. speed m/s -> m/min;
    grade as a fraction (0.05 = 5%).
    """
    s = speed_ms * 60.0
    i = max(-_MINETTI_CLAMP, min(_MINETTI_CLAMP, grade))
    if speed_ms >= RUN_SPEED_MS:
        level = 3.5 + 0.2 * s
        cw = 155.4 * i**5 - 30.4 * i**4 - 43.3 * i**3 + 46.3 * i**2 + 19.5 * i + 3.6
        cw0 = 3.6
    else:
        level = 3.5 + 0.1 * s
        cw = 280.5 * i**5 - 58.7 * i**4 - 76.8 * i**3 + 51.9 * i**2 + 19.6 * i + 2.5
        cw0 = 2.5
    return level * max(cw, 0.7) / cw0  # scale level VO2 by the gradient cost ratio


@dataclass
class SubmaxResult:
    vo2max: float
    n_windows: int
    hr_range: float
    r2: float
    slope: float
    intercept: float
    speed_kmh_mean: float


@dataclass(frozen=True)
class SteadyWindow:
    """One steady window of a session: what BOTH estimators score.

    ``hr`` mean bounded HR over the window, ``vo2`` its ACSM-level cost scaled by the
    Minetti gradient ratio, ``speed_ms`` its mean smoothed speed, and ``elapsed_s`` how
    far into the session it sits (needed to test for cardiac drift).

    There is one definition of "a steady window" and this is it — ``vo2max_from_track``
    regresses over these and ``derive/vo2max_reserve.py`` inverts each one
    independently. Two definitions of steadiness would be two definitions of the
    workload the whole fitness metric rests on (CLAUDE.md: ONE canonical definition per
    metric), and the reserve estimator's whole claim to be a SECOND estimator rather
    than a second *pipeline* is that it disagrees with the first only in the
    aggregation step.
    """

    hr: float
    vo2: float
    speed_ms: float
    elapsed_s: float


def _smooth_elevation(
    points: list[tuple[float, float, float, float | None]], ts: list[float], ele: list[float | None]
) -> list[float | None]:
    """Rolling +/-SMOOTH_S-second median of elevation (averages out GPS noise).

    GPS elevation (no barometer) is noisy at +/-10-30 m; per-second grade off raw
    fixes invents huge fake slopes. Smooth first, then take grade over the whole
    window's distance.
    """
    sm_ele: list[float | None] = [None] * len(points)
    for i in range(len(points)):
        if ele[i] is None:
            continue
        lo, hi = ts[i] - SMOOTH_S, ts[i] + SMOOTH_S
        vals = [ej for j in range(len(points)) if (ej := ele[j]) is not None and lo <= ts[j] <= hi]
        if vals:
            sm_ele[i] = median(vals)
    return sm_ele


def _build_intervals(
    points: list[tuple[float, float, float, float | None]], ts: list[float]
) -> list[tuple[int, int, float, float, float]]:
    """Per-adjacent-fix intervals (i, j, mid_ts, speed, dist), gap/glitch filtered."""
    inter: list[tuple[int, int, float, float, float]] = []
    for i in range(len(points) - 1):
        dt = ts[i + 1] - ts[i]
        if dt <= 0 or dt > _MAX_GAP_S:
            continue
        dist = _haversine_m(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2])
        speed = dist / dt
        if speed > _MAX_HUMAN_SPEED_MS:
            continue
        inter.append((i, i + 1, (ts[i] + ts[i + 1]) / 2.0, speed, dist))
    return inter


def _smooth_interval_speeds(inter: list[tuple[int, int, float, float, float]]) -> list[float]:
    """Smooth each interval's speed over +/-SMOOTH_SPEED_S (total dist / total time).

    Raw 3-5 s GPS speed is very noisy at walking pace, so the raw within-window
    spread falsely reads as "non-steady" and discards good windows. Smoothing leaves
    real pace changes intact.
    """
    mids = [it[_MID] for it in inter]
    dts = [(it[_DIST] / it[_SPEED]) if it[_SPEED] > 0 else 0.0 for it in inter]
    sm_speed: list[float] = []
    for k in range(len(inter)):
        lo, hi = mids[k] - SMOOTH_SPEED_S, mids[k] + SMOOTH_SPEED_S
        ds = tt = 0.0
        for j in range(len(inter)):
            if lo <= mids[j] <= hi:
                ds += inter[j][_DIST]
                tt += dts[j]
        sm_speed.append(ds / tt if tt > 0 else inter[k][_SPEED])
    return sm_speed


def _bin_windows(
    inter: list[tuple[int, int, float, float, float]], t0: float
) -> dict[int, list[int]]:
    """Bin interval indices into WINDOW_S windows past the warm-up drop."""
    windows: dict[int, list[int]] = {}
    for k, it in enumerate(inter):
        if it[_MID] - t0 < WARMUP_DROP_S:
            continue
        windows.setdefault(int((it[_MID] - t0) // WINDOW_S), []).append(k)
    return windows


def _window_point(
    ks: list[int],
    inter: list[tuple[int, int, float, float, float]],
    sm_speed: list[float],
    sm_ele: list[float | None],
    hr_at: Callable[[float], float | None],
) -> tuple[float, float, float] | None:
    """One steady window -> (mean_hr, vo2, mean_speed), or None if it fails a gate."""
    if len(ks) < _MIN_WINDOW_INTERVALS:
        return None
    sps = [sm_speed[k] for k in ks]
    mean_sp = sum(sps) / len(sps)
    if mean_sp < _MIN_STEADY_SPEED_MS:  # essentially stopped — not a load point
        return None
    var = sum((s - mean_sp) ** 2 for s in sps) / len(sps)
    if (var**0.5) / mean_sp > SPEED_CV_MAX:  # non-steady (CV on smoothed speed)
        return None
    dist = sum(inter[k][_DIST] for k in ks)
    i0, i1 = inter[ks[0]][0], inter[ks[-1]][1]
    e0, e1 = sm_ele[i0], sm_ele[i1]
    grade = 0.0
    if dist > _MIN_GRADE_DIST_M and e0 is not None and e1 is not None:
        grade = max(-GRADE_CLAMP, min(GRADE_CLAMP, (e1 - e0) / dist))
    vo2 = _vo2_speed_grade(mean_sp, grade)
    hrs = [h for k in ks if (h := hr_at(inter[k][_MID])) is not None and _HR_LO <= h <= _HR_HI]
    if len(hrs) < _MIN_WINDOW_HR:
        return None
    return sum(hrs) / len(hrs), vo2, mean_sp


def _collect_steady_windows(
    windows: dict[int, list[int]],
    inter: list[tuple[int, int, float, float, float]],
    sm_speed: list[float],
    sm_ele: list[float | None],
    hr_at: Callable[[float], float | None],
    t0: float,
) -> list[SteadyWindow]:
    """Score every window -> the :class:`SteadyWindow` list both estimators consume."""
    out: list[SteadyWindow] = []
    for _, ks in sorted(windows.items()):
        wp = _window_point(ks, inter, sm_speed, sm_ele, hr_at)
        if wp is None:
            continue
        hr, vo2, mean_sp = wp
        elapsed = sum(inter[k][_MID] for k in ks) / len(ks) - t0
        out.append(SteadyWindow(hr=hr, vo2=vo2, speed_ms=mean_sp, elapsed_s=elapsed))
    return out


def steady_windows(
    points: list[tuple[float, float, float, float | None]],
    hr_at: Callable[[float], float | None],
) -> list[SteadyWindow] | None:
    """The steady windows of one session — the shared front half of both estimators.

    Elevation smoothing, interval building, speed smoothing, warm-up drop, binning and
    the per-window steadiness gates, exactly as ``vo2max_from_track`` has always applied
    them.

    ``None`` means the track could not be WINDOWED at all (too few fixes, or fewer than
    10 usable intervals after the gap/glitch filter); an empty list means it windowed
    fine and nothing in it was steady. Those are different failures and the caller says
    so differently — collapsing them would be the "no data and operation failed are
    distinguishable" rule (standards §1) broken inside the science layer.
    [[submaximal_vo2max]], [[hr_reserve_vo2max]].
    """
    if len(points) < 10:
        return None
    ts = [p[0] for p in points]
    sm_ele = _smooth_elevation(points, ts, [p[3] for p in points])
    inter = _build_intervals(points, ts)
    if len(inter) < 10:
        return None
    t0 = inter[0][_MID]
    sm_speed = _smooth_interval_speeds(inter)
    return _collect_steady_windows(_bin_windows(inter, t0), inter, sm_speed, sm_ele, hr_at, t0)


def _fit(pts: list[tuple[float, float]], hrmax: float) -> tuple[_FitResult | None, str]:
    """Least-squares VO2 = slope*HR + intercept, extrapolated to HRmax.

    Returns ((slope, intercept, r2, vo2max), "ok") or (None, reason).
    """
    n = len(pts)
    mx = sum(h for h, _ in pts) / n
    my = sum(v for _, v in pts) / n
    sxx = sum((h - mx) ** 2 for h, _ in pts)
    sxy = sum((h - mx) * (v - my) for h, v in pts)
    if sxx <= 0:
        return None, "degenerate HR distribution"
    slope = sxy / sxx
    intercept = my - slope * mx
    if slope <= 0:
        return None, "non-positive VO₂–HR slope (HR not tracking load)"
    ss_tot = sum((v - my) ** 2 for _, v in pts)
    ss_res = sum((v - (slope * h + intercept)) ** 2 for h, v in pts)
    r2 = 1 - ss_res / ss_tot if ss_tot > 0 else 0.0
    if r2 < MIN_R2:
        return None, f"poor fit (r²={r2:.2f})"
    vo2max = slope * hrmax + intercept
    if not (VO2MAX_LO <= vo2max <= VO2MAX_HI):
        return None, f"implausible VO₂max {vo2max:.1f}"
    return (slope, intercept, r2, vo2max), "ok"


def vo2max_from_track(
    points: list[tuple[float, float, float, float | None]],
    hr_at: Callable[[float], float | None],
    hrmax: float,
) -> tuple[SubmaxResult | None, str]:
    """Estimate VO2max from a GPS track + a HR lookup.

    points : sorted list of (ts_epoch_s, lat, lng, elevation_m | None)
    hr_at  : ts_epoch_s -> heart rate (bpm) or None
    hrmax  : age-predicted HRmax (Tanaka: 208 - 0.7*age)

    Returns (SubmaxResult, "ok") or (None, reason). [[submaximal_vo2max]].
    """
    if len(points) < 10:
        return None, "too few GPS points"
    wins = steady_windows(points, hr_at)
    if wins is None:
        return None, "no usable intervals"
    pts = [(w.hr, w.vo2) for w in wins]
    speeds = [w.speed_ms for w in wins]

    if len(pts) < MIN_WINDOWS:
        return None, f"only {len(pts)} steady windows (need {MIN_WINDOWS})"
    hr_range = max(h for h, _ in pts) - min(h for h, _ in pts)
    if hr_range < MIN_HR_RANGE:
        return None, f"HR range {hr_range:.0f} bpm too narrow (need {MIN_HR_RANGE})"

    fit, reason = _fit(pts, hrmax)
    if fit is None:
        return None, reason
    slope, intercept, r2, vo2max = fit
    return (
        SubmaxResult(
            vo2max=round(vo2max, 1),
            n_windows=len(pts),
            hr_range=round(hr_range, 0),
            r2=round(r2, 2),
            slope=round(slope, 3),
            intercept=round(intercept, 1),
            speed_kmh_mean=round(sum(speeds) / len(speeds) * 3.6, 1),
        ),
        "ok",
    )
