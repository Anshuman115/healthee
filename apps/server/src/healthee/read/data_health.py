"""Per-feed freshness and sync recency — the data-trust card on the Today page.

Split out of ``read/recovery.py`` when that file passed the 400-line gate for the third
time (standards §1), and the seam is the one the as-of-day work made unmistakable.

**This is the only block of ``/api/today`` that describes NOW rather than a day.**
Everything else on that page is a claim about a calendar date and is read from the rows
filed under it, so it answers for any day the owner has data for
(``docs/AS_OF_DAY.md``). Nothing here is: every number below is an age measured against
the request instant — hours since the last heart-rate sample, whether a feed has gone
silent past its cadence, how long since the strap last synced. Those are observations
made *now*, which for a past day would be observations made AFTER it, i.e. the future
leak in its most literal form.

So ``read/today.py`` serves this block only on the owner's today and sends ``null``
otherwise, and this module has one reason to change (what "a live feed is healthy"
means) while recovery has another (what the markers say about the body). It is
deliberately NOT given a ``day`` parameter: a signature that accepted one would invite a
caller to believe an older day could be answered for, and the honest answer is that this
question has no past tense.
"""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from healthee.derive._common import Cur

# (raw metric, label, expected-cadence days). A feed silent longer than this is dead.
_DATA_HEALTH_SPEC = [
    ("hr", "Heart rate", 2),
    ("steps_per_minute", "Steps", 2),
    ("hrv", "HRV", 4),
    ("spo2", "Blood oxygen", 4),
    ("respiratory_rate", "Breathing", 4),
    ("stress", "Stress", 3),
]


def _last_seen(cur: Cur, user_id: UUID, metric: str) -> datetime | None:
    """Newest sample instant for one feed — a targeted index probe, not a scan.

    Six of these beat the one grouped `SELECT metric, max(ts) … GROUP BY metric`
    they replace by ~580x. Measured with EXPLAIN (ANALYZE, BUFFERS) on a year of
    realistic multi-metric data (1.37 M rows / 53 chunks): grouped = 10,481 buffers;
    these six probes = 3 buffers each, 18 total. The grouped form's cost also scales
    with history, while a probe's does not.

    The mechanism is NOT our `0008` `timescaledb.enable_skipscan=off` workaround —
    measured identical with SkipScan on and off, because SkipScan applies to
    `DISTINCT ON`, not to `GROUP BY … max()`. The real reason is that `GROUP BY`
    defeats Postgres' min/max index rewrite: it reads every matching row to compute
    each group's max, where `ORDER BY ts DESC LIMIT 1` walks the index backwards and
    stops at the first row.

    So this is not "N+1 queries are fine". A round-trip per ITEM is still the thing
    standards §1 bans; six bounded probes on the caller's cursor against one scan of
    all history is a different trade, and the numbers are why it goes this way.
    """
    cur.execute(
        "SELECT ts FROM sample WHERE user_id = %s AND metric = %s ORDER BY ts DESC LIMIT 1",
        (user_id, metric),
    )
    row = cur.fetchone()
    return row[0] if row else None


def data_health_payload(cur: Cur, user_id: UUID) -> dict:
    """Per-feed freshness + sync recency so the app flags stale/dead data instead of
    rendering it as real. Conservative: only 'unavailable' when a feed delivered
    NOTHING within its cadence. Reads the v2 ``sample`` table (already v2-native)."""
    now = datetime.now(tz=UTC)
    items, degraded = [], []
    last_by_metric = {m: _last_seen(cur, user_id, m) for m, _, _ in _DATA_HEALTH_SPEC}
    for metric, label, days in _DATA_HEALTH_SPEC:
        last = last_by_metric.get(metric)
        age_h = (now - last).total_seconds() / 3600 if last else None
        status = "unavailable" if (age_h is None or age_h > days * 24) else "ok"
        if status != "ok":
            degraded.append(label)
        items.append(
            {
                "metric": metric,
                "label": label,
                "last_iso": last.isoformat() if last else None,
                "age_h": round(age_h, 1) if age_h is not None else None,
                "status": status,
            }
        )
    return _sync_recency(cur, user_id, now, items, degraded)


def _sync_recency(
    cur: Cur, user_id: UUID, now: datetime, items: list[dict], degraded: list[str]
) -> dict:
    """Sync recency = newest sample of ANY metric; overall trust rollup.

    The bare `max(ts)` with no metric filter is left exactly as it is, deliberately.
    Unlike the grouped scan `_last_seen` replaced, a plain ungrouped `max()` DOES get
    Postgres' min/max index rewrite: measured at 3 buffers on the 1.37 M-row year
    (Result -> ChunkAppend -> index scan of the newest chunk, every older chunk
    "never executed"). It is already optimal and derives no benefit from a metric
    filter or a probe rewrite — the `GROUP BY` was the whole problem, not `max(ts)`.
    """
    cur.execute("SELECT max(ts) FROM sample WHERE user_id = %s", (user_id,))
    r = cur.fetchone()
    newest = r[0] if r and r[0] else None
    age_h = (now - newest).total_seconds() / 3600 if newest else None
    sync_status = (
        "unavailable"
        if age_h is None
        else "ok"
        if age_h <= 8
        else "stale"
        if age_h <= 24
        else "very_stale"
    )
    overall = "ok" if (sync_status == "ok" and not degraded) else "degraded"
    return {
        "overall": overall,
        "sync_status": sync_status,
        "synced_age_h": round(age_h, 1) if age_h is not None else None,
        "synced_iso": newest.isoformat() if newest else None,
        "degraded": degraded,
        "items": items,
    }
