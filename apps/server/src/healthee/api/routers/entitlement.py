"""Entitlement — GET /api/entitlement (Bearer-auth). What the app may render unlocked.

``MULTI_USER.md`` §12.3's last line: *"returns the user's premium state + the locked-
feature list so the app knows what to show as upgradeable."* It is the ONLY endpoint
whose subject is the paywall, and it is deliberately **not** gated — a locked-out owner
is exactly who needs to read it.

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
    """One owner's premium state, plus what is still locked for them.

    ``locked`` is empty for a premium owner. For a free one it is everything they cannot
    use **right now** — which since 6.6a-2 is not the whole list: a free owner with their
    weekly coach question still in hand sees ``coach`` absent from it, and sees it appear
    once they have asked. That is what the field being a LIST rather than a boolean was
    built for, and it is why it needed no wire change to carry the metered allowance.
    """

    model_config = ConfigDict(extra="forbid")

    premium: bool
    status: str
    source: str
    plan: str | None
    expires_at: datetime | None
    locked: list[str]
    upgrade: str


@router.get("/api/entitlement", response_model=EntitlementResponse)
def get_entitlement(user: CurrentUser) -> EntitlementResponse:
    """This owner's premium state and locked-feature list, read fresh from the table."""
    current = entitlement_of(user.id)
    return EntitlementResponse(
        premium=current.premium,
        status=current.status,
        source=current.source,
        plan=current.plan,
        expires_at=current.expires_at,
        locked=gate.locked_features(user),
        upgrade=get_settings().upgrade_url,
    )
