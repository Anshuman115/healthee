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

A refusal bypasses validation ONLY when the whole answer IS a refusal template (they
are safe by construction, §5.5) — never when one is merely embedded in a longer answer.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

from healthee.core.logging import get_logger
from healthee.insights import manifest
from healthee.insights.refusals import REFUSAL_TEMPLATES

log = get_logger(__name__)

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
            r"\b(is|are|was|were) (high|low|elevated|reduced|abnormal|concerning|worrying)\b",
            r"\b(too high|too low|above (the )?normal|below (the )?normal)\b",
        )
    ),
    re.IGNORECASE,
)
# Wrapping characters a refusal may legitimately arrive with (quoted, bolded, padded).
# Stripped from BOTH ends of the answer and the template, so matching stays symmetric.
_REFUSAL_WRAPPER_CHARS = " \t\r\n\"'*`."

_CITE_RE = re.compile(r"\[([a-z0-9_]+(?:\s*,\s*[a-z0-9_]+)*)\]")
_PERSONAL_RE = re.compile(r"\[personal_finding:([^\]]+)\]", re.IGNORECASE)
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


@dataclass
class ValidationResult:
    """Outcome of one validation pass over a generated answer."""

    ok: bool
    issues: list[str] = field(default_factory=list)
    citations: list[str] = field(default_factory=list)
    personal_findings: list[str] = field(default_factory=list)
    grade_floor: str | None = None


def extract_citations(text: str) -> tuple[set[str], set[str]]:
    """(note_ids, personal_finding_names) cited in ``text``.

    Personal-finding tokens carry a colon and are matched separately so they are
    never confused with population note ids.
    """
    personal = {m.group(1).strip() for m in _PERSONAL_RE.finditer(text)}
    ids: set[str] = set()
    for m in _CITE_RE.finditer(text):
        ids.update(part.strip() for part in m.group(1).split(","))
    return ids, personal


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


def _sentences(text: str) -> list[str]:
    """Split into sentences, dropping pure-markdown structure lines."""
    out: list[str] = []
    for raw in re.split(r"(?<=[.!?])\s+", text.strip()):
        clean = raw.strip()
        if clean and not clean.startswith(("#", "|", ">")):
            out.append(clean)
    return out


def _grade_issue(sentence: str, cited_ids: set[str]) -> str | None:
    """Enforce grade-calibrated wording for one cited interpretive sentence."""
    grades = [manifest.grade_of(i) for i in cited_ids]
    ranks = [manifest.GRADE_RANK.get(g or "", 3) for g in grades if g]
    if not ranks:
        return None
    strictest = min(ranks)  # lowest rank = weakest evidence = strictest wording
    if "Contested" in grades and not _MIXED_RE.search(sentence):
        return f"Contested claim not framed as debated: '{sentence[:120]}'"
    if strictest <= 1 and not (_FLAG_RE.search(sentence) or _MIXED_RE.search(sentence)):
        return f"Emerging/weak claim not flagged as uncertain: '{sentence[:120]}'"
    if strictest == 2 and not _HEDGE_RE.search(sentence):
        return f"Probable claim stated without a hedge: '{sentence[:120]}'"
    return None


def _sentence_issues(sentence: str) -> list[str]:
    """Per-sentence checks: grounding, banned tone, and grade calibration."""
    issues: list[str] = []
    if _BANNED_TONE_RE.search(sentence) and not _CITE_RE.search(sentence):
        issues.append(f"Alarmist/reassuring tone without citation: '{sentence[:120]}'")
    if not _INTERP_RE.search(sentence):
        return issues
    cited_ids, _ = extract_citations(sentence)
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


def _run_rules(text: str) -> ValidationResult:
    """The rule engine over a prose blob — shared by the prose and JSON paths.

    Runs the fabricated-id, banned-certainty, and every per-sentence check
    (grounding, tone, grade calibration). The two callers differ ONLY in what
    text they hand in: ``validate`` passes the whole answer; ``validate_json``
    passes the concatenated user-facing interpretive strings.
    """
    ids, personal = extract_citations(text)
    known = manifest.note_ids()
    issues: list[str] = []
    fabricated = ids - known
    if fabricated:
        issues.append(f"Cited ids do not exist in the manifest: {sorted(fabricated)}")
    if _BANNED_CERTAINTY_RE.search(text):
        issues.append("Uses banned certainty language (caused by / definitely / always / never).")
    for sentence in _sentences(text):
        issues.extend(_sentence_issues(sentence))
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
    return _run_rules(response)


def _recs_interpretive_text(payload: object) -> str:
    """Concatenate the USER-FACING interpretive strings from a recs payload.

    Only ``rationale`` / ``action`` / ``expected_effect`` are user-facing prose;
    keys and constrained-vocab fields (``category``, ``signal_source``,
    ``evidence_grade``, ``research_note_ids``) are NOT validated as prose — they
    are structurally checked per-rec in ``jobs/recs.py``. This is why an
    interpretive-looking word in a KEY or a category value cannot false-trip or
    false-satisfy the rules.
    """
    if not isinstance(payload, dict):
        return ""
    recs = payload.get("recommendations")
    if not isinstance(recs, list):
        return ""
    parts: list[str] = []
    for rec in recs:
        if not isinstance(rec, dict):
            continue
        for field_name in ("rationale", "action", "expected_effect"):
            value = rec.get(field_name)
            if isinstance(value, str):
                parts.append(value)
    return "\n".join(parts)


def validate_json(response: str) -> ValidationResult:
    """Validate a JSON answer (recs shape) with the SAME honesty rules as prose.

    Malformed JSON is a hard failure (logged, ``ok=False``) so the choke point
    falls back honestly rather than shipping garbage. Well-formed JSON has its
    user-facing interpretive strings extracted and run through ``_run_rules`` —
    so a fabricated inline ``[note_id]`` in a rationale is blocked exactly as it
    is in the prose path.
    """
    try:
        payload = json.loads(response)
    except (json.JSONDecodeError, ValueError) as exc:
        log.warning("grounded json answer was not valid JSON (%s) — blocking", exc)
        return ValidationResult(ok=False, issues=[f"Response was not valid JSON: {exc}"])
    return _run_rules(_recs_interpretive_text(payload))
