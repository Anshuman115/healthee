"""``POST /api/today/action`` — the owner-triggered reveal of the daily action line.

Gated on ``DAILY_ACTION`` (``api.gate``), which is **uncapped for a premium owner and
hard-locked for everyone else**: the free tier has no AI at all since 2026-08-02, and the
daily action is absent from ``gate.PREMIUM_ALLOWANCE``, so a subscriber may reveal it as
often as the cost limiter below allows. Only the coach carries an included-use cap.

> It was built for a teaser that no longer exists — ``PRICING.md`` §1a's "1 daily-action
> reveal per rolling 7 days", withdrawn with the rest of the free AI. The endpoint stays
> because its real user turned out to be the premium owner: it is the only door that
> **generates** the line rather than reading the overnight cache, which is what a premium
> owner needs on a day the chain has not run yet, and what a re-granted free taste would
> need again. The metering machinery it was written against is intact underneath it.

## Why a POST at all — a reveal can have to mean "generate"

``/api/today`` reads the cache and never generates (standards §Performance: "generation
never blocks a read path"), and ``jobs/chain.py`` warms that cache only for a premium
owner, and only once the chain has run. So a reveal has two possible meanings — generate
on demand, or reveal nothing — and "nothing" is not an answer.

That leaves generating on demand, which the standards permit *here* and forbid on
``/api/today``: this is not a read and not a sync, it is a POST the owner explicitly
triggered, where a few seconds of latency is honest — the same argument
``api.routers.generation`` makes for the two generation endpoints, and the same argument
is why ``/api/today`` is left exactly as it was.

## What counts as a USE

Nothing charges here today, because the only capped feature is the coach. The refunds
below are therefore no-ops *for this endpoint's current pricing* and are kept anyway, for
the reason ``gate.refund_ai_use`` exists at all: they are what keeps "the allowance pays
for a line we actually delivered" true the moment this feature is priced — a re-granted
free taste, or a premium cap on the reveal. Three outcomes, and only the first would ever
be charged:

* a **generation that shipped** — the model ran, the validator passed, the owner has a
  sentence they did not have before;
* a **degraded line** — refused, or unable to ground itself, so ``action`` is ``null``.
  The owner got nothing, so a charge is given back;
* a **cached line** — served without generating (the normal premium path, warmed
  overnight), so no tokens were spent and a charge is given back.

The degraded case is why this endpoint carries a SECOND limiter, and that one is live for
everybody. An allowance that is always refunded on failure would be an unbounded LLM door
for an owner whose data cannot ground a line, so the attempts that actually reach a model
are bounded by ``core.rate_limit`` (:data:`REVEAL_ATTEMPTS_PER_DAY` per owner per local
day) — the abuse/cost limiter, which ``challenges/budget.py``'s docstring says composes
with entitlement rather than replacing it. Entitlement asks *may this person*; the rate
limit asks *how often may anyone*. The ordering is the generation endpoints': the gate
first, then the budget, and a request refused by the budget refunds before it raises.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict

from healthee.api import gate
from healthee.api.gate import DailyActionUser
from healthee.core import rate_limit
from healthee.core.supabase_auth import RequestUser
from healthee.insights import coaching

router = APIRouter(tags=["today"])

# The `core.rate_limit` feature name and per-local-day cap on attempts that reach the
# model. Three is the same number the generation endpoints chose, for the same reason:
# the line is calibrated from whole local days, so a fourth attempt in one day asks a
# differently-worded question about identical inputs. It bounds the degraded-line retry
# loop the allowance refund would otherwise leave open (see §"What counts as a USE").
REVEAL_FEATURE = "daily_action_reveal"
REVEAL_ATTEMPTS_PER_DAY = 3


class RevealedAction(BaseModel):
    """The daily action line, or an honest ``null`` and the fact that it is degraded.

    ``action`` is required-and-nullable rather than absent: unlike ``/api/today``, where
    omission is a paywall closure (§12.7 — nothing to sniff), the owner has *paid* for
    this one with their allowance, so "we could not write you one" is the answer and it
    has to be sayable. ``degraded`` is what distinguishes it from "not generated yet".
    """

    model_config = ConfigDict(extra="forbid")

    action: str | None
    citations: list[str]
    day: str
    degraded: bool


@router.post("/api/today/action", response_model=RevealedAction)
def post_reveal_daily_action(request: Request, user: DailyActionUser) -> RevealedAction:
    """Reveal (generating if needed) this owner's daily action line for their local day.

    Seconds, not milliseconds, on a cold day — a model runs inside this request. 402 for a
    non-premium owner (the gate, before anything here runs); 429 when today's generation
    attempts are used up.
    """
    cached = coaching.cached_payload(user.id, user.timezone, coaching.DAILY_ACTION_KEY)
    if cached is not None:
        # The normal premium path: the chain warmed this overnight, so nothing is
        # generated — and since #95 it is the line the MERGED morning call produced, i.e.
        # the same sentence the Telegram briefing rendered rather than a second opinion
        # about the same day. The refund is a no-op while this feature is uncapped, and is
        # not decoration: it is what keeps "the allowance pays for GENERATION" true the day
        # somebody prices the reveal in either table.
        gate.refund_ai_use(request, user)
        return _wire(cached)
    _charge_attempt(request, user)
    payload = coaching.warm_daily_action(user.id, user.timezone)
    if not _shippable(payload):
        gate.refund_ai_use(request, user)
    return _wire(payload)


def _charge_attempt(request: Request, user: RequestUser) -> None:
    """Charge one model attempt against today's cost budget, or 429 — refunding first.

    The refund is not optional: whatever the gate recorded, it recorded before this runs,
    and letting a 429 keep it would spend an allowance on a request that never reached a
    model.
    """
    verdict = rate_limit.spend(user.id, user.timezone, REVEAL_FEATURE, REVEAL_ATTEMPTS_PER_DAY)
    if verdict.allowed:
        return
    gate.refund_ai_use(request, user)
    raise HTTPException(
        status_code=429,
        detail={
            "reason": "reveal_attempts_spent",
            "error": (
                f"the action line has been rewritten {verdict.limit} times today, which is "
                "all it gets — it is calibrated from whole days of your data, so another "
                "one today would be the same answer in different words. It resets at "
                "midnight your time."
            ),
            "limit": verdict.limit,
            "used": verdict.used,
            "resets_at": verdict.resets_at.isoformat(),
        },
        headers={"Retry-After": str(verdict.retry_after_s)},
    )


def _shippable(payload: dict) -> bool:
    """True iff the line validated and was not refused — i.e. it is a sentence to show."""
    return bool(payload.get("validated")) and not payload.get("refused")


def _wire(payload: dict) -> RevealedAction:
    """Shape a warm/cached coaching payload onto the response model."""
    shippable = _shippable(payload)
    return RevealedAction(
        action=payload.get("text") if shippable else None,
        citations=list(payload.get("citations") or []),
        day=str(payload.get("date", "")),
        degraded=not shippable,
    )
