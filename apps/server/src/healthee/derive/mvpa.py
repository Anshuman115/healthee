"""Cadence-based moderate-to-vigorous physical activity minutes for one day.

Per-minute step cadence classifies each minute: moderate at >=100 steps/min
(with a >=80 prior minute), vigorous at >=130 (with a >=110 prior). Ported
verbatim from legacy v2 ``derive_mvpa``. Knowledge: ``cadence_intensity``
(Tudor-Locke 2018), ``mvpa_minutes_mortality`` (the 150 min/week target).
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from uuid import UUID

from healthee.derive._common import Cur, _day_bounds_utc, _upsert_daily

# Cadence thresholds (steps/min) with a one-minute "prior" gate [[cadence_intensity]].
_MODERATE_SPM = 100
_MODERATE_PRIOR_SPM = 80
_VIGOROUS_SPM = 130
_VIGOROUS_PRIOR_SPM = 110


def _weekly_mvpa_to_srpa(weekly_mvpa_equiv_min: float) -> int:
    """Weekly MVPA-EQUIVALENT minutes -> Jurca SRPA category (0-4).

    Input is the WHO-weighted weekly total (moderate + 2*vigorous — 1 vigorous
    minute counts as 2 moderate; computed by the caller from the daily flags
    [[cadence_intensity]]). Bands map to Jurca's five self-reported physical-
    activity levels [[non_exercise_vo2max]]:
        0: <10   1: 10-19   2: 20-59   3: 60-179   4: >=180  (min/week)
    """
    if weekly_mvpa_equiv_min < 10:
        return 0
    if weekly_mvpa_equiv_min < 20:
        return 1
    if weekly_mvpa_equiv_min < 60:
        return 2
    if weekly_mvpa_equiv_min < 180:
        return 3
    return 4


def derive_mvpa(cur: Cur, user_id: UUID, day: date) -> dict | None:
    """Cadence-based MVPA minutes for one local day. None when no steps recorded."""
    start_utc, end_utc = _day_bounds_utc(day)
    cur.execute(
        "SELECT ts, value FROM sample WHERE metric='steps_per_minute' "
        "AND value>0 AND value<250 AND ts>=%s AND ts<=%s ORDER BY ts",
        (start_utc, end_utc),
    )
    rows = cur.fetchall()
    if not rows:
        return None
    by_min: dict[datetime, float] = {}
    for ts, v in rows:
        k = ts.replace(second=0, microsecond=0)
        by_min[k] = max(by_min.get(k, 0.0), float(v))
    moderate = vigorous = 0
    for ts, spm in by_min.items():
        if spm < _MODERATE_SPM:
            continue
        prev = by_min.get(ts - timedelta(minutes=1), 0.0)
        if spm >= _VIGOROUS_SPM and prev >= _VIGOROUS_PRIOR_SPM:
            vigorous += 1
        elif prev >= _MODERATE_PRIOR_SPM:
            moderate += 1
    mvpa = moderate + vigorous
    _upsert_daily(cur, user_id, day, "mvpa_min", mvpa, {"moderate": moderate, "vigorous": vigorous})
    return {"mvpa_min": mvpa, "moderate": moderate, "vigorous": vigorous}
