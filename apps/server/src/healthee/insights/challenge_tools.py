"""The coach's two challenge tools — adopt a suggestion, or ask for a new one (WP-C5).

CHALLENGES.md §6 and §6a. The difference between the two tools is the whole design:
``adopt_challenge`` takes on something the pipeline ALREADY generated and gated;
``create_challenge`` asks that same pipeline for something new. Neither one lets the
model near a number.

## Why ``create_challenge`` CALLS ``generate_challenges`` instead of doing the work

The tempting shape is a second, smaller pipeline. The coach already holds the corpus,
the owner's data and their discovered patterns in its standing context, so it could
propose a metric and a target here and we could check them here. That is exactly the
failure INTELLIGENCE §4 records: while the coach was enforced-EQUIVALENT to the choke
point rather than routed through it, any rule living in only one of the two paths was a
rule the other silently missed. (#46 has since collapsed the two onto one pipeline — but
the argument here is about GENERATION, which was never the thing that got shared.)
Forking generation would make Gate A (the baseline band) and Gate B (cite-or-refuse)
two things to keep in step — and the last time this codebase held two copies of one
rule, the two surfaces disagreed (``challenges.recovery_guard``'s module docstring).

So the coach supplies INTENT and nothing else. ``generate.generate_challenges(...,
intent=…)`` is the seam WP-C3 built for this, and everything downstream of it — the
lever ranking, the calibration table, Gate A's band, Gate B's blocking validator, the
per-owner cap, the duplicate check, the owner-scoped write — is the same code the
app's own refresh runs. Reusing the pipeline IS the discharge of the mirror rule.
``tests/insights/test_challenge_create.py`` asserts the CALL and not merely the
outcome, so a future fork fails a test instead of quietly shipping a second set of
gates.

One thing the seam did not have and now does: ``replace_feed``. A refresh REPLACES the
owner's suggestion feed (``store.delete_suggestions``), which is right for a refresh
and wrong for a chat message — a coach turn must not silently delete the suggestions
somebody was looking at in another tab. The coach passes ``replace_feed=False`` and
the pipeline then dedupes against suggested metrics as well as active ones.

## What the coach may say afterwards

Anti-hallucination is absolute (INTELLIGENCE §4). Both tools return the STORED row,
target included, because the number the coach reports has to be the number in the
database and not the one it had in mind: Gate A REJECTS an out-of-band target rather
than clamping it, and the pipeline's one retry can come back with a different number
entirely. ``coach._accept`` ties the claim to the tool — "I adopted…" needs
``adopt_challenge`` to have returned ok this turn, and "I created…" needs
``create_challenge`` to have.

## The generation budget, which this used to bypass (#78, 6.6a)

``create_challenge`` charges the SAME per-owner daily counter as
``POST /api/challenges/generate`` — one pool, through ``challenges.budget``. WP-C5
deferred that on the argument that the coach's natural unit is a TURN, not a
generation; the argument lost, because a generation costs the same ~0.74 ¢ whichever
door it came through, and the endpoint that already had the budget said in its own
comment that there is ONE on purpose ("a second name would just be two ways to spend
it"). The deliberate consequence: an owner who spends all three refreshes in the app
cannot create one in chat that day either, and the refusal says so in words the coach
can repeat.

There is no entitlement check HERE, and that is not an omission: the coach is only
reachable through ``POST /api/coach``, which takes the gated ``CoachUser`` identity
(``api.gate``), so an unentitled owner never gets a turn in which to call a tool. A
second check inside the tool would be a second place for the rule to live — the exact
failure this module's opening argument is about.
"""

from __future__ import annotations

import re
from typing import Any
from uuid import UUID

from healthee.challenges import budget, generate, lifecycle, store
from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger
from healthee.insights.challenge_match import refused, resolve
from healthee.insights.tool_spec import function_tool

log = get_logger(__name__)

ADOPT = "adopt_challenge"
CREATE = "create_challenge"

# The names ``coach_tools.execute_tool`` routes here.
TOOL_NAMES: frozenset[str] = frozenset({ADOPT, CREATE})

# Both WRITE, so both are action tools: a claim that one of them happened is only
# truthful if it ran AND returned ok this turn (``coach._accept``).
ACTION_TOOLS: frozenset[str] = TOOL_NAMES

# How many rejection sentences a failed creation carries back. The pipeline logs them
# all (``generate._log_rejections``); this is what the coach needs to say *why*.
_REASON_LIMIT = 4

