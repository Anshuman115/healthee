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

## The metered free allowance (6.6a-2)

``PRICING.md`` §1a promises a free owner a metered taste — **1 coach question and 1
daily-action reveal per rolling 7 days**, with recs, insight cards, the notable feed and
the whole challenges system at a **zero** allowance. :data:`FREE_ALLOWANCE` is that
table, and it is the only place it exists; :mod:`healthee.core.allowance` is the rolling
ledger it is checked against. Entitlement is asked FIRST — a premium owner never touches
the ledger — and the allowance only ever *widens* the gate, never narrows it.

The charge happens in the dependency, not after the work, because that is the order that
cannot be raced: the ledger is edited under a row lock before the handler starts. What a
handler owes in return is a **refund** when it delivered nothing —
:func:`refund_ai_use`, whose contract is "if this request charged the ledger, un-charge
it". A premium request never marked anything, so calling it is a no-op rather than a
condition every handler has to re-derive.

**The metering never runs on a read.** :func:`gate_free_payload` asks entitlement only, so
``/api/today`` still omits ``action`` for a free owner even though they have a reveal in
hand. That is the point of the allowance rather than a gap in it: a *reveal* is one a week
and must be something the owner CHOSE, and a page that spent it by loading would take the
taste without ever offering it. The choice is ``POST /api/today/action``
(``api.routers.daily_action``) — a door the owner knocks on.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, HTTPException, Request

from healthee.core import allowance
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

# Every feature this gate can refuse, in the order the app lists them on the upsell
# screen. `api.routers.entitlement` re-exports it rather than re-typing it, so a feature
# added here cannot go missing from the screen that sells it.
FEATURES: tuple[str, ...] = (COACH, INSIGHT, NOTABLE, CHALLENGES, DAILY_ACTION)

# PRICING.md §1a's tier table, as the only executable copy of it: how many times a
# NON-premium owner may use each feature per rolling `allowance.WINDOW_DAYS`.
#
# The two teasers are the ones §1a names — "1 coach question + 1 daily-action reveal per
# rolling 7 days … enough to feel the value and convert, bounded so cost is trivial
# (~1–2 extra LLM calls / free user / week)". Everything else is zero, and zero is a HARD
# lock, not a small number: recs and the insight cards are "(locked card)" in the table,
# and challenges/programs and the notable feed are "— (premium)" in full (owner decision,
# 2026-07-16).
#
# A feature absent from this dict is hard-locked too (`.get(feature, 0)`), so a sixth
# feature added to `FEATURES` is refused for free owners until somebody deliberately
# prices it. Failing closed is the only safe default for a paywall.
FREE_ALLOWANCE: dict[str, int] = {
    COACH: 1,
    DAILY_ACTION: 1,
    INSIGHT: 0,
    NOTABLE: 0,
    CHALLENGES: 0,
}

# Where a charged request records that it charged. On `request.state`, which is per
# request and dies with it — the alternative (re-reading entitlement and the ledger in
# the refund path) would be two more queries to rediscover something this process already
# knew, and would guess wrong for a subscription that changed mid-request.
_CHARGED_ATTR = "healthee_allowance_charged"

# `/api/today` and `/api/sleep/consistency` are free endpoints carrying one AI field
# each. Named here, next to the gate, because the omission and the 402 are one policy.
TODAY_AI_FIELDS: tuple[str, ...] = ("action", "recommendations")
SLEEP_CONSISTENCY_AI_FIELDS: tuple[str, ...] = ("tonight",)

# The key the stripped payload carries instead. Its presence IS the signal — a premium
# payload has no `locked` key at all, so the free and paid shapes are distinguishable
# without inspecting values.
LOCKED_KEY = "locked"


