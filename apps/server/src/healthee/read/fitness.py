"""Fitness metric payloads — VO2max, cardio load (+ strain 0-21), MVPA, strength,
acute:chronic ratio, and the VO2max-raising plan.

Shared by ``/api/today`` and ``/api/activity``. v2-native: reads ``derived_daily``
(never the ``metric_sample`` view, never a ``source=`` filter). ``moderate_min`` /
``vigorous_min`` live inside the ``mvpa_min`` row's flags in v2 (not as their own
rows), so they are read from flags — the WP6 seam fix.

Computed-on-read formulas (strain, ACWR) are ported VERBATIM — they are the
audit-verified science, cited inline.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from healthee.analytics.biological_age import vo2max_median_for
from healthee.core.tenancy import USER_TODAY_SQL, user_today
from healthee.derive._common import Cur
from healthee.read.common import derived_series, latest_derived, sport_name

# Auto-detected sub-10-min bouts are movement noise, not structured exercise
# (WHO / US Activity Guidelines floor). Legacy ``_MIN_WORKOUT_S``.
_MIN_WORKOUT_S = 600
_STRENGTH_SPORTS = {10: "climbing", 14: "strength", 21: "hiit", 22: "core"}  # device sport codes
_STRENGTH_TYPES = {
    "strength", "weights", "weightlifting", "lifting", "gym", "resistance",
    "calisthenics", "climbing", "bouldering", "powerlifting", "crossfit",
}  # fmt: skip
_YOGA_MIN_DURATION = 30  # generic yoga counts only if >=30 min, at 50% credit


def vo2max_payload(cur: Cur, user_id: UUID, tz: str) -> dict | None:
    """Latest Jurca non-exercise VO2max + 90-day trend + submax GPS estimate.
    [[vo2max_fitness_mortality]] (Mandsager 2018); derivation [[non_exercise_vo2max]]."""
    cur.execute(
        "SELECT day, value, flags FROM derived_daily "
        "WHERE user_id = %s AND metric='vo2max_estimate' "
        f"AND day >= ({USER_TODAY_SQL} - 95) ORDER BY day",
        (user_id, tz),
    )
    rows = cur.fetchall()
    if not rows:
        return None
    trend = [{"date": d.isoformat(), "value": round(float(v), 1)} for d, v, _ in rows]
    latest_date, latest_value, flags = rows[-1][0], float(rows[-1][1]), (rows[-1][2] or {})
    age = int(flags.get("age_years") or 0)
    sex = str(flags.get("sex") or "male")
    median_ref = vo2max_median_for(age, sex) if age else None
    delta = round(latest_value - median_ref, 1) if median_ref else None
    return {
        "submax": _submax_block(cur, user_id, tz, latest_value),
        "estimate": round(latest_value, 1),
        "see_ml_kg_min": float(flags.get("see_ml_kg_min", 5.6)),
        "as_of_date": latest_date.isoformat(),
        "age_years": age,
        "sex": sex,
        "median_for_age": median_ref,
        "delta_from_median": delta,
        "trend_90d": trend,
        # v2 flag names: rhr_med_7d←rhr_med, pa_score←srpa; weekly_mvpa_min not
        # stored in v2 vo2max flags → null (documented WP7 note).
        "inputs": {
            "bmi": flags.get("bmi"),
            "rhr_med_7d": flags.get("rhr_med"),
            "weekly_mvpa_min": None,
            "pa_score": flags.get("srpa"),
        },
        "research_notes": ["vo2max_fitness_mortality", "non_exercise_vo2max"],
    }


def _submax_block(cur: Cur, user_id: UUID, tz: str, jurca_estimate: float) -> dict | None:
    """Submaximal HR-vs-pace VO2max from GPS workouts (``vo2max_submax``)."""
    cur.execute(
        "SELECT day, value, flags FROM derived_daily "
        "WHERE user_id = %s AND metric='vo2max_submax' "
        f"AND day >= ({USER_TODAY_SQL} - 95) ORDER BY day",
        (user_id, tz),
    )
    rows = cur.fetchall()
    if not rows:
        return None
    vals = sorted(float(v) for _, v, _ in rows)
    n = len(vals)
    med = vals[n // 2] if n % 2 else 0.5 * (vals[n // 2 - 1] + vals[n // 2])
    s_day, s_val, s_flags = rows[-1][0], float(rows[-1][1]), (rows[-1][2] or {})
    return {
        "latest": round(s_val, 1),
        "median": round(med, 1),
        "n_sessions": n,
        "as_of_date": s_day.isoformat(),
        "last_r2": s_flags.get("r2"),
        "last_speed_kmh": s_flags.get("speed_kmh"),
        "vs_jurca": round(med - round(jurca_estimate, 1), 1),
        "trend": [{"date": d.isoformat(), "value": round(float(v), 1)} for d, v, _ in rows],
    }


def cardio_load_payload(cur: Cur, user_id: UUID, tz: str) -> dict | None:
    """Daily cardio load (Banister TRIMP) + strain 0-21 + 30-day trend/baseline.
    [[cardio_load_trimp]]."""
    cur.execute(
        "SELECT day, value, flags FROM derived_daily "
        "WHERE user_id = %s AND metric='cardio_load' "
        f"AND day >= ({USER_TODAY_SQL} - 35) ORDER BY day",
        (user_id, tz),
    )
    rows = cur.fetchall()
    if not rows:
        return None
    trend = [{"date": d.isoformat(), "value": round(float(v), 1)} for d, v, _ in rows]
    latest_value, flags = float(rows[-1][1]), (rows[-1][2] or {})
    prior = [float(v) for _, v, _ in rows[:-1]]
    baseline = round(sum(prior) / len(prior), 1) if prior else None
    return {
        "load": round(latest_value, 1),
        "strain": _strain(cur, user_id, tz, latest_value),
        "strain_max": 21.0,
        "as_of_date": rows[-1][0].isoformat(),
        "baseline_30d": baseline,
        "zone_minutes": flags.get("zone_min"),
        "edwards_tl": flags.get("edwards_tl"),
        "hrmax": flags.get("hrmax"),
        "rhr": flags.get("rhr"),
        "hr_minutes": flags.get("hr_minutes"),
        "trend_30d": trend,
        "research_notes": ["cardio_load_trimp"],
    }


def strain_from_load(load: float, p95: float | None) -> float | None:
    """Strain 0-21: the SAME TRIMP load on a personal log scale — 0 load → 0, the
    90-day P95 ("a hard day") → 21, with a mild concave (≈log) curve tracking
    perceived exertion. Ported VERBATIM from legacy (anchored to P95, not min/max,
    so a quiet/partial day reads low, never a misleading 0). [[cardio_load_trimp]]."""
    if not (p95 and p95 > 0):
        return None
    return round(max(0.0, min(21.0, 21.0 * (load / p95) ** 0.75)), 1)


def _strain(cur: Cur, user_id: UUID, tz: str, latest_load: float) -> float | None:
    """Read the personal 90-day P95 of cardio-load and map ``latest_load`` onto 0-21."""
    cur.execute(
        "SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY value) FROM derived_daily "
        "WHERE user_id = %s AND metric='cardio_load' AND value > 0 "
        f"AND day >= ({USER_TODAY_SQL} - 90)",
        (user_id, tz),
    )
    row = cur.fetchone()
    p95 = float(row[0]) if row and row[0] else None
    return strain_from_load(latest_load, p95)


def _weekly_mvpa_rows(cur: Cur, user_id: UUID, tz: str, days: int) -> list[tuple]:
    """(day, moderate, vigorous, mvpa) for the last ``days`` days — moderate/vigorous
    read from the ``mvpa_min`` flags (v2 stores them there, not as own rows)."""
    cur.execute(
        "SELECT day, COALESCE((flags->>'moderate')::float,0), "
        "COALESCE((flags->>'vigorous')::float,0), value FROM derived_daily "
        f"WHERE user_id = %s AND metric='mvpa_min' AND day > ({USER_TODAY_SQL} - %s::int) "
        "ORDER BY day",
        (user_id, tz, days),
    )
    return cur.fetchall()


def mvpa_payload(cur: Cur, user_id: UUID, tz: str) -> dict | None:
    """Weekly moderate-to-vigorous minutes vs the WHO 150-min target + 8-day
    breakdown. [[mvpa_minutes_mortality]], [[cadence_intensity]]."""
    rows = _weekly_mvpa_rows(cur, user_id, tz, 8)
    if not rows:
        return None
    today = user_today(tz)
    monday = today - timedelta(days=today.weekday())
    daily, week_mod, week_vig, week_mvpa, today_mvpa = [], 0, 0, 0, 0
    for d, m, v, mv in rows:
        m_i, v_i, mv_i = int(m), int(v), int(mv)
        daily.append(
            {"date": d.isoformat(), "moderate_min": m_i, "vigorous_min": v_i, "mvpa_min": mv_i}
        )
        if d >= monday:
            week_mod, week_vig, week_mvpa = week_mod + m_i, week_vig + v_i, week_mvpa + mv_i
        if d == today:
            today_mvpa = mv_i
    return {
        "today_min": today_mvpa,
        "week_min": week_mvpa,
        "week_target": 150,
        "week_moderate_min": week_mod,
        "week_vigorous_min": week_vig,
        "week_start_iso": monday.isoformat(),
        "daily": daily,
        "research_notes": ["mvpa_minutes_mortality", "cadence_intensity"],
    }


def strength_payload(cur: Cur, user_id: UUID, tz: str) -> dict:
    """Weekly strength-training minutes vs the 30-60 min sweet spot (Momma 2022).
    v2-native: manual ``exercise`` logs + strength-coded device ``workout`` rows
    (legacy read the v1 ``session`` table). [[strength_training_mortality]]."""
    today = user_today(tz)
    monday = today - timedelta(days=today.weekday())
    minutes, sessions, types = _strength_manual(cur, user_id, tz, monday)
    m2, s2, t2 = _strength_workouts(cur, user_id, tz, monday)
    minutes, sessions, types = minutes + m2, sessions + s2, types | t2
    return {
        "week_min": int(round(minutes)),
        "target_low": 30,
        "target_high": 60,
        "sessions": sessions,
        "types": sorted(types),
        "week_start_iso": monday.isoformat(),
        "research_note": "strength_training_mortality",
    }


def _strength_manual(cur: Cur, user_id: UUID, tz: str, monday) -> tuple[float, int, set[str]]:
    """Strength minutes from manual ``exercise`` entries since Monday (v2-native)."""
    cur.execute(
        "SELECT ts, end_ts, name, amount FROM manual_entry "
        "WHERE user_id = %s AND kind='exercise' AND ts >= %s",
        (user_id, _monday_utc(monday, tz)),
    )
    minutes, sessions, types = 0.0, 0, set()
    for ts, end_ts, name, amount in cur.fetchall():
        ex_type = str(name or "").strip().lower()
        dur = float(amount) if amount else ((end_ts - ts).total_seconds() / 60 if end_ts else 0)
        if dur <= 0:
            continue
        if ex_type in _STRENGTH_TYPES:
            minutes, sessions = minutes + dur, sessions + 1
            types.add(ex_type)
        elif ex_type == "yoga" and dur >= _YOGA_MIN_DURATION:
            minutes, sessions = minutes + dur * 0.5, sessions + 1
            types.add("yoga")
    return minutes, sessions, types


def _strength_workouts(cur: Cur, user_id: UUID, tz: str, monday) -> tuple[float, int, set[str]]:
    """Strength minutes from strength-coded device ``workout`` rows since Monday."""
    cur.execute(
        "SELECT sport, duration_s FROM workout "
        "WHERE user_id = %s AND sport = ANY(%s) AND start_ts >= %s",
        (user_id, list(_STRENGTH_SPORTS), _monday_utc(monday, tz)),
    )
    minutes, sessions, types = 0.0, 0, set()
    for sport, dur_s in cur.fetchall():
        dur = (dur_s or 0) / 60.0
        if dur <= 0:
            continue
        minutes, sessions = minutes + dur, sessions + 1
        types.add(_STRENGTH_SPORTS[sport])
    return minutes, sessions, types


def _monday_utc(monday: date, tz: str) -> datetime:
    """UTC-aware instant for the start of the local week."""
    return datetime(monday.year, monday.month, monday.day, tzinfo=ZoneInfo(tz))


def acwr(cardio: dict | None) -> dict | None:
    """Acute:chronic workload ratio (Gabbett 2016): acute 7d mean ÷ chronic 28d mean;
    0.8-1.3 = the progressive "sweet spot". Ported VERBATIM. [[cardio_load_trimp]]."""
    vals = [
        float(t["value"]) for t in (cardio or {}).get("trend_30d", []) if t.get("value") is not None
    ]
    if len(vals) < 7:
        return None
    acute = sum(vals[-7:]) / 7.0
    chronic = sum(vals[-28:]) / min(len(vals), 28)
    if chronic <= 0:
        return None
    ratio = acute / chronic
    state = (
        "detraining"
        if ratio < 0.8
        else "optimal"
        if ratio <= 1.3
        else "caution"
        if ratio <= 1.5
        else "overreaching"
    )
    return {
        "ratio": round(ratio, 2),
        "acute_7d": round(acute, 1),
        "chronic_28d": round(chronic, 1),
        "state": state,
    }


def fitness_plan_payload(cur: Cur, user_id: UUID, tz: str) -> dict | None:
    """VO2max-raising weekly Rx + a 12-week projected trajectory (an estimate of
    typical response, bounded +2..+5 ml/kg/min, never a promise). [[vo2max_training_program]]."""
    vo = vo2max_payload(cur, user_id, tz)
    if not vo or vo.get("estimate") is None:
        return None
    cur_vo = float(vo["estimate"])
    median = float(vo.get("median_for_age") or 41)
    gain = round(min(5.0, max(2.0, 0.4 * max(0.0, median - cur_vo))), 1)
    today = user_today(tz)
    monday = today - timedelta(days=today.weekday())
    wk = {m: 0.0 for m in ("moderate_min", "vigorous_min")}
    for _d, mod, vig, _mv in _weekly_mvpa_rows(cur, user_id, tz, (today - monday).days + 1):
        wk["moderate_min"] += mod
        wk["vigorous_min"] += vig
    return {
        "current": round(cur_vo, 1),
        "projected_12wk": round(cur_vo + gain, 1),
        "gain": gain,
        "median_for_age": round(median, 1),
        "weeks": 12,
        "plan": {
            "zone2_target_min": 90,
            "zone2_done_min": round(wk["moderate_min"]),
            "zone2_desc": "3 × 30 min easy aerobic — Zone 2, conversational pace",
            "vilpa_target_min": 15,
            "vilpa_done_min": round(wk["vigorous_min"]),
            "vilpa_desc": "1 hard session — 4-5 × 1-min brisk-to-hard bursts "
            "(stairs / hill / fast walk)",
        },
        "note_id": "vo2max_training_program",
        "trend_90d": vo.get("trend_90d") or [],
    }


def activity_metric(
    cur: Cur, user_id: UUID, tz: str, candidates: list[str], days: int = 30
) -> dict | None:
    """Latest value + date + N-day series for the first candidate metric with data
    (steps/calories/distance). v2-native ``derived_daily`` read."""
    for cand in candidates:
        latest = latest_derived(cur, user_id, cand)
        if latest:
            day, value, _flags = latest
            return {
                "metric": cand,
                "value": round(value, 1),
                "as_of_date": day.isoformat(),
                "trend": derived_series(cur, user_id, tz, cand, days),
            }
    return None


def workouts_list(cur: Cur, user_id: UUID, limit: int = 100) -> list[dict]:
    """Device-recorded workouts (>=10 min) with HR detail, newest first."""
    cur.execute(
        "SELECT start_ts, sport, duration_s, calories, distance_m, avg_hr, max_hr, min_hr "
        "FROM workout WHERE user_id = %s AND COALESCE(duration_s, 0) >= %s "
        "ORDER BY start_ts DESC LIMIT %s",
        (user_id, _MIN_WORKOUT_S, limit),
    )
    out = []
    for start_ts, sport, dur_s, cal, dist, avg_hr, max_hr, min_hr in cur.fetchall():
        out.append(
            {
                "start_iso": start_ts.isoformat() if start_ts else None,
                "sport": sport,
                "sport_name": sport_name(sport),
                "duration_min": round((dur_s or 0) / 60) if dur_s else None,
                "calories": int(cal) if cal is not None else None,
                "distance_m": float(dist) if dist is not None else None,
                "avg_hr": int(avg_hr) if avg_hr is not None else None,
                "max_hr": int(max_hr) if max_hr is not None else None,
                "min_hr": int(min_hr) if min_hr is not None else None,
            }
        )
    return out
