"""Today-page series + cards: the secondary metric cards, the 14-day sparklines,
and today's intraday HR / step / stress shapes. v2-native: ``derived_daily`` for
day series/cards, the raw ``sample`` table for intraday, ``weight_log`` for weight.

Sparkline GAPs (keys kept for wire-compat, empty in v2): ``sleep_score`` (v2 uses
``sleep_health_score_4dim``), ``stress`` and ``pai_total`` (not derived in v2 —
analytics/metrics.py). Documented in the WP7 report.
"""

from __future__ import annotations

from datetime import date
from uuid import UUID

from healthee.analytics.baselines import compute_baseline_cur
from healthee.core.tenancy import reference_day
from healthee.derive._common import Cur, _day_bounds_utc
from healthee.derive.freshness import (
    NOT_DERIVED_YET_MESSAGE,
    WEIGHT_STALE,
    WEIGHT_STALE_MESSAGE,
    unavailable_reason,
    weight_is_stale,
    withheld_block,
)
from healthee.derive.hr_validity import HR_VALID_BOUNDS, HR_VALID_SQL
from healthee.read.common import TodayReads, derived_series_many, latest_derived, provenance
from healthee.read.meta import METRIC_META, METRIC_NOTE_ID, TODAY_SECONDARY_METRICS

# Why every intraday query below carries `_day_bounds_utc`'s half-open `ts` range
# ALONGSIDE its `(ts AT TIME ZONE %s)::date = %s` filter: `sample` is a hypertable
# partitioned on `ts`, and a query with no `ts` predicate gets NO chunk exclusion —
# the tz-date expression is a Filter, never an Index Cond, so answering "today" opened
# every chunk of all history. Measured on a 1-year, 1.37 M-row table: 7,914 buffers /
# 53 chunks before, 17 buffers / 1 chunk after, and the old form was O(all history) —
# degrading forever against a p95 < 100 ms budget.
#
# The date filter STAYS. The range is implied by it, so it prunes chunks without
# changing a single row — that redundancy is the correctness argument, not an
# oversight, and `tests/read/test_day_window.py` proves the two agree instant for
# instant against Postgres' own `AT TIME ZONE`, DST transitions included.


def secondary_cards(
    cur: Cur, user_id: UUID, tz: str, reads: TodayReads | None = None, day: date | None = None
) -> list[dict]:
    """RHR / steps / calories / distance / weight cards — first candidate with data
    wins, each with its 30-day median + z-anomaly flag. ``reads`` (when supplied by
    the Today aggregator) serves latest-values + baselines from a single preloaded
    batch instead of a per-card query fan-out."""
    as_of = reference_day(day, tz)
    out: list[dict] = []
    for candidates in TODAY_SECONDARY_METRICS:
        card = _card_for(cur, user_id, tz, candidates, reads, as_of)
        if card:
            out.append(card)
    return out


def _card_for(
    cur: Cur,
    user_id: UUID,
    tz: str,
    candidates: list[str],
    reads: TodayReads | None,
    as_of: date,
) -> dict | None:
    for cand in candidates:
        picked = (
            _weight_card(cur, user_id, tz, as_of)
            if cand == "weight_kg"
            else _derived_card(cur, user_id, tz, cand, reads, as_of)
        )
        if picked:
            return picked
    return None


