"""Challenges — the feed, the lifecycle writes, and the outcome ledger.

Thin (standards §2): auth dep → one domain call inside one owner-scoped transaction
→ shape the response. There is no business logic and no SQL here; every rule lives in
``healthee.challenges``.

Two things this router deliberately does NOT have:

* **A target in any request.** ``POST …/adapt`` takes no body. The recalibration is
  recomputed server-side from the owner's own rows at the moment of the request
  (CHALLENGES.md §5.2) — a client may ask for one, it can never dictate the number,
  and the way to guarantee that is to give it nowhere to put one.
* **A premium gate.** 6.6 is not built (`MULTI_USER.md` §12): there is no
  `subscription` table and no `require_ai_access`, so these endpoints are reachable
  by any authenticated owner — exactly like every other AI surface today. The whole
  challenges system is premium per PRICING §1a and the gate threads through here when
  6.6 lands; it is noted rather than faked, because a comment that claims a gate
  exists is worse than a missing gate.
"""

from __future__ import annotations

from fastapi import APIRouter

from healthee.api.validation import require_ok
from healthee.challenges import ledger, lifecycle
from healthee.core.db import tenant_transaction
from healthee.core.request_auth import CurrentUser

router = APIRouter(tags=["challenges"])


@router.get("/api/challenges")
def get_challenges(user: CurrentUser) -> dict:
    """The owner's feed: suggestions, active challenges with live progress, recent ends.

    A pure read — it never closes a finished challenge (``challenges/lifecycle.py``
    argues why). One that has run out shows here with ``days_left: 0`` until a write
    path freezes it.
    """
    with tenant_transaction(user.id) as cur:
        return lifecycle.list_challenges(cur, user.id, user.timezone)


@router.post("/api/challenges/{challenge_id}/adopt")
def post_adopt(user: CurrentUser, challenge_id: int) -> dict:
    """Take on a suggested challenge, freezing its baseline at this moment."""
    with tenant_transaction(user.id) as cur:
        return require_ok(lifecycle.adopt(cur, user.id, user.timezone, challenge_id))


@router.post("/api/challenges/{challenge_id}/abandon")
def post_abandon(user: CurrentUser, challenge_id: int) -> dict:
    """Stop an active challenge. Its outcome is still frozen — giving up is a result."""
    with tenant_transaction(user.id) as cur:
        return require_ok(lifecycle.abandon(cur, user.id, user.timezone, challenge_id))


@router.post("/api/challenges/{challenge_id}/adapt")
def post_adapt(user: CurrentUser, challenge_id: int) -> dict:
    """Apply the pending recalibration — recomputed here, never taken from the client.

    409 when there is nothing to apply, which is the honest answer most of the time:
    performance inside the productive band means the target should be left alone.
    """
    with tenant_transaction(user.id) as cur:
        return require_ok(lifecycle.apply_adaptation(cur, user.id, user.timezone, challenge_id))


@router.get("/api/challenges/outcomes")
def get_outcomes(user: CurrentUser, limit: int = 20) -> dict:
    """The frozen ledger, newest first.

    Every row carries its own caveats — ``confounds``, ``data_confidence``, and
    ``co_occurring`` with the concurrency count inside it — so nothing downstream can
    read a delta on another metric as an effect of the challenge (§7 decision 1).
    """
    with tenant_transaction(user.id) as cur:
        return {"outcomes": ledger.recent(cur, user.id, limit)}
