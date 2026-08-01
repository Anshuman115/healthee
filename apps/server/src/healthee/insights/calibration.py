"""The LANGUAGE half of the honesty core — what the words in an answer signal.

``validator.py`` owns the rules ("an interpretive sentence needs a citation"); this module
owns the vocabularies those rules are stated in ("what counts as interpretive"). Splitting
them is the same move that produced ``answer_text.py``: three halves that each have one
reason to change — a new markdown shape (``answer_text``), a new rule (``validator``), a
new word (here) — instead of one file that grows every time any of the three does.

Everything is a plain regex over one sentence. There is no model here and no lookup: the
gate has to be deterministic, because an answer that validates today must validate
tomorrow or the honest fallback becomes a coin flip.

## The hedge vocabulary is a claim about English, and it was wrong (#99)

``tests/grounding_eval`` measured, over two paid arms, that ~80% of every answer the
product generated and never shipped failed on grade-calibration WORDING rather than on
missing evidence — and 17 of the 39 recorded issues were "Probable claim stated without a
hedge" on a sentence containing the word **probably**, which this vocabulary did not
list. The grade is *named* Probable. Adding a word here does not loosen what "grounded"
means; it stops the gate lying about what the sentence said.
"""

from __future__ import annotations

import re

# ── What makes a sentence a CLAIM rather than a report ───────────────────────
# Interpretive / causal / recommending markers — a sentence matching one makes a
# claim (vs merely reporting a number) and must be grounded. Ported from legacy.
INTERPRETIVE_RE = re.compile(
    "|".join(
        (
            r"\blikely\b",
            r"\bmay\b",
            r"\bsuggests?\b",
            r"\bindicates?\b",
            r"\bconsistent with\b",
            r"\bassociated with\b",
            r"\bbecause\b",
            r"\bdue to\b",
            r"\bcaused? by\b",
            r"\bimplies\b",
            r"\brecommend(s|ed)?\b",
            r"\bshown to\b",
            r"\blinked to\b",
            r"\btends? to\b",
            r"\bcontribute(d|s)?\b",
            r"\bcorrelated?\b",
            r"\bpredicts?\b",
            r"\baffects?\b",
            r"\bimpact(s|ed)?\b",
            # Advice verbs: a directive to the user IS a recommendation, so it needs the
            # same grounding as "recommend" (already above) — "you should aim for 8 hours"
            # shipped uncited without these. NOT applied to a rec's `action` field, which
            # is a directive by contract and grounded at the rec level (see json_shapes).
            r"\bshould\b",
            r"\baim(ing)? for\b",
            # "shows" asserts the data proves something — the same claim "indicates" makes.
            r"\bshows?\b",
            r"\b(is|are|was|were) (high|low|elevated|reduced|abnormal|concerning|worrying)\b",
            r"\b(too high|too low|above (the )?normal|below (the )?normal)\b",
        )
    ),
    re.IGNORECASE,
)

HONEST_ESCAPE_RE = re.compile(
    r"no\s+strong\s+evidence|no\s+evidence\s+in\s+our\s+base|not\s+covered\s+(by|in)\s+"
    r"(our|the)\s+(evidence|research)\s+base",
    re.IGNORECASE,
)
BANNED_TONE_RE = re.compile(
    r"\b(very\s+)?(concerning|alarming|worrying|dangerous)\b|"
    r"\b(great|excellent|amazing|wonderful)\b|"
    r"\b(unhealthy|healthy)\s+(value|level|reading|number)\b",
    re.IGNORECASE,
)
BANNED_CERTAINTY_RE = re.compile(
    r"\bis caused by\b|\bare caused by\b|\bdefinitely\b|\balways\b|\bnever\b|\bguarantees?\b",
    re.IGNORECASE,
)

# ── Grade calibration ────────────────────────────────────────────────────────
# Contested demands an explicit "mixed" framing; Emerging a flag; Probable any hedge.
# Established needs nothing extra.
MIXED_RE = re.compile(
    r"mixed|debated|conflicting|contested|inconsistent|not settled", re.IGNORECASE
)
FLAG_RE = re.compile(
    r"emerging|preliminary|early (evidence|data)|limited evidence|nascent", re.IGNORECASE
)
_HEDGE_RE = re.compile(
    r"\bmay\b|\bmight\b|\bcould\b|\bcan\b|\bpossibl[ey]\b|"
    # "probable"/"probably" — see the module docstring. This is the omission that was
    # costing ~40% of the product's generations their second half.
    r"\bprobabl[ey]\b|\blikely\b|\bunlikely\b|"
    # Participles and past tenses of hedges already listed. `suggests?` never matched
    # "suggesting", `tends?` never matched "tending" — a purely lexical omission that
    # rejected the same hedge in a different tense.
    r"\bappear(?:s|ed|ing)?\b|\bseem(?:s|ed|ing)?\b|\bsuggest(?:s|ed|ing)?\b|"
    r"\btend(?:s|ed|ing)?\b|\bassociat(?:e|es|ed|ion)\b|consistent with|"
    # Frequency hedges: each says in plain words that the claim does not always hold,
    # which is exactly what "Probable → light hedge" asks for (standards §4).
    r"\busually\b|\btypically\b|\bgenerally\b|\boften\b",
    re.IGNORECASE,
)

