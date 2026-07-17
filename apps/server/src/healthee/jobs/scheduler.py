"""In-process scheduler — ticks, and runs each owner's chain at THEIR local fire time.

Replaces the legacy ``scheduler.py`` cron loop with the structural change the rebuild
mandates: it does NOT ``subprocess.call(["healthee", …])``. Each owner's chain runs
in-process through ``chain.run_chain`` — supervised, so a failure is logged and
Telegram-notified rather than lost (standards §2: "no ``subprocess``/``Popen`` for
in-process work — jobs run as supervised functions").

## The model: tick + the per-owner per-day marker (Phase 6.4c, MULTI_USER.md §6)

The loop does not compute "the next fire instant" and sleep to it. It **ticks** on a
bounded interval and, on every tick, asks of each active owner: *is it past their
local fire time, and has their chain not already run for their local day?* If so, run
it. Idempotence is not the loop's job — it belongs to ``run_chain``'s per-owner
per-day dedup marker (the folded ``kv`` PK), which is what makes this safe by
construction: a missed tick, a container restart, a slow run, or an owner who signed
up after their own fire time all resolve correctly on the next tick.

**Why not a next-fire timer** (the trap this design exists to avoid): a
"compute the next matching instant, sleep, fire, repeat" loop returns *tomorrow* once
an instant has passed. Extended per-(owner) it fires owner A at their 10:30, then
recomputes and sees owner B's identical 10:30 has *just passed* — so B's next fire
becomes tomorrow, and B is silently skipped every single day. Any owner sharing a
fire instant with an earlier-sorted owner never runs. A tick asks a *question about
the present* instead of scheduling a future instant, so it cannot express that bug.

## One chain per owner per local day (the 10:30/10:45/11:00 stagger is gone)

The three staggered timers are collapsed into a single ``run_chain`` per owner per
local day: ``run_chain`` already sequences correlate → recs → warm → briefing *with* the
dependency (a correlate failure skips recs), so the stagger only re-implemented that
ordering with sleep(). It was not spreading LLM load — the steps were fired in the
same fixed order at fixed offsets, and the sweep runs all owners back-to-back within
one timer anyway, so N owners already produced N chains in a burst.

Schedule: ``DAILY_FIRE`` (10:30) **in each owner's own timezone** — late morning,
AFTER a typical late wake + app push, so recs/briefing don't compute on last night's
not-yet-synced sleep. There is no longer a global fire zone (the old ``TZ``): an
owner's ``app_user.timezone`` is the only zone in play for them.

Run it as its own container CMD::

    python -m healthee.jobs.scheduler
"""

from __future__ import annotations

import os
import time
from dataclasses import dataclass
from datetime import date, datetime
from uuid import UUID
from zoneinfo import ZoneInfo

from healthee.core.logging import configure_logging, get_logger
from healthee.core.notify import send_telegram
from healthee.core.tenancy import Tenant, active_users
from healthee.jobs import chain

log = get_logger(__name__)

_UTC = ZoneInfo("UTC")

# How often the loop wakes to ask "is anyone due?". Also the bound on how long a
# container stop signal can be blocked (the old loop chunked its sleep for exactly
# this reason; the tick interval subsumes that). It is the granularity of a fire, not
# a deadline: an owner's chain starts within one tick of their local fire time.
_TICK_INTERVAL_S = 300

# How many times ONE owner's chain may be attempted for ONE of their local days.
#
# The dedup marker is only set once correlate succeeds (deliberately — see
# `chain.run_chain`), so a *failing* chain stays unmarked and would otherwise be
# retried on every tick for the rest of that owner's day: ~150 identical Telegram
# alerts, plus a re-sent briefing each time (briefing runs even when correlate fails).
# That is alert fatigue, which silently costs the health surface its meaning. This
# budget keeps the retry — a transient DB blip at 10:30 must not cost an owner their
# day — while bounding it. It is NOT idempotence (the marker is); it is a retry
# budget, and it deliberately lives in memory: a container restart is itself a good
# reason to try again.
_ATTEMPT_BUDGET = 3


@dataclass(frozen=True)
class FireTime:
    """The local wall-clock time an owner's daily chain runs at."""

    hour: int
    minute: int


DAILY_FIRE = FireTime(hour=10, minute=30)


def local_now(tenant: Tenant, now_utc: datetime) -> datetime:
    """``now_utc`` as wall-clock time in the owner's own zone."""
    return now_utc.astimezone(ZoneInfo(tenant.tz))


