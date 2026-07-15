"""Sleep regularity, the 4-dimension sleep-health score, and sleep need/debt.

All three port the legacy v2 methodology verbatim — only the plumbing changed.
Knowledge notes: ``sleep_regularity_index`` (SRI; Phillips 2017, Windred 2024),
``sleep_score_implementation_plan`` + ``sleep_health_score_multidim`` +
``no_validated_sleep_score`` (the 4-dim RU-SATED-style binary sum, shown with its
dimensions and never as a single validated "score"), ``sleep_need_debt`` (age
sleep need + rolling cumulative debt with partial recovery credit).
"""

from __future__ import annotations

from collections import defaultdict
from datetime import UTC, date, datetime, timedelta

from healthee.derive._common import USER_TZ, Cur, _age, _load_profile, _upsert_daily

# ── 4-dimension sleep score cutoffs — sleep_score_implementation_plan ─────────
SLEEP_DURATION_MIN_H, SLEEP_DURATION_MAX_H = 7.0, 9.0  # Cappuccio 2010
SLEEP_EFFICIENCY_MIN = 0.85  # AASM
SLEEP_TIMING_RANGE = (2, 4)  # Buysse 2014 (midpoint hour)
SRI_GOOD = 70.0  # Windred 2024
SRI_DAYS = 7  # Phillips 2017 minimum window

# ── Sleep need / debt — sleep_need_debt ──────────────────────────────────────
SLEEP_NEED_MIN_18_64 = 480  # NSF 2015 midpoint of 7-9 h
SLEEP_NEED_MIN_65P = 450  # midpoint of 7-8 h
SLEEP_DEBT_WINDOW = 14  # rolling nights
SLEEP_RECOVERY_CREDIT = 0.5  # surplus sleep repays debt at half value (partial recovery)

_AWAKE_STAGE = 7  # stage type code for "awake" in the hypnogram triples


def _sleep_efficiency(tst_min: int, wake_min: int) -> float:
    """Sleep efficiency from the sleep timeline: asleep / (asleep + awake-in-bed).

    Bounded to [0, 1] by construction (belt-and-suspenders clamp), so
    ``efficiency_pct`` can never exceed 100. Legacy divided TST by wall-clock TIB,
    which could report an impossible >100% when the staged asleep+wake minutes
    overshot the session span. [[no_validated_sleep_score]].
    """
    total = tst_min + wake_min
    return min(1.0, tst_min / total) if total > 0 else 0.0


def _compute_sri(cur: Cur, night_date: date) -> float | None:
    """Sleep Regularity Index over the 7-day window ending on `night_date`.

    Built from main-sleep hypnogram stages (asleep = any non-awake stage): the
    percentage agreement, at one-minute resolution, that the person is in the same
    sleep/wake state 24 h apart, mapped to -100..100. None until 7 days are
    present. Phillips 2017 [[sleep_regularity_index]].
    """
    start_local = datetime(
        night_date.year, night_date.month, night_date.day, tzinfo=USER_TZ
    ) - timedelta(days=SRI_DAYS - 1)
    end_local = start_local + timedelta(days=SRI_DAYS)
    cur.execute(
        "SELECT stages FROM sleep_session WHERE kind='main' AND end_ts>=%s AND start_ts<%s",
        (start_local.astimezone(UTC), end_local.astimezone(UTC)),
    )
    grid = _sri_minute_grid(cur.fetchall(), start_local.date())
    if len(grid) < SRI_DAYS:
        return None
    minutes_per_day, days = 1440, SRI_DAYS
    matches = 0
    for j in range(days - 1):
        matches += minutes_per_day - len(grid[j] ^ grid[j + 1])
    return round(-100.0 + (200.0 / (minutes_per_day * (days - 1))) * matches, 2)


def _sri_minute_grid(rows: list, start_date: date) -> dict[int, set[int]]:
    """Map each day-index -> set of minute-of-day the person is asleep."""
    grid: dict[int, set[int]] = defaultdict(set)
    for (stages,) in rows:
        for st in stages or []:
            if st[2] == _AWAKE_STAGE:
                continue
            start = datetime.fromtimestamp(st[0] / 1000, tz=UTC)
            end = datetime.fromtimestamp(st[1] / 1000, tz=UTC)
            minute = start
            while minute < end:
                local = minute.astimezone(USER_TZ)
                day_index = (local.date() - start_date).days
                if 0 <= day_index < SRI_DAYS:
                    grid[day_index].add(local.hour * 60 + local.minute)
                minute += timedelta(minutes=1)
    return grid


