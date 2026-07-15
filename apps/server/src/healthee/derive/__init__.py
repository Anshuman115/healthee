"""The derive package — the accuracy-gated science layer over the sample window.

Pure(ish) derivations that read the single-source `sample`/`sleep_session`/`workout`
tables and materialize `derived_daily`. Ported verbatim from the legacy v2 science
module, split by responsibility (each metric family in its own file). The public
contract WP3 (ingest) depends on:

    derive_day(cur, day)        -> dict   # derive + upsert all daily metrics for a day
    derive_days(conn, days)     -> None   # transactional convenience over many days
    derive_night(cur, s, e)     -> dict   # per-night metrics for one sleep session
    derive_all_nights()         -> dict   # derive every stored main sleep session
"""

from __future__ import annotations

from healthee.derive.orchestrator import (
    derive_all_nights,
    derive_day,
    derive_days,
    derive_night,
)

__all__ = ["derive_all_nights", "derive_day", "derive_days", "derive_night"]