# A cutoff intent names a clock. The registry now HAS a clock — but only on the two
# things this product can see one on: the substances the owner logs with a timestamp
# (``challenges.windowed``). For everything else a ``ChallengeMetric`` is still one
# number per owner-day with no "…after HH:MM" dimension, and the refusal below still
# stands for those.
#
# The refusal exists because the DEGRADATION is the dangerous part. "No caffeine after
# 16:00" expressed as a daily caffeine cap scores three morning coffees as a failure and
# one 23:00 coffee as a pass: wrong in both directions, and wrong quietly. That risk is
# unchanged for "in bed before 23:00" or "10,000 steps before noon", which is why this
# gate narrowed rather than disappeared.
#
# The pattern deliberately requires an explicit clock — "after 16:00", "after 3pm",
# "before bed" — and NOT a bare "after 3", which is far more often a count ("after 3
# coffees") than an hour. That under-matches on purpose: a missed cutoff intent falls
# through to the pipeline, which will say honestly what it could and could not build,
# whereas an over-eager pattern would refuse challenges we can genuinely express.
_TIME_OF_DAY_RE = re.compile(
    r"\b(?:after|before|past|until|till|by|later than|earlier than)\s+"
    r"(?:\d{1,2}[:.]\d{2}\s*(?:am|pm)?"
    r"|\d{1,2}\s*(?:am|pm|o'clock)"
    r"|noon|midday|midnight|lunch(?:time)?|dinner(?:time)?|bed(?:time)?|breakfast)\b",
    re.IGNORECASE,
)

# The words people use for the substances a window can be measured on. The KEYS are
# checked against the registry by a test, so a windowed substance added without its
# vocabulary fails CI rather than silently refusing every intent about it; the words
# themselves are language and no table can derive them.
_WINDOWED_SUBSTANCE_WORDS: dict[str, tuple[str, ...]] = {
    "caffeine": ("caffeine", "coffee", "espresso", "latte", "tea", "energy drink", "cola"),
    "alcohol": (
        "alcohol",
        "alcoholic",
        "drink",
        "drinking",
        "beer",
        "wine",
        "whisky",
        "whiskey",
        "spirits",
        "nightcap",
        "booze",
    ),
}

_TIME_OF_DAY_REFUSAL = (
    "we can only measure a time-of-day cutoff on something they LOG with a clock — "
    "caffeine and alcohol — and this asked for one on something else. Every other "
    "challenge binds to ONE number per day, so a cutoff on it could only be stored as a "
    "daily total, which would score three morning coffees as a failure and one "
    "late-night coffee as a pass. Tell them plainly that we cannot measure a cutoff on "
    "that, and do NOT offer the daily-total version as though it were what they asked for."
)


CHALLENGE_TOOLS: list[dict] = [
    function_tool(
        ADOPT,
        "Start one of the challenges ALREADY suggested to this person — they are listed "
        "in your context with their ids. Only when they say yes. Pass `challenge_id` "
        "when you have it; `reference` is matched against their suggestions and an "
        "ambiguous match is REFUSED rather than guessed. Returns the stored challenge: "
        "report ITS target, not one you had in mind, and never say a challenge started "
        "unless this returned ok.",
        {
            "challenge_id": {
                "type": "integer",
                "description": "the id shown beside the suggestion — the exact form",
            },
            "reference": {
                "type": "string",
                "description": "the suggestion's title, or its metric key, when you have no id",
            },
        },
        [],
    ),
    function_tool(
        CREATE,
        "Ask for a NEW challenge to be authored for this person when nothing already "
        "suggested fits ('make me a sleep challenge'). Pass their INTENT in their own "
        "words: you do not choose the metric, the target, the cadence or the wording. "
        "The generator picks the lever, computes the target from their own baseline and "
        "grounds every claim in the research base — and returns nothing at all when we "
        "cannot track what they asked for or cannot cite it. Report the target it "
        "returns; never one you proposed.",
        {
            "intent": {
                "type": "string",
                "description": "what the person asked for, in their words",
            }
        },
        ["intent"],
    ),
]


def execute(name: str, args: dict[str, Any], user_id: UUID, tz: str) -> dict:
    """Dispatch one of :data:`TOOL_NAMES` to its implementation, scoped to ``user_id``.

    An unrecognised name is a routing bug in ``coach_tools``, not a model mistake, so
    it raises instead of degrading into an honest-looking error dict (standards
    §Errors — "no data" and "failed" are different states, and so is "impossible").
    """
    if name == ADOPT:
        return adopt_challenge(user_id, tz, args.get("challenge_id"), args.get("reference"))
    if name == CREATE:
        return create_challenge(user_id, tz, str(args.get("intent") or ""))
    raise ValueError(f"{name!r} is not a challenge tool")


