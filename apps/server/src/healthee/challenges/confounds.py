"""The reasons to distrust an outcome, computed and stored as structure.

CHALLENGES.md §2.1 and §7 decision 1. Legacy shipped its caveat as prose ("this is
observational, not proof") on top of a data structure that said the opposite. Prose
is not read by the next query, the next rollup, or the next prompt; a column is. So
every reason an outcome might be misleading is a field here.

Three of them, each answering a different way a before/after can lie:

* **illness_days** — the owner was ill during the window. Almost every metric this
  system tracks moves under illness, and none of it is the challenge.
* **concurrent_challenges** — how many OTHER commitments were live at the same time.
  Legacy ran up to four at once and still fed per-challenge "downstream" deltas back
  into generation. With two or more overlapping, attribution is not hard, it is
  **unknowable**, and the count is what says so.
* **regression_to_mean** — the adopt-time baseline was itself abnormal for this
  person, so the metric would have drifted back toward their norm with or without a
  challenge. Judged with the SAME robust-z threshold the anomaly engine uses
  (``analytics.anomalies.Z_THRESHOLD``): "abnormal for you" must not have two
  definitions (CLAUDE.md).

Each is computed from what we actually have. Where we cannot judge one, the flag says
``assessed: false`` and why — an unassessed confound recorded as "no confound" is
worse than none, because it reads as a check that passed.
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from healthee.analytics.anomalies import Z_THRESHOLD
from healthee.analytics.baselines import Baseline
from healthee.challenges.series import baseline_span, metric_series
from healthee.derive._common import Cur
from healthee.derive.robust import median, median_abs_deviation

# The history an adopt-time baseline is judged against. Long enough that a bad or
# unusually good week cannot BE the norm it is compared to, short enough to still be
# this person now rather than this person last year.
LONG_WINDOW_DAYS = 90

# Fewer days than this and the long window is not a norm either, so the question
# cannot be answered and is reported unanswered rather than guessed. Matches the
# baseline sufficiency bar in `ledger` — half a window is where a median stops being
# about the person and starts being about which days happened to record.
MIN_LONG_WINDOW_DAYS = 30


def collect(cur: Cur, user_id: UUID, tz: str, challenge: dict, start: date, end: date) -> dict:
    """Every confound flag for one challenge's window, as the ``confounds`` JSONB."""
    return {
        "illness_days": illness_days(cur, user_id, start, end),
        "concurrent_challenges": concurrent_challenges(cur, user_id, challenge, start, end),
        "regression_to_mean": regression_to_mean(cur, user_id, tz, challenge, start),
    }


def illness_days(cur: Cur, user_id: UUID, start: date, end: date) -> int:
    """Days inside the window on which the owner carried an illness flag.

    ``illness_flag.date`` is already the owner's local wake date (it is keyed that
    way by the derive layer), so this compares local dates to local dates and needs
    no zone conversion — the one shape in this module that is not an instant.
    """
    cur.execute(
        "SELECT count(*) FROM illness_flag WHERE user_id = %s AND date BETWEEN %s AND %s",
        (user_id, start, end),
    )
    row = cur.fetchone()
    return int(row[0]) if row else 0


def concurrent_challenges(cur: Cur, user_id: UUID, challenge: dict, start: date, end: date) -> int:
    """How many of the owner's OTHER challenges overlapped this window.

    Overlap, not containment: a challenge that ran for one day of this window still
    confounds that day. An open-ended row (adopted, never closed) counts as running
    to now, because it was.

    This number is what makes the ledger honest rather than merely cautious — a
    co-occurring delta recorded next to ``concurrent_challenges: 3`` cannot be read
    as an effect of any one of them.
    """
    cur.execute(
        "SELECT count(*) FROM challenge "
        "WHERE user_id = %s AND id <> %s AND adopted_at IS NOT NULL "
        "  AND adopted_at::date <= %s "
        "  AND COALESCE(abandoned_at, completed_at, ends_at, now())::date >= %s",
        (user_id, challenge["id"], end, start),
    )
    row = cur.fetchone()
    return int(row[0]) if row else 0


def regression_to_mean(cur: Cur, user_id: UUID, tz: str, challenge: dict, start: date) -> dict:
    """Was the frozen baseline itself abnormal for this owner?

    People adopt a sleep challenge after a bad week and an alcohol cap after a heavy
    one. If the starting point was an outlier, the metric drifts back toward their
    norm on its own, and a before/after that ignores that credits the challenge with
    the weather.

    The judgement reuses the anomaly engine's own machinery — an
    ``analytics.baselines.Baseline`` and its ``z_score``, over the robust median/MAD
    from ``derive.robust`` — so "abnormal for you" is computed here exactly as it is
    everywhere else. It is built from the CHALLENGE metric series rather than
    ``compute_baseline_cur`` because half the registry does not live in
    ``derived_daily`` as a plain row (sleep duration is a flag; workouts and the
    self-logged caps are not daily metrics at all), and a check that silently skipped
    those would be a check nobody could rely on.
    """
    baseline_value = challenge.get("baseline_value")
    if baseline_value is None:
        return {"assessed": False, "reason": "no baseline was captured at adopt"}
    series = metric_series(
        cur,
        user_id,
        tz,
        challenge["metric"],
        start - timedelta(days=LONG_WINDOW_DAYS),
        until=start - timedelta(days=1),
    )
    values = [v for day, v in series.items() if day < start]
    if len(values) < MIN_LONG_WINDOW_DAYS:
        return {
            "assessed": False,
            "reason": f"only {len(values)} days of history (need {MIN_LONG_WINDOW_DAYS})",
            "days": len(values),
        }
    return _judge(challenge["metric"], float(baseline_value), values, challenge)


def _judge(metric: str, baseline_value: float, values: list[float], challenge: dict) -> dict:
    """The z of the frozen baseline against the owner's long-run norm, and the verdict."""
    daily = _per_day(baseline_value, challenge["cadence"], int(challenge["window_days"]))
    long_run = Baseline(
        metric=metric,
        window_days=LONG_WINDOW_DAYS,
        n=len(values),
        median=median(values),
        mad=median_abs_deviation(values),
        p25=None,
        p75=None,
        min=min(values),
        max=max(values),
    )
    z = long_run.z_score(daily)
    if z is None:  # a history flat enough that MAD is 0 — no spread to judge against
        return {"assessed": False, "reason": "the long-run history has no measurable spread"}
    return {
        "assessed": True,
        "baseline_z": round(z, 2),
        "long_run_median": round(long_run.median, 1) if long_run.median is not None else None,
        "days": len(values),
        "at_risk": abs(z) >= Z_THRESHOLD,
    }


def _per_day(baseline_value: float, cadence: str, window_days: int) -> float:
    """The baseline expressed per DAY, so it is comparable to a per-day history.

    A ``weekly``/``total`` baseline is a period SUM (``series.recent_window``) while the
    long-run series is one value per day. Comparing the two unscaled would report every
    cumulative challenge's baseline as a multi-sigma anomaly — the same units-mismatch
    the adapter's ``_achieved`` scaling exists to prevent.

    The divisor is ``series.baseline_span``, not a hardcoded seven, for exactly the
    reason the baseline itself is no longer a hardcoded seven (#65): a ``total``
    baseline spans the challenge's whole window, so dividing a 21-day sum by 7 would
    hand ``z_score`` a figure three times the owner's real daily norm and flag every
    long cumulative challenge as regression-to-the-mean.
    """
    return (
        baseline_value / baseline_span(cadence, window_days)
        if cadence in ("weekly", "total")
        else baseline_value
    )