def is_due(local: datetime, fire: FireTime = DAILY_FIRE) -> bool:
    """True once the owner's local wall clock has reached their fire time.

    At/after — never "equals". An equality test would need the tick to land on the
    exact minute, so a tick landing at 10:31 would skip the owner for the whole day;
    "past it" plus the dedup marker is what makes a late tick self-heal instead.
    """
    return (local.hour, local.minute) >= (fire.hour, fire.minute)


class Sweeper:
    """The per-tick sweep over active owners, holding the in-memory retry budget.

    A class rather than module globals so the loop's state is injectable and a test
    can drive ``tick`` at arbitrary instants without patching a global (standards §2:
    no import-time side effects, everything testable).
    """

    def __init__(self, fire: FireTime = DAILY_FIRE, budget: int = _ATTEMPT_BUDGET) -> None:
        self._fire = fire
        self._budget = budget
        self._attempts: dict[tuple[UUID, date], int] = {}

    def tick(self, now_utc: datetime | None = None) -> None:
        """Run the chain for every owner whose local fire time has passed today.

        The ``active_users()`` lookup is deliberately OUTSIDE the per-owner boundary:
        if the owner list itself can't be read there is no sweep to continue, so that
        error propagates rather than being swallowed into a silently sweep-less night.
        """
        now_utc = now_utc or datetime.now(tz=_UTC)
        tenants = active_users()
        seen: set[tuple[UUID, date]] = set()
        for tenant in tenants:
            status, day = self._run_for(tenant, now_utc)
            if day is not None:
                seen.add((tenant.id, day))
            if status not in ("waiting", "deduped"):
                log.info("chain for owner %s → %s", tenant.id, status)
        self._prune(seen)

    def _run_for(self, tenant: Tenant, now_utc: datetime) -> tuple[str, date | None]:
        """One owner's tick, isolating THIS owner's failure from the rest of the sweep.

        ``run_chain`` supervises each step's body, but not everything can fail inside
        that boundary: resolving the owner's local day from ``tenant.tz`` happens
        first, so one bad ``app_user.timezone`` row would otherwise abort the sweep for
        every later owner — one user's bad data silently costing everyone else their
        nightly chain. The failure is logged with the owner's id and reported to the
        Telegram health surface, never swallowed (standards §1); it just doesn't stop
        the sweep.
        """
        day: date | None = None
        try:
            local = local_now(tenant, now_utc)
            day = local.date()
            if not is_due(local, self._fire):
                return "waiting", day
            return self._attempt(tenant, day), day
        except Exception as exc:  # supervised: report, then continue the sweep
            log.exception("chain failed for owner %s", tenant.id)
            send_telegram(f"chain failed for owner {tenant.id}: {exc}")
            if day is not None:
                self._spend(tenant, day)
            return "failed", day

    def _attempt(self, tenant: Tenant, day: date) -> str:
        """Run this owner's chain for ``day``, unless already done or out of budget."""
        if self._attempts.get((tenant.id, day), 0) >= self._budget:
            return "exhausted"
        result = chain.run_chain(tenant.id, tenant.tz, day)
        if result.deduped:
            return "deduped"  # the marker says this day already ran — costs no budget
        self._spend(tenant, day)
        failed = [step.name for step in result.steps if step.status == "failed"]
        return f"ran (failed steps: {', '.join(failed)})" if failed else "ran"

    def _spend(self, tenant: Tenant, day: date) -> None:
        """Charge one attempt against this owner-day; announce the last one."""
        spent = self._attempts.get((tenant.id, day), 0) + 1
        self._attempts[(tenant.id, day)] = spent
        if spent >= self._budget:
            log.warning(
                "chain budget spent for owner %s on %s — no more retries today", tenant.id, day
            )
            send_telegram(
                f"chain for owner {tenant.id} exhausted its {self._budget} attempts "
                f"for {day} — no further retries until tomorrow"
            )

    def _prune(self, seen: set[tuple[UUID, date]]) -> None:
        """Drop budget entries for days/owners this tick no longer sees.

        Without it the dict grows one entry per owner per day for the process's life.
        """
        self._attempts = {key: n for key, n in self._attempts.items() if key in seen}


def main() -> None:
    """The tick loop. Blocks forever."""
    configure_logging()
    log.info(
        "healthee scheduler starting (pid=%d, fire=%02d:%02d in each owner's own timezone, "
        "tick=%ds)",
        os.getpid(),
        DAILY_FIRE.hour,
        DAILY_FIRE.minute,
        _TICK_INTERVAL_S,
    )
    sweeper = Sweeper()
    while True:
        sweeper.tick()
        time.sleep(_TICK_INTERVAL_S)


if __name__ == "__main__":
    main()
