"""Identity HTTP layer — GET /api/me and POST /api/device (Supabase-JWT auth).

Thin by design (standards §2): the `current_user` dependency verifies the Supabase
access JWT and resolves the tenant, the handler shapes one typed response. No SQL
and no business logic here — provisioning + token minting live in
`healthee.core.supabase_auth`.

These two endpoints stay **Supabase-JWT only** — deliberately NOT the dual-auth
`core.request_auth.CurrentUser` the rest of `/api/*` uses since 6.4b. Minting a device
token is minting a long-lived credential, so accepting the transitional shared secret
here would let anyone holding it forge a permanent per-user ingest token for the
sentinel — a real escalation beyond what that secret already grants, and one that
would outlive the shared token's removal.
"""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from healthee.core.supabase_auth import RequestUser, current_user, mint_device_token

router = APIRouter(prefix="/api", tags=["auth"])

# The authenticated tenant, injected by the Supabase-JWT dependency. Annotated
# form (not a `Depends(...)` default) keeps ruff B008 happy and reads cleanly. Named
# apart from `request_auth.CurrentUser` because it is strictly narrower: JWT only.
SupabaseUser = Annotated[RequestUser, Depends(current_user)]


class MeResponse(BaseModel):
    """The authenticated user's identity + resolved timezone."""

    id: UUID
    timezone: str


class DeviceTokenResponse(BaseModel):
    """A freshly minted device ingest token — returned exactly once.

    `id` is the TOKEN's id (`device_token.id`), not the owner's. It used to be
    `user.id`: not wrong data, but the wrong subject on a response about a token, and
    the reason a future `DELETE /api/device/{id}` had nothing to address a token by.
    The owner's own id is what `GET /api/me` is for.
    """

    device_token: str
    id: UUID


@router.get("/me", response_model=MeResponse)
def get_me(user: SupabaseUser) -> MeResponse:
    """Return the authenticated user's id + timezone (JIT-provisioned on first hit)."""
    return MeResponse(id=user.id, timezone=user.timezone)


@router.post("/device", response_model=DeviceTokenResponse)
def post_device(user: SupabaseUser) -> DeviceTokenResponse:
    """Mint a long-lived device ingest token for the authenticated user (once)."""
    raw, token_id = mint_device_token(user.id, label=None)
    return DeviceTokenResponse(device_token=raw, id=token_id)
