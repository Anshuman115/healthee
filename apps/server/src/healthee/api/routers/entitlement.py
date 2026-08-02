"""Entitlement — GET /api/entitlement (Bearer-auth). What the app may render unlocked.

``MULTI_USER.md`` §12.3's last line: *"returns the user's premium state + the locked-
feature list so the app knows what to show as upgradeable."* It is the ONLY endpoint
whose subject is the paywall, and it is deliberately **not** gated — a locked-out owner
is exactly who needs to read it.

Since **#116** it carries one thing more: ``included``, the balance left on the caps a
subscriber already bought (:mod:`healthee.api.allowance_report`). It lives here because
this is the endpoint whose subject is *what the owner is entitled to*, and because it is
ungated and uncached for the same two reasons the rest of the payload is.

Two things it is not, both worth stating because both would be security bugs:

* **It is not how access is decided.** Every premium route re-reads entitlement
  server-side per request (``api.gate``). This endpoint is a *display* hint; a client
  that lies to itself about the answer still gets 402 from everything that matters
  (§12.7's first loophole).
* **It is not cached.** It reads the ``subscription`` row on every call, so a refund or
  a cancellation shows up on the next poll rather than at the end of some TTL.

Typed response (standards §2 — small, stable payload).
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter
from pydantic import BaseModel, ConfigDict

from healthee.api import gate
from healthee.api.allowance_report import IncludedAllowance, included_allowances
from healthee.core.config import get_settings
from healthee.core.entitlement import entitlement_of
from healthee.core.request_auth import CurrentUser

router = APIRouter(tags=["entitlement"])

# Every feature the gate can refuse, in the order the app lists them. Re-exported from
# `api.gate` rather than re-typed, so a feature added there cannot go missing from the
# upsell screen. (It moved into `gate` with 6.6a-2, which needed the same tuple to walk
# the allowance table.)
ALL_FEATURES: tuple[str, ...] = gate.FEATURES


class EntitlementResponse(BaseModel):
    """One owner's premium state, what is still locked for them, and what they have left.

    ``locked`` is empty for a premium owner. For a free one it is everything they cannot
    use **right now** — which since 6.6a-2 is not the whole list: a free owner with their
    weekly coach question still in hand sees ``coach`` absent from it, and sees it appear
    once they have asked. That is what the field being a LIST rather than a boolean was
    built for, and it is why it needed no wire change to carry the metered allowance.

    ``included`` is the other side of the same coin and deliberately NOT part of
    ``locked`` (#116): the balance left on a cap the owner already bought. ``locked``
    answers *"what would paying get me"* and so stays empty for a subscriber; ``included``
    answers *"what did paying get me, and how much of it is left"* and so is empty for
    everyone else. See :mod:`healthee.api.allowance_report` for why a free owner gets an
    empty list rather than a meter reading zero, and why an uncapped premium feature is
    absent rather than reported at zero.
    """

    model_config = ConfigDict(extra="forbid")

    premium: bool
    status: str
    source: str
    plan: str | None
    expires_at: datetime | None
    locked: list[str]
    included: list[IncludedAllowance]
    upgrade: str


@router.get("/api/entitlement", response_model=EntitlementResponse)
def get_entitlement(user: CurrentUser) -> EntitlementResponse:
    """Premium state, locked-feature list and included balances, read fresh every call.

    The balances PEEK the ledger (``allowance_report``); an app polling this must never
    cost anybody a question.
    """
    current = entitlement_of(user.id)
    return EntitlementResponse(
        premium=current.premium,
        status=current.status,
        source=current.source,
        plan=current.plan,
        expires_at=current.expires_at,
        locked=gate.locked_features(user),
        included=included_allowances(user),
        upgrade=get_settings().upgrade_url,
    )