def _locked_body(feature: str, verdict: allowance.Verdict | None = None) -> dict:
    """The body a locked card renders from — same shape in the 402 and in a payload.

    ``verdict`` is present only when the refusal was a SPENT ALLOWANCE rather than a hard
    lock, and it changes the sentence as well as adding the numbers: "you have already had
    this week's" and "this is the paid tier" are different facts, and a card that said the
    second when the first is true would sell a subscription to someone who just needs to
    wait until Tuesday.
    """
    body = {
        LOCKED_KEY: True,
        "feature": feature,
        "upgrade": get_settings().upgrade_url,
        "error": (
            "the AI layer is the premium tier — your metrics, charts, baselines and "
            "findings stay free and complete"
        ),
    }
    if verdict is None:
        return body
    return body | {
        "error": (
            f"you have used the free tier's {verdict.limit} per {allowance.WINDOW_DAYS} days "
            f"for this — it comes back on its own, and premium removes the limit"
        ),
        "limit": verdict.limit,
        "used": verdict.used,
        "resets_at": verdict.resets_at.isoformat(),
        "retry_after_s": verdict.retry_after_s,
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

    def __call__(self, request: Request, user: CurrentUser) -> RequestUser:
        """Return the authenticated owner, or raise 402 — ``require_ai_access`` (§12.3).

        Premium **or** within the free allowance, in that order. The order is not a
        preference: a premium owner must never have a ledger row written for them, or a
        lapse would find their week already spent.
        """
        if is_premium(user.id):
            return user
        limit = FREE_ALLOWANCE.get(self.feature, 0)
        if limit <= 0:
            log.info("402 %s for %s — not premium, no free allowance", self.feature, user.id)
            raise HTTPException(status_code=402, detail=_locked_body(self.feature))
        verdict = allowance.spend(user.id, user.timezone, self.feature, limit)
        if not verdict.allowed:
            log.info("402 %s for %s — free allowance spent", self.feature, user.id)
            raise HTTPException(
                status_code=402,
                detail=_locked_body(self.feature, verdict),
                headers={"Retry-After": str(max(1, verdict.retry_after_s))},
            )
        setattr(request.state, _CHARGED_ATTR, self.feature)
        return user


def refund_ai_use(request: Request, user: RequestUser) -> None:
    """Un-charge this request's free-allowance use, if it made one and delivered nothing.

    Called by a handler that produced no value — a refusal decided before the model, a
    transport failure, the honest fallback, or an answer served from a cache this request
    did not fill. A use is a *taste of premium*, and a taste of an apology is not one.

    Idempotent, and a no-op for a premium owner: the marker is only ever set by a request
    that actually wrote to the ledger, and it is cleared here so a second call (a handler
    that refunds in both a branch and its ``except``) cannot mint a second use back.
    """
    feature = getattr(request.state, _CHARGED_ATTR, None)
    if feature is None:
        return
    setattr(request.state, _CHARGED_ATTR, None)
    log.info("refunding the free %s use for %s — the request delivered nothing", feature, user.id)
    allowance.refund(user.id, user.timezone, feature)


def locked_features(user: RequestUser) -> list[str]:
    """Which features this owner may NOT use *right now* — the upsell screen's list.

    Reporting only: it :func:`~healthee.core.allowance.peek`\\ s rather than spending, so
    polling the entitlement endpoint can never cost somebody their weekly question. A
    metered feature with a slot free is deliberately absent from the list — that is what
    ``EntitlementResponse.locked`` being a LIST was built for.
    """
    if is_premium(user.id):
        return []
    return [
        feature
        for feature in FEATURES
        if not _has_free_use(user, feature, FREE_ALLOWANCE.get(feature, 0))
    ]


def _has_free_use(user: RequestUser, feature: str, limit: int) -> bool:
    """Whether a non-premium ``user`` has an unspent allowance for ``feature``."""
    if limit <= 0:
        return False
    return allowance.peek(user.id, user.timezone, feature, limit).allowed


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
DailyActionUser = Annotated[RequestUser, Depends(AIGate(DAILY_ACTION))]

__all__ = [
    "CHALLENGES",
    "COACH",
    "DAILY_ACTION",
    "FEATURES",
    "FREE_ALLOWANCE",
    "INSIGHT",
    "LOCKED_KEY",
    "NOTABLE",
    "SLEEP_CONSISTENCY_AI_FIELDS",
    "TODAY_AI_FIELDS",
    "AIGate",
    "ChallengeUser",
    "CoachUser",
    "DailyActionUser",
    "InsightUser",
    "NotableUser",
    "gate_free_payload",
    "locked_features",
    "refund_ai_use",
    "strip_ai_fields",
]
