"""ONE morning generation — the Telegram briefing body AND today's daily action (#95).

``BRIEFING_TASK`` used to ask, in its own words, for "today's single most useful action",
and the daily-action prompt asked for that same line and nothing else: **two full-corpus
calls per owner per night, of which the first already contained the second.** The evidence
notes are ~86 % of either prompt (``PRICING.md`` §3.1), so that was the most expensive
duplication in the product.

Both surfaces survive — they have genuinely different destinations (Telegram via
``jobs.briefing``; ``/api/today``'s ``action`` via the warm cache in ``coaching``). So this
is not "delete one". It is **generate once, judge once, render twice**.

Measured on a 40-day seeded owner, 2026-08-02, **counted not billed** (tiktoken over the
real assembled prompts, no provider call): the two prompts were **35,728 + 36,375 =
72,103** input tokens; the merged one is **37,787**, so a shipping night costs **34,316
fewer input tokens, −47.6 %**. The same script counts what the merge ADDS to the briefing
call — +2,059, of which 1,360 is the wider context window and ~700 the JSON task and the
union of metrics changing which notes rank in. For scale, the whole nightly chain measured
**134,092** provider-counted input tokens across four calls (``PRICING.md`` §3.1), so this
is ~24 % off the night.

## Two fields, not a regex over prose

The call runs through the choke point's JSON seam (``grounded_ask(response_format="json")``)
and the model returns the two pieces as two fields. Nothing here pulls an action line out
of a paragraph: a regex over generated prose is a parser against a thing with no grammar,
and the sentence it returns would be the wrong one *silently*. ``json_shapes`` registers
the shape and ``validator.validate_json`` then runs the SAME honesty rules over both fields
that the prose path runs over an answer — fabricated ids, grade calibration, banned tone,
uncited interpretation. The hard output guardrails and the anti-hallucination gate are
stage-registry gates and apply unchanged.

## Validation binds both, and a partial pass does not exist

The two fields are ONE candidate at the gates. An ungrounded sentence in ``action`` fails
the whole generation and the briefing does not ship either. That is deliberate: a briefing
assembled from a validated body and an unvalidated action is exactly the half-checked
artefact a blocking validator exists to prevent, and there is no honest way to ship half a
judged answer.

## The coupling is handled, not noted (#95's real risk)

A merged surface that halves availability to save money is not a win. So the merged call is
an **optimisation, never a dependency**:

* it ships → both surfaces are filled for one call's price;
* it does not ship → **each surface falls back to exactly the independent generation it
  makes today** — ``coaching.warm_daily_action`` for the action, :func:`generate_briefing`
  for the briefing. Neither can go dark because of the other's sentence.

Cost then follows availability instead of the reverse, and the arithmetic says where the
line is. Write *a* for "the merged candidate clears the gates first time", *F* for "it fails
both attempts", and *s* for the same first-time rate on a single surface. A gate failure
costs one nudged retry (``pipeline.MAX_VALIDATION_RETRIES = 1``), so:

    before = 2·(2 − s) calls          after = (2 − a) + F·2·(2 − s) calls

With *a ≈ s* those are equal exactly at **F = 0.5**: the merge is cheaper whenever the
merged call's total-failure rate is under half, and it degrades to *at most* the old spend
plus the merged attempt otherwise. Measured fallback rates on this pipeline are **0 % on
current main** (§9.3's before arm, 14/14) and **31 % at the 2026-08-01 baseline**, both far
inside that. Each surface's failure MODE is unchanged: the briefing Telegrams the honest
fallback, and the action stays ``null`` so ``/api/today`` says nothing rather than guessing.

## The window and the metrics: the union, and why that is not splitting the difference

``context_days = 30`` — the daily action's window, not the briefing's 14. The action is
calibrated from whole local days (``api.routers.daily_action``) and its own prompt asks for
"my recent data"; narrowing it to 14 would silently change what a shipped surface can see,
which is a behaviour change hiding inside a cost change. Widening the briefing to 30 changes
nothing it may *say* — its claims are comparisons against a personal baseline, which a
longer window serves at least as well — only what it may consider. Measured on a 40-day
seeded owner (2026-08-02, **counted not billed**): the 14→30 widening costs **+1,360 input
tokens**, against the **36,375** a second call costs. The union is not a compromise, it is
the cheap half of the trade.

``metrics`` is the UNION of the two lists, and that is nearly free: ``metrics`` feeds
retrieval's RANKING and the coverage metadata, and ``retrieval.evidence_section`` embeds a
fixed ``DEFAULT_TOP_N`` notes however many metrics are named — so the union changes WHICH
six notes ship in full, not HOW MANY. Dropping either surface's metrics would blind the
merged answer to evidence one of them was written against.
"""

from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from healthee.core.logging import get_logger
from healthee.insights.client import LLMClient
from healthee.insights.grounded import GroundedResult, grounded_ask

log = get_logger(__name__)

# Each ask is stated ONCE and assembled into the three prompts below. The merged task and
# the two standalone fallbacks must ask for the same things in the same words, or the
# fallback would quietly be a different product than the fast path.
_BRIEFING_ASK = (
    "where I stand today, using my real numbers: my recovery/readiness and what training "
    "intensity that supports, and the ONE thing most off my personal baseline"
)
_ACTION_ASK = (
    "the single highest-impact thing to do TODAY, chosen from my recent data and today's "
    "recovery — name the lever and one concrete move I can make today"
)
_HONESTY = (
    "Be honest — if it's a flat or below-par day, say so plainly, no cheerleading. Cite "
    "[note_id] for every health claim. No diagnosis, no alarmism."
)