def adopt_challenge(
    user_id: UUID, tz: str, challenge_id: Any = None, reference: str | None = None
) -> dict:
    """Adopt one PRE-GENERATED suggestion of ``user_id``'s. Ambiguity refuses.

    Every lifecycle rule (the suggested-only status guard, the per-owner cap, the
    cadence-expressibility check, the baseline frozen at adopt) belongs to
    ``lifecycle.adopt`` and is not restated here — this function's whole job is
    deciding WHICH suggestion was meant, and refusing when that is not knowable.
    """
    with tenant_transaction(user_id) as cur:
        suggestions = store.list_by_status(cur, user_id, ("suggested",))
        resolved = resolve(suggestions, challenge_id, reference)
        if not resolved.get("ok"):
            log.info("coach adopt refused for %s: %s", user_id, resolved.get("reason"))
            return resolved
        result = lifecycle.adopt(cur, user_id, tz, int(resolved["id"]))
    if not result.get("ok"):
        log.info("coach adopt refused by lifecycle for %s: %s", user_id, result.get("reason"))
        return result
    return {
        "ok": True,
        "challenge": result["challenge"],
        "note": "started now. Report the target and cadence exactly as stored above — "
        "it was calibrated to their own baseline, which is frozen on the row.",
    }


def create_challenge(user_id: UUID, tz: str, intent: str) -> dict:
    """Author a new challenge for ``user_id`` from their stated ``intent``.

    Every gate is ``generate_challenges``'; this function contributes exactly two
    things of its own — the deterministic refusal for a shape the registry cannot
    express at all (:data:`_TIME_OF_DAY_RE`), and the translation of the pipeline's
    outcome into something the coach can say honestly.

    It charges the shared generation budget (#78), so a chat-created challenge costs the
    owner the same unit an in-app refresh does. The clock-shape refusal above is checked
    FIRST and deliberately: it never asks a model, so charging for it would take a
    refresh away for a sentence we already know we cannot express.

    The created row is ``suggested``, NOT active. Creating and starting are two
    consents, and the person gave one: the coach shows them what was built and calls
    :func:`adopt_challenge` only if they say yes.
    """
    intent = (intent or "").strip()
    if not intent:
        return refused("no_intent", "say what the person actually asked for")
    if _TIME_OF_DAY_RE.search(intent) and not _names_a_windowed_substance(intent):
        log.info("coach create refused for %s: no time-of-day predicate for that", user_id)
        return refused("no_time_of_day_predicate", _TIME_OF_DAY_REFUSAL)
    result = budget.spend_then_run(
        user_id,
        tz,
        lambda: generate.generate_challenges(
            user_id, tz, intent=intent, max_new=1, replace_feed=False
        ),
        generate.PRE_LLM_REFUSALS,
    )
    if not result.get("ok"):
        return result
    created = result.get("challenges") or []
    if not created:
        return _nothing_created(list(result.get("rejected") or []))
    return {
        "ok": True,
        "challenge": created[0],
        "status": "suggested",
        "note": "created as a SUGGESTION — not started. Report the target exactly as "
        "stored here: it was computed from their own baseline, not from anything you "
        "proposed. Call adopt_challenge only if they say yes.",
    }


def _names_a_windowed_substance(intent: str) -> bool:
    """Whether this cutoff intent is about something we can actually put a clock on.

    A pass here is NOT permission — it hands the intent to the pipeline, which offers a
    window only where the owner's own finding placed one and otherwise creates nothing
    and says why (``challenges.levers._unfounded_window``). What it prevents is this
    regex answering a question it is not qualified to answer: "no caffeine after 16:00"
    is now an expressible challenge for an owner whose data found that cutoff, and a
    blanket refusal would be a false statement about what the product can do.
    """
    lowered = intent.lower()
    return any(word in lowered for words in _WINDOWED_SUBSTANCE_WORDS.values() for word in words)


def _nothing_created(rejected: list[str]) -> dict:
    """The two ways a run can survive both gates and still write nothing.

    They are different states and the coach has to be able to say which (standards
    §Errors): an intent no trackable metric can express is a permanent "we cannot
    measure that", while a proposal the gates threw out is a "we could not build one
    that fits your own numbers" — and the second comes with its reasons.
    """
    if not rejected:
        return refused(
            "not_trackable",
            "nothing in the trackable metric set can express that, or their own data "
            "could not calibrate a target for it. Say so plainly — do not describe a "
            "challenge that was not created.",
        )
    return refused(
        "rejected_by_gates",
        "every proposal for that intent was rejected before it could be stored: "
        + "; ".join(rejected[:_REASON_LIMIT]),
    )
