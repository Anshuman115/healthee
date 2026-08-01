"""The shape of a hard output rule, shared by the two tables that produce them.

``output_guard.py`` holds the ENFORCEMENT (when the rules run, what happens on a hit)
and the hand-compiled ``_DOCUMENTED_RULES``. ``guard_directives.py`` holds the rules
COMPILED from notes that declare a Coach Directive ``safety_critical``. Both need the
same rule type and the same negation semantics, and neither may import the other, so
the type lives here — one definition, no cycle.

Splitting this out is not decoration: before #87 the second table did not exist, and
``output_guard.py`` was already at 314 lines. A safety file that has to grow past the
400-line gate to add a rule is a file that stops getting rules added.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

__all__ = ["ANY", "NEGATOR_RE", "PRESCRIPTION_RE", "OutputRule", "rx"]


def rx(*fragments: str) -> re.Pattern[str]:
    """One case-insensitive alternation over ``fragments``."""
    return re.compile("|".join(fragments), re.IGNORECASE)


# A negator "cancels" a forbidden action only inside its OWN clause and within a tight
# window: the negator must be within 30 characters AND have no `.,;:—–` between it and
# the action. A looser window is a guardrail bypass, not a nicety — "You should not
# rest — you can push through the chest pain" would otherwise suppress its own rule.
NEGATOR_RE = re.compile(
    r"\b(?:don'?t|do not|does not|doesn'?t|did not|didn'?t|never|not|no|avoids?|avoiding|"
    r"shouldn'?t|should not|must not|won'?t|cannot|can'?t|stop|refrain from|"
    r"rather than|instead of|without)\b[^.;:,—–]{0,30}$",
    re.IGNORECASE,
)

ANY = re.compile(r"")  # a rule whose action phrase is specific enough on its own

# Prescription shape: a modal/suggestion aimed at the user, OR a sentence-initial
# imperative. Required by rules whose forbidden move is PRESCRIBING something the corpus
# also DESCRIBES at length — "the popular rule says stop eating three hours before bed"
# is a sentence this product must be able to write, and blocking it would be the
# over-broad filter that eats honest science. `^` anchors to the sentence, since
# sentences are split before any rule is asked.
#
# Deliberately NOT the same object as ``output_guard._ADVICE_RE``, which is narrower and
# is the live subject of the shipped sleep-restriction rule: widening a rule that is
# already in force is a behaviour change, and it does not get to happen as a side effect
# of adding different rules.
PRESCRIPTION_RE = rx(
    r"\byou (?:could|can|should|might|may|would|need to|ought to|want to)\b",
    r"\bI'?d (?:suggest|recommend|advise)\b",
    r"\b(?:try|consider|aim to|aim for|feel free|go ahead|make sure|be sure|stick to|"
    r"it'?s (?:fine|ok|okay|worth))\b",
    r"\blet'?s\b",
    # Sentence-initial imperative, including the PROHIBITIVE one: "Don't eat after 9pm"
    # is an eating restriction, not the absence of one. A subject list that omitted the
    # negative imperative would have let every rule be bypassed by phrasing it as a ban.
    r"^\s*(?:cut|trim|shave|reduce|shorten|sacrifice|skimp|restrict|skip|trade|stop|"
    r"finish|avoid|limit|drink|sip|hydrate|keep|start|don'?t|do not|never)\b",
)


@dataclass(frozen=True)
class OutputRule:
    """One hard output rule: what it's about, the forbidden move, and its origin.

    A sentence fires the rule when it matches ``subject`` AND contains an *un-negated*
    ``action``. ``source`` is not documentation — it is the admission criterion: a rule
    whose forbidden-ness cannot be pointed at in a doc or a note does not belong here.
    """

    name: str
    source: str
    action: re.Pattern[str]
    response: str
    subject: re.Pattern[str] = ANY

    def fires(self, sentence: str) -> bool:
        """True when ``sentence`` is about ``subject`` and makes the forbidden move."""
        if not self.subject.search(sentence):
            return False
        return any(
            not NEGATOR_RE.search(sentence[: m.start()]) for m in self.action.finditer(sentence)
        )
