"""Hard output rules COMPILED from notes that declare a directive ``safety_critical``.

## What this module makes true (#87)

Roughly two dozen notes asserted some form of *"mirrored as a hard guardrail; the AI
may not override this"*. It was false twice over: ``output_guard.py`` was hand-compiled
and read nothing from the corpus, and no note carried a marker anything could key off.
A false safety claim inside the safety system is the worst kind — an auditor reads it,
believes the enforcement exists, and stops looking.

The fix is a two-ended contract, not a rewording:

  * the **corpus owns the claim** — a note names the directive numbers it asserts as
    hard in frontmatter (``safety_critical: [5, 6]``), and ``gen_manifest.py`` refuses
    to publish a marker that points at a directive which does not exist or does not say
    ``SAFETY-CRITICAL`` in its own text;
  * the **code owns the pattern** — one ``OutputRule`` per marked directive, below;
  * a **test owns the correspondence** — ``tests/insights/test_guard_directives.py``
    asserts a bijection between :data:`_COMPILED` and every ``safety_critical`` marker
    the manifest publishes. A note that claims a guardrail nobody wrote fails the build;
    a rule whose origin directive was edited away fails the build too.

The regex stays in Python on purpose. A research note is prose maintained by people
editing science; a safety pattern silently broken by a prose edit is precisely the
failure mode this exists to end. And a pattern is reviewable, testable and mutable in a
way a YAML string in a note is not.

## What a compiled rule does and does not promise

It promises that **the answer does not ship** when a sentence matches. It does not
promise to detect every possible phrasing of a violation — no regex does. These are a
deterministic FLOOR under the model, exactly like the hand-compiled table: the note's
prose, the system prompt and the validator all still carry the directive. Each rule
below states which clause of its directive it deterministically catches, so nobody
reads more into it than is there.

The opposite failure is equally real and is why the subject/action split exists at all:
an over-broad safety filter that eats honest cited science is its own harm. Every rule
here is gated on a SUBJECT so that describing a topic never trips a rule aimed at
prescribing on it.
"""

from __future__ import annotations

from healthee.insights import prompts
from healthee.insights.guard_rules import PRESCRIPTION_RE, OutputRule, rx
from healthee.insights.red_flags import EXERTION_OR_HEAT_RE, EXERTIONAL_RED_FLAG_RE

__all__ = ["compiled_rules", "origins"]

# ── Responses ────────────────────────────────────────────────────────────────
# A blocked answer says a rule fired rather than pretending the model had nothing to
# say. This product's one promise is that it does not lie, and that applies to its own
# failures too.
_CLINICIAN = (
    "I'm stopping myself here. What you've described is the kind of thing a clinician "
    "should look at rather than a wearable — a new, worsening or uncontrollable need to "
    "sleep during the day can have causes I have no way to see, and reassurance from me "
    "would be worth nothing. Please raise it with a doctor."
)
_FLUID_BLOCK = (
    "I'm not going to answer that with a fluid target. Drinking to a schedule or a "
    "volume during exercise or heat is how exercise-associated hyponatraemia happens, "
    "and it kills people; the same goes for any fluid advice around kidney, heart or "
    f"liver conditions, diuretics or a prescribed fluid restriction. {prompts.FALLBACK}"
)
_EATING_BLOCK = (
    "I'm not going to give you an eating cutoff, an eating window or a fasting "
    "schedule. The evidence on eating late and sleep is genuinely split, we hold no "
    "dietary data about you at all, and restriction advice from a health app is a known "
    f"harm pathway. {prompts.FALLBACK}"
)
_EXERTIONAL_EMERGENCY = (
    "I'm stopping myself here, and I'm not going to soften it. Confusion, collapse, "
    "vomiting, a seizure, staggering or altered behaviour around a hard or hot effort "
    "are how exertional heat stroke, exercise-associated hyponatraemia and altitude "
    "illness present, and all three can kill within hours. This needs urgent medical "
    "care now — and active cooling on the way if it is heat. It does not need anything "
    "from me about training, fluids or food."
)

