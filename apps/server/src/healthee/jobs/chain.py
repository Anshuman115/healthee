"""The supervised event chain — replaces the legacy shell ``Popen``.

Legacy triggered ``subprocess.Popen("healthee correlate && healthee recs && "
"healthee daily-insight", shell=True)`` from two sites (api/app.py:933,
v2/api.py:74). A failure in any step vanished into the shell — the classic
swallowed-error class the rebuild exists to kill.

Here the same three steps run IN ORDER as in-process function calls, each wrapped
by ``_run_supervised``: a failure is CAUGHT, logged with context through
``core.logging``, and reported to Telegram via ``core.notify`` — never silently
passed (standards §1: "Background/silent contexts … must report failures to their
health surface"). The chain then applies dependency logic:

  * a ``correlate`` failure ABORTS ``recs`` (recs reads the findings correlate
    writes) — recs is marked skipped, not run on stale inputs;
  * a ``briefing`` failure does NOT undo the recs already persisted.

The chain is deduped per day via the ``kv`` table: once a day's chain has run its
generating steps, a second ``run_chain`` for that day is a no-op (legacy deduped
on last-night's sleep landing). ``run_step`` exposes the same supervised runner
for the scheduler, which fires the steps on their own daily timers.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import date
from uuid import UUID

from healthee.core.db import transaction
from healthee.core.logging import get_logger
from healthee.core.notify import send_telegram
from healthee.core.tenancy import user_today
from healthee.insights.client import LLMClient
from healthee.jobs import briefing as briefing_mod
from healthee.jobs import correlate as correlate_mod
from healthee.jobs import recs as recs_mod

log = get_logger(__name__)

STEP_NAMES = ("correlate", "recs", "briefing")

# kv key prefix; the per-day marker is f"{_DONE_KEY}:{day}". The OWNER is deliberately
# NOT in this string: 0004 folded user_id into the kv PRIMARY KEY and every read of it
# filters by owner, so two users' markers for the same day are already distinct rows.
# Prefixing would state the tenant twice — once in the key column, once in the string.
_DONE_KEY = "job:chain_done"


@dataclass
class StepOutcome:
    """Result of one supervised step: ok / failed / skipped, plus its detail/error."""

    name: str
    status: str  # "ok" | "failed" | "skipped"
    detail: dict | None = None
    error: str | None = None


@dataclass
class ChainResult:
    """Outcome of a whole ``run_chain`` invocation."""

    day: date
    deduped: bool
    steps: list[StepOutcome] = field(default_factory=list)


# ── the three steps (thin adapters onto the step modules) ──────────────────────


def step_correlate(
    _day: date,
    user_id: UUID,
    tz: str,
    *,
    client: LLMClient | None = None,  # noqa: ARG001
) -> dict:
    """Recompute one owner's personal findings (no LLM — ``client`` is unused here)."""
    return correlate_mod.run_correlate(user_id, tz)


def step_recs(day: date, user_id: UUID, tz: str, *, client: LLMClient | None = None) -> dict:
    """Generate one owner's grounded recommendations for their local day."""
    return recs_mod.generate_recs(user_id, tz, day, client=client)


def step_briefing(day: date, user_id: UUID, tz: str, *, client: LLMClient | None = None) -> dict:
    """Send one owner's morning Telegram briefing."""
    return briefing_mod.send_briefing(user_id, tz, day, client=client)


# ── supervision ────────────────────────────────────────────────────────────────


def _run_supervised(name: str, run: Callable[[], dict]) -> StepOutcome:
    """Run one step; on ANY exception log with context + Telegram-notify, never pass.

    This is the fix for the legacy swallow: the failure is surfaced on the job
    health surface (logs + Telegram) and returned as a ``failed`` outcome — the
    process is not crashed and the error is not hidden (standards §1).
    """
    log.info("chain step '%s' starting", name)
    try:
        detail = run()
    except Exception as exc:  # supervised boundary: report to the health surface, don't swallow
        log.exception("chain step '%s' failed", name)
        send_telegram(f"chain step '{name}' failed: {exc}")
        return StepOutcome(name=name, status="failed", error=str(exc))
    log.info("chain step '%s' ok: %s", name, detail)
    return StepOutcome(name=name, status="ok", detail=detail)


