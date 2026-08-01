"""Blocking citation validator (v2) — the enforcement half of the honesty core.

Legacy validation was *advisory*: it retried once, then returned the text anyway
with ``validation_ok=False`` (INTELLIGENCE §5.2). Here validation is **blocking** —
the choke point (``grounded.py``) ships an honest fallback rather than text that
fails these checks (§3, hole #2).

Rules enforced against the generated answer:
  1. Every cited ``[note_id]`` exists in the manifest (fabricated ids are blocked).
  2. Every interpretive sentence carries a real ``[note_id]`` or an honest escape
     ("no strong evidence in our base"). A ``[personal_finding:…]`` token is NOT a
     substitute — personal n=1 patterns are distinguished from population research.
  3. Grade-calibrated language: a sentence's wording must match the strictest grade
     among its cited notes (Established → plain · Probable → hedged · Emerging →
     flagged · Contested → "the science is mixed").
  4. Banned tone (alarming/reassuring) needs a supporting citation; banned certainty
     ("is caused by", "definitely", "always", "never") is never allowed.
  5. A truncated or empty answer is blocked outright (prose path): it is not a
     validated answer, only one that happened to contain nothing checkable.

Rules 1–4 are enforced over every sentence the answer actually contains — INCLUDING
inside markdown tables, headings and blockquotes, which an earlier splitter dropped
(``answer_text.sentences``). A refusal bypasses validation ONLY when the whole answer IS
a refusal template (they are safe by construction, §5.5) — never when one is merely
embedded in a longer answer.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

from healthee.core.logging import get_logger
from healthee.insights import manifest
from healthee.insights.answer_text import extract_citations, sentences, truncation_issue
from healthee.insights.json_shapes import JSON_SHAPES, Segment, segments_for
from healthee.insights.refusals import REFUSAL_TEMPLATES

log = get_logger(__name__)

# Re-exported: `extract_citations` is part of the validator's public surface.
__all__ = ["ValidationResult", "extract_citations", "is_refusal", "validate", "validate_json"]

# Interpretive / causal / recommending markers — a sentence matching one makes a
# claim (vs merely reporting a number) and must be grounded. Ported from legacy.
_INTERP_RE = re.compile(
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
            # is a directive by contract and grounded at the rec level (see _recs_segments).
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
# Wrapping characters a refusal may legitimately arrive with (quoted, bolded, padded).
# Stripped from BOTH ends of the answer and the template, so matching stays symmetric.
_REFUSAL_WRAPPER_CHARS = " \t\r\n\"'*`."

_ESCAPE_RE = re.compile(
    r"no\s+strong\s+evidence|no\s+evidence\s+in\s+our\s+base|not\s+covered\s+(by|in)\s+"
    r"(our|the)\s+(evidence|research)\s+base",
    re.IGNORECASE,
)
_BANNED_TONE_RE = re.compile(
    r"\b(very\s+)?(concerning|alarming|worrying|dangerous)\b|"
    r"\b(great|excellent|amazing|wonderful)\b|"
    r"\b(unhealthy|healthy)\s+(value|level|reading|number)\b",
    re.IGNORECASE,
)
_BANNED_CERTAINTY_RE = re.compile(
    r"\bis caused by\b|\bare caused by\b|\bdefinitely\b|\balways\b|\bnever\b|\bguarantees?\b",
    re.IGNORECASE,
)

# Grade-calibration vocabularies. Contested demands an explicit "mixed" framing;
# Emerging a flag; Probable any hedge. Established needs nothing extra.
_MIXED_RE = re.compile(
    r"mixed|debated|conflicting|contested|inconsistent|not settled", re.IGNORECASE
)
_FLAG_RE = re.compile(
    r"emerging|preliminary|early (evidence|data)|limited evidence|nascent", re.IGNORECASE
)
_HEDGE_RE = re.compile(
    r"\bmay\b|\bmight\b|\bcould\b|\bappears?\b|consistent with|associated|"
    r"\blikely\b|\btends?\b|\bsuggests?\b|\bpossible\b|\bcan\b",
    re.IGNORECASE,
)
# Myth/Refuted demand CORRECTION framing — the sentence must mark the claim as one the
# evidence does not support, not merely hedge it. See `_REFUTED_GRADES` for why this is
# its own branch rather than a hedge strength (#91).
_CORRECTION_RE = re.compile(
    r"\bmyth\b|\bmisconception\b|\bdebunk\w*|\bunfounded\b|\bdisproven\b|\brefuted\b|"
    r"\bno\s+(?:good\s+|strong\s+|solid\s+|scientific\s+)?(?:evidence|basis|support|"
    r"studies|data)\b|\bnot\s+(?:supported|backed|borne\s+out|true|the\s+case)\b|"
    r"\bisn'?t\s+(?:true|supported|backed)\b|\bdoes\s+not\s+hold\b|"
    r"\b(?:commonly|widely|often|frequently)\s+(?:believed|repeated|claimed|said|"
    r"assumed|cited)\b|\bpopular\s+(?:belief|claim|idea)\b|\bturns\s+out\b|"
    r"\bcontrary\s+to\b|\bin\s+fact\b",
    re.IGNORECASE,
)
# The grades whose required framing is a correction, not a hedge. Kept as a named set
# because `GRADE_RANK` maps BOTH to 0 and the branch keys on meaning, not on rank.
_REFUTED_GRADES = frozenset({"Myth", "Refuted"})


@dataclass
class ValidationResult:
    """Outcome of one validation pass over a generated answer."""

    ok: bool
    issues: list[str] = field(default_factory=list)
    citations: list[str] = field(default_factory=list)
    personal_findings: list[str] = field(default_factory=list)
    grade_floor: str | None = None


def _normalize_refusal(text: str) -> str:
    """Collapse whitespace and shed wrapping punctuation so echoed templates still match.

    A model re-wrapping a template across lines, or quoting/bolding it, is still
    emitting that template. Nothing here can *shorten* a longer answer to a
    template: only whitespace runs collapse, and only leading/trailing wrapper
    characters are shed — interior words always survive.
    """
    return re.sub(r"\s+", " ", text).strip(_REFUSAL_WRAPPER_CHARS)


_NORMALIZED_REFUSALS: frozenset[str] = frozenset(_normalize_refusal(t) for t in REFUSAL_TEMPLATES)


def is_refusal(text: str) -> bool:
    """True only when the WHOLE answer IS one of the hard-refusal templates.

    Whole-answer EQUALITY, never containment. This was a substring match, which was a
    total validation bypass: any answer *containing* a template — and templates sit in
    coach conversation history for a model to echo — skipped every citation, tone,
    calibration and certainty check (INTELLIGENCE §6, hole #2). Refusals bypass those
    checks because they are safe by construction (§5.5); text merely wrapped around one
    is not, so an embedded template cannot suppress validation: any prose outside the
    template leaves the normalized answer unequal to it.
    """
    return _normalize_refusal(text) in _NORMALIZED_REFUSALS


def _grade_issue(sentence: str, cited_ids: set[str]) -> str | None:
    """Enforce grade-calibrated wording for one cited interpretive sentence.

    ## Myth/Refuted is its own branch (#91)

    Standards §4 and CLAUDE.md both promise FIVE calibrated framings — Established
    plainly, Probable hedged, Emerging flagged, Contested debated, **Myth/Refuted
    corrected gently**. This function used to implement THREE. ``Myth`` and
    ``Refuted`` rank 0 in ``GRADE_RANK``, so they fell through the ``strictest <= 1``
    branch they share with ``Emerging`` and were satisfied by the word "preliminary"
    or "limited evidence" — which is not a correction, it is a hedge, and hedging a
    debunked claim is how a myth ships wearing the costume of thin-but-real evidence.
    Nothing in the corpus is graded Myth yet, which is exactly why the gap survived:
    the branch was unreachable, so no test could fail on it.

    That is the #83 defect class one layer down — the authored intent (the standards
    doc) and the enforced value (this function) had diverged, and the divergence was
    invisible because the two live in different files and only one of them runs.

    A refuted grade OWNS the sentence: it is the strictest grade there is, so it
    returns rather than falling through to the hedge branches, and correction framing
    alone satisfies it.

    **What this does and does not enforce.** It enforces that the sentence *marks the
    claim as unsupported*. It cannot enforce "gently" — tone is not a regex — so the
    banned-tone rule, the note's own prose and the system prompt still carry that half.
    """
    grades = [manifest.grade_of(i) for i in cited_ids]
    ranks = [manifest.GRADE_RANK.get(g or "", 3) for g in grades if g]
    if not ranks:
        return None
    strictest = min(ranks)  # lowest rank = weakest evidence = strictest wording
    if any(g in _REFUTED_GRADES for g in grades):
        if not _CORRECTION_RE.search(sentence):
            return f"Myth/Refuted claim not framed as a correction: '{sentence[:120]}'"
        return None
    if "Contested" in grades and not _MIXED_RE.search(sentence):
        return f"Contested claim not framed as debated: '{sentence[:120]}'"
    if strictest <= 1 and not (_FLAG_RE.search(sentence) or _MIXED_RE.search(sentence)):
        return f"Emerging/weak claim not flagged as uncertain: '{sentence[:120]}'"
    if strictest == 2 and not _HEDGE_RE.search(sentence):
        return f"Probable claim stated without a hedge: '{sentence[:120]}'"
    return None


def _sentence_issues(sentence: str, *, require_grounding: bool = True) -> list[str]:
    """Per-sentence checks: grounding, banned tone, and grade calibration.

    ``require_grounding=False`` exempts a segment from the interpretive-citation and
    grade-calibration rules ONLY — banned tone still applies, as do the whole-answer
    fabricated-id and certainty checks. It exists for text that is grounded structurally
    rather than sentence-by-sentence (a rec's ``action``; see ``_recs_segments``).
    """
    issues: list[str] = []
    cited_ids, _ = extract_citations(sentence)
    if _BANNED_TONE_RE.search(sentence) and not cited_ids:
        issues.append(f"Alarmist/reassuring tone without citation: '{sentence[:120]}'")
    if not require_grounding or not _INTERP_RE.search(sentence):
        return issues
    if not cited_ids:
        if not _ESCAPE_RE.search(sentence):
            issues.append(f"Interpretive sentence lacks a citation: '{sentence[:120]}'")
        return issues
    grade_issue = _grade_issue(sentence, cited_ids)
    if grade_issue:
        issues.append(grade_issue)
    return issues


def _grade_floor(valid_ids: set[str]) -> str | None:
    """The weakest grade among the response's valid citations (its evidence floor)."""
    graded = [
        (manifest.GRADE_RANK.get(manifest.grade_of(i) or "", 3), manifest.grade_of(i))
        for i in valid_ids
    ]
    return min(graded)[1] if graded else None


def _run_rules(
    segments: list[Segment], *, extra_issues: list[str] | None = None
) -> ValidationResult:
    """The rule engine over user-facing text — shared by the prose and JSON paths.

    Fabricated-id and banned-certainty checks always run over ALL segments' text; the
    per-sentence checks honour each segment's ``require_grounding``. The two callers
    differ only in the segments they hand in: ``validate`` passes the whole answer as one
    grounded segment; ``validate_json`` passes a rec's user-facing strings.
    """
    text = "\n".join(seg.text for seg in segments)
    ids, personal = extract_citations(text)
    known = manifest.note_ids()
    issues: list[str] = list(extra_issues or [])
    fabricated = ids - known
    if fabricated:
        issues.append(f"Cited ids do not exist in the manifest: {sorted(fabricated)}")
    if _BANNED_CERTAINTY_RE.search(text):
        issues.append("Uses banned certainty language (caused by / definitely / always / never).")
    for seg in segments:
        for sentence in sentences(seg.text):
            issues.extend(_sentence_issues(sentence, require_grounding=seg.require_grounding))
    return ValidationResult(
        ok=not issues,
        issues=issues,
        citations=sorted(ids & known),
        personal_findings=sorted(personal),
        grade_floor=_grade_floor(ids & known),
    )


def validate(response: str) -> ValidationResult:
    """Run every rule; ``ok`` is True only when zero issues are found (blocking)."""
    if is_refusal(response):
        return ValidationResult(ok=True)
    truncation = truncation_issue(response)
    return _run_rules([Segment(response)], extra_issues=[truncation] if truncation else None)


def validate_json(response: str) -> ValidationResult:
    """Validate a JSON answer with the SAME honesty rules as prose.

    Malformed JSON is a hard failure (logged, ``ok=False``) so the choke point falls back
    honestly rather than shipping garbage, and so is a well-formed payload in a shape no
    registered extractor understands (see ``json_shapes.JSON_SHAPES``). A recognised payload has its
    user-facing interpretive strings extracted and run through ``_run_rules`` — so a
    fabricated inline ``[note_id]`` in a rationale, or in a challenge's ``why``, is
    blocked exactly as it is in the prose path.

    An EMPTY known array (``{"recommendations": []}`` / ``{"challenges": []}``) stays
    valid: "nothing meaningful applies" is an answer both surfaces are built to give, and
    it is distinguishable from an unknown shape by the key being present.
    """
    try:
        payload = json.loads(response)
    except (json.JSONDecodeError, ValueError) as exc:
        log.warning("grounded json answer was not valid JSON (%s) — blocking", exc)
        return ValidationResult(ok=False, issues=[f"Response was not valid JSON: {exc}"])
    if not isinstance(payload, dict):
        return ValidationResult(ok=False, issues=["JSON answer was not an object"])
    segments = segments_for(payload)
    if segments is None:
        log.warning("grounded json answer is in no known shape — blocking")
        return ValidationResult(
            ok=False,
            issues=[f"JSON answer has none of the known payload keys: {sorted(JSON_SHAPES)}"],
        )
    return _run_rules(segments)
