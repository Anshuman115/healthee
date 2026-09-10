"""Field-level gating — the AI fields inside an otherwise-FREE payload.

Split from `gate.py` at the 400-line gate, along the seam the two halves already
had. `gate.py` refuses a REQUEST: an AI route takes a gated identity and a
non-premium owner gets a 402 instead of an answer. This module refuses a FIELD:
`/api/today` and `/api/sleep/consistency` are free endpoints that happen to carry
one or two AI-written values, so the payload is served and those values are taken
out of it.

The distinction matters at the boundary. §12.7's closure for "sniff the response
for the fields the app hides" is that the data is **not in the response at all** —
which is a property of this module, not of the route gate.
"""

from __future__ import annotations

from healthee.api.gate import LOCKED_KEY, locked_body
from healthee.core.entitlement import is_premium
from healthee.core.supabase_auth import RequestUser

TODAY_AI_FIELDS: tuple[str, ...] = ("action", "recommendations")
SLEEP_CONSISTENCY_AI_FIELDS: tuple[str, ...] = ("tonight",)


def strip_ai_fields(payload: dict, fields: tuple[str, ...], feature: str) -> dict:
    """Remove ``fields`` from a free endpoint's payload and mark what was withheld.

    ``pop``, not ``= None``: §12.7's closure for "sniff the response for the AI fields
    the app hides" is that the data is not in the response at all. A null would still
    tell a client the field exists, and a future refactor could reintroduce a value into
    a key the client already parses.

    Mutates and returns the same dict — these payloads are the ~20 KB aggregates the
    standards exempt from response models, and copying one to delete two keys would be
    a measurable cost for no gain.
    """
    for field in fields:
        payload.pop(field, None)
    payload[LOCKED_KEY] = locked_body(feature)
    return payload


def gate_free_payload(
    user: RequestUser, payload: dict, fields: tuple[str, ...], feature: str
) -> dict:
    """Serve the whole payload to a premium owner; strip ``fields`` for everyone else."""
    if is_premium(user.id):
        return payload
    return strip_ai_fields(payload, fields, feature)
