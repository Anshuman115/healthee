"""The ONE generation budget, charged by every door into the pipeline (#78).

There are two ways to make the pipeline author a challenge — ``POST /api/challenges/
generate`` and the coach's ``create_challenge`` tool — and until 6.6a only the first one
paid. This module is the shared charge, so "one budget" is a fact about the code rather
than a claim in two docstrings.

## Why the coach pays the same price

WP-C3b argued the other way: the coach's natural unit is a TURN, not a generation, so
metering one of its three tools would meter a third of a conversation. That is true and
it is not the point. A generation costs ~0.74 ¢ of tokens whichever door it came through
(``api.routers.generation`` §2 does the arithmetic), the money comes out of the same
margin, and the endpoint's own comment already said there is ONE budget on purpose
because "a second name would just be two ways to spend it". A per-turn coach limiter is
still worth having — it bounds a different thing, the conversation — and when it exists
it composes with this one instead of replacing it.

The consequence is deliberate and worth saying out loud: an owner who spends all three
generations through the app cannot create one in chat either, and vice versa. That is
what a shared cost pool means. The refusal says so in words the coach can repeat.

## Why here and not in ``core.rate_limit``

``core.rate_limit`` knows how to count; it must not know what a challenge is. And why
not inside ``generate.generate_challenges`` itself, which would be the most airtight
place? Because the pipeline is called directly by a large body of tests and by future
non-metered callers (a backfill, an admin re-run), and a limiter buried in it would
either break them or need a bypass flag — which is a second door again. The doors pay;
the pipeline computes.

## Why not ``api.validation``

The coach is not an HTTP surface. A refusal here is a plain domain dict — the shape
``lifecycle`` and ``generate`` already refuse in — and the ROUTER is what turns it into
429 with ``Retry-After``. Putting the HTTP status in this module would make the coach
import a status code it has no use for.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any
from uuid import UUID

from healthee.core import rate_limit
from healthee.core.logging import get_logger

log = get_logger(__name__)

# The shared per-owner daily budget. The number is a cost decision, argued in full in
# `api.routers.generation`'s module docstring §2 against PRICING.md §3.1's model and
# §6.1's profit-per-premium-user — it is not a magic constant, and it moved here rather
# than being duplicated so that the endpoint and the coach cannot drift.
GENERATIONS_PER_DAY = 3

# The `core.rate_limit` feature name every door charges. ONE budget on purpose: a
# challenge, a ladder and a chat-created challenge are the same pipeline and the same
# money, and a second name would just be a second way to spend it.
FEATURE = "generation"

# The refusal `spend_then_run` returns when the budget is gone. Named so both callers
# can recognise it without matching on prose — the router maps it to 429, the coach
# reads it out loud.
BUDGET_SPENT = "generation_budget_spent"


def spend_then_run(
    user_id: UUID,
    tz: str,
    run: Callable[[], dict],
    uncharged: frozenset[str],
) -> dict:
    """Charge one generation, run ``run``, refund a refusal that never asked a model.

    The order is charge-then-run, not check-then-charge: the charge is ONE statement
    (``rate_limit.spend``), so two concurrent requests cannot both read "two used" and
    both proceed. The refund is what keeps that fair — ``uncharged`` is the pipeline's
    own list of the refusals it decides before the LLM is reached
    (``generate.PRE_LLM_REFUSALS``), and those cost two cheap queries and no tokens, so
    charging for them would let somebody lose a day's refreshes to a state they can fix
    in a tap while the spend this exists to bound went unspent.

    Returns either the pipeline's result or a :data:`BUDGET_SPENT` refusal carrying the
    numbers a caller needs to say when it resets.
    """
    verdict = rate_limit.spend(user_id, tz, FEATURE, GENERATIONS_PER_DAY)
    if not verdict.allowed:
        log.info(
            "generation refused for %s: budget spent (%d/%d)", user_id, verdict.used, verdict.limit
        )
        return _budget_refusal(verdict)
    result = run()
    if not result.get("ok", True) and str(result.get("reason", "")) in uncharged:
        rate_limit.refund(user_id, tz, FEATURE)
    return result


def _budget_refusal(verdict: rate_limit.Verdict) -> dict[str, Any]:
    """The out-of-budget refusal, in the same ``{ok, reason, error}`` shape as every other.

    The sentence is written to be said to a person, because both callers say it to one:
    the app renders it under a locked refresh button and the coach repeats it in chat.
    """
    return {
        "ok": False,
        "reason": BUDGET_SPENT,
        "error": (
            f"you have asked for {verdict.limit} generations today, which is all this "
            "owner gets — a new suggestion is calibrated from whole days of your own "
            "data, so another one today would be the same question in different words. "
            "It resets at midnight your time. The app and the coach share this budget."
        ),
        "limit": verdict.limit,
        "used": verdict.used,
        "resets_at": verdict.resets_at.isoformat(),
        "retry_after_s": verdict.retry_after_s,
    }


__all__ = ["BUDGET_SPENT", "FEATURE", "GENERATIONS_PER_DAY", "spend_then_run"]