# The merged task. JSON mode is on, so the two fields come back as fields — see the module
# docstring on why this is not a regex over prose. The briefing is told NOT to repeat the
# action because the action is rendered beneath it (:meth:`Morning.message`): ONE canonical
# action per day, stated once, on both surfaces.
MORNING_TASK = f"""\
Write my morning briefing and today's single action as ONE answer.

Output ONLY a JSON object (JSON mode is on — no prose, no code fences) of this exact shape:
{{"briefing": "<3-5 short lines on {_BRIEFING_ASK}. Do NOT include the action here — it is \
the next field, and it is shown directly beneath this text>",
 "action": "<one or two short sentences giving {_ACTION_ASK}. Self-contained: it is also \
shown on its own, with none of the briefing around it>"}}

{_HONESTY} Both fields are read by a person: finished text, not notes."""

# The standalone briefing — what ships when the merged call could not. Identical to the
# task this surface sent before #95, reassembled from the same fragments: it asks for the
# action INLINE, because on this path there is no second field to carry it.
BRIEFING_TASK = (
    f"Give me a SHORT morning briefing (3-5 lines) on {_BRIEFING_ASK}; and {_ACTION_ASK}. "
    f"{_HONESTY}"
)

# The standalone action — what `/api/today`'s reveal endpoint and the merged call's
# fallback send. Unchanged in substance from the prompt `coaching` shipped before #95.
DAILY_ACTION_PROMPT = (
    f"In one or two short sentences, give me {_ACTION_ASK}. Cite [note_id] for any health "
    "claim; be direct and kind, never alarmist. No diagnosis."
)

# The metrics retrieval ranks each surface's evidence notes against, and the window its
# context is built over. Module constants rather than call-site literals so a test can rank
# the SHIPPED prompt against the SHIPPED metrics instead of a copy that drifts.
BRIEFING_METRICS = ["recovery_score", "hrv_sleep_avg", "sleep_health_score_4dim", "mvpa_min"]
BRIEFING_CONTEXT_DAYS = 14
DAILY_ACTION_METRICS = ["recovery_score", "mvpa_min", "cardio_load", "sleep_debt_min"]
DAILY_ACTION_CONTEXT_DAYS = 30

# The union of the two, in the order they were declared above (no metric twice). See the
# module docstring: the union changes which notes rank in, not how many are embedded.
MORNING_METRICS = list(dict.fromkeys([*BRIEFING_METRICS, *DAILY_ACTION_METRICS]))
MORNING_CONTEXT_DAYS = DAILY_ACTION_CONTEXT_DAYS


@dataclass(frozen=True)
class Morning:
    """One shipped morning generation: the briefing body, today's action, its grounding.

    ``result`` is the whole ``GroundedResult`` because both surfaces publish the same
    citations, grade floor and data coverage — they came from one judged answer, so
    reporting two different sets of grounding metadata would be a fiction.
    """

    briefing: str
    action: str
    result: GroundedResult

    @property
    def message(self) -> str:
        """The Telegram body: the briefing, then the same action the app shows."""
        return f"{self.briefing}\n\nToday's one thing: {self.action}"


def generate_morning(user_id: UUID, tz: str, *, client: LLMClient | None = None) -> Morning | None:
    """ONE grounded call for both morning surfaces, or ``None`` when it cannot ship.

    ``None`` is not an error and never raises: it is "the fast path did not earn its
    saving", and the caller (``coaching.warm_morning``) then lets each surface generate
    independently. A transport failure still propagates — a broken model and an ungroundable
    answer are different states and stay distinguishable (standards §Errors).
    """
    result = grounded_ask(
        MORNING_TASK,
        user_id,
        tz,
        metrics=MORNING_METRICS,
        context_days=MORNING_CONTEXT_DAYS,
        response_format="json",
        client=client,
    )
    if result.refused or not result.validated or result.data is None:
        log.info(
            "morning[%s]: merged generation did not ship (refused=%s validated=%s) — "
            "each surface falls back to its own call",
            user_id,
            result.refused,
            result.validated,
        )
        return None
    fields = _fields(result.data)
    if fields is None:
        log.warning(
            "morning[%s]: the JSON validated but a field was missing or empty — falling back",
            user_id,
        )
        return None
    briefing, action = fields
    return Morning(briefing=briefing, action=action, result=result)


def _fields(payload: dict) -> tuple[str, str] | None:
    """The two non-empty strings, or None — the structural check the validator cannot make.

    ``validate_json`` checks the honesty of the text a payload CONTAINS; a payload missing
    ``action`` entirely contains no ungrounded sentence and passes. That is the same
    fail-closed seam ``jobs/recs.py::_rec_ok`` stands on, and it is why the shape is checked
    here rather than assumed: a briefing rendered around an absent action would ship the
    word "None" to Telegram.
    """
    briefing = payload.get("briefing")
    action = payload.get("action")
    if not isinstance(briefing, str) or not isinstance(action, str):
        return None
    if not briefing.strip() or not action.strip():
        return None
    return briefing.strip(), action.strip()


def generate_briefing(user_id: UUID, tz: str, *, client: LLMClient | None = None) -> GroundedResult:
    """The briefing ALONE — the independent fallback, and the pre-#95 call unchanged.

    Reached when the merged generation did not ship, or when it never ran at all (a
    ``correlate`` failure skips the ``warm`` step that hosts it, ``jobs/chain.py``). Its
    honest fallback is still SENT: a briefing that says "I can't ground that" is an answer,
    and silence is not.
    """
    return grounded_ask(
        BRIEFING_TASK,
        user_id,
        tz,
        metrics=BRIEFING_METRICS,
        context_days=BRIEFING_CONTEXT_DAYS,
        client=client,
    )
