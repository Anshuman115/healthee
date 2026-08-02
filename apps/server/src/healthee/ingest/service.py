"""Orchestrates a full /ingest/helio push: upsert raw + typed rows, derive the
days the push touched, then apply the strap's authoritative daily-total override.

The whole flow is one transaction (`core.db.tenant_connection()` commits on clean
exit, and sets the owner the `0008` RLS policies gate on),
so the daily-total override and the derivation it corrects are atomic — a partial
push never leaves the dashboard half-updated.

Derive seam (WP2): the derivation step is an injected callable. Its default lazily
imports `healthee.derive.derive_batch` INSIDE the function — an intentional seam so
this package builds and its tests run before WP2 merges, not a swallowed error. If
derive/ is absent at runtime the default raises loudly (a silent skip would leave
the dashboard stale and lie about it); tests inject a stub.

What the push derives (#107): a `DerivePlan` of the push's fresh NIGHTS and the days
it touched — in that order, which `derive.derive_batch` owns. This used to be days
only, so the night pass never ran and every metric derived from a sleep session
silently stopped existing while the day metrics kept updating.
"""

from __future__ import annotations

import time
from collections.abc import Callable
from dataclasses import dataclass
from datetime import date, datetime
from uuid import UUID

from psycopg import Connection
from psycopg.rows import TupleRow
from pydantic import BaseModel

from healthee.core.db import tenant_connection
from healthee.core.logging import get_logger
from healthee.ingest.models import ALLOWED_METRICS, HelioPayload, SleepIn
from healthee.ingest.upsert import (
    apply_daily_totals,
    build_fresh_predicate,
    epoch_to_utc,
    local_date,
    upsert_profile,
    upsert_samples,
    upsert_sleep,
    upsert_weight,
    upsert_workouts,
)

log = get_logger(__name__)


@dataclass(frozen=True)
class DerivePlan:
    """The derivation one push implies: its fresh nights, and the days it touched.

    Two lists rather than one because they are two passes run in a fixed order, not one
    set of work — `derive.derive_batch` derives every night before any day, since the
    day pass reads what the night pass writes. Bundling them into one argument is what
    keeps that from degrading into two positional lists a caller can swap.
    """

    nights: list[tuple[datetime, datetime]]
    days: list[date]


# derive_batch(conn, user_id, tz, nights, days) is WP2's contract, addressed through a
# plan. Injectable so tests need no derive/.
DeriveTrigger = Callable[[Connection[TupleRow], UUID, str, DerivePlan], None]


class IngestSummary(BaseModel):
    """Counts returned to the app after a push (mirrors the legacy summary)."""

    samples_accepted: int
    samples_rejected: int
    sleep: int
    workouts: int
    daily_totals: int
    days_derived: int
    server_ts: int


def _default_derive(conn: Connection[TupleRow], user_id: UUID, tz: str, plan: DerivePlan) -> None:
    """Default derive trigger — resolves WP2 at integration time.

    The import is intentionally local: it lets ingest build and be tested before
    derive/ lands, and it must FAIL LOUDLY at runtime if derive/ is missing
    (ingest that silently skipped derivation would leave stale dashboards).
    """
    from healthee.derive import derive_batch

    derive_batch(conn, user_id, tz, plan.nights, plan.days)


def _is_derivable_night(session: SleepIn, is_fresh: Callable[[SleepIn], bool]) -> bool:
    """Is this pushed session a night worth deriving? — the ONE rule, asked twice.

    Naps never count: a nap is not a night, and `derive_night` writes overnight RHR /
    HRV / SpO2 / regularity rows keyed to a wake date. Stale re-pushed sessions do not
    count either, on the freshness predicate the per-minute emit already uses — which
    is what keeps a re-push of ~80 historical nights from re-deriving all 80.

    Nights and days ask the same question because they answer it about the same
    sessions; two spellings of "worth deriving" is how the two passes would drift apart.
    """
    return session.kind != "nap" and is_fresh(session)


