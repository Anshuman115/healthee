"""Hard output guardrails — the deterministic floor UNDERNEATH the validator.

``refusals.py`` classifies the QUESTION before the LLM runs. This module guards the
ANSWER after it runs. Both are needed and neither replaces the other: a benign
question ("how's my fitness trending?") can still produce a forbidden answer ("your
VO2max puts you at a 22% higher risk of dying"), and that answer can be perfectly
cited, grade-calibrated and validator-clean — an external review proved exactly that
by execution. So these rules fire **regardless of citations, grade, refusal status or
validation outcome**. They are not validator rules; the validator asks "is this
claim grounded?", the guard asks "is this output allowed to exist at all?".

On a hit the answer does not ship — the caller returns the rule's ``response`` and
the fire is logged at ERROR. A guardrail firing means a model tried to emit something
the product documents as forbidden; that is a signal a human should see, never a
silent swallow.

## Where the rules come from (the whole discipline)

Every rule carries the doc/note line that forbids it in its ``source`` field. Nothing
here is invented: an over-broad safety filter that eats honest cited science is its
own harm, and this corpus is full of mortality-related notes whose *population*
claims must keep flowing. A rule with no documented origin does not ship.

Today the table is ``_DOCUMENTED_RULES`` below, hand-compiled from what the product
already documents. INTELLIGENCE §2 specifies that safety-critical *note* directives
compile into this same table — but no note carries a ``safety_critical`` flag yet and
the manifest emits no directives at all, so that source would compile to nothing.
``output_rules()`` is the seam it plugs into when the corpus is marked up; the
enforcement layer here does not change when it is.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from healthee.core.logging import get_logger
from healthee.insights import prompts
from healthee.insights.answer_text import sentences
from healthee.insights.refusals import EMERGENCY

log = get_logger(__name__)

__all__ = ["OutputRule", "check_output", "output_rules"]


def _rx(*fragments: str) -> re.Pattern[str]:
    return re.compile("|".join(fragments), re.IGNORECASE)


# What ships when an answer trips a non-emergency guardrail. Deliberately says that a
# rule fired rather than pretending the model simply had nothing to say — this product's
# one promise is that it does not lie, and that applies to its own failures too.
GUARDRAIL_BLOCK = (
    "I'm not going to show you what I just wrote — it crossed one of my hard safety "
    "rules. I don't put personal risk numbers on your data, and anything involving "
    "pain, injury, or not feeling well belongs with a clinician rather than a wearable. "
    f"{prompts.FALLBACK}"
)

# ── Shared fragments ─────────────────────────────────────────────────────────
# A negator "cancels" a forbidden action only inside its OWN clause and within a tight
# window: the negator must be within 30 characters AND have no `.,;:—–` between it and
# the action. A looser window is a guardrail bypass, not a nicety — "You should not
# rest — you can push through the chest pain" would otherwise suppress its own rule.
_NEGATOR_RE = re.compile(
    r"\b(?:don'?t|do not|does not|doesn'?t|did not|didn'?t|never|not|no|avoids?|avoiding|"
    r"shouldn'?t|should not|must not|won'?t|cannot|can'?t|stop|refrain from|"
    r"rather than|instead of|without)\b[^.;:,—–]{0,30}$",
    re.IGNORECASE,
)

_ANY = re.compile(r"")  # a rule whose action phrase is specific enough on its own

# Second person — the marker that turns population research into a personal projection.
_PERSONAL_RE = _rx(r"\byou\b", r"\byou'?re\b", r"\byou'?ll\b", r"\byou'?ve\b", r"\byour\b")

# Advice shape: a modal/suggestion aimed at the user, OR a sentence-initial imperative.
# Required by the sleep rule so that DESCRIBING sleep restriction's cost (which the
# corpus does at length — sleep_need_debt, sleep-and-recovery) never trips a rule aimed
# at PRESCRIBING it. `^` anchors to the sentence, since sentences are split beforehand.
_ADVICE_RE = _rx(
    r"\byou (?:could|can|should|might|may|would)\b",
    r"\bI'?d (?:suggest|recommend)\b",
    r"\b(?:try|consider|aim to|feel free|go ahead|it'?s (?:fine|ok|okay|worth))\b",
    r"\blet'?s\b",
    r"^\s*(?:cut|trim|shave|reduce|shorten|sacrifice|skimp|restrict|skip|trade)\b",
)

# ── Rule 1+2 · never show a personal death-risk number or life projection ────
# The corpus says this in at least eight places, e.g.:
#   KNOWLEDGE_RECONCILIATION.md:46 / TEMPLATE.md:79 — "never show a death-risk number"
#   sports-science/metrics/resting-heart-rate.md:104 — "an n = 1 mortality/risk
#     projection from a single person's RHR ... must never be shown"
# The subject gate (`_PERSONAL_RE`) is what keeps honest POPULATION science shippable:
# "cohorts show a 20% lower risk of death above 7,000 steps [steps_mortality]" carries
# no second person and does not fire. Attaching that same number to "you" is precisely
# the laundering steps_mortality.md:132 and resting-heart-rate.md:143 forbid.
_QTY = r"\d+(?:[.,]\d+)?\s*(?:%|percent|x|×|-?fold|times)"
_DEATH = (
    r"(?:(?:risk|chance|probability|odds|likelihood|hazard)\s+of\s+"
    r"(?:dying|death|premature\s+death|all-cause\s+mortality)"
    r"|(?:mortality|death)\s+risk"
    r"|risk\s+of\s+all-cause\s+mortality)"
)
_DEATH_RISK_NUMBER_RE = re.compile(
    rf"(?:{_QTY}[^.]{{0,40}}{_DEATH}|{_DEATH}[^.]{{0,40}}{_QTY})", re.IGNORECASE
)
_LIFE_PROJECTION_RE = _rx(
    r"\byour life expectancy\b",
    r"\b(?:shortens?|shortening|cuts?|cutting|takes?|knocks?)\s+[^.]{0,20}\byour life\b",
    r"\byears?\s+off\s+your\s+life\b",
    r"\badds?\s+[^.]{0,20}\byears?\s+to\s+your\s+life\b",
    r"\byou(?:'ll| will)\s+(?:probably\s+|likely\s+)?die\b",
    r"\byou(?:'re| are)\s+(?:likely\s+)?to\s+die\b",
    r"\byou\s+ha(?:ve|d)\s+[^.]{0,20}\byears?\s+to\s+live\b",
    r"\bdie\s+\d+\s+years?\s+(?:earlier|sooner|younger)\b",
)

# ── Rule 3 · never advise through a red-flag symptom ─────────────────────────
# INTELLIGENCE.md:49-50 — "never advise through chest pain" (named as a hard guardrail).
# The symptom set is the one COACHING-RULES.md rule 4 (injury/pain pause: "never advise
# running through it") and rule 7 (symptomatic bradycardia: "dizziness, syncope, chest
# discomfort, exertional intolerance, irregular beats") already enumerate.
_RED_FLAG_SYMPTOM_RE = _rx(
    r"chest\s+(?:pain|pressure|tightness|discomfort)",
    r"short(?:ness)?\s+of\s+breath",
    r"can'?t\s+breathe",
    r"\bfaint(?:ing|ed)?\b",
    r"\bsyncope\b",
    r"pass(?:ed|ing)\s+out",
    r"black(?:ed|ing)\s+out",
    r"cough(?:ing)?\s+up\s+blood",
    r"\bpalpitations\b",
    r"irregular\s+(?:heart)?beats?",
    r"\bdizz(?:y|iness)\b",
)
_TRAIN_THROUGH_RE = _rx(
    r"\b(?:push|pushing|train|training|run|running|work|working|power|powering|"
    r"exercise|exercising)\s+through\b",
    r"\bkeep\s+(?:on\s+)?(?:training|running|going|pushing|exercising|moving)\b",
    r"\b(?:fine|ok|okay|safe|reasonable)\s+to\s+(?:train|run|push|exercise|continue)\b",
    r"\btrain\s+around\s+(?:it|this|the)\b",
    r"\b(?:no need|nothing)\s+to\s+(?:worry|stop|rest|see)\b",
    r"\byou\s+can\s+still\s+(?:train|run|push|exercise)\b",
)

# ── Rule 4 · never advise sleep restriction ──────────────────────────────────
# INTELLIGENCE.md:50 — "never advise sleep restriction" (named as a hard guardrail);
# COACHING-RULES.md:103 rule 16 — "Never require sleep restriction. Do not prescribe,
# endorse, or design plans that require habitual sleep restriction to fit training in";
# sports-science/metrics/sleep-and-recovery.md:233 — "must never prescribe or encourage
# sleep restriction to 'fit in' training".
# The `sleep(?!...)` lookahead is load-bearing: "reduce your sleep DEBT" and "cut sleep
# LATENCY" are honest, desirable advice and must not trip a rule about cutting sleep.
_SLEEP_NOT_A_TARGET = (
    r"(?!\s*(?:debt|latency|deprivation|disrupt|fragment|inertia|loss|apnoea|apnea|"
    r"onset|issues?|problems?|quality|efficiency|need|regularity|variability))"
)
_SLEEP_RESTRICTION_RE = _rx(
    r"\b(?:cut|cutting|trim|trimming|shave|shaving|reduce|reducing|shorten|shortening|"
    r"sacrifice|sacrificing|skimp\s+on|restrict|restricting|skip|skipping)\s+"
    rf"(?:back\s+on\s+|down\s+on\s+)?(?:your\s+|some\s+|an?\s+hour\s+of\s+)?sleep\b"
    rf"{_SLEEP_NOT_A_TARGET}",
    r"\b(?:prescrib|recommend|endors|advis|suggest)\w*\s+(?:habitual\s+)?sleep\s+restriction\b",
    r"\bsleep\s+(?:just\s+|only\s+)?\d+(?:\.\d+)?\s*(?:h|hr|hrs|hours?)\s+"
    r"(?:so|to|and)\s+(?:you\s+can\s+)?(?:train|fit|run|work)",
    r"\b(?:wake|get)\s+up\s+[^.]{0,20}earlier\s+to\s+(?:train|run|work\s?out|fit|hit)",
    r"\btrade\s+(?:your\s+|some\s+)?sleep\b",
)

# ── Rule 5 · bone-stress / REDs is a hard stop, not "train around it" ────────
# INTELLIGENCE.md:49 — "bone-stress / REDs hard stop" (named as a hard guardrail).
# COACHING-RULES.md rule 4 — on suspected bone-stress injury "stop running and refer —
# never advise running through it"; rule 11 (low energy availability / REDs) — "do not
# increase load and refer ... never advise further restriction, and never normalise
# weight loss/low EA as a performance strategy"; injury-prevention.md:371 concurs.
_BONE_STRESS_REDS_RE = _rx(
    r"bone[-\s]stress",
    r"stress\s+fracture",
    r"bony\s+tenderness",
    r"\bRED-?S\b",
    r"\bREDs\b",
    r"low\s+energy\s+availability",
    r"relative\s+energy\s+deficiency",
)
_LOAD_OR_RESTRICT_RE = _rx(
    _TRAIN_THROUGH_RE.pattern,
    r"\bincreas(?:e|ing)\s+(?:your\s+)?(?:load|volume|mileage|training|intensity)\b",
    r"\b(?:build|ramp|step)\s+up\s+(?:your\s+)?(?:load|volume|mileage|training)\b",
    r"\b(?:cut|cutting|reduce|reducing|lower|lowering|restrict|restricting|drop|dropping)"
    r"\s+(?:your\s+)?(?:calories|intake|food|energy\s+intake|carbs|portions)\b",
    r"\b(?:eat|fuel)\s+less\b",
    r"\blose\s+(?:more\s+)?(?:weight|body\s?fat)\b",
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
    subject: re.Pattern[str] = _ANY

    def fires(self, sentence: str) -> bool:
        """True when ``sentence`` is about ``subject`` and makes the forbidden move."""
        if not self.subject.search(sentence):
            return False
        return any(
            not _NEGATOR_RE.search(sentence[: m.start()]) for m in self.action.finditer(sentence)
        )


_DOCUMENTED_RULES: tuple[OutputRule, ...] = (
    OutputRule(
        name="personal_death_risk_number",
        source=(
            "KNOWLEDGE_RECONCILIATION.md:46 + TEMPLATE.md:79 'never show a death-risk "
            "number'; steps_mortality.md:115; sleep_duration_mortality.md:91; "
            "resting-heart-rate.md:143 (D13); vo2max.md:507"
        ),
        subject=_PERSONAL_RE,
        action=_DEATH_RISK_NUMBER_RE,
        response=GUARDRAIL_BLOCK,
    ),
    OutputRule(
        name="personal_life_expectancy_projection",
        source=(
            "resting-heart-rate.md:104 'an n = 1 mortality/risk projection ... must never "
            "be shown'; non_exercise_vo2max.md:180 'do not launder the estimate into a "
            "death-risk number'; vo2max.md:39"
        ),
        subject=_PERSONAL_RE,
        action=_LIFE_PROJECTION_RE,
        response=GUARDRAIL_BLOCK,
    ),
    OutputRule(
        name="advise_through_red_flag_symptom",
        source=(
            "INTELLIGENCE.md:49-50 'never advise through chest pain'; "
            "COACHING-RULES.md rule 4 'never advise running through it'; rule 7"
        ),
        subject=_RED_FLAG_SYMPTOM_RE,
        action=_TRAIN_THROUGH_RE,
        response=EMERGENCY,  # refer out — the documented response to a red flag
    ),
    OutputRule(
        name="advise_sleep_restriction",
        source=(
            "INTELLIGENCE.md:50 'never advise sleep restriction'; COACHING-RULES.md:103 "
            "rule 16; sleep-and-recovery.md:233"
        ),
        subject=_ADVICE_RE,
        action=_SLEEP_RESTRICTION_RE,
        response=GUARDRAIL_BLOCK,
    ),
    OutputRule(
        name="advise_through_bone_stress_or_reds",
        source=(
            "INTELLIGENCE.md:49 'bone-stress / REDs hard stop'; COACHING-RULES.md rules "
            "4, 5 and 11; injury-prevention.md:371"
        ),
        subject=_BONE_STRESS_REDS_RE,
        action=_LOAD_OR_RESTRICT_RE,
        response=GUARDRAIL_BLOCK,
    ),
)


def output_rules() -> tuple[OutputRule, ...]:
    """The hard output rules in force — THE seam a corpus-driven table plugs into.

    Today this is exactly ``_DOCUMENTED_RULES``. INTELLIGENCE §2 specifies that notes'
    ``safety_critical`` directives compile into this same table; when the corpus is
    marked up and the manifest emits directives, the compiled rules are concatenated
    here and every call site below inherits them with no other change. That work is
    deliberately not done here: marking 41 notes is research judgement, and a table
    compiled from an unmarked corpus would be empty — which is what it would be today.
    """
    return _DOCUMENTED_RULES


def check_output(text: str) -> OutputRule | None:
    """The first hard rule ``text`` breaks, or None when it is allowed to ship.

    Deterministic and independent of every other stage: it does not look at citations,
    grades, or whether the validator was happy. A *cited* mortality projection is still
    a mortality projection. Sentence-scoped (via ``answer_text.sentences``, so markdown
    tables/headings are seen into exactly as the validator sees them) because both the
    subject/action co-occurrence and the negation window are only meaningful inside one
    sentence. On the JSON path this runs over the raw JSON text, which is strictly
    broader than the rec fields the validator segments out — a forbidden claim in a
    ``rationale`` is caught either way.
    """
    for sentence in sentences(text):
        for rule in output_rules():
            if rule.fires(sentence):
                log.error(
                    "OUTPUT GUARDRAIL fired: rule=%s — answer blocked, not shipped. "
                    "source=%s sentence=%r",
                    rule.name,
                    rule.source,
                    sentence[:120],
                )
                return rule
    return None
