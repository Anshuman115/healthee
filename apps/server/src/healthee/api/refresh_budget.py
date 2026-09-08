"""``refresh=true`` costs money, so it is metered. A cached read stays free.

## The gap this closes

Every insight route takes ``refresh: bool = False`` and forwards it;
``insights/surfaces.py`` skips the cache when it is true, which forces a fresh
generation. The gate above those routes is ``InsightUser`` / ``NotableUser``, and
``api.gate.PREMIUM_ALLOWANCE`` holds one entry — the coach. By that table's own stated
semantics ("a feature ABSENT from this table is UNLIMITED"), ``INSIGHT`` and ``NOTABLE``
are uncapped for a paying owner, and ``core.rate_limit`` was applied to neither. A
premium owner — or anything holding their credential — polling ``?refresh=true`` spent
the OpenRouter budget in a loop.

## Why a limiter and not a ``PREMIUM_ALLOWANCE`` entry

Those are different questions and only one of them is being answered here.
``PREMIUM_ALLOWANCE`` prices what an owner is *entitled to*: the coach's 20 questions
are a product promise, printed on the pricing page, and spending one is a thing the
owner chose. A cached insight card costs nothing to serve, and reading it is not a use
of anything. Putting INSIGHT in the entitlement table would meter the READ — a paying
owner who opened the Sleep tab twenty times in a day would find their cards locked,
having spent nothing.

What actually costs is the one thing on these routes that bypasses the cache. So this
is ``core.rate_limit`` — the module whose docstring already says it "answers *how often
may anyone, premium included, spend on this*, and it is abuse/cost protection", and
which ``challenges/budget.py`` and ``api/routers/daily_action.py`` already use for
exactly this. Entitlement is checked first by the gate; this bounds the spend
underneath it. They compose rather than replace.
"""

from __future__ import annotations

from fastapi import HTTPException

from healthee.core import rate_limit
from healthee.core.supabase_auth import RequestUser

# The rate-limit feature key. One key for all five surfaces on purpose: the budget being
# protected is the OpenRouter bill, which is one bill, and five separate allowances would
# be five times the ceiling for the same money.
FEATURE = "insight_refresh"

# Six forced regenerations per owner per local day. A refresh is a deliberate "this card
# is stale, write me a new one" — the surfaces are five, so this is roughly one re-write
# of each per day plus a spare, and it is well above any honest use of the button while
# being nowhere near a poll. The neighbouring limiters are 3/day
# (``challenges.budget.GENERATIONS_PER_DAY``, ``daily_action.REVEAL_ATTEMPTS_PER_DAY``);
# this is more generous because it is shared across five surfaces rather than one.
REFRESHES_PER_DAY = 6


def charge_refresh(user: RequestUser, refresh: bool) -> bool:
    """Meter a forced regeneration; return the ``refresh`` flag to forward.

    Returns ``False`` unchanged when the caller did not ask for one — the cached read
    is free and must stay free, so nothing is spent and no row is written. Raises 429
    with the reset instant when today's budget is gone, matching the shape
    ``daily_action`` already returns.
    """
    if not refresh:
        return False
    verdict = rate_limit.spend(user.id, user.timezone, FEATURE, REFRESHES_PER_DAY)
    if verdict.allowed:
        return True
    raise HTTPException(
        status_code=429,
        detail={
            "reason": "insight_refreshes_spent",
            "error": (
                f"these cards have been rewritten {verdict.limit} times today, which is "
                "all they get — each one is written from whole days of your data, so "
                "another today would be the same answer in different words. The cards "
                "you have keep loading; the rewrites reset at midnight your time."
            ),
            "limit": verdict.limit,
            "used": verdict.used,
            "resets_at": verdict.resets_at.isoformat(),
        },
        headers={"Retry-After": str(verdict.retry_after_s)},
    )


__all__ = ["FEATURE", "REFRESHES_PER_DAY", "charge_refresh"]
