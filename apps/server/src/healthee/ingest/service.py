"""Orchestrates a full /ingest/helio push: upsert raw + typed rows, derive the
days the push touched, then apply the strap's authoritative daily-total override.

The whole flow is one transaction (`core.db.connection()` commits on clean exit),
so the daily-total override and the derivation it corrects are atomic — a partial
push never leaves the dashboard half-updated.

Derive seam (WP2): the derivation step is an injected callable. Its default lazily
imports `healthee.derive.derive_days` INSIDE the function — an intentional seam so
this package builds and its tests run before WP2 merges, not a swallowed error. If
derive/ is absent at runtime the default raises loudly (a silent skip would leave
the dashboard stale and lie about it); tests inject a stub.
"""

from __future__ import annotations

import time
from collections.abc import Callable
from datetime import date

from psycopg import Connection
from psycopg.rows import TupleRow
from pydantic import BaseModel

from healthee.core.db import connection
from healthee.core.logging import get_logger
from healthee.ingest.models import ALLOWED_METRICS, HelioPayload
from healthee.ingest.upsert import (
    apply_daily_totals,
    build_fresh_predicate,
    local_date,
    upsert_profile,
    upsert_samples,
    upsert_sleep,
    upsert_weight,
    upsert_workouts,
)

log = get_logger(__name__)

# derive_days(conn, days) is WP2's contract. Injectable so tests need no derive/.
DeriveTrigger = Callable[[Connection[TupleRow], list[date]], None]


class IngestSummary(BaseModel):
    """Counts returned to the app after a push (mirrors the legacy summary)."""

    samples_accepted: int
    samples_rejected: int
    sleep: int
    workouts: int
    daily_totals: int
    days_derived: int
    server_ts: int


def _default_derive(conn: Connection[TupleRow], days: list[date]) -> None:
    """Default derive trigger — resolves WP2 at integration time.

    The import is intentionally local: it lets ingest build and be tested before
    derive/ lands, and it must FAIL LOUDLY at runtime if derive/ is missing
    (ingest that silently skipped derivation would leave stale dashboards).
    """
    # derive/ is delivered by WP2; this import resolves at integration. The
    # pyright ignore is scoped to that seam only — remove it once WP2 merges.
    from healthee.derive import derive_days  # pyright: ignore[reportMissingImports]

    derive_days(conn, days)


def _affected_days(payload: HelioPayload, is_fresh: Callable[..., bool]) -> list[date]:
    """The user-local dates this push touched — every day that got new samples,
    a workout, a daily total, or a fresh night. Fresh-gating the sleep dates
    keeps a re-push of ~80 historical nights from re-deriving all of them."""
    days: set[date] = set()
    for sample in payload.samples:
        if sample.metric in ALLOWED_METRICS:
            days.add(local_date(sample.ts))
    for workout in payload.workouts:
        days.add(local_date(workout.start_ts))
    for total in payload.daily_totals:
        days.add(total.day)
    for session in payload.sleep:
        if session.kind != "nap" and is_fresh(session):
            days.add(local_date(session.start_ts))
            days.add(local_date(session.end_ts))
    return sorted(days)


def ingest_helio(
    payload: HelioPayload, *, derive: DeriveTrigger = _default_derive
) -> IngestSummary:
    """Apply a push end-to-end and return the counts. One transaction: upsert →
    derive touched days → apply the strap's daily-total override (after derive,
    which it corrects)."""
    with connection() as conn, conn.cursor() as cur:
        accepted, rejected = upsert_samples(cur, payload.samples)
        # Predicate must be built BEFORE upsert_sleep — it reads which nights
        # already existed so re-pushed history isn't re-emitted.
        is_fresh = build_fresh_predicate(cur, payload.sleep)
        n_sleep = upsert_sleep(cur, payload.sleep, is_fresh)
        n_workouts = upsert_workouts(cur, payload.workouts)
        if payload.profile is not None:
            upsert_profile(cur, payload.profile)
            if payload.profile.weight_kg is not None:
                upsert_weight(cur, payload.profile.weight_kg)

        days = _affected_days(payload, is_fresh)
        if days:
            derive(conn, days)
        # Daily-total override runs AFTER derive on purpose (it overrides the
        # steps_total derive just computed with the strap's real counter).
        n_totals = apply_daily_totals(cur, payload.daily_totals)

    log.info(
        "ingest_helio: samples=%d(-%d) sleep=%d workouts=%d totals=%d days=%d",
        accepted,
        rejected,
        n_sleep,
        n_workouts,
        n_totals,
        len(days),
    )
    return IngestSummary(
        samples_accepted=accepted,
        samples_rejected=rejected,
        sleep=n_sleep,
        workouts=n_workouts,
        daily_totals=n_totals,
        days_derived=len(days),
        server_ts=int(time.time()),
    )
