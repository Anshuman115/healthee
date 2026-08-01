"""``POST /api/today/action`` — the free tier's metered reveal of the daily action line.

The second half of ``PRICING.md`` §1a's teaser: *"1 daily-action reveal per rolling 7
days"*. The first half (the coach question) needed no new surface — ``POST /api/coach``
already existed and 6.6a-2 only widened its gate. This one needed a door, and the reason
is the shape of what 6.6a built.

## Why a POST at all — the jobs skip made "reveal" mean "generate"

``jobs/chain.py`` skips ``warm`` for a non-premium owner, so a free owner's daily action
line **is never generated**. Nothing is cached, and ``/api/today`` reads the cache and
never generates (standards §Performance: "generation never blocks a read path"). So a
reveal has exactly two possible meanings — generate on demand, or reveal nothing — and
"nothing" is not a taste of premium.

That leaves generating on demand, which the standards permit *here* and forbid on
``/api/today``: this is not a read and not a sync, it is a POST the owner explicitly
triggered, where a few seconds of latency is honest — the same argument
``api.routers.generation`` makes for the two generation endpoints, and the same argument
is why ``/api/today`` is left exactly as it was.

## What counts as a USE

**One reveal that produced a line.** Two cases, and only the first is charged:

* a **generation that shipped** — the model ran, the validator passed, the owner has a
  sentence they did not have before. That is the taste, and it is charged.
* a **degraded line** — refused, or unable to ground itself, so ``action`` is ``null``.
  The owner got nothing; charging a week's allowance for an apology would be the
  cheapest possible way to make the teaser feel like a bait. Refunded.

A cached line is served without generating (the normal path for a premium owner, whose
chain warmed it overnight) and the charge is given back, since no tokens were spent. For
a **free** owner that branch is all but unreachable, and the reason is worth stating
because it is a real consequence rather than an oversight: the gate charges in the
dependency, *before* the handler can look at the cache, so a free owner's second POST
inside the same seven days is a **402** and not a re-read. It has to be that way — a gate
that peeked and let the handler charge afterwards would let a hundred concurrent requests
all pass the peek and generate before any of them recorded a use, which is a bypass and
not a nicety. So the reveal is genuinely ONE reveal: the response carries the line, and
the client is what holds it. ``/api/today`` is deliberately not changed to serve it (see
``api.gate``) — a page load must not be able to spend the taste.

The refusal case is why this endpoint carries a SECOND limiter. An allowance that is always
refunded on failure is an unbounded free LLM door for an owner whose data cannot ground a
line, so the attempts that actually reach a model are bounded by ``core.rate_limit``
(:data:`REVEAL_ATTEMPTS_PER_DAY` per owner per local day) — the abuse/cost limiter, which
``challenges/budget.py``'s docstring says composes with entitlement rather than replacing
it. Entitlement asks *may this person*; the rate limit asks *how often may anyone*. Here
both are needed, and the ordering is the same as the generation endpoints': the gate
first, then the budget, and a request refused by the budget refunds the allowance before
it raises.
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

    Seconds, not milliseconds, on a cold day — a model runs inside this request. 402 when
    a free owner's weekly reveal is already spent (with the instant it comes back); 429
    when today's generation attempts are used up.
    """
    cached = coaching.cached_payload(user.id, user.timezone, coaching.DAILY_ACTION_KEY)
    if cached is not None:
        # The premium path: the chain warmed this overnight, so nothing is generated. The
        # refund is a no-op there (a premium request never charged) and is not decoration:
        # it is what keeps "the allowance pays for GENERATION" true if a free owner ever
        # reaches here — a warmed line surviving a mid-day lapse, say.
        gate.refund_ai_use(request, user)
        return _wire(cached)
    _charge_attempt(request, user)
    payload = coaching.warm_daily_action(user.id, user.timezone)
    if not _shippable(payload):
        gate.refund_ai_use(request, user)
    return _wire(payload)


def _charge_attempt(request: Request, user: RequestUser) -> None:
    """Charge one model attempt against today's cost budget, or 429 — refunding first.

    The refund is not optional: the gate has already recorded the owner's weekly reveal
    by the time this runs, and letting a 429 keep it would spend somebody's week on a
    request that never reached a model.
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