def _derived_card(
    cur: Cur, user_id: UUID, tz: str, metric: str, reads: TodayReads | None, as_of: date
) -> dict | None:
    """One derived secondary card — the day's value, its date, and the gate on both.

    **The date was being thrown away.** ``latest_derived`` answers "the newest row at or
    before this day", which on a day with no row is an OLDER day's row — and this card
    unpacked it as ``_day, value, flags`` and shipped the value bare. So a resting heart
    rate measured three nights ago rendered in the Today row as this morning's, with
    nothing on the wire able to say otherwise. That is the stale-as-current class in
    ``derive/freshness.py``'s opening paragraph, on the page whose whole contract is the
    named day, and it applied to every metric in this row: RHR, steps, all three calorie
    rows, distance.

    The gate is ``freshness.unavailable_reason`` — the ONE question, not a fourth date
    check — and the treatment is the one ``_weight_card`` below already gives: the date
    always ships, and past the gate ``value`` itself goes ``None`` with a ``withheld``
    block carrying the last reading. Both halves, because a date in a field the UI may
    not render does not undo a confident current-looking number
    (``read/vo2max.py``).

    Weight is deliberately NOT on this path: it is typed in rather than derived, so it
    gets ``freshness``'s documented horizon instead of today-or-nothing. That split is
    argued in that module, not re-decided here.
    """
    latest = reads.latest.get(metric) if reads else latest_derived(cur, user_id, metric, as_of)
    if not latest:
        return None
    row_day, value, flags = latest
    reason = unavailable_reason(as_of, row_day)
    meta = METRIC_META[metric]
    # Preloaded baseline when the aggregator supplied one; else compute on demand —
    # on THIS cursor, so a card whose metric the aggregator forgot to preload costs an
    # extra query, never an extra pooled connection. Either way it ENDS at the reference
    # day, so the z-score prices this value against days that had already happened.
    baseline = (reads.baselines.get(metric) if reads else None) or compute_baseline_cur(
        cur, user_id, tz, metric, window_days=30, end_date=as_of
    )
    z = None if reason else baseline.z_score(value)
    return {
        "metric": metric,
        "label": meta["label"],
        "value": None if reason else value,
        "unit": meta["unit"],
        # The window's own centre and spread, ending at the reference day. Kept when the
        # value is withheld for the reason ``read/vo2max.py`` keeps ``median_for_age``:
        # this describes the 30 days behind the day, not the day itself, so withholding
        # it would be silence about something we do know. `sd_30d` is the MAD scaled to a
        # normal-equivalent SD (#B4) — the same spread `z` is already divided by, so a
        # client can draw the band it was scored against instead of a bare line.
        "median_30d": baseline.median,
        "sd_30d": baseline.robust_sd,
        "z": z,
        "anomalous": z is not None and abs(z) >= 2,
        # The row's OWN day, always — including when it is the reference day. A field
        # that appears only on stale answers is one the client learns to ignore.
        "as_of_date": row_day.isoformat(),
        "withheld": withheld_block(
            reason, NOT_DERIVED_YET_MESSAGE, as_of, row_day, last_value=value
        )
        if reason
        else None,
        # A PERMANENT key, empty for every metric with nothing to disclose (#127). The
        # derive layer decides what leans and why — this card only refuses to drop it,
        # which is the half that was missing: `derive/energy.py` could have stamped a
        # stale-weight caveat for months and no reader would have rendered it, because
        # this function discarded `flags` outright.
        "caveats": flags.get("caveats") or [],
        # WHICH instrument produced this number, and what it was assembled from — the
        # derive layer's own record, forwarded rather than re-derived. `derive/
        # device_totals.py` decides between two step instruments and stamps the answer in
        # `flags.source`; `derive/energy.py` records how much of a day's calories came
        # from the MET model and how much from the device's workout figure. Both stopped
        # at the database until now (audit C5, C6), which is the same silence `caveats`
        # above was added to end: a disclosure only the database can see is not a
        # disclosure. See `read/common.provenance` for the allow-list and why it is one.
        "provenance": provenance(flags),
        # The note licensing the card, for the ⓘ sheet. None for a metric we have not
        # cited, never a guessed id.
        "note_id": METRIC_NOTE_ID.get(metric),
    }


