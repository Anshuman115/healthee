"""The AI paywall at the HTTP edge — ``require_ai_access`` (Phase 6.6a, §12.3).

One dependency, used in place of ``CurrentUser`` on every premium endpoint. It
authenticates exactly as before and then asks ``core.entitlement`` — the same function
the nightly chain asks — whether this owner may have AI output at all. If not: **402**,
before the handler body, before any model, before any stored AI row is read.

``MULTI_USER.md`` §12.7's invariant is *no AI response bytes ever leave the server for a
request whose owner is not premium — enforced at the endpoint AND in the jobs, from
server-owned entitlement, with RLS underneath.* This module is the endpoint half. Three
of its design choices are that invariant, restated as code:

* **It runs on the server route, not the screen.** A patched client, a curl, a replayed
  request — all reach the same dependency, and all get 402. The client renders what the
  server already decided; it is never asked.
* **It replaces ``CurrentUser`` rather than sitting beside it.** An endpoint cannot take
  the owner's identity without also taking the gate, so the failure mode "someone added
  an AI route and forgot the dependency" needs a *deliberate* choice of the ungated
  alias — and ``tests/premium/test_ai_gate.py`` enumerates every mounted route and fails
  on any un-allowlisted one that has no gate.
* **402, not 403.** "Payment Required" is what this is, and the body says so in the
  shape the app renders a locked card from — ``{"locked": true, "feature": …,
  "upgrade": …}``. An error dialog for an unsubscribed user would be a lie about what
  happened.

## Free reads keep serving — with the AI fields OMITTED

``/api/today`` and ``/api/sleep/consistency`` are FREE endpoints that each carry one
LLM-authored field. They are not gated; :func:`strip_ai_fields` removes those fields
from the payload instead, so the page still renders every metric. §12.7 is explicit
that the field is *omitted*, not nulled and not hidden: "the data is not in the response
at all, so there's nothing to sniff." The ``locked`` marker that replaces it says which
fields were withheld, so the client can render the upsell without guessing.

## What is NOT here, and is not pretended to be

``PRICING.md`` §1a promises free users a metered taste — 1 coach question and 1
daily-action reveal per rolling 7 days. **That metering is not built** (6.6a-2), so
today every non-premium owner is hard-locked out of all five features. Stated plainly
rather than sketched as an unenforced allowance table: this repo's rule is that a
comment claiming a gate is worse than a missing gate, and the same goes for a constant
claiming an allowance nothing reads. The seam is :func:`require_ai_access` itself —
6.6a-2 adds the allowance check there, and nothing else moves.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, HTTPException

from healthee.core.config import get_settings
from healthee.core.entitlement import is_premium
from healthee.core.logging import get_logger
from healthee.core.request_auth import CurrentUser
from healthee.core.supabase_auth import RequestUser

log = get_logger(__name__)

# The premium features, as the 402 body names them. They are the granularity the free
# allowance will need (PRICING.md §1a meters coach and the daily action separately from
# the cards, which get none), so they are split that way now rather than re-cut later.
COACH = "coach"
INSIGHT = "insight"
NOTABLE = "notable"
CHALLENGES = "challenges"
# The warmed read-surface coaching lines: `/api/today`'s `action` AND
# `/api/sleep/consistency`'s `tonight`. One feature because they are one generator
# (`insights.coaching.warm_lines`) and one entitlement; PRICING.md §1a names only the
# daily action, which is a gap in the doc rather than a second product.
DAILY_ACTION = "daily_action"

# `/api/today` and `/api/sleep/consistency` are free endpoints carrying one AI field
# each. Named here, next to the gate, because the omission and the 402 are one policy.
TODAY_AI_FIELDS: tuple[str, ...] = ("action", "recommendations")
SLEEP_CONSISTENCY_AI_FIELDS: tuple[str, ...] = ("tonight",)

# The key the stripped payload carries instead. Its presence IS the signal — a premium
# payload has no `locked` key at all, so the free and paid shapes are distinguishable
# without inspecting values.
LOCKED_KEY = "locked"


def _locked_body(feature: str) -> dict:
    """The body a locked card renders from — same shape in the 402 and in a payload."""
    return {
        LOCKED_KEY: True,
        "feature": feature,
        "upgrade": get_settings().upgrade_url,
        "error": (
            "the AI layer is the premium tier — your metrics, charts, baselines and "
            "findings stay free and complete"
        ),
    }


class AIGate:
    """A FastAPI dependency that authenticates, then refuses 402 if not entitled.

    A class rather than a closure so the feature is a readable attribute: the route
    completeness test walks every mounted route's dependency tree looking for one of
    these, and ``isinstance`` is a check that cannot be fooled by a same-named
    function defined somewhere else.
    """

    def __init__(self, feature: str) -> None:
        self.feature = feature

    def __call__(self, user: CurrentUser) -> RequestUser:
        """Return the authenticated owner, or raise 402 when they are not premium."""
        if not is_premium(user.id):
            log.info("402 %s for %s — not premium", self.feature, user.id)
            raise HTTPException(status_code=402, detail=_locked_body(self.feature))
        return user


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
    payload[LOCKED_KEY] = _locked_body(feature)
    return payload


def gate_free_payload(
    user: RequestUser, payload: dict, fields: tuple[str, ...], feature: str
) -> dict:
    """Serve the whole payload to a premium owner; strip ``fields`` for everyone else."""
    if is_premium(user.id):
        return payload
    return strip_ai_fields(payload, fields, feature)


# The gated identities, one per feature. An endpoint takes ONE of these in place of
# `CurrentUser`; taking `CurrentUser` on an AI route is what the completeness test fails.
CoachUser = Annotated[RequestUser, Depends(AIGate(COACH))]
InsightUser = Annotated[RequestUser, Depends(AIGate(INSIGHT))]
NotableUser = Annotated[RequestUser, Depends(AIGate(NOTABLE))]
ChallengeUser = Annotated[RequestUser, Depends(AIGate(CHALLENGES))]

__all__ = [
    "CHALLENGES",
    "COACH",
    "DAILY_ACTION",
    "INSIGHT",
    "LOCKED_KEY",
    "NOTABLE",
    "SLEEP_CONSISTENCY_AI_FIELDS",
    "TODAY_AI_FIELDS",
    "AIGate",
    "ChallengeUser",
    "CoachUser",
    "InsightUser",
    "NotableUser",
    "gate_free_payload",
    "strip_ai_fields",
]
