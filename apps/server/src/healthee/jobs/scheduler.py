"""In-process scheduler — fires the supervised chain steps on daily timers.

Ports the legacy ``scheduler.py`` cron loop (self-rescheduling, all times in
Asia/Kolkata) with the one structural change the rebuild mandates: it does NOT
``subprocess.call(["healthee", …])``. Each timer fires the corresponding
in-process chain step through ``chain.run_step`` — supervised, so a failure is
logged and Telegram-notified rather than lost (standards §2: "no ``subprocess``/
``Popen`` for in-process work — jobs run as supervised functions").

Each timer fires a SWEEP: the step runs once per active owner (`core.tenancy.
active_users`), against that owner's own data and own local day, with one owner's
failure isolated from the rest (§6). The fire times themselves stay global — see
``TZ`` for the accepted limitation and its 6.4 fix.

Schedule (late morning, AFTER a typical late wake + app push, so recs/briefing
don't compute on last night's not-yet-synced sleep) — times in ``TZ``:

    10:30  correlate     (recompute personal findings + cutoffs)
    10:45  recs          (grounded daily recommendations — reads correlate's output)
    11:00  briefing      (the morning Telegram daily-insight)

Run it as its own container CMD::

    python -m healthee.jobs.scheduler

Survives restarts: every loop recomputes the next fire from the current wall
clock, so there is no persisted timer to drift.
"""

from __future__ import annotations

import os
import time
from dataclasses import dataclass
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from healthee.core.logging import configure_logging, get_logger
from healthee.core.notify import send_telegram
from healthee.core.tenancy import Tenant, active_users
from healthee.jobs import chain

log = get_logger(__name__)

# The SWEEP CADENCE — the zone the fire times below are expressed in. It is NOT
# "the user's timezone": each owner's chain resolves its own local day from their
# `app_user.timezone` (see `_fire`), so what this constant fixes is only WHEN the
# sweep wakes up, not which day any owner's data is anchored to.
#
# KNOWN LIMITATION (accepted; per-user fire times are 6.4 — MULTI_USER.md §11): the
# times are global, so an owner far from this zone gets their chain at an awkward
# local hour — e.g. the 10:30 IST correlate lands at 00:00 for a US-Central owner,
# which still computes THEIR correct local day, just at an odd moment. §6's fix is
# ingest-triggered per-user chains (each strap syncs on its own schedule) plus a
# nightly sweep for stragglers.
TZ = ZoneInfo("Asia/Kolkata")

_UTC = ZoneInfo("UTC")
_SLEEP_CHUNK_S = 300  # wake every 5 min so a container stop signal isn't blocked
_POST_RUN_BUFFER_S = 60  # avoid re-firing inside the same minute


@dataclass(frozen=True)
class Job:
    """One daily timer bound to a supervised chain step."""

    step: str  # a name in chain.STEP_NAMES
    hour: int
    minute: int


# Defaults matched to the legacy schedule. The chain step names are the contract
# with ``chain.run_step``; the times are the in-container cron.
JOBS: tuple[Job, ...] = (
    Job(step="correlate", hour=10, minute=30),
    Job(step="recs", hour=10, minute=45),
    Job(step="briefing", hour=11, minute=0),
)


def next_fire(now_utc: datetime, hour: int, minute: int) -> datetime:
    """Next UTC instant matching (hour, minute) in the sweep zone (today or +1d)."""
    now_local = now_utc.astimezone(TZ)
    target = now_local.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if target <= now_local:
        target += timedelta(days=1)
    return target.astimezone(_UTC)


def _select_next(now_utc: datetime) -> tuple[datetime, Job]:
    """The earliest-firing job from now."""
    upcoming = [(next_fire(now_utc, j.hour, j.minute), j) for j in JOBS]
    return min(upcoming, key=lambda pair: pair[0])


def _sleep_until(when_utc: datetime) -> None:
    """Sleep in bounded chunks until ``when_utc`` (interruptible by a stop signal)."""
    remaining = (when_utc - datetime.now(tz=_UTC)).total_seconds()
    while remaining > 0:
        time.sleep(min(remaining, _SLEEP_CHUNK_S))
        remaining = (when_utc - datetime.now(tz=_UTC)).total_seconds()


def _fire_for(job: Job, tenant: Tenant) -> str:
    """Run one owner's step, isolating THIS owner's failure from the rest of the sweep.

    ``chain.run_step`` supervises the step body itself, but not everything can fail
    inside that boundary: resolving the owner's local day from ``tenant.tz`` happens
    first, so one bad ``app_user.timezone`` row would otherwise abort the sweep for
    every later owner — a single user's bad data silently costing everyone else their
    nightly chain. This boundary is the same contract as ``chain._run_supervised``:
    the failure is logged with the owner's id and reported to the Telegram health
    surface, never swallowed (standards §1) — it just doesn't stop the sweep.
    """
    try:
        return chain.run_step(job.step, user_id=tenant.id, tz=tenant.tz).status
    except Exception as exc:  # supervised: report, then continue the sweep
        log.exception("scheduler step '%s' failed for owner %s", job.step, tenant.id)
        send_telegram(f"scheduler step '{job.step}' failed for owner {tenant.id}: {exc}")
        return "failed"


def _fire(job: Job) -> None:
    """Run one job's chain step for EVERY active owner — the per-user sweep (§6).

    Each owner's step runs against their own data and their own local day (``run_step``
    derives the day from ``tenant.tz``). The ``active_users()`` lookup is deliberately
    OUTSIDE the per-owner boundary: if the owner list itself can't be read there is no
    sweep to continue, so that error propagates rather than being swallowed here.
    """
    tenants = active_users()
    log.info("scheduler firing '%s' for %d active owner(s)", job.step, len(tenants))
    for tenant in tenants:
        status = _fire_for(job, tenant)
        log.info("scheduler fired '%s' for %s → %s", job.step, tenant.id, status)


def main() -> None:
    """The self-rescheduling loop. Blocks forever; one job fires per wake."""
    configure_logging()
    log.info("healthee scheduler starting (tz=%s, pid=%d)", TZ, os.getpid())
    for j in JOBS:
        log.info("  scheduled: %-10s at %02d:%02d %s", j.step, j.hour, j.minute, TZ)

    while True:
        now_utc = datetime.now(tz=_UTC)
        fire_at, job = _select_next(now_utc)
        wait_min = (fire_at - now_utc).total_seconds() / 60
        log.info(
            "next: %s at %s (in %.1f min)",
            job.step,
            fire_at.astimezone(TZ).isoformat(timespec="minutes"),
            wait_min,
        )
        _sleep_until(fire_at)
        _fire(job)
        time.sleep(_POST_RUN_BUFFER_S)


if __name__ == "__main__":
    main()
