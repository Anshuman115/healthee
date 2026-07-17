"""Daily cardiovascular load (Banister TRIMP) + time-in-HR-zones (Edwards).

Over WAKING minutes only (sleep is recovery, not load; workouts included). The
per-minute Banister term comes from ``derive/trimp`` — the ONE definition of the
load currency, shared with the per-session figure in ``read/workout``; zones by
%HRmax. HRmax from Tanaka 2001, RHR measured. Ported verbatim from legacy v2.
Knowledge: [[training_stress_score]], [[heart_rate_zones]], [[maximum_heart_rate]].
"""

from __future__ import annotations

from datetime import date, datetime
from uuid import UUID

from healthee.derive._common import Cur, _age, _day_bounds_utc, _load_profile, _upsert_daily
from healthee.derive.hr_validity import HR_VALID_BOUNDS, HR_VALID_SQL
from healthee.derive.trimp import trimp_minute

# Edwards zone lower bounds as %HRmax; zone weights are 1..5.
EDWARDS_ZONE_LO = (0.50, 0.60, 0.70, 0.80, 0.90)

_RHR_FALLBACK = 60.0  # when no measured resting HR is available


def derive_cardio_load(cur: Cur, user_id: UUID, tz: str, day: date) -> dict | None:
    """Banister TRIMP + Edwards training load over waking minutes for one day.

    None without a profile, without a usable HR reserve, or with no waking HR.
    """
    prof = _load_profile(cur, user_id, tz, day)
    if not prof:
        return None
    age = _age(prof["dob"], day)
    hrmax = 208 - 0.7 * age  # Tanaka 2001
    rhr = _measured_rhr(cur, user_id, day)
    if hrmax - rhr < 1:
        return None
    start_utc, end_utc = _day_bounds_utc(day, tz)
    cur.execute(
        "SELECT start_ts, end_ts FROM sleep_session "
        "WHERE user_id = %s AND end_ts>=%s AND start_ts<=%s",
        (user_id, start_utc, end_utc),
    )
    sleep_wins = cur.fetchall()
    cur.execute(
        "SELECT date_trunc('minute', ts) m, AVG(value) FROM sample "
        f"WHERE user_id = %s AND metric='hr' AND {HR_VALID_SQL} "
        "AND ts>=%s AND ts<=%s GROUP BY m",
        (user_id, *HR_VALID_BOUNDS, start_utc, end_utc),
    )
    rows = cur.fetchall()

    trimp, zones, n_hr = _trimp_and_zones(rows, sleep_wins, rhr, hrmax, prof["sex"])
    if n_hr == 0:
        return None
    edwards = sum((i + 1) * z for i, z in enumerate(zones))
    flags = {
        "method": "banister",
        "hrmax": round(hrmax),
        "rhr": round(rhr),
        "zone_min": zones,
        "edwards_tl": edwards,
        "hr_minutes": n_hr,
    }
    _upsert_daily(cur, user_id, day, "cardio_load", round(trimp, 1), flags)
    _upsert_daily(cur, user_id, day, "hr_zone_minutes", float(sum(zones)), {"zone_min": zones})
    return {"cardio_load": round(trimp, 1), "edwards_tl": edwards, "zone_min": zones}


def _measured_rhr(cur: Cur, user_id: UUID, day: date) -> float:
    """Most-recent measured resting HR on/before the day; falls back to 60."""
    cur.execute(
        "SELECT value FROM derived_daily WHERE user_id = %s AND metric='rhr_daily' AND day<=%s "
        "ORDER BY day DESC LIMIT 1",
        (user_id, day),
    )
    r = cur.fetchone()
    return float(r[0]) if r and r[0] is not None else _RHR_FALLBACK


def _trimp_and_zones(
    rows: list, sleep_wins: list, rhr: float, hrmax: float, sex: str | None
) -> tuple[float, list[int], int]:
    """Accumulate TRIMP and per-zone minutes over waking HR minutes."""

    def _asleep(m: datetime) -> bool:
        return any(s <= m < e for s, e in sleep_wins)

    trimp = 0.0
    zones = [0, 0, 0, 0, 0]
    n_hr = 0
    for m, hr in rows:
        if hr is None or _asleep(m):
            continue
        n_hr += 1
        hr = float(hr)
        trimp += trimp_minute(hr, rhr, hrmax, sex)
        pct = hr / hrmax
        for zi in range(4, -1, -1):  # highest zone first
            if pct >= EDWARDS_ZONE_LO[zi]:
                zones[zi] += 1
                break
    return trimp, zones, n_hr
