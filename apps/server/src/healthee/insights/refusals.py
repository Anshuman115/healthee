"""Deterministic safety pre-classifier — the first stage of the choke point.

Five refusal domains (A–E), ported verbatim from legacy ``llm/prompts.py`` (the
exact templates KEEP so the app and validator recognise them). A query that hits a
domain is refused *before* the LLM is ever called — the model cannot be prompted,
jailbroken, or cajoled past a hard guardrail because it never runs (INTELLIGENCE
§3 step 1, §5.5). This is a code guardrail, not an instruction the LLM could
override.

Matching is intentionally broad (recall over precision): for safety-critical
categories a false refusal is acceptable, a false pass is not.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

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
    """One refusal domain: a name, its trigger regex, and its exact template."""

    name: str
    pattern: re.Pattern[str]
    template: str


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
            r"stroke",
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
        if domain.pattern.search(question):
            return domain
    return None
