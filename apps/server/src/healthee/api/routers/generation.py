"""The two generation endpoints — where the challenges track becomes reachable.

WP-C3b and WP-C4b. Everything under ``healthee.challenges`` was built, tested and merged
with no way to *acquire* a challenge or a program: the pipelines existed, the HTTP surface
did not. These two POSTs are that surface, and nothing else. Thin (standards §2): auth dep
→ spend the budget → one domain call → shape the response.

They live in one router rather than on the challenges and programs routers because what
makes them different from every other endpoint in this codebase is the same thing for both
— they call a model, they cost money, and they share one budget. Splitting them would put
that one argument in two docstrings.

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
down spends our margin. ``PRICING.md`` §6.1 calls free-tier cost control existential and
§6.3 makes it a hard rule.

:data:`GENERATIONS_PER_DAY` is 3, per owner, per THEIR local day, shared by both endpoints.
The number is a cost decision, against ``PRICING.md`` §3.1's model (Gemini 3 Flash,
$0.50/M in · $3.00/M out):

* one completion here is ~10 k input (system + v2 context + top-6 full notes + the lever
  and calibration tables) and ~800 output ⇒ **~0.74 ¢**;
* one REQUEST is 1 completion in the ordinary case and at most 4 in the worst
  (``generate._MAX_BOUNDS_RETRIES`` = 1 outer × ``grounded._MAX_RETRIES`` = 1 inner) ⇒
  **0.74 ¢ typical, ~3.1 ¢ worst**;
* at the cap, that is **~2.2 ¢/owner/day ≈ $0.67/owner/month** typically and **~9.3 ¢/day
  ≈ $2.79/month** in the pathological case where every run loses both gates twice.

Weigh that against the number that actually decides it — **§6.1's profit per premium user,
$1.42/month planning and $2.12 optimized.** An owner who genuinely maxed the cap every
single day would take ~47 % of the planning-case profit, and the pathological case would
take all of it. Two things make three the right number anyway, and both are stated rather
than assumed:

* **Nobody maxes it.** A suggestion is calibrated from ``series.recent_window``, which
  reads whole LOCAL DAYS, so a second refresh inside one day asks a differently-worded
  question about identical inputs. Real use is a refresh every few days, which rounds to
  cents a month; the cap exists for the owner who does not behave like that.
* **No daily cap makes the pathological case free** — even a limit of ONE costs
  ~$0.93/month if every run loses both gates twice. What a cap buys is a bound, and the
  bound is one line to change. ``PRICING.md`` §6.4's cost levers (prompt caching,
  Flash-Lite) roughly halve every figure above and are the real answer.

**It is not §12.3's metering.** That gate (``require_ai_access`` — premium OR one coach
question per rolling seven days) answers *may this person use an AI feature at all*; this
one answers *how often may anyone, premium included, spend on this*. They compose: when
6.6 lands, entitlement is checked first and this budget still bounds a paying owner.
Building one as the other would either hand a free user a paid allowance or wall a paying
one out.

**What it covers, since 6.6a:** the coach's ``create_challenge`` too. This section used
to say the opposite — that the coach's natural unit is a TURN, so bolting the budget onto
one of its three tools would meter a third of a conversation. That argument lost to a
simpler one: a generation costs ~0.74 ¢ whichever door it came through, and this module's
own comment on :data:`BUDGET_FEATURE` already said why there is ONE budget ("a second name
would just be two ways to spend it"). Both doors now charge the same per-owner counter
through :mod:`healthee.challenges.budget`, and the consequence is deliberate — spending
all three through the endpoint means chat cannot create one either, because it is one
cost pool and not two allowances.

## 3. The premium gate (6.6a)

Challenges and programs are premium in full (``PRICING.md`` §1a). Both endpoints take
``ChallengeUser`` (``api.gate``) rather than ``CurrentUser``, so entitlement is checked
by a FastAPI dependency — i.e. BEFORE :func:`_spend_then_run` — and an owner with no
entitlement gets **402** without spending a unit of a budget they could not have used.
The ordering matters for one concrete reason: this budget is charge-then-refund, so
checking entitlement after it would leave a locked-out owner's counter at 1/3 for a
request that never reached a model — a number that would then be wrong the day they
subscribe.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Literal

from fastapi import APIRouter, HTTPException

from healthee.api.gate import ChallengeUser
from healthee.api.routers.challenges import Challenge, _Wire
from healthee.api.routers.programs import Program
from healthee.api.validation import require_ok
from healthee.challenges import budget, generate, program_generate

router = APIRouter(tags=["generation"])

# The budget itself moved DOWN to `challenges.budget` in 6.6a so the coach's
# `create_challenge` charges the same counter (#78) — `insights` may not import a
# router. The number and the arithmetic behind it are unchanged; §2 above still argues
# them, and these two names are re-exported because the endpoints' tests and docs refer
# to them by these names.
GENERATIONS_PER_DAY = budget.GENERATIONS_PER_DAY
BUDGET_FEATURE = budget.FEATURE


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


class GeneratedProgram(_Wire):
    """``POST /api/programs/generate`` — the stored ladder, or nothing and why.

    ``program`` is a single object or ``null`` rather than a list, mirroring
    ``ProgramFeed.active``: one ladder is designed at a time because one is all an owner
    may run (``ladder.MAX_ACTIVE_PROGRAMS``), and a menu of ladders would be a lot of
    tokens spent on a choice the engine caps at one. Required-and-nullable, never
    defaulted — the challenges router's rule 2.
    """

    ok: Literal[True]
    generated: int
    rejected: list[str]
    program: Program | None


@router.post("/api/challenges/generate", response_model=GeneratedChallenges)
def post_generate_challenges(user: ChallengeUser) -> GeneratedChallenges:
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


@router.post("/api/programs/generate", response_model=GeneratedProgram)
def post_generate_program(user: ChallengeUser) -> GeneratedProgram:
    """Design, gate and persist ONE multi-week ladder for this owner (WP-C4b).

    The ladder is stored ``suggested`` with every rung ``locked``: designing is not
    starting, and starting is ``POST /api/programs/{program_id}/adopt``, which recalibrates
    the first rung against the owner's baseline at that moment.

    409 with a named reason when a rule refused — already climbing a ladder, or too little
    of their data to calibrate against. A design the shape gates threw out is a **200**
    with ``generated: 0`` and the reasons in ``rejected``: the pipeline worked, the model's
    ladder did not, and those are different answers (``challenges/program_screen.py``).
    """
    result = _spend_then_run(
        user,
        lambda: program_generate.generate_program(user.id, user.timezone),
        program_generate.PRE_LLM_REFUSALS,
    )
    return GeneratedProgram.model_validate(result)


def _spend_then_run(
    user: ChallengeUser, run: Callable[[], dict], uncharged: frozenset[str]
) -> dict:
    """Charge the shared budget, run the pipeline, and shape a refusal onto the wire.

    The charging itself is :func:`healthee.challenges.budget.spend_then_run` — the ONE
    place a generation is paid for, whichever door it came through (#78). What is left
    here is HTTP: an exhausted budget is a **429** carrying ``Retry-After`` and the
    instant it resets, which is a status the coach has no use for and this router is the
    only one that can set.
    """
    result = budget.spend_then_run(user.id, user.timezone, run, uncharged)
    if result.get("reason") == budget.BUDGET_SPENT:
        raise HTTPException(
            status_code=429,
            detail={key: result[key] for key in ("reason", "error", "limit", "used", "resets_at")},
            headers={"Retry-After": str(result["retry_after_s"])},
        )
    return require_ok(result)
