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
from uuid import UUID

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

# derive_days(conn, user_id, days) is WP2's contract. Injectable so tests need no derive/.
DeriveTrigger = Callable[[Connection[TupleRow], UUID, str, list[date]], None]


class IngestSummary(BaseModel):
    """Counts returned to the app after a push (mirrors the legacy summary)."""

    samples_accepted: int
    samples_rejected: int
    sleep: int
    workouts: int
    daily_totals: int
    days_derived: int
    server_ts: int


def _default_derive(conn: Connection[TupleRow], user_id: UUID, tz: str, days: list[date]) -> None:
    """Default derive trigger — resolves WP2 at integration time.

    The import is intentionally local: it lets ingest build and be tested before
    derive/ lands, and it must FAIL LOUDLY at runtime if derive/ is missing
    (ingest that silently skipped derivation would leave stale dashboards).
    """
    from healthee.derive import derive_days

    derive_days(conn, user_id, tz, days)


def _affected_days(payload: HelioPayload, tz: str, is_fresh: Callable[..., bool]) -> list[date]:
    """The user-local dates this push touched — every day that got new samples,
    a workout, a daily total, or a fresh night. Fresh-gating the sleep dates
    keeps a re-push of ~80 historical nights from re-deriving all of them."""
    days: set[date] = set()
    for sample in payload.samples:
        if sample.metric in ALLOWED_METRICS:
            days.add(local_date(sample.ts, tz))
    for workout in payload.workouts:
        days.add(local_date(workout.start_ts, tz))
    for total in payload.daily_totals:
        days.add(total.day)
    for session in payload.sleep:
        if session.kind != "nap" and is_fresh(session):
            days.add(local_date(session.start_ts, tz))
            days.add(local_date(session.end_ts, tz))
    return sorted(days)


def ingest_helio(
    payload: HelioPayload, user_id: UUID, tz: str, *, derive: DeriveTrigger = _default_derive
) -> IngestSummary:
    """Apply a push end-to-end under `user_id` and return the counts.

    One transaction: upsert → derive touched days → apply the strap's daily-total
    override (after derive, which it corrects). `user_id` is the owner every raw,
    typed, and derived row is written under; the router supplies it (the sentinel
    today, the device token's real owner from 6.4 — MULTI_USER.md §7)."""
    with connection() as conn, conn.cursor() as cur:
        accepted, rejected = upsert_samples(cur, user_id, payload.samples)
        # Predicate must be built BEFORE upsert_sleep — it reads which nights
        # already existed so re-pushed history isn't re-emitted.
        is_fresh = build_fresh_predicate(cur, user_id, payload.sleep)
        n_sleep = upsert_sleep(cur, user_id, payload.sleep, is_fresh)
        n_workouts = upsert_workouts(cur, user_id, payload.workouts)
        if payload.profile is not None:
            upsert_profile(cur, user_id, payload.profile)
            if payload.profile.weight_kg is not None:
                upsert_weight(cur, user_id, tz, payload.profile.weight_kg)

        days = _affected_days(payload, tz, is_fresh)
        if days:
            derive(conn, user_id, tz, days)
        # Daily-total override runs AFTER derive on purpose (it overrides the
        # steps_total derive just computed with the strap's real counter).
        n_totals = apply_daily_totals(cur, user_id, payload.daily_totals)

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
