"""The ``derived_daily`` half of the contract fixture — 30 steady days, one per metric.

Split out of ``seed.py`` in #117, which took that file past the 400-line gate. The two
have different reasons to change: ``seed.py`` seeds the raw tables a read endpoint joins,
this one seeds the DERIVED layer whose values the snapshots pin — and the derived layer is
where a science change lands.
"""

from __future__ import annotations

import json
from datetime import date, timedelta

from healthee.core.tenancy import SENTINEL_USER_ID


def _dd(cur, day: date, metric: str, value: float, flags: dict | None = None) -> None:
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) VALUES (%s,%s,%s,%s,%s) "
        "ON CONFLICT (user_id, day, metric) DO UPDATE SET "
        "value=EXCLUDED.value, flags=EXCLUDED.flags",
        (SENTINEL_USER_ID, day, metric, value, json.dumps(flags or {})),
    )


def seed_derived(cur, today: date) -> None:
    """derived_daily rows across a 30-day window (steady values → stable baselines)."""
    for n in range(30):
        day = today - timedelta(days=n)
        seed_derived_day(cur, day, today)


def seed_derived_day(cur, day: date, today: date) -> None:
    sleep_flags = {
        "tst_min": 380,
        "tib_min": 450,
        "efficiency_pct": 84.4,
        "midpoint_local": f"{day.isoformat()}T02:45:00+05:30",
        "session_source": "zepp_cloud",
        "sri": 74.0,
    }
    _dd(cur, day, "rhr_daily", 55.0, {"n": 120})
    _dd(cur, day, "hrv_sleep_avg", 45.0)
    _dd(cur, day, "spo2_overnight", 97.0)
    _dd(cur, day, "spo2_overnight_min", 93.0)
    _dd(cur, day, "respiratory_rate_sleep", 14.0)
    _dd(cur, day, "sleep_health_score_4dim", 3, sleep_flags)
    for dim in ("duration", "efficiency", "timing", "regularity"):
        _dd(cur, day, f"sleep_dim_{dim}", 1 if dim != "timing" else 0, sleep_flags)
    _dd(cur, day, "sleep_regularity_index", 74.0, sleep_flags)
    _dd(cur, day, "sleep_need_min", 480.0, {"basis": "NSF2015", "age": 35})
    _dd(
        cur,
        day,
        "sleep_debt_min",
        120.0,
        {
            "window_nights": 14,
            "nights": 14,
            "avg_tst_min": 380,
            "avg_deficit_min": 100,
            "nights_below": 12,
        },
    )
    _dd(cur, day, "steps_total", 8200.0)
    _dd(cur, day, "distance_m_daily", 6100.0, {"method": "stride", "stride_m": 0.744})
    _dd(cur, day, "total_calories", 2350.0)
    _dd(cur, day, "active_calories", 620.0)
    _dd(cur, day, "basal_calories", 1730.0)
    _dd(cur, day, "mvpa_min", 32.0, {"moderate": 24, "vigorous": 4})
    _dd(
        cur,
        day,
        "cardio_load",
        55.0,
        {
            "method": "banister",
            "hrmax": 185,
            "rhr": 55,
            "zone_min": [20, 15, 8, 3, 1],
            "edwards_tl": 120,
            "hr_minutes": 47,
        },
    )
    _dd(
        cur,
        day,
        "recovery_score",
        72.0,
        {
            "factors": {
                "sleep": {"sub": 60},
                "hrv": {"sub": 80},
                "rhr": {"sub": 70},
                "rr": {"sub": 75},
            },
            "weights": {"sleep": 0.4, "hrv": 0.3, "rhr": 0.2, "rr": 0.1},
        },
    )
    if day == today:
        # A recorded session on the snapshot's "today", and the estimate that follows
        # from it (#117). `vo2max_estimate` is tiered — a graded GPS fit inside the
        # freshness horizon IS the estimate, and the fallback model does not run — so
        # seeding a Jurca row alongside a same-day graded session, as this file did
        # until #117, describes a state the derivation cannot produce.
        _dd(cur, day, "vo2max_submax", 43.0, {"method": "gps_graded", "r2": 0.82, "speed_kmh": 8.1})
        _dd(
            cur,
            day,
            "vo2max_estimate",
            43.0,
            {
                "method": "gps_graded",
                "n_sessions": 1,
                "measured_first_day": day.isoformat(),
                "measured_as_of": day.isoformat(),
                "measured_age_days": 0,
                "hrr_median": None,
                # Carrier 2023's MAPE, not Jurca's SEE: 43.0 × 0.0685.
                "see_ml_kg_min": 2.95,
                "see_source": ("Carrier 2023: MAPE 6.85% vs lab CPET, structured outdoor running"),
                "age_years": 35,
                "sex": "male",
            },
        )
        return
    _dd(
        cur,
        day,
        "vo2max_estimate",
        41.5,
        {
            # The fallback tier, on the days with no recorded session (#117).
            "method": "jurca_non_exercise",
            "rhr_med": 55.0,
            # SR-PA 2, matching the profile this seeder writes — the owner's answer,
            # not a category derived from step cadence (#108). `see_ml_kg_min` is
            # Jurca 2005's published NASA SEE of 1.45 METs × 3.5, replacing an
            # unsourced 5.6 that appears nowhere in the paper.
            "srpa": 2,
            "bmi": 23.4,
            "age_years": 35,
            "sex": "male",
            "see_ml_kg_min": 5.075,
        },
    )
