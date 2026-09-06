"""Find stored nights whose inputs arrived in this upload page.

Sleep sessions and their samples are uploaded independently. A session's first
derivation is therefore not final: subsequent pages must invalidate its metrics.
"""

from datetime import datetime
from uuid import UUID

from healthee.ingest.models import SampleIn
from healthee.ingest.upsert import Cur, epoch_to_utc

_NIGHT_INPUTS = frozenset({"hr", "hrv", "spo2", "respiratory_rate"})


def sample_affected_nights(
    cur: Cur, user_id: UUID, samples: list[SampleIn]
) -> list[tuple[datetime, datetime]]:
    """Select overlapping main sleeps in one owner-scoped query, including old nights."""
    instants = sorted({epoch_to_utc(s.ts) for s in samples if s.metric in _NIGHT_INPUTS})
    if not instants:
        return []
    cur.execute(
        "SELECT start_ts, end_ts FROM sleep_session "
        "WHERE user_id = %s AND kind = 'main' AND start_ts <= %s AND end_ts >= %s "
        "AND EXISTS (SELECT 1 FROM unnest(%s::timestamptz[]) AS incoming(ts) "
        "WHERE incoming.ts >= start_ts AND incoming.ts <= end_ts) "
        "ORDER BY start_ts",
        (user_id, instants[-1], instants[0], instants),
    )
    return [(row[0], row[1]) for row in cur.fetchall()]
