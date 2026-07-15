"""Daily step, distance, and calorie totals for one local day.

Steps summed from per-minute samples; distance from steps x stride
(0.414 x height); calories delegated to the MET-by-state energy model. Ported
verbatim from legacy v2 ``derive_daily_activity``. Knowledge:
``distance_from_steps``, ``steps_mortality``, ``energy_expenditure_derivation``.
"""

from __future__ import annotations

from datetime import date

from healthee.derive._common import Cur, _day_bounds_utc, _load_profile, _scalar, _upsert_daily
from healthee.derive.energy import derive_calories

_STRIDE_HEIGHT_FRACTION = 0.414  # stride length ~= 0.414 x height [[distance_from_steps]]


def derive_daily_activity(cur: Cur, day: date) -> dict:
    """steps_total, distance_m_daily, and total/active/basal calories for a day.

    steps_total is always upserted (0 is valid, so re-derivation overwrites stale
    rows). Distance and calories need a profile (height/sex/dob + a logged weight)
    and are skipped when it is absent.
    """
    out: dict = {}
    start_utc, end_utc = _day_bounds_utc(day)

    cur.execute(
        "SELECT COALESCE(SUM(value),0) FROM sample WHERE metric='steps_per_minute' "
        "AND value < 250 AND ts >= %s AND ts <= %s",
        (start_utc, end_utc),
    )
    steps = _scalar(cur)
    _upsert_daily(cur, day, "steps_total", steps)
    out["steps_total"] = round(steps, 0)

    prof = _load_profile(cur, day)
    if prof:
        stride_m = _STRIDE_HEIGHT_FRACTION * prof["height_cm"] / 100.0
        dist = steps * stride_m
        _upsert_daily(
            cur, day, "distance_m_daily", dist, {"method": "stride", "stride_m": round(stride_m, 3)}
        )
        out["distance_m_daily"] = round(dist, 0)
        out.update(derive_calories(cur, day, prof, start_utc, end_utc, stride_m))
    return out