def _weight_card(cur: Cur, user_id: UUID, tz: str, as_of: date) -> dict | None:
    """Weight is stored in ``weight_log`` (not derived_daily); no derived baseline.

    This card sat in the Today row beside steps and calories and rendered the newest
    ``weight_log`` value with no date on it at all — so a weigh-in from March read as
    "Weight 79.9 kg" in August, indistinguishable from a number measured this morning.
    That is the stale-as-current class, on the page whose entire contract is *today*.

    Two things change and both are needed. ``as_of_date`` always ships, so a weight that
    is merely a few days old is still shown and is now dated. Past
    ``freshness.WEIGHT_MAX_AGE_DAYS`` the ``value`` itself goes ``None`` and a
    ``withheld`` block carries the last reading — because a date in a field the UI may
    not render does not undo a confident current-looking number, which is the lesson
    ``read/vo2max.py`` is written on.

    As of a past day the weigh-in is the newest one filed ON OR BEFORE it, and the
    14-day horizon is measured from THAT day. A weight logged three days before 29 July
    was that owner's weight on 29 July, and a weigh-in in August is not — which is the
    horizon-from-D rule, and the reason both the row and the staleness test move
    together rather than one of them.
    """
    cur.execute(
        "SELECT kg, (ts AT TIME ZONE %s)::date FROM weight_log "
        "WHERE user_id = %s AND (ts AT TIME ZONE %s)::date <= %s ORDER BY ts DESC LIMIT 1",
        (tz, user_id, tz, as_of),
    )
    r = cur.fetchone()
    if not r:
        return None
    kg, logged_on = float(r[0]), r[1]
    stale = weight_is_stale(logged_on, as_of)
    meta = METRIC_META["weight_kg"]
    return {
        "metric": "weight_kg",
        "label": meta["label"],
        "value": None if stale else kg,
        "unit": meta["unit"],
        # Both null and both PRESENT: weight lives in ``weight_log``, so it has no
        # ``derived_daily`` baseline to take a centre or a spread from. The keys stay so
        # every card in this row carries the same shape — a key that appears on some
        # cards and not others is one a client has to guess about.
        "median_30d": None,
        "sd_30d": None,
        "z": None,
        "anomalous": False,
        "as_of_date": logged_on.isoformat(),
        "withheld": withheld_block(WEIGHT_STALE, WEIGHT_STALE_MESSAGE, as_of, logged_on, last_kg=kg)
        if stale
        else None,
        # No `caveats`, no `provenance`: weight is TYPED IN rather than derived, so
        # there is no derive-layer record of its making to forward, and its own absence is
        # already answered by `withheld` above. The exception is pre-existing and pinned by
        # `tests/derive/test_calorie_weight_staleness.py`; the audit did not raise it and
        # this change does not reverse it.
        "note_id": METRIC_NOTE_ID["weight_kg"],
    }


# Legacy sparkline slots → the v2 metric that backs each. ``None`` = a v2 GAP
# (key kept for wire-compat, empty series). See the module docstring.
_SPARKLINE_METRICS: dict[str, str | None] = {
    "rhr_daily": "rhr_daily",
    "sleep_score": None,
    "sleep_health_score_4dim": "sleep_health_score_4dim",
    "sleep_regularity_index": "sleep_regularity_index",
    "hrv_sleep_avg": "hrv_sleep_avg",
    "stress": None,
    "pai_total": None,
    "total_calories": "total_calories",
    "respiratory_rate_sleep": "respiratory_rate_sleep",
    "spo2_overnight": "spo2_overnight",
    "spo2_overnight_min": "spo2_overnight_min",
}