def run_step(
    name: str,
    user_id: UUID,
    tz: str,
    day: date | None = None,
    *,
    client: LLMClient | None = None,
) -> StepOutcome:
    """Supervised single-step run for ONE owner (used by the scheduler's sweep).

    ``day`` defaults to THAT owner's local today (from their ``tz``) — a global
    "today" would put a user several zones away on the wrong day's data.

    Dispatches to the module-level ``step_*`` functions by name (resolved at call
    time, so they stay individually patchable/testable).
    """
    day = day or user_today(tz)
    if name == "correlate":
        return _run_supervised(name, lambda: step_correlate(day, user_id, tz, client=client))
    if name == "recs":
        return _run_supervised(name, lambda: step_recs(day, user_id, tz, client=client))
    if name == "briefing":
        return _run_supervised(name, lambda: step_briefing(day, user_id, tz, client=client))
    raise ValueError(f"unknown chain step: {name!r}")


# ── the chain ──────────────────────────────────────────────────────────────────


def run_chain(
    user_id: UUID,
    tz: str,
    day: date | None = None,
    *,
    client: LLMClient | None = None,
    force: bool = False,
) -> ChainResult:
    """Run ONE owner's correlate → recs → briefing in order, supervised, deduped per day.

    Dependency: a ``correlate`` failure skips ``recs`` (which depends on the
    findings it writes). A ``briefing`` failure never undoes persisted recs. A
    second call for an already-run day is a no-op unless ``force`` — and the dedup
    marker is per-owner (the folded ``kv`` PK), so one owner's chain can never dedup
    another's. ``day`` defaults to the owner's own local today.
    """
    day = day or user_today(tz)
    if not force and _chain_done(user_id, day):
        log.info("chain[%s] for %s already ran — dedup no-op", user_id, day)
        return ChainResult(day=day, deduped=True)

    steps: list[StepOutcome] = []
    correlate = _run_supervised(
        "correlate", lambda: step_correlate(day, user_id, tz, client=client)
    )
    steps.append(correlate)

    if correlate.status == "ok":
        steps.append(_run_supervised("recs", lambda: step_recs(day, user_id, tz, client=client)))
        # Correlate succeeded → recs had valid inputs and its chance to run; mark the
        # day done so it isn't re-run. A correlate failure leaves it un-marked so a
        # later fire/ingest retries the whole chain.
        _mark_chain_done(user_id, day)
    else:
        steps.append(
            StepOutcome(
                name="recs",
                status="skipped",
                error="correlate failed — recs depends on its findings",
            )
        )

    steps.append(
        _run_supervised("briefing", lambda: step_briefing(day, user_id, tz, client=client))
    )
    return ChainResult(day=day, deduped=False, steps=steps)


def _chain_done(user_id: UUID, day: date) -> bool:
    """True if this user's chain has already run its generating steps for ``day``."""
    with transaction() as cur:
        cur.execute(
            "SELECT 1 FROM kv WHERE user_id = %s AND key = %s",
            (user_id, f"{_DONE_KEY}:{day.isoformat()}"),
        )
        return cur.fetchone() is not None


def _mark_chain_done(user_id: UUID, day: date) -> None:
    """Set ``user_id``'s per-day dedup marker (idempotent upsert).

    The marker is per-owner via the folded kv PK, so one user's chain cannot dedup
    another's — which is what makes the 6.3c per-user sweep safe to run.
    """
    with transaction() as cur:
        cur.execute(
            "INSERT INTO kv (user_id, key, value) VALUES (%s, %s, %s) "
            "ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value",
            (user_id, f"{_DONE_KEY}:{day.isoformat()}", day.isoformat()),
        )
