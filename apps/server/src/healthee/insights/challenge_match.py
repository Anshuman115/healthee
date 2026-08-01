"""Which suggestion did they mean — and how to name it back (WP-C5, split out in 6.6a).

One responsibility: turning a person's *reference* to a challenge ("the walk one", a
title, an id) into exactly one stored suggestion, or refusing because it is not
knowable. It carries the refusal shape too, because a refusal here echoes the
candidates back — naming them is the same job as matching them.

Split out of ``challenge_tools`` when that file crossed the 400-line gate (standards
§1). The seam is the honest one: everything here is about LANGUAGE and identity, and
nothing in it knows what a challenge does or costs.
"""

from __future__ import annotations

import re
from typing import Any

# How many suggestions a refusal echoes back. Enough for the coach to ask "which of
# these?" and few enough that a refusal does not become a second context dump.
_ECHO_LIMIT = 5


def resolve(suggestions: list[dict], challenge_id: Any, reference: str | None) -> dict:
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
            return refused("bad_reference", f"challenge_id {challenge_id!r} is not an id")
    if not suggestions:
        return refused(
            "nothing_suggested",
            "there are no suggested challenges to adopt — use create_challenge if they "
            "want one authored for them",
        )
    if not (reference or "").strip():
        return refused(
            "no_reference",
            "say which suggestion: pass its challenge_id, or its title as `reference`",
            suggestions,
        )
    matches = _matches(suggestions, str(reference))
    if not matches:
        return refused("no_match", f"nothing suggested matches {reference!r}", suggestions)
    if len(matches) > 1:
        return refused(
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


def refused(reason: str, message: str, candidates: list[dict] | None = None) -> dict:
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


__all__ = ["refused", "resolve"]