def sparklines(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> dict[str, list[dict]]:
    """The 14 days ENDING at ``day``, per Today sparkline slot (empty for v2 gaps).

    All backed slots load in ONE batched query (``derived_series_many``) rather
    than a query per slot; the v2-gap slots (metric ``None``) stay empty."""
    backed = {key: m for key, m in _SPARKLINE_METRICS.items() if m}
    series = derived_series_many(cur, user_id, list(backed.values()), 14, reference_day(day, tz))
    return {
        key: (series.get(metric, []) if metric else [])
        for key, metric in _SPARKLINE_METRICS.items()
    }


def hr_hourly(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> list[dict]:
    """Hourly avg/min/max HR for one local day — that day's heart-rate shape.

    **This one needed only its anchor.** The query was already a per-day read
    (``(ts AT TIME ZONE %s)::date = %s``) with the wall clock supplying the day, so an
    older date is answerable from the same statement over the same raw samples. The
    hourly traces were the largest block ``docs/AS_OF_DAY.md`` did not have to argue
    for: nothing about them is derived or "latest".

    Bounded by ``derive.hr_validity``, the one plausibility predicate every HR
    reader shares.
    """
    day = reference_day(day, tz)
    ts_from, ts_to = _day_bounds_utc(day, tz)  # chunk pruning + the date filter; see above
    cur.execute(
        "SELECT date_trunc('hour', ts AT TIME ZONE %s) AS h, ROUND(AVG(value))::int, "
        "  MIN(value)::int, MAX(value)::int "
        f"FROM sample WHERE user_id = %s AND metric='hr' AND {HR_VALID_SQL} "
        "  AND ts >= %s AND ts < %s "
        "  AND (ts AT TIME ZONE %s)::date = %s GROUP BY 1 ORDER BY 1",
        (tz, user_id, *HR_VALID_BOUNDS, ts_from, ts_to, tz, day),
    )
    return [
        {"hour_iso": h.isoformat(), "hour": h.hour, "avg": avg, "min": mn, "max": mx}
        for h, avg, mn, mx in cur.fetchall()
    ]


def step_buckets(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> list[dict]:
    """One local day's 15-minute step buckets — steps, and only steps.

    ## The two fields this used to carry, and why neither could stay

    **``distance_m`` was ``SUM(value) * 0.78``**, inline in the SQL, a second definition of
    stride sitting beside the canonical one. ``derive/activity.py`` derives the stride from
    the OWNER's height (``0.414 × height``, [[distance_from_steps]]) and
    ``device_totals.select_distance`` returns ``None`` when there is no profile to take a
    height from — the honest refusal. ``0.78`` implies a 188 cm owner, needs no profile, and
    so could never refuse: at 175 cm the personal stride is 0.7245 m, making every bar
    about 7.7% long and stopping the strip from summing to the ``distance_m_daily`` card
    above it. Two definitions of one metric, and the uncited one was the one that never
    said "I don't know" (audit B4).

    **``calories`` was the literal ``0``** on every bucket — a hardcoded zero for a
    quantity nobody computed, bypassing the MET-by-state model entirely. That is the
    empty-collection failure ``read/today.py`` argues at length for ``anomalies`` ("an
    empty list is indistinguishable from 'nothing was anomalous'"), repeated as a scalar
    and worse, because a scalar zero reads as a measurement.

    Both are REMOVED rather than nulled, because there is no per-bucket quantity behind
    either name. Nothing renders them (``data/models/today_series.dart`` parses both and no
    widget reads either), so nothing loses a number. If the chart ever wants distance the
    derived ``stride_m`` gets passed in as a bound parameter and the field returns null
    without a profile, matching ``derive/activity.py``; per-bucket energy would have to
    come from the MET model, which is its own piece of work.
    """
    day = reference_day(day, tz)
    ts_from, ts_to = _day_bounds_utc(day, tz)  # chunk pruning + the date filter; see above
    cur.execute(
        "SELECT (time_bucket('15 minutes', ts) AT TIME ZONE %s)::time AS local_t, "
        "  SUM(value)::int AS steps, "
        "  (EXTRACT(HOUR FROM time_bucket('15 minutes', ts) AT TIME ZONE %s)::int * 4 "
        "   + EXTRACT(MINUTE FROM time_bucket('15 minutes', ts) AT TIME ZONE %s)::int / 15)::int "
        "FROM sample WHERE user_id = %s AND metric='steps_per_minute' "
        "AND ts >= %s AND ts < %s "
        "AND (ts AT TIME ZONE %s)::date = %s "
        "GROUP BY 1, 3 HAVING SUM(value) > 0 ORDER BY 1",
        (tz, tz, tz, user_id, ts_from, ts_to, tz, day),
    )
    return [
        {
            "time": local_t.isoformat(timespec="minutes"),
            "bucket": bucket,
            "steps": steps,
        }
        for local_t, steps, bucket in cur.fetchall()
    ]


def stress_series(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> list[dict]:
    """Hourly stress averages for one local day. Empty if no stress rows."""
    day = reference_day(day, tz)
    ts_from, ts_to = _day_bounds_utc(day, tz)  # chunk pruning + the date filter; see above
    cur.execute(
        "SELECT date_trunc('hour', ts AT TIME ZONE %s) AS h, ROUND(AVG(value))::int, "
        "  MAX(value)::int, COUNT(*)::int "
        "FROM sample WHERE user_id = %s AND metric='stress' AND value BETWEEN 0 AND 100 "
        "  AND ts >= %s AND ts < %s "
        "  AND (ts AT TIME ZONE %s)::date = %s GROUP BY 1 ORDER BY 1",
        (tz, user_id, ts_from, ts_to, tz, day),
    )
    return [
        {"hour_iso": h.isoformat(), "hour": h.hour, "avg": avg, "max": mx, "n": n}
        for h, avg, mx, n in cur.fetchall()
    ]