# ── napping D5 · a new/worsening/uncontrollable need to nap belongs to a clinician ──
# Catches DETERMINISTICALLY: reassurance ("that's completely normal"), benign-cause
# attribution ("that's just sleep debt"), and the nap-length fix the directive names.
# The subject is what keeps the rest of the note shippable — the coach answers "how long
# should I nap?" with the 10-20 minute dose curve all day long, and none of that carries
# the new/worsening/unintentional marker this rule is gated on.
_HYPERSOMNOLENCE_RE = rx(
    r"\b(?:new|newly|worsening|worse|increasing|growing|sudden(?:ly)?|uncontrollable|"
    r"irresistible|overwhelming|unstoppable)\b[^.]{0,45}\b(?:need|urge|desire|craving)\s+"
    r"(?:to\s+)?(?:nap|sleep|lie\s+down)",
    r"\b(?:need|urge|desire)\s+to\s+(?:nap|sleep)\b[^.]{0,35}\b(?:new|newly|worsening|"
    r"uncontrollable|irresistible|overwhelming|out\s+of\s+nowhere)\b",
    r"\bfall(?:ing|s)?\s+asleep\s+(?:unintentionally|unexpectedly|without\s+"
    r"(?:meaning|warning|intending)|at\s+(?:the\s+wheel|my\s+desk|work)|while\s+driving|"
    r"mid-\w+|in\s+meetings)",
    r"\bnodd(?:ing|ed)\s+off\b",
    r"\bcan'?t\s+stay\s+awake\b",
    r"\bexcessive\s+daytime\s+sleepiness\b",
)
_NAP_REASSURE_RE = rx(
    r"\b(?:that'?s|this\s+is|it'?s|is|are)\s+(?:completely\s+|totally\s+|perfectly\s+|"
    r"quite\s+|pretty\s+|entirely\s+|all\s+)?(?:normal|fine|common|typical|expected|"
    r"harmless|nothing\s+unusual)\b",
    r"\bnothing\s+to\s+worry\s+about\b",
    r"\bwouldn'?t\s+worry\b",
    r"\b(?:just|simply|merely|only)\s+(?:your\s+)?(?:sleep\s+debt|tiredness|being\s+"
    r"tired|a\s+late\s+night|short\s+sleep|catching\s+up)\b",
    r"\b(?:keep|limit|cap|stick\s+to)\s+(?:your\s+|the\s+)?naps?\s+(?:to|at|under)\b",
    r"\b(?:try|take|have)\s+(?:a\s+)?\d+(?:\s*[-–]\s*\d+)?\s*(?:min\w*|m)\s+nap\b",
    r"\b(?:a\s+)?\d+(?:\s*[-–]\s*\d+)?\s*(?:minute|min)\s+nap\s+(?:should|will|would)\b",
)

# ── hydration_everyday D5 · never a volume/schedule fluid target for exercise or heat ──
# Catches DETERMINISTICALLY: any per-time or per-distance drinking rate, and any explicit
# volume instruction, inside an exercise/heat sentence. Excess fluid intake can be fatal;
# `fueling_and_hydration` owns the exercise-associated-hyponatraemia guardrail and even
# it prescribes by thirst, not by schedule.
# The subject is `red_flags.EXERTION_OR_HEAT_RE` — the same exercise-or-heat vocabulary
# D12 is scoped to and that `refusals.py`'s pre-LLM screen now reads (#106). One copy.
_FLUID_TARGET_RE = rx(
    r"\b\d+(?:[.,]\d+)?\s*(?:ml|millilit(?:re|er)s?|l\b|lit(?:re|er)s?|oz|ounces?|cups?|"
    r"glasses|bottles?)\b[^.]{0,45}\b(?:per|every|each|an?)\s*\d*\s*"
    r"(?:hour|hr|min\w*|km|mile|kilomet\w+)",
    r"\b(?:drink|sip|take\s+in|consume|aim\s+for|target|have)\b[^.]{0,35}\b"
    r"\d+(?:[.,]\d+)?\s*(?:ml|millilit(?:re|er)s?|l\b|lit(?:re|er)s?|oz|ounces?|cups?|"
    r"glasses|bottles?)\b",
    r"\b(?:drink|sip|hydrate)\s+(?:every|each)\s+\d+\s*(?:min\w*|km|miles?|hours?)\b",
    r"\b(?:every|each)\s+\d+\s*(?:min\w*|km|miles?)\b[^.]{0,30}\b"
    r"(?:drink|sip|fluid|water|hydrat\w+)\b",
)

