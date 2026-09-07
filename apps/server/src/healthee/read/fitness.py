"""Fitness metric payloads — cardio load (+ strain 0-21), MVPA, strength,
and the VO2max-raising plan.

Shared by ``/api/today`` and ``/api/activity``. v2-native: reads ``derived_daily``
(never the ``metric_sample`` view, never a ``source=`` filter). ``moderate_min`` /
``vigorous_min`` live inside the ``mvpa_min`` row's flags in v2 (not as their own
rows), so they are read from flags — the WP6 seam fix.

``vo2max_payload`` lived here until its freshness gate pushed this file past the
400-line limit; it moved to ``read/vo2max.py`` with the submax block it owns. That
was the right home anyway — "what do we know about aerobic fitness today" is not a
training-load concern (standards §1: a file has one reason to change).

``acwr`` moved to ``read/acwr.py`` when its own argument pushed this file past the
400-line limit. That was the right home too: the ratio's governing note is graded
Contested and its evidence is still moving, which is a different reason to change from
anything else here.

The strain formula is ported VERBATIM — audit-verified science, cited inline.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from uuid import UUID

from healthee.core.tenancy import AS_OF_DAY_SQL, reference_day
from healthee.derive._common import Cur, _day_bounds_utc
from healthee.derive.freshness import NOT_DERIVED_YET_MESSAGE, unavailable_reason, withheld_block
from healthee.read.common import derived_series, latest_derived, sport_name
from healthee.read.mvpa_week import mvpa_week, weekly_mvpa_rows
from healthee.read.vo2max import vo2max_payload

# Auto-detected sub-10-min bouts are movement noise, not structured exercise
# (WHO / US Activity Guidelines floor). Legacy ``_MIN_WORKOUT_S``.
_MIN_WORKOUT_S = 600
_STRENGTH_SPORTS = {10: "climbing", 14: "strength", 21: "hiit", 22: "core"}  # device sport codes
_STRENGTH_TYPES = {
    "strength", "weights", "weightlifting", "lifting", "gym", "resistance",
    "calisthenics", "climbing", "bouldering", "powerlifting", "crossfit",
}  # fmt: skip
_YOGA_MIN_DURATION = 30  # generic yoga counts only if >=30 min, at 50% credit

# The window ``baseline_30d`` and ``trend_30d`` are BOTH named after. It read
# ``as_of - 35`` — thirty-SIX days behind two keys that say thirty — so the baseline a
# ratio is drawn against, and the chart beside it, covered a window neither name
# described. One window, one length, and the two names now tell the truth.
_LOAD_WINDOW_DAYS = 30

# The floor a personal baseline is reported above, in days of history.
#
# NOT a new number: ``derive/recovery._BASELINE_MIN_POINTS`` is 5 with the comment "need
# at least this many days to trust a baseline", and ``read/recovery._sleep_signal``
# already refuses under five nights. ``baseline_30d`` had NO floor at all — with two rows
# it was one day's value, published under a thirty-day name and drawn by the app as
# ``load / baseline_30d``. A ratio against a single day is an invented normal.
#
# The count ships beside the value (``baseline_30d_n``) rather than only gating it,
# because a floor answers "may we say this" and the count answers "how much is behind
# it", and those are different questions. ``analytics.Baseline`` has carried ``n`` for
# exactly this reason since it was written.
_BASELINE_MIN_DAYS = 5


def cardio_load_payload(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> dict | None:
    """Daily cardio load (Banister TRIMP) + strain 0-21 + 30-day trend, as of a day.
    [[training_stress_score]].

    The window closes at the reference day, so ``rows[-1]`` — which every field below
    treats as "the load that speaks for this day" — cannot be a day after it. The 30-day
    baseline is the mean of the window's PRIOR days, so it moves with the same bound.

    ## ``baseline_30d`` is thirty days, has a floor, and ships its count

    Three things were wrong with it and the app draws the result as a RATIO
    (``activity_today.dart``'s ``load / baseline_30d``), which is the reason all three
    matter rather than only the first:

    * the window was ``as_of - 35``, i.e. **36 days** under a 30-day name;
    * there was **no minimum** — with two rows in the window the "30-day baseline" was one
      day's value, and today's load was expressed as a multiple of it;
    * there was **no ``n``** on the wire, so no client could tell the two apart.

    It is still an arithmetic MEAN, deliberately and not by omission: a load baseline is
    the same summary ACWR's chronic term is (``[[training_load_acwr]]``: "the average dose
    over a longer window"), and swapping it for ``analytics.baselines``' median+MAD would
    change a published number with no note behind the change. What it borrows from that
    module is the discipline, not the statistic — a floor, and ``n`` beside the value.
    """
    as_of = reference_day(day, tz)
    cur.execute(
        "SELECT day, value, flags FROM derived_daily "
        "WHERE user_id = %s AND metric='cardio_load' "
        f"AND day > ({AS_OF_DAY_SQL} - %s::int) AND day <= {AS_OF_DAY_SQL} ORDER BY day",
        (user_id, as_of, _LOAD_WINDOW_DAYS, as_of),
    )
    rows = cur.fetchall()
    if not rows:
        return None
    trend = [{"date": d.isoformat(), "value": round(float(v), 1)} for d, v, _ in rows]
    latest_value, flags = float(rows[-1][1]), (rows[-1][2] or {})
    prior = [float(v) for _, v, _ in rows[:-1]]
    # Withheld, not floored to something: under the minimum there is no honest number to
    # report and `baseline_30d_n` says how far short it fell. The app already draws
    # nothing without a baseline, so the ratio disappears with its denominator.
    baseline = round(sum(prior) / len(prior), 1) if len(prior) >= _BASELINE_MIN_DAYS else None
    return {
        "load": round(latest_value, 1),
        "strain": _strain(cur, user_id, as_of, latest_value),
        "strain_max": 21.0,
        "as_of_date": rows[-1][0].isoformat(),
        "baseline_30d": baseline,
        # Days of history behind it, always — present when the baseline is, and present
        # when it is not so the absence is legible as "too few days" rather than as a gap.
        "baseline_30d_n": len(prior),
        "baseline_30d_min_n": _BASELINE_MIN_DAYS,
        "zone_minutes": flags.get("zone_min"),
        "edwards_tl": flags.get("edwards_tl"),
        "hrmax": flags.get("hrmax"),
        "rhr": flags.get("rhr"),
        "hr_minutes": flags.get("hr_minutes"),
        "trend_30d": trend,
        # The manifest ID. ``cardio_load_trimp`` is an ALIAS of it, and an alias resolves
        # to nothing in every consumer of a cited id — see ``read/activity.py``.
        "research_notes": ["training_stress_score"],
    }


def strain_from_load(load: float, p95: float | None) -> float | None:
    """Strain 0-21: the SAME TRIMP load on a personal log scale — 0 load → 0, the
    90-day P95 ("a hard day") → 21, with a mild concave (≈log) curve tracking
    perceived exertion. Ported VERBATIM from legacy (anchored to P95, not min/max,
    so a quiet/partial day reads low, never a misleading 0). [[training_stress_score]]."""
    if not (p95 and p95 > 0):
        return None
    return round(max(0.0, min(21.0, 21.0 * (load / p95) ** 0.75)), 1)


def _strain(cur: Cur, user_id: UUID, as_of: date, latest_load: float) -> float | None:
    """The personal 90-day P95 of cardio-load ENDING at ``as_of``, mapped onto 0-21.

    "A hard day for this person" is a claim about the 90 days behind the day being
    answered for. An open-topped window would price a June effort against a P95 that
    includes August — the same value read on a scale it could not have been measured on.
    """
    cur.execute(
        "SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY value) FROM derived_daily "
        "WHERE user_id = %s AND metric='cardio_load' AND value > 0 "
        f"AND day >= ({AS_OF_DAY_SQL} - 90) AND day <= {AS_OF_DAY_SQL}",
        (user_id, as_of, as_of),
    )
    row = cur.fetchone()
    p95 = float(row[0]) if row and row[0] else None
    return strain_from_load(latest_load, p95)


def mvpa_payload(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> dict | None:
    """Weekly moderate-to-vigorous minutes vs the WHO 150-min target + 8-day
    breakdown, as of a day. [[mvpa_minutes_mortality]], [[cadence_intensity]].

    The summing itself moved to ``read/mvpa_week.py`` when ``read/vo2max.py`` stopped
    shipping ``weekly_mvpa_min`` as a hardcoded null: two surfaces reporting one
    quantity get one implementation, or they get two definitions of "this week".
    """
    week = mvpa_week(cur, user_id, reference_day(day, tz))
    if week is None:
        return None
    return {
        "today_min": week.on_day_min,
        "week_min": week.mvpa_min,
        "week_target": 150,
        "week_moderate_min": week.moderate_min,
        "week_vigorous_min": week.vigorous_min,
        "week_start_iso": week.week_start.isoformat(),
        "daily": week.daily,
        "research_notes": ["mvpa_minutes_mortality", "cadence_intensity"],
    }


def strength_payload(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> dict:
    """Weekly strength-training minutes vs the 30-60 min sweet spot (Momma 2022).
    v2-native: manual ``exercise`` logs + strength-coded device ``workout`` rows
    (legacy read the v1 ``session`` table). [[strength_training_mortality]].

    The week is Monday through ``day`` inclusive, both edges bound as instants in the
    owner's zone. Open at the top it would count sessions the reference day had not
    seen yet — a week in June reporting effort logged in August.
    """
    as_of = reference_day(day, tz)
    monday = as_of - timedelta(days=as_of.weekday())
    minutes, sessions, types = _strength_manual(cur, user_id, tz, monday, as_of)
    m2, s2, t2 = _strength_workouts(cur, user_id, tz, monday, as_of)
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


def _strength_manual(
    cur: Cur, user_id: UUID, tz: str, monday: date, as_of: date
) -> tuple[float, int, set[str]]:
    """Strength minutes from manual ``exercise`` entries, Monday through ``as_of``."""
    cur.execute(
        "SELECT ts, end_ts, name, amount FROM manual_entry "
        "WHERE user_id = %s AND kind='exercise' AND ts >= %s AND ts < %s",
        (user_id, *_week_bounds_utc(monday, as_of, tz)),
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


def _strength_workouts(
    cur: Cur, user_id: UUID, tz: str, monday: date, as_of: date
) -> tuple[float, int, set[str]]:
    """Strength minutes from strength-coded ``workout`` rows, Monday through ``as_of``."""
    cur.execute(
        "SELECT sport, duration_s FROM workout "
        "WHERE user_id = %s AND sport = ANY(%s) AND start_ts >= %s AND start_ts < %s",
        (user_id, list(_STRENGTH_SPORTS), *_week_bounds_utc(monday, as_of, tz)),
    )
    minutes, sessions, types = 0.0, 0, set()
    for sport, dur_s in cur.fetchall():
        dur = (dur_s or 0) / 60.0
        if dur <= 0:
            continue
        minutes, sessions = minutes + dur, sessions + 1
        types.add(_STRENGTH_SPORTS[sport])
    return minutes, sessions, types


def _week_bounds_utc(monday: date, as_of: date, tz: str) -> tuple[datetime, datetime]:
    """The half-open UTC bracket for the local days ``monday`` through ``as_of``.

    Replaces ``_monday_utc``, which built a local midnight by hand. Now that the week
    has a CLOSING edge as well as an opening one, that hand-rolled instant would have
    been a second definition of a local day boundary sitting beside
    ``derive._common._day_bounds_utc`` — the module whose whole docstring is about the
    two ways a day edge is got wrong across a DST transition. One definition, used at
    both ends (standards §Duplication).
    """
    return _day_bounds_utc(monday, tz)[0], _day_bounds_utc(as_of, tz)[1]


def fitness_plan_payload(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> dict | None:
    """VO2max-raising weekly Rx + a 12-week projected trajectory (an estimate of
    typical response, bounded +2..+5 ml/kg/min, never a promise). [[vo2max]].

    Every input is the reference day's: the estimate it starts from, and the
    week-to-date it measures progress against.
    """
    as_of = reference_day(day, tz)
    vo = vo2max_payload(cur, user_id, tz, as_of)
    if not vo or vo.get("estimate") is None:
        return None
    cur_vo = float(vo["estimate"])
    median_ref = float(vo.get("median_for_age") or 41)
    gain = round(min(5.0, max(2.0, 0.4 * max(0.0, median_ref - cur_vo))), 1)
    monday = as_of - timedelta(days=as_of.weekday())
    # A day whose `mvpa_min` row carries no intensity breakdown makes the week's
    # done-minutes unknowable rather than smaller — the same rule `mvpa_week` applies, and
    # applied here rather than re-derived because progress against a plan is exactly where
    # an understated total reads as "you have done less than you have".
    week_mod: float | None = 0.0
    week_vig: float | None = 0.0
    for _d, mod, vig, _mv in weekly_mvpa_rows(cur, user_id, as_of, (as_of - monday).days + 1):
        if mod is None or vig is None:
            week_mod = week_vig = None
        elif week_mod is not None and week_vig is not None:
            week_mod, week_vig = week_mod + mod, week_vig + vig
    return {
        "current": round(cur_vo, 1),
        "projected_12wk": round(cur_vo + gain, 1),
        "gain": gain,
        "median_for_age": round(median_ref, 1),
        "weeks": 12,
        "plan": {
            "zone2_target_min": 90,
            "zone2_done_min": None if week_mod is None else round(week_mod),
            "zone2_desc": "3 × 30 min easy aerobic — Zone 2, conversational pace",
            "vilpa_target_min": 15,
            "vilpa_done_min": None if week_vig is None else round(week_vig),
            "vilpa_desc": "1 hard session — 4-5 × 1-min brisk-to-hard bursts "
            "(stairs / hill / fast walk)",
        },
        # ``vo2max_training_program`` is an ALIAS of ``vo2max`` — see ``read/activity.py``.
        "note_id": "vo2max",
        "trend_90d": vo.get("trend_90d") or [],
    }


def activity_metric(
    cur: Cur,
    user_id: UUID,
    tz: str,
    candidates: list[str],
    days: int = 30,
    day: date | None = None,
) -> dict | None:
    """Value + date + N-day series, as of ``day``, for the first candidate with data
    (steps/calories/distance). v2-native ``derived_daily`` read.

    ``caveats`` is a permanent key and empty for a metric with nothing to disclose — the
    same contract ``read/today_series.py::_derived_card`` holds, because the Activity tab
    and the Today card render the same two calorie rows and must not differ on whether the
    weight behind them is current (#127).

    **The freshness gate is here for the same reason, and it is the same gate.** This
    already carried ``as_of_date``, which the Today card did not — but a date is only half
    the contract, and half of it was on each side: the Activity tab dated a value it
    would still present as the day's, and the Today card refused nothing and said nothing.
    Two surfaces rendering one row cannot answer "is this current" differently, or the
    stale number simply moves one tab across (``derive/freshness.py``: five checks is how
    a metric ends up with two definitions of current).
    """
    as_of = reference_day(day, tz)
    for cand in candidates:
        latest = latest_derived(cur, user_id, cand, as_of)
        if latest:
            row_day, value, flags = latest
            reason = unavailable_reason(as_of, row_day)
            return {
                "metric": cand,
                "value": None if reason else round(value, 1),
                "as_of_date": row_day.isoformat(),
                "caveats": flags.get("caveats") or [],
                "withheld": withheld_block(
                    reason, NOT_DERIVED_YET_MESSAGE, as_of, row_day, last_value=round(value, 1)
                )
                if reason
                else None,
                # The series keeps its own days and is NOT withheld: a trend that ends
                # before the reference day is honest as long as nothing claims it ends on
                # it (``read/vo2max.py`` keeps ``trend_90d`` on a withheld day for the
                # same reason).
                "trend": derived_series(cur, user_id, cand, days, as_of),
            }
    return None


def workouts_list(
    cur: Cur, user_id: UUID, tz: str, limit: int = 100, day: date | None = None
) -> list[dict]:
    """Device-recorded workouts (>=10 min) with HR detail, newest first, ending at ``day``.

    A list "newest first" is a list of latests, so it takes the bound like every other:
    the Activity tab as of 29 July must not show a session recorded in August above the
    ones it is meant to be about.
    """
    as_of = reference_day(day, tz)
    cur.execute(
        "SELECT start_ts, sport, duration_s, calories, distance_m, avg_hr, max_hr, min_hr "
        "FROM workout WHERE user_id = %s AND COALESCE(duration_s, 0) >= %s AND start_ts < %s "
        "ORDER BY start_ts DESC LIMIT %s",
        (user_id, _MIN_WORKOUT_S, _day_bounds_utc(as_of, tz)[1], limit),
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
