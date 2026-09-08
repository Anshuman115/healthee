"""The frozen outcome ledger — what we are willing to claim a challenge did.

WP-C2, CHALLENGES.md §2.1 / §2.6 / §7 decision 1. This is the honesty-critical
piece of the whole track, because it is the one that turns a week of a person's life
into a stored claim — and every later surface (the Insights rollup, the WP-C5 coach
context, WP-C3's generation) reads that claim rather than the week.

## What we claim, and what we refuse to

**We claim one thing: the challenge's OWN target metric, before vs after.** That is
a fair comparison — the owner committed to move exactly that number, and both sides
are computed by the SAME estimator over the SAME number of days
(``series.recent_window``), one ending the day before the challenge started and one
ending the day it finished. Using a different window on either side would measure the
estimator rather than the person.

**We refuse to claim anything about other metrics.** Legacy computed adjacent-window
deltas on other metrics and fed them back into generation as this challenge's
"downstream" effects, while up to four challenges ran concurrently. That attribution
is not merely uncertain, it is unknowable, and the product exists not to ship small
confident lies. So other metrics are recorded under ``co_occurring`` — the same
numbers, stripped of the causal claim, carrying the count of other commitments that
were live at the same time so the caveat cannot be separated from the data.

**We refuse to publish a comparison we cannot support.** A before/after computed
from two logged days looks exactly like one computed from seven. When either side is
thin the outcome is written with ``data_confidence='insufficient_data'`` — written,
not skipped. Legacy's ``_result`` returned ``None`` and the outcome simply vanished,
which is the worst of both: no record, and no reason.
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import date, datetime, timedelta
from typing import LiteralString, cast
from uuid import UUID

from psycopg.types.json import Jsonb

from healthee.analytics.series import daily_series
from healthee.challenges import confounds as confounds_mod
from healthee.challenges.metrics import spec
from healthee.challenges.series import BASELINE_DAYS, MIN_COMPARISON_DAYS, recent_window
from healthee.core.logging import get_logger
from healthee.derive._common import Cur

log = get_logger(__name__)

# Fewer measured days than `MIN_COMPARISON_DAYS` on EITHER side and the before/after
# is not a comparison, it is two anecdotes. The threshold itself now lives with the
# estimator it qualifies (`series.MIN_COMPARISON_DAYS`) because WP-C3's Gate A judges
# the same number by the same line; it is re-exported here, not redefined.

# `recent`'s row cap: a query string may not choose an answer's size (`PERF_AUDIT.md` B4).
MAX_RECENT_OUTCOMES = 100  # `list_gps_tracks`' number, taken rather than invented

# The other metrics whose movement is worth recording — as CO-OCCURRING, never as
# caused. Deliberately a short fixed panel of the outcomes an owner actually asks
# about, not "every metric we have": a wide net over a 7-day window is a machine for
# manufacturing spurious deltas, and every extra one dilutes the few that matter.
# Real personal cause-and-effect is the FDR-controlled correlation engine's job
# (`analytics/`), not a window diff (§2.1).
CO_OCCURRING_METRICS: tuple[str, ...] = (
    "hrv_sleep_avg",
    "rhr_daily",
    "recovery_score",
    "sleep_health_score_4dim",
)

# challenge.status -> the outcome's own terminal vocabulary. `expired` becomes
# `unmet_timed_out` and NOT "completed": legacy recorded a timed-out rung as
# completed, and a ledger that files failures as successes teaches the generation
# layer to keep prescribing what did not work (§2.3).
_TERMINAL = {"completed": "met", "expired": "unmet_timed_out", "abandoned": "abandoned"}


def freeze(
    cur: Cur,
    user_id: UUID,
    tz: str,
    challenge: dict,
    progress: dict,
    status: str,
    start: date,
    today: date,
) -> dict:
    """Compute and store one challenge's outcome. Idempotent; returns what was computed.

    Called from the two places a challenge ends — the lifecycle's ``finalize_due``
    and ``abandon`` — inside their transaction, so the terminal status and its
    outcome land together or not at all.
    """
    end = min(start + timedelta(days=int(challenge["window_days"]) - 1), today)
    outcome = _compute(cur, user_id, tz, challenge, progress, status, start, end)
    _store(cur, user_id, int(challenge["id"]), outcome)
    log.info(
        "challenge %s outcome frozen: %s, improvement=%s, confidence=%s",
        challenge["id"],
        outcome["status"],
        outcome["improvement_pct"],
        outcome["data_confidence"],
    )
    return outcome


def _compute(
    cur: Cur,
    user_id: UUID,
    tz: str,
    challenge: dict,
    progress: dict,
    status: str,
    start: date,
    end: date,
) -> dict:
    """The whole outcome as a mapping — pure enough to assert on without the DB row."""
    metric = challenge["metric"]
    baseline = challenge.get("baseline_value")
    # `window_days` reaches the estimator because a `total` baseline spans the whole
    # window (`series.baseline_span`, #65). Without it the "after" side would be a
    # trailing seven while the "before" side frozen at adopt was a whole window, and
    # `_improvement_pct` would divide two different units into a percentage.
    final, final_days = recent_window(
        cur,
        user_id,
        tz,
        metric,
        challenge["cadence"],
        end + timedelta(days=1),
        int(challenge["window_days"]),
    )
    improvement = _improvement_pct(metric, baseline, final)
    days_active = (end - start).days + 1
    return {
        "metric": metric,
        "category": challenge.get("category"),
        "difficulty": challenge.get("difficulty"),
        "cadence": challenge["cadence"],
        "target": challenge["target_value"],
        "baseline": baseline,
        "final": final,
        "improvement_pct": improvement,
        "improved": None if improvement is None else improvement > 0,
        "adherence": _adherence(challenge, progress, days_active),
        "days_active": days_active,
        "status": _TERMINAL.get(status, status),
        "confounds": confounds_mod.collect(cur, user_id, tz, challenge, start, end),
        "co_occurring": _co_occurring(cur, user_id, challenge, start, end),
        "data_confidence": _confidence(cur, user_id, tz, challenge, start, final_days),
    }


def _improvement_pct(metric: str, baseline: float | None, final: float | None) -> float | None:
    """Percent move of the target metric, SIGNED so positive = what was asked for.

    A raw delta cannot mean "it worked": for a ``good="down"`` metric (the caps a
    personal-cutoff finding produces) a −40 % change is the challenge succeeding, and
    a ledger that filed it as a negative result would teach WP-C3's generation exactly
    the wrong lesson. The direction comes from the registry, so it is the same
    direction every other surface uses.

    ``None`` when there is nothing to divide by — a missing baseline, or a zero one
    (an owner who logged no alcohol before a cap). A percentage change from zero is
    undefined, not infinite and not 100.
    """
    if baseline is None or final is None or baseline == 0:
        return None
    direction = 1.0 if spec(metric).good == "up" else -1.0
    return round(direction * (final - baseline) / abs(baseline) * 100.0, 1)


def _adherence(challenge: dict, progress: dict, days_active: int) -> float | None:
    """The BEHAVIOUR rate: days the commitment was met / days elapsed (§2.6).

    Split from the metric move on purpose — legacy's single ``adherence`` answered
    both, so "they showed up every day and it did nothing" was indistinguishable from
    "they barely showed up and it worked anyway", which are opposite lessons.

    ``None`` for ``weekly``/``total``, and that is the honest answer rather than a
    gap: a cumulative rule makes no per-day commitment, so there are no days on which
    it was or was not met. Inventing a rate for it would be a composite score with no
    methodology (CLAUDE.md).
    """
    if challenge["cadence"] != "daily" or days_active <= 0:
        return None
    return round(int(progress.get("hit_days") or 0) / days_active, 3)


def _confidence(
    cur: Cur, user_id: UUID, tz: str, challenge: dict, start: date, final_days: int
) -> str:
    """``ok`` or ``insufficient_data`` — the gate, applied to BOTH sides.

    A thin *final* window is exactly as misleading as a thin baseline, and only one of
    the two is stored as a count, so the baseline's day count is recomputed here from
    the same estimator that produced it.
    """
    _, baseline_days = recent_window(
        cur,
        user_id,
        tz,
        challenge["metric"],
        challenge["cadence"],
        start,
        int(challenge["window_days"]),
    )
    if baseline_days < MIN_COMPARISON_DAYS or final_days < MIN_COMPARISON_DAYS:
        return "insufficient_data"
    return "ok"


def _co_occurring(cur: Cur, user_id: UUID, challenge: dict, start: date, end: date) -> dict:
    """What else moved during the window — recorded, and explicitly NOT attributed.

    The structure carries its own caveat: ``attribution: "none"`` and the count of
    other commitments that were live at the same time sit beside the numbers, so the
    deltas cannot be lifted out of context by the next query or the next prompt.
    The challenge's own target metric is excluded — that one IS a claim, and it lives
    in ``improvement_pct`` where it can be read as one.
    """
    metrics = tuple(m for m in CO_OCCURRING_METRICS if m != challenge["metric"])
    return {
        "attribution": "none",
        "note": "moved during the same window; not attributed to this challenge",
        "concurrent_challenges": confounds_mod.concurrent_challenges(
            cur, user_id, challenge, start, end
        ),
        "metrics": {m: _delta(cur, user_id, m, start, end) for m in metrics},
    }


def _delta(cur: Cur, user_id: UUID, metric: str, start: date, end: date) -> dict | None:
    """Before/after means for one co-occurring metric, or ``None`` if either is thin.

    Same estimator both sides, same number of days — the property that makes the
    challenge's own before/after fair applies here too, even though nothing is being
    claimed from it.
    """
    series = daily_series(cur, user_id, metric, since=start - timedelta(days=BASELINE_DAYS))
    before = [
        v for day, v in series.items() if start - timedelta(days=BASELINE_DAYS) <= day < start
    ]
    after = [
        v for day, v in series.items() if end - timedelta(days=BASELINE_DAYS - 1) <= day <= end
    ]
    if len(before) < MIN_COMPARISON_DAYS or len(after) < MIN_COMPARISON_DAYS:
        return None
    before_mean = sum(before) / len(before)
    after_mean = sum(after) / len(after)
    return {
        "before": round(before_mean, 1),
        "after": round(after_mean, 1),
        # Raw and SIGNED, not direction-aware: `improvement_pct` means "it worked",
        # and nothing here is allowed to mean that.
        "delta_pct": round((after_mean - before_mean) / abs(before_mean) * 100.0, 1)
        if before_mean
        else None,
    }


def _store(cur: Cur, user_id: UUID, challenge_id: int, outcome: dict) -> None:
    """Write the outcome once. A second attempt changes nothing.

    ``DO NOTHING``, not ``DO UPDATE``: an outcome is a historical record of what was
    true when a commitment ended, and the lifecycle's status guards already make the
    first write the only legitimate one. A second write means something is wrong, and
    the answer to that is not to quietly overwrite the history.
    """
    cur.execute(
        "INSERT INTO challenge_outcome (user_id, challenge_id, metric, category, difficulty, "
        "  cadence, target, baseline, final, improvement_pct, improved, adherence, days_active, "
        "  status, confounds, co_occurring, data_confidence) "
        "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) "
        "ON CONFLICT (challenge_id) DO NOTHING",
        (
            user_id,
            challenge_id,
            outcome["metric"],
            outcome["category"],
            outcome["difficulty"],
            outcome["cadence"],
            outcome["target"],
            outcome["baseline"],
            outcome["final"],
            outcome["improvement_pct"],
            outcome["improved"],
            outcome["adherence"],
            outcome["days_active"],
            outcome["status"],
            Jsonb(outcome["confounds"]),
            Jsonb(outcome["co_occurring"]),
            outcome["data_confidence"],
        ),
    )


def recent(cur: Cur, user_id: UUID, limit: int = 20) -> list[dict]:
    """One owner's frozen outcomes, newest first — the ledger read (windowed by ROWS).

    Use this when the question is "what has this owner done lately" and a tail is the
    honest answer. When the question is a RULE with a time bound in it, use
    :func:`since` — a row limit cannot express a 60-day cooldown, and a rule that reads
    a tail is correct only while an unstated throughput invariant holds.
    ``limit`` is CLAMPED to :data:`MAX_RECENT_OUTCOMES`: it reached ``LIMIT %s`` straight
    off ``/api/challenges/outcomes``'s query string (`PERF_AUDIT.md` B4).
    """
    query = cast(  # `_READ_SELECT` is a module constant of column names, never input
        LiteralString,
        f"SELECT {_READ_SELECT} FROM challenge_outcome WHERE user_id = %s "
        "ORDER BY ended_at DESC LIMIT %s",
    )
    cur.execute(query, (user_id, max(1, min(limit, MAX_RECENT_OUTCOMES))))
    return [dict(zip(_READ_COLUMNS, row, strict=True)) for row in cur.fetchall()]


def since(cur: Cur, user_id: UUID, instant: datetime) -> list[dict]:
    """One owner's frozen outcomes that ended at or after ``instant``, newest first.

    The read a time-bounded rule wants, bounded by the quantity the rule is actually
    about. ``levers._recently_abandoned`` used ``recent(limit=50)`` with the reason
    "these rules only care about the LATEST row per metric, and there are nine metrics"
    — which is not what makes 50 sufficient. What made it sufficient was an unstated
    invariant, *fewer than ~50 outcomes are frozen in any 60 days*, and the legal worst
    case exceeds it: ``lifecycle.MAX_ACTIVE = 3`` concurrent challenges at
    ``gen_prompt.MIN_WINDOW_DAYS = 3`` is up to 60 outcomes in 60 days. A metric whose
    latest outcome fell past row 50 read as *never abandoned* and was re-offered inside
    its own cooldown.

    Still windowed (standards section Performance): the bound is the cooldown itself, so
    the read can never return more than the outcomes physically frozen in that span.
    ``ended_at`` is the same column ``recent`` orders on, and it is indexed by the
    table's own ordering read.
    """
    query = cast(  # `_READ_SELECT` is a module constant of column names, never input
        LiteralString,
        f"SELECT {_READ_SELECT} FROM challenge_outcome WHERE user_id = %s "
        "AND ended_at >= %s ORDER BY ended_at DESC",
    )
    cur.execute(query, (user_id, instant))
    return [dict(zip(_READ_COLUMNS, row, strict=True)) for row in cur.fetchall()]


def by_challenge(cur: Cur, user_id: UUID, challenge_ids: Sequence[int]) -> dict[int, dict]:
    """The frozen outcomes for a NAMED set of this owner's challenges, keyed by id.

    ``recent`` answers "what has this owner done lately"; this answers "what happened to
    these particular commitments", which is the question a program read asks of its own
    rungs. One statement over the whole set rather than a lookup per rung — a ladder is a
    handful of rows and an N+1 on a read path is a budget violation, not a style point
    (standards §Performance).

    A rung with no outcome is simply absent from the result: a locked rung never ran and
    an active one has not finished, and both are states the caller must be able to tell
    from "ended with nothing recorded".
    """
    if not challenge_ids:
        return {}
    query = cast(  # `_READ_SELECT` is a module constant — see `recent`
        LiteralString,
        f"SELECT {_READ_SELECT} FROM challenge_outcome "
        "WHERE user_id = %s AND challenge_id = ANY(%s)",
    )
    cur.execute(query, (user_id, list(challenge_ids)))
    rows = (dict(zip(_READ_COLUMNS, row, strict=True)) for row in cur.fetchall())
    return {int(row["challenge_id"]): row for row in rows}


# Mirrors `_store`'s INSERT, and IS the SELECT both reads run — the two used to be a
# tuple and a hand-typed string beside each other, which is one edit away from a
# ledger read that silently drops a column. ``difficulty`` was
# written on every row and selected on none (#62) — populated, and invisible on the
# wire. Resolved as a MISSING FIELD rather than dead data: the difficulty of what
# someone was asked to do is half of what an outcome means (a met `stretch` and a met
# `gentle` are different results), and the rollup that groups outcomes by it is a
# planned surface — CHALLENGES.md's WP-C6 Insights tab, which legacy already shipped.
# The column is NULLABLE, so it is read and modelled as nullable even though today's
# writer always fills it from a NOT NULL `challenge.difficulty`: rows written before
# `_store` carried the column, and rows from any future writer, outlive that habit.
_READ_COLUMNS = (
    "challenge_id",
    "metric",
    "category",
    "difficulty",
    "cadence",
    "target",
    "baseline",
    "final",
    "improvement_pct",
    "improved",
    "adherence",
    "days_active",
    "status",
    "confounds",
    "co_occurring",
    "data_confidence",
    "ended_at",
)

_READ_SELECT = ", ".join(_READ_COLUMNS)