# ── hydration_everyday D6 · no fluid advice at all where a fluid-sensitive condition
#    or a fluid restriction is mentioned ──────────────────────────────────────
# Catches DETERMINISTICALLY: any prescription-shaped fluid instruction in a sentence that
# mentions kidney/heart/liver disease, a diuretic, or a prescribed restriction. In those
# people "drink more water" is not neutral advice, and the directive is absolute: no
# fluid advice, route to their clinician.
_FLUID_SENSITIVE_CONDITION_RE = rx(
    r"\bkidney\b",
    r"\brenal\b",
    r"\bdialysis\b",
    r"\bnephro\w+\b",
    r"\bheart\s+failure\b",
    r"\bCHF\b",
    r"\bliver\b",
    r"\bcirrhosis\b",
    r"\bhepatic\b",
    r"\bascites\b",
    r"\bdiuretics?\b",
    r"\bfurosemide\b|\bfrusemide\b|\bspironolactone\b|\bhydrochlorothiazide\b",
    r"\bwater\s+pills?\b",
    r"\bfluid[\s-]restrict\w+\b",
    r"\brestricted\s+fluids?\b",
    r"\bSIADH\b|\bhyponatr\w+\b",
)
_FLUID_ADVICE_RE = rx(
    r"\b(?:you\s+(?:should|could|can|might|may|need\s+to|ought\s+to)|I'?d\s+"
    r"(?:suggest|recommend|advise)|try\s+to|consider|aim\s+(?:for|to)|make\s+sure\s+to|"
    r"be\s+sure\s+to|it'?s\s+(?:fine|worth|a\s+good\s+idea))\b[^.]{0,45}\b"
    r"(?:drink|drinking|hydrat\w+|fluids?|water\s+intake|water\b)",
    r"^\s*(?:drink|sip|hydrate)\b",
    r"\b(?:drink|aim\s+for|have)\s+\d+(?:[.,]\d+)?\s*(?:ml|lit(?:re|er)s?|l\b|oz|cups?|"
    r"glasses)\b",
    r"\b(?:increase|up|boost|raise|cut\s+back\s+on|reduce|lower|limit)\s+(?:your\s+)?"
    r"(?:fluid|water)\s*(?:intake|consumption)?\b",
    r"\bstay\s+(?:well\s+)?hydrated\b",
    r"\bdrink\s+more\s+(?:water|fluids?)\b",
)

# ── late_eating_sleep D5 · never an eating restriction, window or fasting schedule ──
# Catches DETERMINISTICALLY: a prescribed eating cutoff, an eating/fasting window, and
# an explicit intake restriction. The subject gate is load-bearing here in a way it is
# nowhere else: this note's whole job is to DISCUSS the "stop eating three hours before
# bed" rule and say it is not settled, so the description must stay shippable and only
# the prescription may be blocked.
_EATING_RESTRICTION_RE = rx(
    r"\bstop\s+eating\s+(?:at\s+least\s+)?(?:\S+\s+){0,3}?(?:after|by|before|past|"
    r"no\s+later\s+than)\b",
    # The PROHIBITIVE phrasing has to match starting AT the negator, or the negation
    # window would cancel the rule with the very words that make it a restriction.
    r"\b(?:don'?t|do\s+not|never|avoid|no)\s+eat\w*\s+(?:after|within|past|later\s+than|"
    r"in\s+the\s+\d)",
    r"\b(?:finish|stop|have)\s+(?:your\s+)?(?:last\s+)?(?:meal|dinner|eating|food)\b"
    r"[^.]{0,35}\b(?:before|prior\s+to)\s+(?:bed|sleep|lights)",
    r"\b(?:eating|feeding|fasting)\s+window\b",
    r"\b\d{1,2}\s*[:/]\s*\d{1,2}\s+(?:fast\w*|protocol|schedule)\b",
    r"\b(?:cut[\s-]?off|cutoff)\s+(?:time\s+)?for\s+(?:eating|food|meals|dinner)\b",
    r"\b(?:restrict|limit|cap)\s+(?:your\s+)?(?:eating|food\s+intake|calories|"
    r"calorie\s+intake)\b",
    r"\b(?:skip|drop)\s+(?:breakfast|dinner|a\s+meal|meals)\b",
)


