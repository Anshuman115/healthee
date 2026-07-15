"""Daily cardiovascular load (Banister TRIMP) + time-in-HR-zones (Edwards).

Over WAKING minutes only (sleep is recovery, not load; workouts included). Load
per minute = HR-reserve fraction (Karvonen) weighted by the sex-specific lactate
term; zones by %HRmax. HRmax from Tanaka 2001, RHR measured. Ported verbatim from
legacy v2. Knowledge: ``cardio_load_trimp``, ``heart_rate_zones``,
``maximum_heart_rate``.
"""

from __future__ import annotations

import math
from datetime import date, datetime

from healthee.derive._common import Cur, _age, _day_bounds_utc, _load_profile, _upsert_daily

# (a, b) in the Banister weighting a * e^(b * dHR); dHR = HR-reserve fraction.
TRIMP_W = {"male": (0.64, 1.92), "female": (0.86, 1.67)}
# Edwards zone lower bounds as %HRmax; zone weights are 1..5.
EDWARDS_ZONE_LO = (0.50, 0.60, 0.70, 0.80, 0.90)

_RHR_FALLBACK = 60.0  # when no measured resting HR is available


def derive_cardio_load(cur: Cur, day: date) -> dict | None:
    """Banister TRIMP + Edwards training load over waking minutes for one day.

    None without a profile, without a usable HR reserve, or with no waking HR.
    """
    prof = _load_profile(cur, day)
    if not prof:
        return None
    age = _age(prof["dob"], day)
    hrmax = 208 - 0.7 * age  # Tanaka 2001
    rhr = _measured_rhr(cur, day)
    if hrmax - rhr < 1:
        return None
    start_utc, end_utc = _day_bounds_utc(day)
    cur.execute(
        "SELECT start_ts, end_ts FROM sleep_session WHERE end_ts>=%s AND start_ts<=%s",
        (start_utc, end_utc),
    )
    sleep_wins = cur.fetchall()
    cur.execute(
        "SELECT date_trunc('minute', ts) m, AVG(value) FROM sample "
        "WHERE metric='hr' AND value BETWEEN 30 AND 220 AND ts>=%s AND ts<=%s GROUP BY m",
        (start_utc, end_utc),
    )
    rows = cur.fetchall()

    a, b = TRIMP_W.get(prof["sex"], TRIMP_W["male"])
    trimp, zones, n_hr = _trimp_and_zones(rows, sleep_wins, rhr, hrmax, a, b)
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
    _upsert_daily(cur, day, "cardio_load", round(trimp, 1), flags)
    _upsert_daily(cur, day, "hr_zone_minutes", float(sum(zones)), {"zone_min": zones})
    return {"cardio_load": round(trimp, 1), "edwards_tl": edwards, "zone_min": zones}


def _measured_rhr(cur: Cur, day: date) -> float:
    """Most-recent measured resting HR on/before the day; falls back to 60."""
    cur.execute(
        "SELECT value FROM derived_daily WHERE metric='rhr_daily' AND day<=%s "
        "ORDER BY day DESC LIMIT 1",
        (day,),
    )
    r = cur.fetchone()
    return float(r[0]) if r and r[0] is not None else _RHR_FALLBACK


def _trimp_and_zones(
    rows: list, sleep_wins: list, rhr: float, hrmax: float, a: float, b: float
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
        dhr = max(0.0, min(1.0, (hr - rhr) / (hrmax - rhr)))
        trimp += dhr * a * math.exp(b * dhr)
        pct = hr / hrmax
        for zi in range(4, -1, -1):  # highest zone first
            if pct >= EDWARDS_ZONE_LO[zi]:
                zones[zi] += 1
                break
    return trimp, zones, n_hr
