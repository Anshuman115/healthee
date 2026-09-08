"""The three recovery SIGNALS — individual favourable/unfavourable markers, no composite.

Split out of ``read/recovery.py`` when naming this file's cut-points (the audit's D-a) and
saying which limb of the sleep signal decided its verdict (D-c) pushed that file past the
400-line gate for the fourth time. The seam is real rather than convenient: a SIGNAL is a
comparison of one marker against this owner's own recent history, and the recovery SCORE
beside it is an evidence-weighted composite over a different set of inputs. They answer
different questions, they change for different reasons, and every constant below belongs
to the first question only.

Nothing about the statistics changed in the move. The one addition is
``direction_basis``, which says WHICH of the sleep signal's two limbs produced its word.
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from healthee.analytics.baselines import compute_baseline_cur
from healthee.core.tenancy import reference_day
from healthee.derive._common import Cur, _day_bounds_utc
from healthee.derive.robust import median, median_abs_deviation, robust_sd
from healthee.read.common import TodayReads, latest_derived

# Degenerate-history guard on the sleep signal's robust SD, in MINUTES — the units of
# the only baseline in this module that computes its own dispersion (`_sleep_signal`
# medians sleep-session durations; the RHR/HRV signals delegate to
# `analytics.baselines`, which is unfloored). It binds only when the trailing MAD is
# under ~0.67 min, i.e. a sleep history flat to within 40 seconds.
#
# NOT the 0.5 that [[recovery_readiness]] pins on the recovery derivation
# (derive/recovery.py:_AUTONOMIC_MIN_SD): that floor guards ms/bpm, this one guards
# minutes, and a floor is scale-dependent — the same number would mean something
# different here. Both descend from legacy, where the value tracked the FILE rather
# than the metric (legacy api/app.py:1908 floored sleep-MINUTES at 1.0 and :1967
# floored HRV-ms at 1.0, while v2/derive.py:745 floored the same HRV at 0.5). The
# rebuild left them on disjoint metrics, so they no longer contradict each other; they
# are kept distinct and named rather than unified, because unifying them would change
# an ungoverned metric's z-score with no note behind it.
_SLEEP_MIN_SD_MIN = 1.0

# Days of history a recovery signal needs before it publishes a direction.
#
# The RHR and HRV signals had NO count gate at all: their only admission rule was a
# non-zero `robust_sd`, and with **two** days MAD is the half-distance, so the z is finite
# and the payload published `baseline`, `baseline_sd`, `z` and a `direction` of "favorable"
# or "unfavorable" — a verdict on this owner's autonomic state from two mornings.
#
# Five is not a new number. `_sleep_signal` in this same function has always used
# `len(durs) < 5`, and `derive/recovery._BASELINE_MIN_POINTS` is 5 with the comment "need
# at least this many days to trust a baseline". One payload was running three signals under
# two admission rules; this is the one that was already written down.
#
# `Baseline.n` was on the object both functions already held and was simply not consulted.
# It ships beside `baseline` and `baseline_sd` now, on all three, so a reader can weigh a
# direction rather than take it.
_SIGNAL_MIN_DAYS = 5

# ── The sleep signal's two limbs, named because they are two ─────────────────
#
# The signal describes itself as "vs personal usual" and then decides its direction from
# an ABSOLUTE floor as well as from the personal z. For a chronic short sleeper — which
# this product's owner is — the floor is met every night, so the personal z the signal
# computes, ships and labels can never change the verdict: the number on the card is
# personal and the judgement beside it is a population threshold (audit D-c).
#
# The thresholds are not wrong and are not moved. [[sleep_duration_mortality]] supports
# the population claim, and moving a scoring cutoff is a science behaviour change owed its
# own PR with known-value tests (CLAUDE.md). What was wrong is that nothing said which
# limb spoke, so ``direction_basis`` ships beside the direction: "population" when the
# absolute limb decided it on its own, "personal" when the z did, "both" when they agreed.
#
# 6 h — the lower shoulder of the U-shaped duration/mortality association, below which
# short sleep is associated with excess all-cause mortality.
_SLEEP_FAVORABLE_FLOOR_MIN = 360.0
# 5 h — deep in the short arm of the same curve, where the association is strongest.
_SLEEP_UNFAVORABLE_FLOOR_MIN = 300.0
# The personal limbs, in robust SDs from this owner's own median. Deliberately asymmetric
# and unchanged: a night has to be clearly below usual to count against, and only
# not-far-below to count for.
_SLEEP_FAVORABLE_Z = -0.5
_SLEEP_UNFAVORABLE_Z = -1.0

# The RHR and HRV signals' direction thresholds, in robust SDs from this owner's own
# baseline. Asymmetric on purpose and unchanged: the FAVOURABLE side is the tighter of the
# two (|0.3| SD), so a marker has to be clearly better than usual to be called favourable,
# while the unfavourable side allows a larger excursion (|0.5| SD) before it is named. Not
# research constants — [[recovery_readiness]] licenses the comparison against a personal
# baseline, not these cut-points — so they are named rather than cited, which is what a
# constant with no paper behind it is owed.
_AUTONOMIC_FAVORABLE_Z = 0.3
_AUTONOMIC_UNFAVORABLE_Z = 0.5


def recovery_signals(
    cur: Cur, user_id: UUID, tz: str, reads: TodayReads | None = None, day: date | None = None
) -> dict | None:
    """Individual recovery markers (RHR / sleep duration / overnight HRV), each with
    its evidence citation. No composite score — the literature backs the markers
    individually but has no replicated composite formula. Ported to v2-native reads.

    **Each signal now ships the spread it was scored against**, not just the centre.
    All three divide by a robust SD to get ``z`` and then sent only ``baseline`` and
    ``z``, so a client could draw the reference LINE but not the band around it — and a
    reader with no σ cannot tell a value one unit above a tight baseline from one unit
    above a scattered one, which is the whole content of the z it is being handed.
    ``baseline_sd`` is that exact divisor (``Baseline.robust_sd``, MAD scaled to a
    normal-equivalent SD; the sleep signal's own floored form), so ``value``,
    ``baseline``, ``baseline_sd`` and ``z`` are arithmetically consistent on the wire and
    a band is drawable without a second read.
    """
    as_of = reference_day(day, tz)
    candidates = (
        _rhr_signal(cur, user_id, tz, reads, as_of),
        _sleep_signal(cur, user_id, tz, as_of),
        _hrv_signal(cur, user_id, tz, reads, as_of),
    )
    signals = [s for s in candidates if s]
    if not signals:
        return None
    favorable = sum(1 for s in signals if s["direction"] == "favorable")
    unfavorable = sum(1 for s in signals if s["direction"] == "unfavorable")
    summary = _summary(signals, favorable, unfavorable)
    return {
        "summary": summary,
        "favorable": favorable,
        "unfavorable": unfavorable,
        "neutral": len(signals) - favorable - unfavorable,
        "total": len(signals),
        "signals": signals,
    }


def _summary(signals: list[dict], favorable: int, unfavorable: int) -> str:
    """The one-line reading of the markers — SINGULAR when there is one marker.

    "Recovery signals lean favorable" from a single available marker is a plural sentence
    about one thing, and the plural is the claim: it reads as agreement across markers when
    there was nothing to agree with. The module docstring says this payload reports
    "individual favourable/unfavourable markers, no composite", and a plural summary over an
    unweighted vote is the closest this file comes to contradicting it.

    Which way it leans is unchanged. Only the sentence's arithmetic honesty is.
    """
    if len(signals) == 1:
        lean = signals[0]["direction"]
        if lean == "neutral":
            return f"One recovery signal, and it is neutral: {signals[0]['name'].lower()}"
        return f"One recovery signal, and it leans {lean}: {signals[0]['name'].lower()}"
    if favorable > unfavorable:
        return "Recovery signals lean favorable"
    if unfavorable > favorable:
        return "Recovery signals lean unfavorable"
    return "Mixed recovery signals"


def _rhr_signal(
    cur: Cur, user_id: UUID, tz: str, reads: TodayReads | None, as_of: date
) -> dict | None:
    """Resting HR vs personal baseline — LOWER is favourable (Aune 2017)."""
    latest = (
        reads.latest.get("rhr_daily") if reads else latest_derived(cur, user_id, "rhr_daily", as_of)
    )
    if not latest:
        return None
    value = latest[1]
    b = (reads.baselines.get("rhr_daily") if reads else None) or compute_baseline_cur(
        cur, user_id, tz, "rhr_daily", window_days=30, end_date=as_of
    )
    if b.median is None or not b.robust_sd or b.n < _SIGNAL_MIN_DAYS:
        return None
    z = (value - b.median) / b.robust_sd
    direction = (
        "favorable"
        if z < -_AUTONOMIC_FAVORABLE_Z
        else "unfavorable"
        if z > _AUTONOMIC_UNFAVORABLE_Z
        else "neutral"
    )
    return {
        "name": "Resting HR",
        "value": value,
        "unit": "bpm",
        "baseline": b.median,
        "baseline_sd": b.robust_sd,
        "n": b.n,
        "z": z,
        "direction": direction,
        # The manifest ID; ``resting_hr_health_marker`` was an ALIAS — see
        # ``read/activity.py`` for why an alias on the wire resolves to nothing.
        "research_note_id": "resting_heart_rate",
    }


def _sleep_signal(cur: Cur, user_id: UUID, tz: str, as_of: date) -> dict | None:
    """The night ending on or before ``as_of`` vs personal usual — Cappuccio 2010
    (v2: TST from sleep_session stage minutes).

    Both reads used to be unbounded at the top — the first a plain "newest session", the
    second ``start_ts > now() - interval '30 days'``, i.e. a window anchored to the
    request instant rather than to the day. As of a past day that is two future leaks in
    one signal: a night after the day being answered for, compared against a usual that
    includes every night since.
    """
    ends_before = _day_bounds_utc(as_of, tz)[1]
    cur.execute(
        "SELECT (light_min+deep_min+rem_min) FROM sleep_session "
        "WHERE user_id = %s AND kind='main' AND end_ts < %s ORDER BY start_ts DESC LIMIT 1",
        (user_id, ends_before),
    )
    row = cur.fetchone()
    if not row or not row[0]:
        return None
    today_dur = float(row[0])
    cur.execute(
        "SELECT (light_min+deep_min+rem_min) FROM sleep_session "
        "WHERE user_id = %s AND kind='main' AND start_ts > %s AND start_ts < %s",
        (user_id, ends_before - timedelta(days=30), ends_before),
    )
    durs = [float(r[0]) for r in cur.fetchall() if r[0]]
    if len(durs) < _SIGNAL_MIN_DAYS:
        return None
    # The ONE median/MAD (``derive/robust``). This used to take the UPPER-middle value
    # of an even-length window rather than interpolating — not a median, and a second
    # definition of one alongside ``derive/recovery``'s. See that module's baseline.
    med = median(durs)
    # The one divisor, named: it is floored at `_SLEEP_MIN_SD_MIN` (unlike the two
    # `Baseline.robust_sd` signals, which are unfloored — see that property), so shipping
    # the unfloored MAD instead would hand the client a σ that does not reproduce `z`.
    sd = robust_sd(median_abs_deviation(durs), _SLEEP_MIN_SD_MIN)
    z = (today_dur - med) / sd
    population = today_dur < _SLEEP_UNFAVORABLE_FLOOR_MIN
    personal = z < _SLEEP_UNFAVORABLE_Z
    direction = (
        "favorable"
        if today_dur >= _SLEEP_FAVORABLE_FLOOR_MIN and z > _SLEEP_FAVORABLE_Z
        else "unfavorable"
        if population or personal
        else "neutral"
    )
    return {
        "name": "Sleep duration",
        "value": today_dur,
        "unit": "min",
        "baseline": med,
        "baseline_sd": sd,
        "n": len(durs),
        "z": z,
        "direction": direction,
        # WHICH limb produced that word. Both limbs are legitimate and both are reported;
        # what a reader could not previously tell is that for a chronic short sleeper the
        # population floor decides every night and the personal number beside it cannot
        # change the verdict (audit D-c). Null on a direction neither limb forced.
        "direction_basis": _direction_basis(direction, population, personal),
        "population_floor_min": _SLEEP_UNFAVORABLE_FLOOR_MIN,
        "research_note_id": "sleep_duration_mortality",
    }


def _direction_basis(direction: str, population: bool, personal: bool) -> str | None:
    """Which limb of the sleep signal produced an unfavourable direction, or None.

    Only the unfavourable branch has two independent limbs (``or``); the favourable branch
    requires BOTH, so it has nothing to disambiguate, and the neutral branch is the absence
    of a verdict rather than one.
    """
    if direction != "unfavorable":
        return None
    if population and personal:
        return "both"
    return "population" if population else "personal"


def _hrv_signal(
    cur: Cur, user_id: UUID, tz: str, reads: TodayReads | None, as_of: date
) -> dict | None:
    """Overnight HRV vs personal usual — HIGHER is favourable (Plews 2013)."""
    latest = (
        reads.latest.get("hrv_sleep_avg")
        if reads
        else latest_derived(cur, user_id, "hrv_sleep_avg", as_of)
    )
    if not latest:
        return None
    value = latest[1]
    b = (reads.baselines.get("hrv_sleep_avg") if reads else None) or compute_baseline_cur(
        cur, user_id, tz, "hrv_sleep_avg", window_days=30, end_date=as_of
    )
    if b.median is None or not b.robust_sd or b.n < _SIGNAL_MIN_DAYS:
        return None
    z = (value - b.median) / b.robust_sd
    direction = (
        "favorable"
        if z > _AUTONOMIC_FAVORABLE_Z
        else "unfavorable"
        if z < -_AUTONOMIC_UNFAVORABLE_Z
        else "neutral"
    )
    return {
        "name": "Overnight HRV",
        "value": round(value, 1),
        "unit": "ms",
        "baseline": round(b.median, 1),
        "n": b.n,
        # NOT rounded to the baseline's 1 dp: `z` is `(value - baseline) / baseline_sd`,
        # and rounding the divisor would make the three numbers stop reconciling.
        "baseline_sd": b.robust_sd,
        "z": z,
        "direction": direction,
        # The manifest ID; ``hrv_recovery_marker`` was an ALIAS — see ``read/activity.py``.
        "research_note_id": "heart_rate_variability",
    }