# ── environmental_stress D12 · exertional red flags go to urgent care, not to me ──
# Catches DETERMINISTICALLY: reassurance ("that's normal in the heat"), benign-cause
# attribution ("just dehydration"), continue-training advice, and the it-will-pass
# brush-off — the four ways an answer can absorb a medical emergency instead of routing
# it. It does NOT catch every phrasing of offering a fix instead of care; the note's
# prose, the prompt and the validator still carry the rest of the directive.
#
# Why this one and not the other ~25 safety-tagged sports-science directives: the two
# guards already in force demonstrably miss this symptom set. `output_guard`'s
# `advise_through_red_flag_symptom` knows chest pain, breathlessness, syncope,
# palpitations and dizziness; `refusals.py`'s emergency classifier knows "faint",
# "passed out", "loss of consciousness" and "sudden headache". Neither knows confusion,
# disorientation, collapse, vomiting, seizure, ataxia or heat stroke — which is the
# presentation of the three exertional emergencies that actually kill runners. The note
# itself reached this conclusion under *Safety bounds* and named D11–D13 as the
# candidates; this compiles the one of them whose forbidden move is a text pattern
# rather than a plan shape.
#
# The symptom vocabulary is `red_flags.EXERTIONAL_RED_FLAG_RE`, and it lives there rather
# than here because #106 gave it a second consumer: `refusals.py`'s pre-LLM screen asks
# the same words a different question — "is the OWNER reporting one?" — after prod showed
# that this rule cannot fire when the owner reports the emergency and the model's reply
# happens to be innocuous. Two copies of a safety vocabulary is the `evidence_grade`
# (#83) / `GRADE_RANK` (#88) defect class with a worse blast radius.
_EMERGENCY_DEFLECTION_RE = rx(
    # Reassurance.
    r"\b(?:that'?s|this\s+is|it'?s|is|are)\s+(?:completely\s+|totally\s+|perfectly\s+|"
    r"quite\s+|pretty\s+|entirely\s+|fairly\s+|all\s+)?(?:normal|fine|common|typical|"
    r"expected|harmless|nothing\s+unusual|to\s+be\s+expected)\b",
    r"\bnothing\s+to\s+worry\s+about\b",
    r"\bwouldn'?t\s+(?:worry|be\s+concerned)\b",
    r"\bno\s+cause\s+for\s+(?:concern|alarm)\b",
    # Benign-cause attribution — the directive's "stop training advice" clause fails
    # just as badly when the answer explains the emergency away as when it coaches it.
    r"\b(?:just|simply|merely|only|probably|likely|almost\s+certainly)\s+"
    r"(?:the\s+|a\s+bit\s+of\s+|some\s+|your\s+)?(?:dehydration|dehydrated|the\s+heat|"
    r"heat|low\s+blood\s+sugar|a\s+bonk|bonking|fatigue|tiredness|nerves|"
    r"under[\s-]?fuel\w*|electrolytes?)\b",
    # Continue-training advice.
    r"\b(?:push|pushing|train|training|run|running|race|racing|work|working|power|"
    r"powering)\s+through\b",
    r"\bkeep\s+(?:on\s+)?(?:training|running|racing|going|pushing|moving)\b",
    r"\b(?:fine|ok|okay|safe|reasonable)\s+to\s+(?:train|run|race|push|continue|"
    r"carry\s+on)\b",
    r"\byou\s+can\s+still\s+(?:train|run|race|push|finish)\b",
    # The it-will-pass brush-off, and the fix-instead-of-care shapes narrow enough to
    # match only when they are offered AS the answer.
    r"\b(?:you'?ll|it'?ll|that'?ll|they'?ll)\s+(?:be\s+(?:fine|ok|okay|alright)|pass|"
    r"settle|sort\s+itself|come\s+right)\b",
    r"\b(?:just|simply)\s+(?:drink|sip|rest|sit|lie|cool|walk\s+it)\b",
    r"\bsleep\s+it\s+off\b|\bshake\s+it\s+off\b|\bwalk\s+it\s+off\b",
)


