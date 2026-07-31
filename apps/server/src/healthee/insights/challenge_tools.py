"""The coach's two challenge tools — adopt a suggestion, or ask for a new one (WP-C5).

CHALLENGES.md §6 and §6a. The difference between the two tools is the whole design:
``adopt_challenge`` takes on something the pipeline ALREADY generated and gated;
``create_challenge`` asks that same pipeline for something new. Neither one lets the
model near a number.

## Why ``create_challenge`` CALLS ``generate_challenges`` instead of doing the work

The tempting shape is a second, smaller pipeline. The coach already holds the corpus,
the owner's data and their discovered patterns in its standing context, so it could
propose a metric and a target here and we could check them here. That is exactly the
failure INTELLIGENCE §4 warns about: the coach is enforced-EQUIVALENT to the choke
point rather than routed through it, so any rule living in only one of the two paths
is a rule the other silently misses. Forking generation would make Gate A (the
baseline band) and Gate B (cite-or-refuse) two things to keep in step — and the last
time this codebase held two copies of one rule, the two surfaces disagreed
(``challenges.recovery_guard``'s module docstring).

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

## Not premium-gated, because 6.6 does not exist

The same statement ``generate`` makes: the whole challenges system is premium
(PRICING §1a), there is no ``subscription`` table and no ``require_ai_access`` to hang
a gate on (MULTI_USER.md §12), so these tools are reachable by any authenticated owner
exactly like every other AI surface today. Noted rather than faked — a comment
claiming a gate that is not there is worse than a missing gate.
"""

from __future__ import annotations

import re
from typing import Any
from uuid import UUID

from healthee.challenges import generate, lifecycle, store
from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger
from healthee.insights.tool_spec import function_tool

log = get_logger(__name__)

ADOPT = "adopt_challenge"
CREATE = "create_challenge"

# The names ``coach_tools.execute_tool`` routes here.
TOOL_NAMES: frozenset[str] = frozenset({ADOPT, CREATE})

# Both WRITE, so both are action tools: a claim that one of them happened is only
# truthful if it ran AND returned ok this turn (``coach._accept``).
ACTION_TOOLS: frozenset[str] = TOOL_NAMES

# How many suggestions a refusal echoes back. Enough for the coach to ask "which of
# these?" and few enough that a refusal does not become a second context dump.
_ECHO_LIMIT = 5

# How many rejection sentences a failed creation carries back. The pipeline logs them
# all (``generate._log_rejections``); this is what the coach needs to say *why*.
_REASON_LIMIT = 4

# A cutoff intent names a clock, and the registry has no clock. A ``ChallengeMetric``
# yields ONE number per owner-day and carries no "…logged after HH:MM" predicate —
# ``challenges.metrics``'s closing paragraph states that limit; this acts on it.
#
# The refusal exists because the DEGRADATION is the dangerous part. "No caffeine after
# 15:00" expressed as a daily caffeine cap scores three morning coffees as a failure
# and one 23:00 coffee as a pass: wrong in both directions, and wrong quietly. Building
# the predicate is the next work package (CHALLENGES.md §5.1 makes the cutoff findings
# a first-class generation input, and this is the shape they naturally produce).
#
# The pattern deliberately requires an explicit clock — "after 15:00", "after 3pm",
# "before bed" — and NOT a bare "after 3", which is far more often a count ("after 3
# coffees") than an hour. That under-matches on purpose: a missed cutoff intent falls
# through to the pipeline, which can still only bind it to a daily total and will say
# so through the ordinary rejection path, whereas an over-eager pattern would refuse
# challenges we can genuinely express.
_TIME_OF_DAY_RE = re.compile(
    r"\b(?:after|before|past|until|till|by|later than|earlier than)\s+"
    r"(?:\d{1,2}[:.]\d{2}\s*(?:am|pm)?"
    r"|\d{1,2}\s*(?:am|pm|o'clock)"
    r"|noon|midday|midnight|lunch(?:time)?|dinner(?:time)?|bed(?:time)?|breakfast)\b",
    re.IGNORECASE,
)

