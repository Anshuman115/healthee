"""Deterministic safety pre-classifier — the first stage of the choke point.

Five refusal domains (A–E), ported verbatim from legacy ``llm/prompts.py`` (the
exact templates KEEP so the app and validator recognise them), plus a sixth added by
#106. A query that hits a domain is refused *before* the LLM is ever called — the model
cannot be prompted, jailbroken, or cajoled past a hard guardrail because it never runs
(INTELLIGENCE §3 step 1, §5.5). This is a code guardrail, not an instruction the LLM
could override.

Matching is intentionally broad (recall over precision): for safety-critical
categories a false refusal is acceptable, a false pass is not.

The sixth domain, ``exertional_emergency``, is the one that could not be written as a
bare pattern. Driving prod on 2026-08-01 asked *"During my long run yesterday I got
confused and started vomiting, then collapsed. Was that just dehydration? Should I run
again tomorrow?"* — textbook exertional heat stroke — and got ``refused=False`` twice.
The red-flag vocabulary existed in the codebase all along, but only in
``guard_directives``' environmental_stress D12, which reads the MODEL'S OUTPUT: it stops
the coach *saying* something dangerous and cannot fire when the owner *reports* the
emergency and the reply happens to be innocuous. ``red_flags`` now owns those words for
both sides, and this domain asks them of the question.

Its ``confirm`` conjunct exists because that screen cannot be a pattern. "I collapsed
during my run yesterday" and "what are the signs of heat stroke?" share their words and
differ in grammar, and an emergency screen that fires on the second trains people to
ignore the first.

## Why "heat stroke" was NOT handed over to that screen (#110)

The obvious follow-up to #106 is to strip heat/sun stroke out of ``emergency`` — the new
screen reads them better, so let the better mechanism own them. **Measured, it opens a
hole.** ``exertional_emergency`` requires OWNER attribution, deliberately, and these do
not have it:

  * *"my friend collapsed with heat stroke, what do I do?"* — a third party's emergency,
    and the person typing is the one who can act on it;
  * *"I think I'm having heat stroke right now"* — first person, but the gerund puts the
    sign outside ``red_flags``' owner-experience window, so the screen reads it as a topic;
  * *"I got sun stroke yesterday"* — ``EXERTIONAL_RED_FLAG_RE`` has no sun-stroke
    alternative at all, so it falls out of both mechanisms.

All three refuse today and would stop refusing. So heat and sun stroke **stay here**,
where a pattern with no attribution test catches them regardless of who they happened to.
The cost is that *"what are the signs of heat stroke?"* keeps being refused — a known,
stated over-refusal, which is the side of the trade this file's doctrine picks and the
cheap error of the two. The two mechanisms overlap on owner-reported heat stroke;
``emergency`` is checked first, so such a question is named ``emergency``, not
``exertional_emergency``. Widening ``owner_reports_emergency`` to third parties is not a
side effect this change gets to have — it is a behaviour change to a live screen and
belongs to its own diff.
"""

from __future__ import annotations

import re
from collections.abc import Callable
from dataclasses import dataclass

from healthee.insights import red_flags

# ── Exact refusal templates (verbatim from legacy prompts.py §A–E) ──────────
EMERGENCY = (
    "These symptoms can require urgent medical evaluation. Please contact emergency "
    "services or your physician immediately. I am not a clinical service and cannot "
    "evaluate or guide care for symptoms."
)
DIAGNOSIS = (
    "Diagnosis isn't something I can do. Please discuss this with your physician — they "
    "can examine you and run appropriate tests. I can describe your measured data, but a "
    "wearable reading is not a diagnosis."
)
MEDICATION = (
    "Medication and treatment decisions belong with your physician or pharmacist. I won't "
    "suggest doses, stops, starts, or interactions."
)
PREGNANCY_PEDIATRIC = (
    "This is outside what I'm built for. Please speak with an obstetrician / pediatrician — "
    "they can give context-specific guidance I cannot."
)
MENTAL_HEALTH = (
    "This is important and deserves a qualified clinician. Please contact a mental health "
    "professional or your primary physician. I'm not equipped to support this safely."
)

# The set the validator uses to recognise a refusal and skip citation checks.
REFUSAL_TEMPLATES: frozenset[str] = frozenset(
    {EMERGENCY, DIAGNOSIS, MEDICATION, PREGNANCY_PEDIATRIC, MENTAL_HEALTH}
)


@dataclass(frozen=True)
class Domain:
    """One refusal domain: a name, its trigger regex, its exact template.

    ``confirm`` is an optional SECOND conjunct for a domain whose boundary a pattern
    cannot draw on its own. It never widens a domain — the pattern still has to hit
    first — it only lets one narrow itself on structure the regex cannot see. Exactly one
    domain uses it, and the alternative was a heuristic pattern that fired on every
    question mentioning heat stroke.
    """

    name: str
    pattern: re.Pattern[str]
    template: str
    confirm: Callable[[str], bool] | None = None

    def hits(self, question: str) -> bool:
        """True when ``question`` belongs to this domain and must never reach the model."""
        if not self.pattern.search(question):
            return False
        return self.confirm is None or self.confirm(question)


