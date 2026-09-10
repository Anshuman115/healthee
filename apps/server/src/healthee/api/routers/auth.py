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

from datetime import datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from healthee.core.device_token import (
    list_device_tokens,
    mint_device_token,
    revoke_device_token,
)
from healthee.core.supabase_auth import RequestUser, current_user

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


# A device name, not a document. Long enough for "Ashish's Pixel 8 Pro" and short
# enough that the column is not somewhere to put a payload.
_LABEL_MAX = 80


class DeviceTokenRequest(BaseModel):
    """What the caller says this token is for.

    Optional, and free text. The label is the ONLY thing distinguishing one row
    from another in `GET /api/device` — an owner revoking a lost phone is choosing
    between two UUIDs otherwise — so the client is expected to send the device
    name. It is the caller's own string about the caller's own device and it is
    never interpreted, only stored and read back.
    """

    label: str | None = None


@router.post("/device", response_model=DeviceTokenResponse)
def post_device(user: SupabaseUser, body: DeviceTokenRequest | None = None) -> DeviceTokenResponse:
    """Mint a long-lived device ingest token for the authenticated user (once).

    409 when the account already holds `_MAX_LIVE_DEVICE_TOKENS` live ones; the
    body says which state that is and that revoking frees a slot.

    The body is optional so a client that sends none still gets a token: this
    endpoint predates the label, and a mint that started failing on a missing
    field would break the very clients the label exists to help.
    """
    raw, token_id = mint_device_token(user.id, label=_label(body))
    return DeviceTokenResponse(device_token=raw, id=token_id)


def _label(body: DeviceTokenRequest | None) -> str | None:
    """The trimmed label, or None. Blank and absent are the same thing."""
    if body is None or body.label is None:
        return None
    trimmed = body.label.strip()
    return trimmed[:_LABEL_MAX] if trimmed else None


class DeviceListItem(BaseModel):
    """One live device token, as its owner sees it.

    **No token and no hash.** The raw value is unrecoverable by design, and the
    hash is still derived from a live credential — it travels over the wire and
    into whatever the client logs. What an owner needs in order to decide whether
    to revoke something is which one it is and when it was last used.
    """

    id: UUID
    label: str | None
    last_seen: datetime | None
    created_at: datetime


@router.get("/device", response_model=list[DeviceListItem])
def get_devices(user: SupabaseUser) -> list[DeviceListItem]:
    """List the caller's LIVE device tokens, newest first.

    Revocation without listing is not usable — an owner cannot revoke a credential
    they cannot see — so this ships with `DELETE` rather than after it. Scoped to
    the caller by `list_device_tokens`, which puts the owner in the WHERE clause.
    """
    return [
        DeviceListItem(
            id=row.id,
            label=row.label,
            last_seen=row.last_seen,
            created_at=row.created_at,
        )
        for row in list_device_tokens(user.id)
    ]


@router.delete("/device/{token_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_device(token_id: UUID, user: SupabaseUser) -> None:
    """Revoke one of the caller's device tokens. 404 when there is none to revoke.

    ## The same 404 for somebody else's token and for one that never existed

    `revoke_device_token` puts the owner in the WHERE clause, so a token belonging
    to another account simply matches no row — and this handler cannot tell that
    case from a bad id, which is the correct answer to both. Confirming that an id
    exists but is not yours tells a caller something about an account that is not
    theirs, and a revocation endpoint that enumerated other owners' token ids would
    be a worse leak than the one it was built to close.

    An already-revoked token is also a 404: the owner pressed revoke and nothing
    changed, and saying so is more use than a 204 that implies something did.
    """
    if not revoke_device_token(user.id, token_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No live device token with that id on this account.",
        )
