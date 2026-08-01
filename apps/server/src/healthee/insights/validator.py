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

The vocabularies these rules are stated in — what counts as interpretive, as a hedge,
as banned tone — live in ``calibration.py``; this module is the rule engine over them.

Rules 1–4 are enforced over every sentence the answer actually contains — INCLUDING
inside markdown tables, headings and blockquotes, which an earlier splitter dropped
(``answer_text.sentence_units``). A refusal bypasses validation ONLY when the whole
answer IS a refusal template (they are safe by construction, §5.5) — never when one is
merely embedded in a longer answer.

## What rules 2 and 3 do NOT apply to, and why (#99)

Measured 2026-08-01 by ``tests/grounding_eval``: ~80% of the answers this product paid
for and never shipped failed on grade-calibration wording rather than on missing
evidence. Four of those causes were the validator being wrong, not the model:

  * a **section heading** ("**What the data shows**") counted as an uncited interpretive
    sentence, because it contains the word "shows". A heading labels the claims beneath
    it; it makes none (``answer_text.Unit``). Only when its sole interpretive marker is a
    reporting verb, though — "## Your recovery is low because of sleep debt" is a claim
    with a hash in front of it, and ``test_validator_hardening`` holds that line;
  * a sentence **reporting the owner's own measured numbers** counted as an unhedged
    Probable claim. Stating a measurement is not a claim about the world, and hedging a
    number we measured would be less honest, not more (``calibration.quotes_own_measurement``);
  * the hedge vocabulary did not contain the word **"probably"** — so a sentence hedged
    with the plainest hedge in English, sharing its root with the grade's own name, was
    rejected for having no hedge (``calibration``'s hedge vocabulary);
  * a sentence that **declined to make a claim** ("the data does not support a confident
    call") was rejected for insufficient hedging — the product refusing to ship its own
    admission of uncertainty (``calibration.is_hedged``'s second half).

None of the four loosens what "grounded" means: every one is a case where the rule fired
on text that was already honest. The hard output guardrails are a separate stage and take
none of these exemptions — a forbidden output is blocked in a heading exactly as in prose
(``output_guard.check_output`` reads ``answer_text.sentences``, which is flat).
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

from healthee.core.logging import get_logger
from healthee.insights import manifest
from healthee.insights.answer_text import extract_citations, sentence_units, truncation_issue
from healthee.insights.calibration import (
    BANNED_CERTAINTY_RE,
    BANNED_TONE_RE,
    FLAG_RE,
    HONEST_ESCAPE_RE,
    INTERPRETIVE_RE,
    MIXED_RE,
    is_hedged,
    quotes_own_measurement,
    reports_only,
)
from healthee.insights.json_shapes import JSON_SHAPES, Segment, segments_for
from healthee.insights.refusals import REFUSAL_TEMPLATES

log = get_logger(__name__)

# Re-exported: `extract_citations` is part of the validator's public surface.
__all__ = ["ValidationResult", "extract_citations", "is_refusal", "validate", "validate_json"]

# Wrapping characters a refusal may legitimately arrive with (quoted, bolded, padded).
# Stripped from BOTH ends of the answer and the template, so matching stays symmetric.
_REFUSAL_WRAPPER_CHARS = " \t\r\n\"'*`."


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
    """Enforce grade-calibrated wording for one cited interpretive sentence."""
    grades = [manifest.grade_of(i) for i in cited_ids]
    ranks = [manifest.GRADE_RANK.get(g or "", 3) for g in grades if g]
    if not ranks:
        return None
    strictest = min(ranks)  # lowest rank = weakest evidence = strictest wording
    if "Contested" in grades and not MIXED_RE.search(sentence):
        return f"Contested claim not framed as debated: '{sentence[:120]}'"
    if strictest <= 1 and not (FLAG_RE.search(sentence) or MIXED_RE.search(sentence)):
        return f"Emerging/weak claim not flagged as uncertain: '{sentence[:120]}'"
    if strictest == 2 and not is_hedged(sentence):
        return f"Probable claim stated without a hedge: '{sentence[:120]}'"
    return None


def _sentence_issues(
    sentence: str, *, require_grounding: bool = True, heading: bool = False
) -> list[str]:
    """Per-sentence checks: grounding, banned tone, and grade calibration.

    ``require_grounding=False`` exempts a sentence from the interpretive-citation and
    grade-calibration rules ONLY — banned tone still applies, as do the whole-answer
    fabricated-id and certainty checks, and so do the hard output guardrails, which are a
    different stage entirely. It exists for text grounded structurally rather than
    sentence-by-sentence (a rec's ``action``; see ``json_shapes``).

    ``heading=True`` marks a markdown section heading (``answer_text.Unit``). It is NOT a
    blanket exemption: a heading is excused only when the sole thing that made it look
    interpretive was a reporting verb — "**What the data shows**" is a table of contents,
    while "## Your recovery is low because of sleep debt" is a claim that happens to be
    typed after a hash.
    """
    issues: list[str] = []
    cited_ids, _ = extract_citations(sentence)
    if BANNED_TONE_RE.search(sentence) and not cited_ids:
        issues.append(f"Alarmist/reassuring tone without citation: '{sentence[:120]}'")
    if not require_grounding or not INTERPRETIVE_RE.search(sentence):
        return issues
    if reports_only(sentence) and (heading or quotes_own_measurement(sentence)):
        return issues
    if not cited_ids:
        if not HONEST_ESCAPE_RE.search(sentence):
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
    if BANNED_CERTAINTY_RE.search(text):
        issues.append("Uses banned certainty language (caused by / definitely / always / never).")
    for seg in segments:
        for unit in sentence_units(seg.text):
            issues.extend(
                _sentence_issues(
                    unit.text,
                    require_grounding=seg.require_grounding,
                    heading=unit.heading,
                )
            )
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