def _rx(*fragments: str) -> re.Pattern[str]:
    return re.compile("|".join(fragments), re.IGNORECASE)


# Order matters: emergency is checked first so a crisis phrase always wins.
DOMAINS: tuple[Domain, ...] = (
    Domain(
        "emergency",
        _rx(
            r"chest pain",
            r"chest (pressure|tightness)",
            r"can'?t breathe",
            r"(severe|sudden).{0,20}(shortness of breath|short of breath)",
            r"face drooping",
            r"arm weakness",
            r"slurred speech",
            # Cerebrovascular stroke. The legacy port carried this bare and unanchored,
            # so it also refused every METRIC sense of the word: "stroke rate" (rowing,
            # swimming), "stroke volume" and "stroke index" (the cardiac terms four of
            # our own notes teach), "strokes per minute" — and, unanchored, the inside
            # of "breaststroke" and "backstroke". Only those senses are excluded, and
            # only where the qualifier FOLLOWS, because no presentation of a stroke puts
            # one of these words next to it (#110).
            # Left refused on purpose: the BARE noun, as in "how do I improve my swim
            # stroke?". Separating it from "is this a stroke?" needs grammar, not a
            # pattern — and half-closing the class by naming "swim" would be arbitrary.
            r"\bstrokes?\b(?!\s*(?:rate|volume|count|length|index|per\b))",
            # The closed compounds, and ONLY those: "sunstroke", "heatstroke". They need
            # their own alternative because they carry no internal word boundary for the
            # line above to anchor on. "heat stroke" and "heat-stroke" are already caught
            # there (a space and a hyphen are both boundaries) and each has its own test,
            # so writing them here too would add a branch no mutation could kill.
            r"\b(?:sun|heat)stroke\b",
            r"faint(ing|ed)?",
            r"pass(ed|ing) out",
            r"loss of consciousness",
            r"cough(ing)? (up )?blood",
            r"severe bleeding",
            r"anaphylaxis",
            r"suicid",
            r"kill myself",
            r"self.?harm",
            r"overdose",
            r"severe (abdominal|head) (pain|injury)",
            r"sudden.{0,15}headache",
            r"sudden vision loss",
            r"sepsis",
        ),
        EMERGENCY,
    ),
    # Second, not first, so that nothing already classified changes name: the legacy
    # emergency phrases keep winning where both could hit, and both ship EMERGENCY
    # anyway. What this adds is the set that domain never knew — collapse, confusion,
    # vomiting, seizure, ataxia, heat stroke — the presentation of the three exertional
    # emergencies that actually kill runners (environmental_stress D12/D13,
    # fueling_and_hydration D12).
    Domain(
        "exertional_emergency",
        red_flags.EXERTIONAL_RED_FLAG_RE,
        EMERGENCY,
        confirm=red_flags.owner_reports_emergency,
    ),
    Domain(
        "diagnosis",
        _rx(
            r"do i have",
            r"is this (a )?(disease|cancer|diabetes|apnea|infection|depression)",
            r"could (this|it) be",
            r"am i (having|getting)",
            # Requests to be diagnosed — NOT the bare word: our own surface prompts
            # say "No diagnosis", which must never self-trigger the classifier.
            r"\bdiagnose\b",
            r"(my|a|the|your) diagnosis",
            r"diagnosis of",
            r"what('?s| is) wrong with me",
            r"interpret (my|these) (labs?|results?|blood)",
        ),
        DIAGNOSIS,
    ),
    Domain(
        "medication",
        _rx(
            r"(should|can) i (take|stop|start|increase|lower|reduce)\b.{0,30}\b"
            r"(med|medication|dose|pill|drug|supplement|statin|insulin|antidepressant)",
            r"\bdosage\b",
            r"\bdose of\b",
            r"drug interaction",
            r"stop (taking|my) (med|medication)",
            r"change (my )?medication",
        ),
        MEDICATION,
    ),
    Domain(
        "pregnancy_pediatric",
        _rx(
            r"pregnan",
            r"\bfertility\b",
            r"trying to conceive",
            r"breastfeed",
            r"lactat",
            r"\bmy (baby|infant|toddler|child|kid)\b",
            r"pediatric",
        ),
        PREGNANCY_PEDIATRIC,
    ),
    Domain(
        "mental_health",
        _rx(
            r"\b(depress(ed|ion)|anxious|anxiety|panic attack)\b",
            r"eating disorder",
            r"anorexi",
            r"bulimi",
            r"substance (abuse|dependence)",
            r"(alcohol|drug) (addiction|dependence)",
            r"feel(ing)? hopeless",
            r"can'?t cope",
        ),
        MENTAL_HEALTH,
    ),
)


def classify_refusal(question: str) -> Domain | None:
    """Return the first refusal domain the question hits, or None if it's answerable.

    Deterministic and case-insensitive. Checked before any context build or LLM
    call so a hit short-circuits the entire pipeline.
    """
    for domain in DOMAINS:
        if domain.hits(question):
            return domain
    return None
