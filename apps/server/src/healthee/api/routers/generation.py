"""The generation endpoints — where the challenges track becomes reachable.

WP-C3b. Everything under ``healthee.challenges`` was built, tested and merged with no way
to *acquire* a challenge: the pipeline existed, the HTTP surface did not. This POST is
that surface, and nothing else. Thin (standards §2): auth dep → spend the budget → one
domain call → shape the response.

It lives in its own router rather than on the challenges router because what makes it
different from every other endpoint in this codebase is one thing — it calls a model and
it costs money — and that argument belongs in one place. WP-C4b's program generation
joins it here for the same reason and shares the same budget.

## 1. Why an LLM may sit on THIS request path

Standards §Performance is explicit: *"LLM endpoints: pre-warmed/cached per day;
generation never blocks a sync or a read path."* Neither of these is a read or a sync.
They are POSTs the owner explicitly triggered ("refresh my suggestions"), where seconds of
latency is honest — the app can say "writing you a challenge" and mean it.

What the budget protects is the other half of that sentence, and it is enforced
structurally:

* ``GET /api/challenges`` and ``GET /api/programs`` stay PURE. They do not generate on an
  empty feed and they never will: a GET that writes is not idempotent, races itself, and
  would only generate for the owner who happens to be looking (``challenges/lifecycle.py``
  argues it at length; ``tests/contracts/test_generation_endpoints.py`` pins that a GET
  writes no row and asks no model).
* **The empty-feed trigger is the CLIENT's**, and it is a trigger, not a loop: WP-C6 calls
  this once when the feed comes back empty and does not retry within the same local day.
  The budget below is what makes a client that gets that wrong cost three requests instead
  of unbounded spend.

Expected latency is the model's, and almost only the model's — MEASURED rather than
asserted (standards §Performance: "measure, don't guess"). With the client stubbed, the
whole pipeline is **~70 ms warm and ~180 ms cold** on the seeded set, and the endpoint
end-to-end through an in-process test client is **~200 ms**; the cold/warm gap is the
corpus manifest and the ranked notes, which every grounded surface shares. The model then
adds seconds. That server-side half is above the p95 < 100 ms READ budget and is not
governed by it — this is an LLM endpoint, and the read budget's own surfaces
(``GET /api/challenges``) are untouched — but it is stated as a number so that a
regression in it is visible, which is what ``test_generation_endpoints`` pins with a stub
and no network call.

## 2. The budget — abuse and cost protection, NOT the free-tier gate

``MULTI_USER.md`` §11 lists rate limiting as unbuilt, and this endpoint is what makes it
necessary: generation is the first LLM surface a client can ask for on demand (everything
else is nightly-deduped or cached per day), so without a bound an owner holding the button
down spends our margin. ``PRICING.md`` §6.3 calls free-tier cost control existential.

:data:`GENERATIONS_PER_DAY` is 3, per owner, per THEIR local day, and WP-C4b's program
generation shares it.
The number is a cost decision, against ``PRICING.md`` §3.1's model (Gemini 3 Flash,
$0.50/M in · $3.00/M out):

* one completion here is ~10 k input (system + v2 context + top-6 full notes + the lever
  and calibration tables) and ~800 output ⇒ **~0.74 ¢**;
* one REQUEST is 1 completion in the ordinary case and at most 4 in the worst
  (``generate._MAX_BOUNDS_RETRIES`` = 1 outer × ``grounded._MAX_RETRIES`` = 1 inner) ⇒
  **0.74 ¢ typical, ~3.1 ¢ worst**;
* at the cap, that is **~2.2 ¢/owner/day ≈ $0.67/owner/month** typically and **~9.3 ¢/day
  ≈ $2.79/month** in the pathological case where every run loses both gates twice.

Against §3.1's ~$1.14–1.77/user/month all-in and §4's $3.99 price, the typical figure fits
inside the stated "$1–2 planning number" and the worst case is bounded and visible rather
than unbounded. Three is also generous against what the product actually earns: a
suggestion is calibrated from ``series.recent_window``, which reads whole local days, so a
second refresh inside one day asks a differently-worded question about identical inputs.

**It is not §12.3's metering.** That gate (``require_ai_access`` — premium OR one coach
question per rolling seven days) answers *may this person use an AI feature at all*; this
one answers *how often may anyone, premium included, spend on this*. They compose: when
6.6 lands, entitlement is checked first and this budget still bounds a paying owner.
Building one as the other would either hand a free user a paid allowance or wall a paying
one out.

**What it does not cover:** the coach's ``create_challenge`` (WP-C5) calls the same
pipeline without passing through here. That is deliberate — the natural unit for the coach
is a TURN, not a generation, and metering coach turns is §12.3's job on a surface that has
no limiter of its own today. Bolting this budget onto one of the coach's three tools would
meter a third of a conversation. Stated rather than hidden: an owner can still reach the
generation pipeline through chat at whatever rate the coach itself allows, which is
unbounded until 6.6.

## 3. The premium gate is still not built

Challenges and programs are premium in full (``PRICING.md`` §1a), and 6.6 does not exist:
there is no ``subscription`` table and no ``require_ai_access`` (``MULTI_USER.md`` §12), so
these are reachable by any authenticated owner exactly like every other AI surface today.
It threads through **here**, as a second FastAPI dependency beside ``CurrentUser``, checked
BEFORE :func:`_spend_then_run` (an owner with no entitlement must get 402 rather than spend
a unit of a budget they cannot use). Noted rather than faked — a comment claiming a gate
that is not there is worse than a missing gate.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Literal

from fastapi import APIRouter, HTTPException

from healthee.api.routers.challenges import Challenge, _Wire
from healthee.api.validation import require_ok
from healthee.challenges import generate
from healthee.core import rate_limit
from healthee.core.request_auth import CurrentUser

router = APIRouter(tags=["generation"])

# The shared per-owner daily budget. See §2 of the module docstring for the arithmetic
# that produced the number; it is a cost decision, not a magic constant.
GENERATIONS_PER_DAY = 3

# The `core.rate_limit` feature name this endpoint charges. ONE budget for every
# generation surface on purpose: a challenge and a ladder are the same pipeline shape and
# the same money, and two budgets would just be two ways to spend it.
BUDGET_FEATURE = "generation"


class GeneratedChallenges(_Wire):
    """``POST /api/challenges/generate`` — what survived both gates, and what did not.

    ``rejected`` is part of the ANSWER rather than only a log line, and that is the
    §2.5 fix: an empty feed with no reason is exactly the silent degraded state the
    standards forbid. A client can say "we could not build one, because…" only if the
    server told it because-what.

    ``ok`` is ``Literal[True]``: a refusal never reaches this model, because
    :func:`require_ok` has already turned it into a 4xx.
    """

    ok: Literal[True]
    generated: int
    rejected: list[str]
    challenges: list[Challenge]


@router.post("/api/challenges/generate", response_model=GeneratedChallenges)
def post_generate_challenges(user: CurrentUser) -> GeneratedChallenges:
    """Author, gate and persist a fresh suggestion feed for this owner (WP-C3, WP-C3b).

    Seconds, not milliseconds — an LLM runs inside this request (§1). 429 when the daily
    budget is gone, carrying ``Retry-After`` and the instant it resets; 409 with a named
    reason when a rule refused (already running three, too little data to calibrate
    against, nothing the evidence base could ground).

    The suggestion feed is REPLACED, which is what a refresh means: the old suggestions
    were calibrated against a baseline that has since moved (``store.delete_suggestions``).
    A run that survives the gates with nothing leaves the existing feed alone rather than
    costing the owner their menu.
    """
    result = _spend_then_run(
        user,
        lambda: generate.generate_challenges(user.id, user.timezone),
        generate.PRE_LLM_REFUSALS,
    )
    return GeneratedChallenges.model_validate(result)


def _spend_then_run(user: CurrentUser, run: Callable[[], dict], uncharged: frozenset[str]) -> dict:
    """Charge the budget, run the pipeline, refund a refusal that never asked a model.

    The order is charge-then-run, not check-then-charge: the charge is one statement, so
    two concurrent requests cannot both read "two used" and both proceed. The refund is
    what keeps that safe from being unfair — ``uncharged`` is the pipeline's own list of
    the refusals it decides before the LLM is reached (``generate.PRE_LLM_REFUSALS``), and
    those cost nothing to serve.
    """
    verdict = rate_limit.spend(user.id, user.timezone, BUDGET_FEATURE, GENERATIONS_PER_DAY)
    if not verdict.allowed:
        raise HTTPException(
            status_code=429,
            detail={
                "reason": "generation_budget_spent",
                "error": (
                    f"you have asked for {verdict.limit} generations today, which is all "
                    "this owner gets — a new suggestion is calibrated from whole days of "
                    "your own data, so another one today would be the same question in "
                    "different words. It resets at midnight your time."
                ),
                "limit": verdict.limit,
                "used": verdict.used,
                "resets_at": verdict.resets_at.isoformat(),
            },
            headers={"Retry-After": str(verdict.retry_after_s)},
        )
    result = run()
    if not result.get("ok", True) and str(result.get("reason", "")) in uncharged:
        rate_limit.refund(user.id, user.timezone, BUDGET_FEATURE)
    return require_ok(result)
