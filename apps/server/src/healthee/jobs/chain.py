"""The supervised event chain — replaces the legacy shell ``Popen``.

Legacy triggered ``subprocess.Popen("healthee correlate && healthee recs && "
"healthee daily-insight", shell=True)`` from two sites (api/app.py:933,
v2/api.py:74). A failure in any step vanished into the shell — the classic
swallowed-error class the rebuild exists to kill.

Here the steps run IN ORDER as in-process function calls, each wrapped by
``_run_supervised``: a failure is CAUGHT, logged with context through
``core.logging``, and reported to Telegram via ``core.notify`` — never silently
passed (standards §1: "Background/silent contexts … must report failures to their
health surface"). The chain then applies dependency logic:

  * ``challenges`` runs FIRST and depends on nothing — closing out a commitment that
    ended last night, and moving a program ladder on from it, is not downstream of
    any computation, and an owner whose findings failed still deserves an honest
    outcome for it (WP-C2/WP-C4; the choice to finalize here rather than inside a
    list read is argued in ``challenges/lifecycle.py``);
  * a ``correlate`` failure ABORTS ``recs`` AND ``warm`` (both read the findings
    correlate writes, via the choke point's context) — they are marked skipped, not
    run on stale inputs;
  * a ``briefing`` failure does NOT undo the recs already persisted;
  * a ``warm`` failure costs only the coaching lines — the chain continues.

``warm`` is the step that makes the read surfaces' LLM lines exist at all: the
``/api/today`` action and the sleep-tonight line are cache-only on the read path
(``coaching.cached_line`` never generates, standards §Performance), so without an
off-read-path warmer they are null forever. It runs here, once per owner per THEIR
local day, because that is the one place that already knows both.

The chain is deduped per day via the ``kv`` table: once a day's chain has run its
generating steps, a second ``run_chain`` for that day is a no-op (legacy deduped
on last-night's sleep landing). That marker is what lets the scheduler tick
repeatedly and still run each owner's chain exactly once per their local day
(6.4c) — it is the whole idempotence story, so the scheduler owns no dedup of its
own.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import date
from uuid import UUID

from healthee.challenges import ladder, lifecycle
from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger
from healthee.core.notify import send_telegram
from healthee.core.tenancy import user_today
from healthee.insights import coaching as coaching_mod
from healthee.insights.client import LLMClient
from healthee.jobs import briefing as briefing_mod
from healthee.jobs import correlate as correlate_mod
from healthee.jobs import recs as recs_mod

log = get_logger(__name__)

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


# ── the steps (thin adapters onto the step modules) ───────────────────────────


def step_challenges(
    day: date,
    user_id: UUID,
    tz: str,
    *,
    client: LLMClient | None = None,  # noqa: ARG001
) -> dict:
    """Close out one owner's challenges that have ended, then move their ladder on (no LLM).

    This is where auto-completion lives, rather than inside the challenges list read
    the way legacy did it (``challenges/lifecycle.py`` argues the choice). It runs
    FIRST and independently of everything else: closing a finished commitment is not
    downstream of correlate, and an owner whose chain failed on findings should still
    get an honest outcome for the challenge that ended last night.

    Advancement (WP-C4) is the same step and the same transaction, deliberately. A
    program rung IS one of the challenges ``finalize_due`` just closed, so its terminal
    status and whatever the ladder does about it — promote, deload, hold, stop — are one
    fact about one night. Splitting them would let a rung be recorded ``expired`` while
    the ladder's answer to that failure rolled back, which is the half-state the freeze
    is written in-transaction to avoid.

    The ORDER here is the useful one, not a required one: ``advance_due`` reads the
    rungs' stored statuses rather than re-scoring them, so running it before the close
    would simply find an active rung and do nothing (``challenges/ladder.py``).
    """
    with tenant_transaction(user_id) as cur:
        closed = lifecycle.finalize_due(cur, user_id, tz, day)
        advanced = ladder.advance_due(cur, user_id, tz, day)
    return {"closed": closed, "advanced": advanced}


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


def step_warm(
    _day: date,
    user_id: UUID,
    tz: str,
    *,
    client: LLMClient | None = None,
) -> dict:
    """Warm one owner's read-surface coaching lines for their local day (off the read path).

    ``_day`` is unused deliberately: a coaching line is advice for the owner's day as
    it is NOW, and its cache freshness is stamped from ``tz`` (``cache.today_iso``).
    So a chain re-run for an explicit past ``day`` still warms today's lines rather
    than caching yesterday's advice under today's key.
    """
    return coaching_mod.warm_lines(user_id, tz, client=client)


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


# ── the chain ──────────────────────────────────────────────────────────────────


def run_chain(
    user_id: UUID,
    tz: str,
    day: date | None = None,
    *,
    client: LLMClient | None = None,
    force: bool = False,
) -> ChainResult:
    """Run ONE owner's challenges → correlate → recs → warm → briefing, supervised, deduped.

    Dependency: a ``correlate`` failure skips ``recs`` and ``warm`` (both consume the
    findings it writes). A ``briefing`` failure never undoes persisted recs, and a
    ``warm`` failure costs only the coaching lines. A second call for an already-run
    day is a no-op unless ``force`` — and the dedup marker is per-owner (the folded
    ``kv`` PK), so one owner's chain can never dedup another's. ``day`` defaults to
    the owner's own local today.
    """
    day = day or user_today(tz)
    if not force and _chain_done(user_id, day):
        log.info("chain[%s] for %s already ran — dedup no-op", user_id, day)
        return ChainResult(day=day, deduped=True)

    steps: list[StepOutcome] = []
    # Before anything is computed: close out what has already ended. Nothing below
    # depends on it, and it must not be skipped when something below fails.
    steps.append(
        _run_supervised("challenges", lambda: step_challenges(day, user_id, tz, client=client))
    )
    correlate = _run_supervised(
        "correlate", lambda: step_correlate(day, user_id, tz, client=client)
    )
    steps.append(correlate)

    if correlate.status == "ok":
        steps.append(_run_supervised("recs", lambda: step_recs(day, user_id, tz, client=client)))
        # Warming is NON-FATAL by construction (`_run_supervised` returns, never raises):
        # a missing coaching line is a degraded card, whereas aborting here would cost
        # the owner their briefing over a one-liner. The failure is still reported.
        steps.append(_run_supervised("warm", lambda: step_warm(day, user_id, tz, client=client)))
        # Correlate succeeded → the generating steps had valid inputs and their chance
        # to run; mark the day done so they aren't re-run. A correlate failure leaves it
        # un-marked so a later fire/ingest retries the whole chain.
        _mark_chain_done(user_id, day)
    else:
        steps.extend(_skipped_after_correlate())

    steps.append(
        _run_supervised("briefing", lambda: step_briefing(day, user_id, tz, client=client))
    )
    return ChainResult(day=day, deduped=False, steps=steps)


def _skipped_after_correlate() -> list[StepOutcome]:
    """The steps that must NOT run once ``correlate`` failed — both read its findings.

    ``recs`` reads them via ``recs_context``; ``warm`` reads them via the choke point's
    ``findings_section``. Running either on stale findings would ship yesterday's
    correlations as today's advice, which is the honesty contract's exact failure mode.
    """
    return [
        StepOutcome(
            name=name,
            status="skipped",
            error="correlate failed — this step depends on its findings",
        )
        for name in ("recs", "warm")
    ]


def _chain_done(user_id: UUID, day: date) -> bool:
    """True if this user's chain has already run its generating steps for ``day``."""
    with tenant_transaction(user_id) as cur:
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
    with tenant_transaction(user_id) as cur:
        cur.execute(
            "INSERT INTO kv (user_id, key, value) VALUES (%s, %s, %s) "
            "ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value",
            (user_id, f"{_DONE_KEY}:{day.isoformat()}", day.isoformat()),
        )