# A sentence that DECLINES to make a claim cannot be overstating one. "The data does not
# support a confident call because your 30-day history is static" was rejected for being
# insufficiently hedged — the product refusing to ship its own admission of uncertainty,
# which is the single behaviour this whole subsystem exists to produce. Four of the 39
# measured issues were this shape.
#
# Anchored on the epistemic words only (confident / certain / conclusive / definitive /
# unclear), never on "enough", so that "you should not train hard without enough recovery"
# — a recommendation, not a disclaimer — keeps needing its hedge.
_DECLINES_TO_CLAIM_RE = re.compile(
    r"\b(?:not|cannot|can'?t|lacks?|lacking|insufficient|no|too little)\b[^.]{0,40}?"
    r"\b(?:confiden\w+|certain(?:ty)?|conclusive|definitive)\b|"
    r"\bunclear\b|\binconclusive\b|\bnot enough (?:data|history|nights|evidence)\b",
    re.IGNORECASE,
)


def is_hedged(sentence: str) -> bool:
    """Does ``sentence`` carry the light hedge a Probable-graded claim must have?

    Two ways to satisfy it, and they are different statements: the sentence hedges the
    claim it makes, or it declines to make one at all.
    """
    return bool(_HEDGE_RE.search(sentence) or _DECLINES_TO_CLAIM_RE.search(sentence))


# ── Myth / Refuted: a correction, NOT a hedge (#91) ──────────────────────────
# The standards promise five framings; `_grade_issue` implemented three. Myth and
# Refuted rank 0, so they fell through the `strictest <= 1` branch shared with Emerging
# and were satisfied by a plain hedge — "napping may not really pay off your sleep debt"
# reads as uncertainty about a live question, when the note's whole point is that the
# claim is false. It survived because NO note was graded Myth: the branch was
# unreachable, so no test could fail on it.
#
# The required shape is different in kind from a hedge. A hedge says "this may not
# always hold"; a correction says "people commonly believe this and the evidence does
# not support it". Hedging a myth is how a myth survives being mentioned.
CORRECTION_RE = re.compile(
    r"\bmyth\b|\bmisconception\b|\bdebunk\w*|\bunfounded\b|\bdisproven\b|\brefuted\b|"
    r"\bno\s+(?:good\s+|strong\s+|solid\s+|scientific\s+)?(?:evidence|basis|support|"
    r"studies|data)\b|\bnot\s+(?:supported|backed|borne\s+out|true|the\s+case)\b|"
    r"\bisn'?t\s+(?:true|supported|backed)\b|\bdoes\s+not\s+hold\b|"
    r"\b(?:commonly|widely|often|frequently)\s+(?:believed|repeated|claimed|said|"
    r"assumed|cited)\b|\bpopular\s+(?:belief|claim|idea)\b|\bturns\s+out\b|"
    r"\bcontrary\s+to\b|\bin\s+fact\b",
    re.IGNORECASE,
)
# Kept as a named set because `GRADE_RANK` maps BOTH to 0 and the branch keys on
# meaning, not on rank — a future grade that also ranked 0 would not automatically
# demand correction framing, and should have to say so here.
REFUTED_GRADES = frozenset({"Myth", "Refuted"})


# ── Measurement reports (#99) ────────────────────────────────────────────────
# Stating the owner's own measured number is not an interpretive claim: "your sleep stages
# (90m deep, 90m REM) are consistent with your personal baseline" is arithmetic on their
# data, and no research note grounds it — the citation rule was demanding one, and the
# grade rule was demanding a hedge on a fact. Hedging a measurement makes it *less*
# honest, which is the opposite of what these rules are for.
#
# The exemption is deliberately narrow, because "your data shows X" is also how an
# ungrounded claim gets laundered through a number.
_REPORTING_RE = re.compile(r"\bshows?\b|consistent with", re.IGNORECASE)
_OWN_DATA_RE = re.compile(r"\byour\b|\byou\b|\bmy\b|\bmine\b", re.IGNORECASE)
_NUMBER_RE = re.compile(r"\d")
# The moment a "report" mentions the world, it is no longer only a report. This is what
# keeps "your VO2max of 32 shows you are 3 years older than your age" out of the
# exemption — the claim it launders is a population one, and it must be cited and graded
# like one.
_WORLD_CLAIM_RE = re.compile(
    r"\brisks?\b|\bmortality\b|\bdeaths?\b|\bdiseases?\b|\blongevity\b|\bhealthspan\b|"
    r"\blife expectancy\b|\byears?\b|\bolder\b|\byounger\b|\badults?\b|\bpeople\b|"
    r"\bpopulations?\b|\bstud(?:y|ies)\b|\bresearch\b|\bevidence\b|\bcohorts?\b|"
    r"\bbiological age\b|\bnormal (?:range|for)\b",
    re.IGNORECASE,
)


def reports_only(sentence: str) -> bool:
    """Is every interpretive marker in ``sentence`` a REPORTING verb?

    The gate both exemptions in ``validator`` stand on, and the reason neither is wide.
    One "because", "recommend", "should" or "is low" anywhere in the sentence and it is
    making an argument, not describing one — ``test_validator_hardening``'s "## Your
    recovery is low because of sleep debt" is exactly that case and stays blocked whether
    it is a heading or not.
    """
    markers = list(INTERPRETIVE_RE.finditer(sentence))
    return bool(markers) and all(_REPORTING_RE.fullmatch(m.group(0)) for m in markers)


def quotes_own_measurement(sentence: str) -> bool:
    """Does the sentence quote a number of the owner's own, and reach no further?

    Three conditions: a number is actually present (this is what keeps "your data shows
    poor consistency" — a judgement with nothing measured in it — outside), it is the
    owner's own data, and the sentence claims nothing about the world.
    """
    return bool(
        _NUMBER_RE.search(sentence)
        and _OWN_DATA_RE.search(sentence)
        and not _WORLD_CLAIM_RE.search(sentence)
    )
