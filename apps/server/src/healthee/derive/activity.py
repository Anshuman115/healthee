"""Daily step, distance, and calorie totals for one local day.

Steps come from the tiered choice in ``derive/device_totals.py`` — the strap's own daily
counter when it reported one, the per-minute sample sum otherwise (#121). Distance is the
device's metres, else steps × stride (0.414 × height); calories are delegated to the
MET-by-state energy model. Ported verbatim from legacy v2 ``derive_daily_activity``; the
step/distance PRECEDENCE is the one thing that is not legacy's, because legacy had none —
the strap counter was pasted over this pass's output after the fact and destroyed by the
next one. Knowledge: [[distance_from_steps]], [[steps_mortality]],
[[energy_expenditure_derivation]].
"""

from __future__ import annotations

from datetime import date, datetime
from uuid import UUID

from healthee.derive._common import Cur, _day_bounds_utc, _load_profile, _scalar, _upsert_daily
from healthee.derive.device_totals import device_total, select_distance, select_steps
from healthee.derive.energy import derive_calories

_STRIDE_HEIGHT_FRACTION = 0.414  # stride length ~= 0.414 x height [[distance_from_steps]]


def _steps_per_minute_sum(cur: Cur, user_id: UUID, start_utc: datetime, end_utc: datetime) -> float:
    """The day's steps as the per-minute stream reports them — the FALLBACK tier.

    Values >= 250 steps/min are excluded as implausible for a wrist counter. This sum is
    what ``steps_total`` used to be unconditionally; ``device_totals.select_steps`` decides
    whether it is what the day gets.
    """
    cur.execute(
        "SELECT COALESCE(SUM(value),0) FROM sample "
        "WHERE user_id = %s AND metric='steps_per_minute' "
        "AND value < 250 AND ts >= %s AND ts < %s",  # half-open: see `_day_bounds_utc`
        (user_id, start_utc, end_utc),
    )
    return _scalar(cur)


def derive_daily_activity(cur: Cur, user_id: UUID, tz: str, day: date) -> dict:
    """steps_total, distance_m_daily, and total/active/basal calories for a day.

    steps_total is always upserted (0 is valid, so re-derivation overwrites stale rows) and
    always carries its instrument in ``flags.source``. Distance needs either a device-
    reported figure or a profile (for the stride); calories additionally need a logged
    weight, and are skipped when the profile is absent.
    """
    out: dict = {}
    start_utc, end_utc = _day_bounds_utc(day, tz)

    device = device_total(cur, user_id, day)
    steps = select_steps(device, _steps_per_minute_sum(cur, user_id, start_utc, end_utc))
    _upsert_daily(cur, user_id, day, "steps_total", steps.value, steps.flags)
    out["steps_total"] = round(steps.value, 0)

    prof = _load_profile(cur, user_id, tz, day)
    stride_m = _STRIDE_HEIGHT_FRACTION * prof["height_cm"] / 100.0 if prof else None
    dist = select_distance(device, steps, stride_m)
    if dist is not None:
        _upsert_daily(cur, user_id, day, "distance_m_daily", dist.value, dist.flags)
        out["distance_m_daily"] = round(dist.value, 0)
    if prof and stride_m is not None:
        out.update(derive_calories(cur, user_id, day, prof, start_utc, end_utc, stride_m))
    return out
