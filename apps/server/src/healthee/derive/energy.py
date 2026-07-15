"""Daily energy expenditure (calories) — free-living, MET-by-state, BMR-anchored.

Total EE is built minute-by-minute from a MET assigned to each minute's state
(walking from steps via ACSM | asleep | awake-NEAT), anchored so 1 MET == BMR/min
(Mifflin-St Jeor). Heart rate is deliberately NOT used for free-living EE — without
raw accelerometry it can't separate awake-rest from activity and overcounts. Ported
verbatim from legacy v2. Knowledge: ``energy_expenditure_derivation``.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta

from healthee.derive._common import Cur, _age, _scalar, _upsert_daily

# Awake non-step NEAT — context-aware by step proximity instead of a flat value.
# A flat 1.4 overcounts long sedentary stretches (Compendium: sitting-quiet 1.3)
# AND undercounts time up-and-about between strides (standing/light 1.5-1.8). So
# each non-step waking minute is classified: near step activity (within
# +/-NEAT_WINDOW min) => up & moving ~1.55; isolated => seated/resting ~1.3.
AWAKE_SEDENTARY_MET = 1.3  # Compendium 07021 — sitting quietly
AWAKE_ACTIVE_MET = 1.55  # standing / light household between steps
NEAT_WINDOW = 7  # minutes either side to look for movement
SLEEP_MET = 0.95  # sleep is ~0.9-0.95 x RMR

_WALK_RUN_SPEED_M_MIN = 134  # ACSM equation switch (m/min): walking vs running VO2


def _tee_met(
    cur: Cur, start_utc: datetime, end_utc: datetime, bmr: float, stride_m: float
) -> float:
    """Total EE for one day via state->MET, anchored to BMR (1 MET == BMR/min).

    Per minute: walking (ACSM, from steps) | asleep (0.95) | awake-NEAT
    (1.3/1.55). Workout minutes are excluded — counted via the device's measured
    calories by the caller.
    """
    bmr_min = bmr / 1440.0
    cur.execute(
        "SELECT start_ts, end_ts FROM sleep_session WHERE end_ts>=%s AND start_ts<=%s",
        (start_utc, end_utc),
    )
    sleep_wins = cur.fetchall()
    cur.execute(
        "SELECT start_ts, duration_s FROM workout WHERE start_ts>=%s AND start_ts<=%s",
        (start_utc, end_utc),
    )
    wk_wins = [(w[0], w[0] + timedelta(seconds=int(w[1] or 0))) for w in cur.fetchall()]
    cur.execute(
        "SELECT date_trunc('minute', ts) m, SUM(value) FROM sample "
        "WHERE metric='steps_per_minute' AND value < 250 AND ts>=%s AND ts<=%s GROUP BY m",
        (start_utc, end_utc),
    )
    steps_by_min = {r[0]: float(r[1]) for r in cur.fetchall()}

    def _asleep(m: datetime) -> bool:
        return any(s <= m < e for s, e in sleep_wins)

    def _in_wk(m: datetime) -> bool:
        return any(s <= m < e for s, e in wk_wins)

    total = 0.0
    base = start_utc.replace(second=0, microsecond=0)
    for i in range(1440):
        m = base + timedelta(minutes=i)
        if _in_wk(m):
            continue
        total += _minute_met(m, steps_by_min, stride_m, _asleep) * bmr_min
    return total


def _minute_met(m: datetime, steps_by_min: dict, stride_m: float, is_asleep) -> float:
    """MET for one minute: walking (ACSM) | asleep | seated/active NEAT."""
    st = steps_by_min.get(m, 0.0)
    if st > 0:
        speed = st * stride_m  # m/min
        vo2 = (0.2 * speed + 3.5) if speed >= _WALK_RUN_SPEED_M_MIN else (0.1 * speed + 3.5)
        return vo2 / 3.5
    if is_asleep(m):
        return SLEEP_MET
    # awake, no steps this minute: seated unless step activity is nearby (then the
    # person is up & moving between strides).
    near = any(
        (m + timedelta(minutes=k)) in steps_by_min for k in range(-NEAT_WINDOW, NEAT_WINDOW + 1)
    )
    return AWAKE_ACTIVE_MET if near else AWAKE_SEDENTARY_MET


def derive_calories(
    cur: Cur,
    day: date,
    prof: dict,
    start_utc: datetime,
    end_utc: datetime,
    stride_m: float,
) -> dict:
    """Total / active / basal calories for one local day; upserts all three.

    BMR from Mifflin-St Jeor; TEE from the MET-by-state model plus the device's
    measured workout calories; active = TEE - BMR (floored at 0).
    """
    age = _age(prof["dob"], day)
    bmr = (
        10 * prof["weight_kg"]
        + 6.25 * prof["height_cm"]
        - 5 * age
        + (5 if prof["sex"] == "male" else -161)
    )
    total = _tee_met(cur, start_utc, end_utc, bmr, stride_m)
    cur.execute(
        "SELECT COALESCE(SUM(calories),0) FROM workout WHERE start_ts >= %s AND start_ts <= %s",
        (start_utc, end_utc),
    )
    workout_cal = _scalar(cur)
    total += workout_cal
    active_total = max(0.0, total - bmr)
    flags = {
        "bmr": round(bmr),
        "workout_cal": round(workout_cal),
        "stride_m": round(stride_m, 3),
        "pal": round(total / bmr, 2),
    }
    _upsert_daily(cur, day, "total_calories", total, flags)
    _upsert_daily(cur, day, "active_calories", active_total)
    _upsert_daily(cur, day, "basal_calories", bmr)
    return {
        "total_calories": round(total),
        "active_calories": round(active_total),
        "basal_calories": round(bmr),
    }