def derive_sleep_score(
    cur: Cur,
    start_ts: datetime,
    end_ts: datetime,
    rem: int,
    light: int,
    deep: int,
    wake: int,
    night_date: date,
) -> dict:
    """4-dimension sleep-health score (duration, efficiency, timing, regularity).

    Each dimension is a 0/1 point; the score is their sum (0-4). Written both as
    the composite and as per-dimension metrics (legacy reads the dimensions as
    separate 0/1 rows). Raw measurements ride along in `flags`. Never presented as
    a single validated score [[no_validated_sleep_score]].
    """
    tst = light + deep + rem
    tib = max(1, int((end_ts - start_ts).total_seconds() / 60))  # raw wall-clock span
    p_dur = 1 if SLEEP_DURATION_MIN_H <= tst / 60.0 <= SLEEP_DURATION_MAX_H else 0
    eff = _sleep_efficiency(tst, wake)  # <= 1 by construction (never >100%)
    p_eff = 1 if (tst > 0 and eff >= SLEEP_EFFICIENCY_MIN) else 0
    mid = (start_ts + (end_ts - start_ts) / 2).astimezone(USER_TZ)
    p_tim = 1 if SLEEP_TIMING_RANGE[0] <= mid.hour < SLEEP_TIMING_RANGE[1] else 0
    sri = _compute_sri(cur, night_date)
    p_reg = 1 if (sri is not None and sri >= SRI_GOOD) else 0
    score = p_dur + p_eff + p_tim + p_reg
    flags = {
        "duration": p_dur,
        "efficiency": p_eff,
        "timing": p_tim,
        "regularity": p_reg,
        "tst_min": tst,
        "tib_min": tib,
        "efficiency_pct": round(eff * 100, 1),
        "midpoint_local": mid.isoformat(),
        "midpoint_hr": mid.hour,
        "sri": sri,
        "session_source": "zepp_cloud",
    }
    _upsert_daily(cur, night_date, "sleep_health_score_4dim", score, flags)
    _upsert_daily(cur, night_date, "sleep_dim_duration", p_dur, flags)
    _upsert_daily(cur, night_date, "sleep_dim_efficiency", p_eff, flags)
    _upsert_daily(cur, night_date, "sleep_dim_timing", p_tim, flags)
    _upsert_daily(cur, night_date, "sleep_dim_regularity", p_reg, flags)
    if sri is not None:
        _upsert_daily(cur, night_date, "sleep_regularity_index", sri, flags)
    return {"sleep_health_score_4dim": score, "sri": sri}


def derive_sleep_debt(cur: Cur, day: date) -> dict | None:
    """Age-based sleep need (NSF 2015) + rolling 14-night cumulative debt.

    Debt = shortfall minus half the surplus (partial recovery), over recorded
    nights only — no artificial cap, so a real chronic deficit shows in full.
    Reads TST from the sleep-score flags. None without a profile or any recorded
    night. [[sleep_need_debt]].
    """
    prof = _load_profile(cur, day)
    if not prof:
        return None
    age = _age(prof["dob"], day)
    need = SLEEP_NEED_MIN_65P if age >= 65 else SLEEP_NEED_MIN_18_64
    cur.execute(
        "SELECT (flags->>'tst_min')::float FROM derived_daily "
        "WHERE metric='sleep_health_score_4dim' AND day<=%s AND day>%s "
        "AND flags ? 'tst_min' ORDER BY day",
        (day, day - timedelta(days=SLEEP_DEBT_WINDOW)),
    )
    tsts = [float(t[0]) for t in cur.fetchall() if t[0] is not None]
    if not tsts:
        return None
    shortfall = sum(max(0.0, need - t) for t in tsts)
    surplus = sum(max(0.0, t - need) for t in tsts)
    debt = max(0.0, shortfall - SLEEP_RECOVERY_CREDIT * surplus)
    avg_tst = sum(tsts) / len(tsts)
    avg_deficit = max(0.0, need - avg_tst)
    nights_below = sum(1 for t in tsts if t < need)
    _upsert_daily(cur, day, "sleep_need_min", float(need), {"basis": "NSF2015", "age": age})
    _upsert_daily(
        cur,
        day,
        "sleep_debt_min",
        round(debt, 0),
        {
            "window_nights": SLEEP_DEBT_WINDOW,
            "nights": len(tsts),
            "avg_tst_min": round(avg_tst),
            "avg_deficit_min": round(avg_deficit),
            "nights_below": nights_below,
            "recovery_credit": SLEEP_RECOVERY_CREDIT,
        },
    )
    return {
        "sleep_need_min": need,
        "sleep_debt_min": round(debt),
        "avg_deficit_min": round(avg_deficit),
    }
