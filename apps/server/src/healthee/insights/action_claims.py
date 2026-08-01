"""The anti-hallucination gate: a first-person action claim needs a tool that said ok.

Split out of ``coach.py`` when the choke point's stages were collapsed into
``pipeline.py``. It lived in the coach because the coach is the only surface with tools
— but that is exactly the reasoning that produced the two-copies problem this refactor
exists to kill. The rule is not "the coach must not lie about tools", it is **no surface
may claim an action nothing performed**, and a tool-less surface satisfies it trivially
(``acted_ok`` is empty, so *every* action claim is an issue). Stating it that way lets
the gate sit in the ONE shared registry instead of in one surface's loop.

INTELLIGENCE §4: "never claim logged/adopted/created/started unless the tool returned
ok:true this turn". WP-C5 made it **per-tool** — with one action tool "did any action
tool succeed" was the same question; with three, a successful ``log_entry`` would
otherwise license "I started your challenge".
"""

from __future__ import annotations

import re
from collections.abc import Collection

__all__ = ["ACTION_CLAIM_RE", "CLAIM_TOOLS", "claim_issues"]

# First-person action claims that may only be made when SOME action tool returned ok
# THIS turn — the floor of the guard.
ACTION_CLAIM_RE = re.compile(
    r"\bI(?:'ve| have)?\s+(?:just\s+)?"
    r"(?:logged|recorded|started|ended|stopped|adopted|created|saved)\b|"
    r"\blogged your\b|\bstarted (?:a|your) fast\b|\bended your fast\b|\badopted (?:the|your)\b",
    re.IGNORECASE,
)


def _claim_pattern(verbs: str) -> re.Pattern[str]:
    """ "I …<verb>… challenge" — tolerating adverbs, refusing a NEGATED claim.

    The adverb gap matters ("I've also adopted…") and so does the negation guard: an
    honest "I have not started a challenge" is the sentence this coach is supposed to
    be able to say, and a guard that pushed it into the fallback would punish exactly
    the behaviour it exists to enforce.
    """
    return re.compile(
        r"\bI(?:'ve| have)?\s+(?:(?!not\b|never\b)[a-z]+\s+){0,2}"
        rf"(?:{verbs})\b[^.!?]{{0,60}}\bchallenge\b",
        re.IGNORECASE,
    )


# …and the claims that name ONE specific action, each tied to the only tool that can
# make it true. The floor above asks whether ANY action tool succeeded, which was
# exactly right while `log_entry` was the only one; with three action tools (WP-C5) it
# would let a successful coffee log license "I started your challenge". A claim about a
# commitment somebody now believes they have made is not a claim to be loose about.
CLAIM_TOOLS: tuple[tuple[re.Pattern[str], str], ...] = (
    (_claim_pattern("adopted|started|kicked off"), "adopt_challenge"),
    (_claim_pattern("created|built|made|set up|written"), "create_challenge"),
)


def claim_issues(text: str, acted_ok: Collection[str]) -> list[str]:
    """Every action ``text`` claims that no tool actually performed this turn."""
    issues: list[str] = []
    if ACTION_CLAIM_RE.search(text) and not acted_ok:
        issues.append(
            "Claims an action (logged/started/adopted/created/…) but no action tool "
            "returned ok this turn — never state an action you did not take."
        )
    for pattern, tool in CLAIM_TOOLS:
        if pattern.search(text) and tool not in acted_ok:
            issues.append(
                f"Claims something only `{tool}` can do, but `{tool}` did not return ok "
                "this turn — say what actually happened."
            )
    return issues