_COMPILED: dict[tuple[str, int], OutputRule] = {
    ("napping", 5): OutputRule(
        name="napping_D5_hypersomnolence_to_clinician",
        source=(
            "notes/sleep/napping.md Coach Directive 5 (SAFETY-CRITICAL): 'if the owner "
            "reports a new, worsening or uncontrollable need to nap, or falling asleep "
            "unintentionally, say plainly that this belongs with a clinician. Do not "
            "reassure, do not offer a cause, do not offer a nap-length fix.'"
        ),
        subject=_HYPERSOMNOLENCE_RE,
        action=_NAP_REASSURE_RE,
        response=_CLINICIAN,
    ),
    ("hydration_everyday", 5): OutputRule(
        name="hydration_everyday_D5_no_exercise_fluid_target",
        source=(
            "notes/intake/hydration_everyday.md Coach Directive 5 (SAFETY-CRITICAL): "
            "'never generate a scheduled or volume-target hydration instruction for "
            "exercise or heat from this note ... Excess fluid intake can be fatal.'"
        ),
        subject=EXERTION_OR_HEAT_RE,
        action=_FLUID_TARGET_RE,
        response=_FLUID_BLOCK,
    ),
    ("hydration_everyday", 6): OutputRule(
        name="hydration_everyday_D6_no_advice_when_fluid_sensitive",
        source=(
            "notes/intake/hydration_everyday.md Coach Directive 6 (SAFETY-CRITICAL): "
            "'if the owner mentions kidney, heart or liver disease, a diuretic, or a "
            "prescribed fluid restriction, give no fluid-intake advice at all and route "
            "to their clinician.'"
        ),
        subject=_FLUID_SENSITIVE_CONDITION_RE,
        action=_FLUID_ADVICE_RE,
        response=_FLUID_BLOCK,
    ),
    ("environmental_stress", 12): OutputRule(
        name="environmental_stress_D12_exertional_red_flags_to_urgent_care",
        source=(
            "environmental_stress — sports-science/wellness/environmental-stress.md "
            "Coach Directive 12 "
            "(SAFETY-CRITICAL): 'on heat-illness red flags (confusion, collapse, "
            "disorientation, vomiting, altered behavior) during/after hot exercise, stop "
            "training advice and direct the runner to immediate cooling and urgent "
            "medical care.' The same forbidden move is stated by this note's D13 "
            "(altitude illness) and by fueling-and-hydration D12 (EAH); both defer here "
            "rather than restating a second guardrail for one rule."
        ),
        subject=EXERTIONAL_RED_FLAG_RE,
        action=_EMERGENCY_DEFLECTION_RE,
        response=_EXERTIONAL_EMERGENCY,
    ),
    ("late_eating_sleep", 5): OutputRule(
        name="late_eating_sleep_D5_no_eating_restriction",
        source=(
            "notes/intake/late_eating_sleep.md Coach Directive 5 (SAFETY-CRITICAL): "
            "'never issue an eating restriction, a fasting window or a \"stop eating "
            'after X" instruction; route anything resembling restriction to '
            "[[fasting_metrics]]'s eating-disorder guardrail.'"
        ),
        subject=PRESCRIPTION_RE,
        action=_EATING_RESTRICTION_RE,
        response=_EATING_BLOCK,
    ),
}


def origins() -> tuple[tuple[str, int], ...]:
    """Every ``(note_id, directive_number)`` a rule is compiled from.

    The test compares this against the ``safety_critical`` markers the manifest
    publishes; equality in both directions is what makes the corpus's "mirrored as a
    hard guardrail" sentence a fact rather than a hope.
    """
    return tuple(sorted(_COMPILED))


def compiled_rules() -> tuple[OutputRule, ...]:
    """The rules compiled from safety-critical corpus directives, in a stable order."""
    return tuple(_COMPILED[key] for key in origins())
