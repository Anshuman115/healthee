"""Identity HTTP layer — GET /api/me and POST /api/device (Supabase-JWT auth).

Thin by design (standards §2): the `current_user` dependency verifies the Supabase
access JWT and resolves the tenant, the handler shapes one typed response. No SQL
and no business logic here — provisioning + token minting live in
`healthee.core.supabase_auth`.

ADDITIVE: these two endpoints are the only surfaces wired to Supabase identity in
Phase 6.1. Every existing router keeps its shared-token `require_token` guard.
"""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from healthee.core.supabase_auth import RequestUser, current_user, mint_device_token

router = APIRouter(prefix="/api", tags=["auth"])

# The authenticated tenant, injected by the Supabase-JWT dependency. Annotated
# form (not a `Depends(...)` default) keeps ruff B008 happy and reads cleanly.
CurrentUser = Annotated[RequestUser, Depends(current_user)]


class MeResponse(BaseModel):
    """The authenticated user's identity + resolved timezone."""

    id: UUID
    timezone: str


class DeviceTokenResponse(BaseModel):
    """A freshly minted device ingest token — returned exactly once."""

    device_token: str
    id: UUID


@router.get("/me", response_model=MeResponse)
def get_me(user: CurrentUser) -> MeResponse:
    """Return the authenticated user's id + timezone (JIT-provisioned on first hit)."""
    return MeResponse(id=user.id, timezone=user.timezone)


@router.post("/device", response_model=DeviceTokenResponse)
def post_device(user: CurrentUser) -> DeviceTokenResponse:
    """Mint a long-lived device ingest token for the authenticated user (once)."""
    raw = mint_device_token(user.id, label=None)
    return DeviceTokenResponse(device_token=raw, id=user.id)