def _affected_days(
    payload: HelioPayload, tz: str, is_fresh: Callable[[SleepIn], bool]
) -> list[date]:
    """The user-local dates this push touched — every day that got new samples,
    a workout, a daily total, or a fresh night."""
    days: set[date] = set()
    for sample in payload.samples:
        if sample.metric in ALLOWED_METRICS:
            days.add(local_date(sample.ts, tz))
    for workout in payload.workouts:
        days.add(local_date(workout.start_ts, tz))
    for total in payload.daily_totals:
        days.add(total.day)
    for session in payload.sleep:
        if _is_derivable_night(session, is_fresh):
            days.add(local_date(session.start_ts, tz))
            days.add(local_date(session.end_ts, tz))
    return sorted(days)


def _affected_nights(
    payload: HelioPayload, is_fresh: Callable[[SleepIn], bool]
) -> list[tuple[datetime, datetime]]:
    """This push's fresh main-sleep windows, oldest first — what `derive_night` needs.

    The seam `_affected_days`' docstring already implied ("a fresh night" is one of the
    things that marks a day affected) but nothing ever consumed: the day was derived,
    the night it depends on was not.
    """
    windows = [
        (epoch_to_utc(session.start_ts), epoch_to_utc(session.end_ts))
        for session in payload.sleep
        if _is_derivable_night(session, is_fresh)
    ]
    return sorted(windows)


def _derive_plan(payload: HelioPayload, tz: str, is_fresh: Callable[[SleepIn], bool]) -> DerivePlan:
    """Everything this push must derive, in the two passes it takes."""
    return DerivePlan(
        nights=_affected_nights(payload, is_fresh), days=_affected_days(payload, tz, is_fresh)
    )


def ingest_helio(
    payload: HelioPayload, user_id: UUID, tz: str, *, derive: DeriveTrigger = _default_derive
) -> IngestSummary:
    """Apply a push end-to-end under `user_id` and return the counts.

    One transaction: upsert → derive the touched nights and then days → apply the
    strap's daily-total override (after derive, which it corrects). `user_id` is the
    owner every raw, typed, and derived row is written under; the router supplies it
    (the sentinel today, the device token's real owner from 6.4 — MULTI_USER.md §7)."""
    with tenant_connection(user_id) as conn, conn.cursor() as cur:
        accepted, rejected = upsert_samples(cur, user_id, payload.samples)
        # Predicate must be built BEFORE upsert_sleep — it reads which nights
        # already existed so re-pushed history isn't re-emitted.
        is_fresh = build_fresh_predicate(cur, user_id, payload.sleep)
        n_sleep = upsert_sleep(cur, user_id, payload.sleep, is_fresh)
        n_workouts = upsert_workouts(cur, user_id, payload.workouts)
        if payload.profile is not None:
            upsert_profile(cur, user_id, tz, payload.profile)
            if payload.profile.weight_kg is not None:
                upsert_weight(cur, user_id, tz, payload.profile.weight_kg)

        plan = _derive_plan(payload, tz, is_fresh)
        if plan.nights or plan.days:
            derive(conn, user_id, tz, plan)
        # Daily-total override runs AFTER derive on purpose (it overrides the
        # steps_total derive just computed with the strap's real counter).
        n_totals = apply_daily_totals(cur, user_id, payload.daily_totals)

    log.info(
        "ingest_helio: samples=%d(-%d) sleep=%d workouts=%d totals=%d nights=%d days=%d",
        accepted,
        rejected,
        n_sleep,
        n_workouts,
        n_totals,
        len(plan.nights),
        len(plan.days),
    )
    return IngestSummary(
        samples_accepted=accepted,
        samples_rejected=rejected,
        sleep=n_sleep,
        workouts=n_workouts,
        daily_totals=n_totals,
        days_derived=len(plan.days),
        server_ts=int(time.time()),
    )