_TIME_OF_DAY_REFUSAL = (
    "we cannot track a time-of-day rule yet, so this specific shape does not exist. "
    "Every challenge binds to ONE number per day and the metric registry has no "
    "'after HH:MM' predicate, so a cutoff could only be stored as a daily total — "
    "which would score three morning coffees as a failure and one late-night coffee "
    "as a pass. Tell them plainly that we cannot measure a cutoff yet, and do NOT "
    "offer the daily-total version as though it were what they asked for."
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
        resolved = _resolve(suggestions, challenge_id, reference)
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


def _resolve(suggestions: list[dict], challenge_id: Any, reference: str | None) -> dict:
    """Which suggestion was meant — or a refusal. It never picks for the person.

    An explicit id is taken as given rather than re-matched: ``lifecycle.adopt``
    re-reads it under the owner's own scope and refuses it honestly when it is not
    theirs or is no longer suggested, so nothing trusted here escapes being checked
    there.
    """
    if challenge_id is not None:
        try:
            return {"ok": True, "id": int(challenge_id)}
        except (TypeError, ValueError):
            return _refused("bad_reference", f"challenge_id {challenge_id!r} is not an id")
    if not suggestions:
        return _refused(
            "nothing_suggested",
            "there are no suggested challenges to adopt — use create_challenge if they "
            "want one authored for them",
        )
    if not (reference or "").strip():
        return _refused(
            "no_reference",
            "say which suggestion: pass its challenge_id, or its title as `reference`",
            suggestions,
        )
    matches = _matches(suggestions, str(reference))
    if not matches:
        return _refused("no_match", f"nothing suggested matches {reference!r}", suggestions)
    if len(matches) > 1:
        return _refused(
            "ambiguous",
            f"{reference!r} matches {len(matches)} of their suggestions — ask which one "
            "they mean, or call again with its challenge_id. Nothing was started.",
            matches,
        )
    return {"ok": True, "id": int(matches[0]["id"])}


def _matches(suggestions: list[dict], reference: str) -> list[dict]:
    """The most specific tier of match that has any candidates; ``[]`` when none does.

    Three tiers, tried in order — an exact title, then the metric key, then
    containment either way ("the walk one" ⊃ "Walk a little more"). Preferring an
    exact title over a containment is not a guess: it is strictly more evidence, and
    the tiers exist so that one suggestion matching exactly is not drowned out by two
    others that merely share a word.

    Ambiguity WITHIN the winning tier is not resolved — the caller refuses. Legacy
    adopted "by title match" and took whatever came first, which is the shape of
    error this product exists not to make: a challenge somebody did not choose,
    reported to them as one they did.
    """
    ref = _normalize(reference)
    for predicate in (_same_title, _same_metric, _contains):
        found = [s for s in suggestions if predicate(s, ref)]
        if found:
            return found
    return []


def _normalize(text: str) -> str:
    """Lowercase, punctuation-flattened, whitespace-collapsed — for comparison only."""
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def _same_title(suggestion: dict, ref: str) -> bool:
    return _normalize(str(suggestion["title"])) == ref


def _same_metric(suggestion: dict, ref: str) -> bool:
    return _normalize(str(suggestion["metric"])) == ref


def _contains(suggestion: dict, ref: str) -> bool:
    title = _normalize(str(suggestion["title"]))
    return bool(ref) and (ref in title or title in ref)


def create_challenge(user_id: UUID, tz: str, intent: str) -> dict:
    """Author a new challenge for ``user_id`` from their stated ``intent``.

    Every gate is ``generate_challenges``'; this function contributes exactly two
    things of its own — the deterministic refusal for a shape the registry cannot
    express at all (:data:`_TIME_OF_DAY_RE`), and the translation of the pipeline's
    outcome into something the coach can say honestly.

    The created row is ``suggested``, NOT active. Creating and starting are two
    consents, and the person gave one: the coach shows them what was built and calls
    :func:`adopt_challenge` only if they say yes.
    """
    intent = (intent or "").strip()
    if not intent:
        return _refused("no_intent", "say what the person actually asked for")
    if _TIME_OF_DAY_RE.search(intent):
        log.info("coach create refused for %s: time-of-day predicate does not exist", user_id)
        return _refused("no_time_of_day_predicate", _TIME_OF_DAY_REFUSAL)
    result = generate.generate_challenges(user_id, tz, intent=intent, max_new=1, replace_feed=False)
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


def _nothing_created(rejected: list[str]) -> dict:
    """The two ways a run can survive both gates and still write nothing.

    They are different states and the coach has to be able to say which (standards
    §Errors): an intent no trackable metric can express is a permanent "we cannot
    measure that", while a proposal the gates threw out is a "we could not build one
    that fits your own numbers" — and the second comes with its reasons.
    """
    if not rejected:
        return _refused(
            "not_trackable",
            "nothing in the trackable metric set can express that, or their own data "
            "could not calibrate a target for it. Say so plainly — do not describe a "
            "challenge that was not created.",
        )
    return _refused(
        "rejected_by_gates",
        "every proposal for that intent was rejected before it could be stored: "
        + "; ".join(rejected[:_REASON_LIMIT]),
    )


def _refused(reason: str, message: str, candidates: list[dict] | None = None) -> dict:
    """A rule outcome — named, explicit, and never an empty success (standards §Errors).

    Same shape ``lifecycle`` and ``generate`` already refuse in, so the coach reads one
    vocabulary whichever layer said no.
    """
    refusal: dict[str, Any] = {"ok": False, "reason": reason, "error": message}
    if candidates is not None:
        refusal["suggested"] = [_candidate(c) for c in candidates[:_ECHO_LIMIT]]
    return refusal


def _candidate(suggestion: dict) -> dict:
    """One suggestion, reduced to what the coach needs to name it back to the person."""
    return {
        "challenge_id": int(suggestion["id"]),
        "title": suggestion["title"],
        "metric": suggestion["metric"],
        "target_value": float(suggestion["target_value"]),
        "cadence": suggestion["cadence"],
    }
