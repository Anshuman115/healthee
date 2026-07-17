"""The ``recs`` chain step — daily recommendations, v2-native, cite-or-drop.

Ports the INTENT of legacy ``llm/recs.py`` (1–3 grounded daily actions per day,
progress-framed, no meds/dosing/diagnosis) but fixes its two structural flaws:

  * **Through the choke point.** Generation runs via ``insights.grounded_ask`` —
    the ONE grounded path (v2-native context, manifest-ranked evidence, refusal
    gating, and the *blocking* validator). A response whose citations don't
    validate never ships (legacy's validator was advisory); a fabricated inline
    ``[note_id]`` is blocked there before any rec is parsed.
  * **V2-native, DB profile, audit columns.** Signals read ``derived_daily`` /
    the ``profile`` table (``recs_context``), not v1 views or a JSON profile
    file; each row is written with ``raw_llm_prompt`` / ``raw_llm_response``
    (the columns legacy's v2 schema lacked — bug A4).

Per-rec structural validation still drops any individual rec that cites an
unknown note or misses a field (legacy's cite-or-drop), on top of the whole-
response blocking done by the choke point.

**A rec's evidence grade is PROVED, not believed.** ``evidence_grade`` is a number
the model writes about itself, and it used to be checked only for being 2 or 3 —
never against ``manifest.grade_of()`` of the notes the rec cites. A rec citing a
Contested note could therefore self-declare 3 and ship to the user labelled
*Established*: the prose validator grade-calibrates every sentence, but nothing
policed the structured field beside it, so the honesty contract's rule 2
("confidence is part of the answer") was enforced everywhere except on the field
that literally states the confidence. ``_provable_grade`` now resolves the shipped
grade from the strictest cited note — overclaims are corrected down, evidence below
Probable never ships. See that function for the drop-vs-correct reasoning.
"""

from __future__ import annotations

import re
from datetime import date
from typing import TypeGuard
from uuid import UUID

from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger
from healthee.core.tenancy import user_today
from healthee.insights import manifest
from healthee.insights.client import LLMClient
from healthee.insights.grounded import GroundedResult, grounded_ask
from healthee.jobs.recs_context import build_recs_signals

log = get_logger(__name__)

# Metrics whose evidence notes the choke point should rank into full context.
RECS_METRICS = [
    "recovery_score",
    "mvpa_min",
    "steps_total",
    "vo2max_estimate",
    "sleep_health_score_4dim",
    "sleep_regularity_index",
    "hrv_sleep_avg",
    "cardio_load",
]

_MAX_RECS = 3
_REQUIRED_FIELDS = ("action", "rationale", "category", "evidence_grade", "research_note_ids")
_VALID_GRADES = frozenset({2, 3})

# The weakest evidence a rec may ship on: Probable (GRADE_RANK 2). A rec is a
# directive to act TODAY, so evidence below Probable — Emerging, Contested, Myth —
# does not get to drive one, however the model graded itself. This is §5.6's
# "grade>=2 whitelist", enforced on the PROVABLE floor instead of on the claim.
# Weaker notes stay retrievable (the coach may still discuss, or correct, a Myth);
# it is the recs surface that acts, and only this surface is gated.
_MIN_SHIPPABLE_RANK = 2

# The JSON task handed to the choke point as the user question. The choke point's
# system prompt + EVIDENCE NOTES supply the citation whitelist and grade rules;
# this fixes the output shape and the recs-specific framing.
RECS_TASK = """\
Act as the recommendations engine: produce 1–3 concrete actions I can do TODAY,
each anchored to a specific number from my SIGNALS/CONTEXT and grounded in the
EVIDENCE NOTES. Respect the recovery ceiling. Progress framing, never deficit
framing. No medications, doses, supplements, diagnoses, or symptom interpretation.

Output ONLY a JSON object (JSON mode is on — no prose, no code fences) of this exact shape:
{"recommendations": [
  {"action": "<one-line directive>",
   "rationale": "<=2 sentences, each interpretive clause ending in an inline [note_id]>",
   "expected_effect": "<quantified personal effect, or omit>",
   "category": "sleep|activity|recovery|intake|fitness",
   "evidence_grade": 2 or 3,
   "research_note_ids": ["<id>", ...],
   "signal_source": "<short label of the triggering signal>"}
]}
If nothing meaningful applies today, return {"recommendations": []}."""

# Safety keyword block on generated recs (drop the rec, don't retry) — ported
# from legacy recs.py: dosing / meds / supplements / diagnosis / symptoms.
_BANNED_RE = re.compile(
    r"\bmg\b|\bdose|\bdosing\b|\bprescri|\bdiagnos|\bsymptom|\bmedication\b|"
    r"\bsupplement\b|\bmedicine\b|\bdrug\b|\bpill\b|\btablet\b",
    re.IGNORECASE,
)
_INLINE_CITE_RE = re.compile(r"\[[a-z0-9_]+(?:\s*,\s*[a-z0-9_]+)*\]")


def _no_grounded_output(user_id: UUID, day: date, question: str, result: GroundedResult) -> dict:
    """The choke point refused / fell back — ship NO recs rather than ungrounded ones.

    Stale rows are still cleared and the audit row still written, so a bad day is a
    visibly empty day, never yesterday's advice masquerading as today's. Extracted
    (unchanged) from ``generate_recs`` to keep it inside the 40-line gate.
    """
    log.info(
        "recs[%s] %s: no grounded output (refused=%s validated=%s)",
        user_id,
        day,
        result.refused,
        result.validated,
    )
    _persist(user_id, day, [], prompt=question, raw=result.text)
    return {
        "ok": True,
        "day": day.isoformat(),
        "persisted": 0,
        "dropped": 0,
        "validated": result.validated,
        "refused": result.refused,
    }


def generate_recs(
    user_id: UUID,
    tz: str,
    day: date | None = None,
    *,
    client: LLMClient | None = None,
    model: str | None = None,
) -> dict:
    """Generate, validate, and persist ``user_id``'s recommendations. Returns a status dict.

    ``day`` defaults to the OWNER's local today (from their ``tz``), not a global one.
    ``client`` is injectable so tests run a deterministic stub with no network.
    Errors propagate to the supervised chain runner (never swallowed, standards §1).
    """
    day = day or user_today(tz)
    signals = build_recs_signals(user_id, tz)
    question = f"{RECS_TASK}\n\n# TODAY'S SIGNALS (anchor every action to these)\n\n{signals}"

    result = grounded_ask(
        question,
        user_id,
        tz,
        metrics=RECS_METRICS,
        context_days=14,
        response_format="json",
        client=client,
        model=model,
    )
    if result.refused or not result.validated or result.data is None:
        return _no_grounded_output(user_id, day, question, result)

    clean, dropped = _parse_and_validate(result.data)
    persisted = _persist(user_id, day, clean, prompt=question, raw=result.text)
    log.info("recs[%s] %s: %d persisted, %d dropped", user_id, day, persisted, dropped)
    return {
        "ok": True,
        "day": day.isoformat(),
        "persisted": persisted,
        "dropped": dropped,
        "validated": True,
        "refused": False,
    }


def _parse_and_validate(payload: dict) -> tuple[list[dict], int]:
    """Keep only the structurally valid, citable recs from the parsed payload.

    ``payload`` is the object the choke point already parsed and citation-validated
    (``grounded_ask(response_format="json")`` → ``result.data``); the JSON is no
    longer parsed here. Returns (clean_recs, dropped_count). A rec is dropped (not
    retried) when it misses a field, uses a bad grade, cites an unknown note, lacks
    an inline ``[note_id]``, or trips the safety keyword block.
    """
    recs = payload.get("recommendations")
    if not isinstance(recs, list):
        log.warning("recs payload missing a 'recommendations' array — no recs shipped")
        return [], 0

    known = manifest.note_ids()
    clean: list[dict] = []
    dropped = 0
    for rec in recs:
        shippable = _shippable_rec(rec, known)
        if shippable is not None:
            clean.append(shippable)
        else:
            dropped += 1
        if len(clean) >= _MAX_RECS:
            break
    return clean, dropped


def _shippable_rec(rec: object, known: set[str]) -> dict | None:
    """One rec as it may ship — grade corrected to what its notes PROVE — or None.

    Structural validity first (``_rec_ok``), then the grade resolution: the returned
    rec carries the provable grade, not the declared one, so ``_persist`` can only
    ever write a grade the manifest backs.
    """
    if not _rec_ok(rec, known):
        return None
    grade = _provable_grade(rec)
    if grade is None:
        return None
    return {**rec, "evidence_grade": grade}


def _provable_grade(rec: dict) -> int | None:
    """The grade the rec's OWN citations support, or None if it may not ship at all.

    The model self-declares ``evidence_grade``; that number is a claim, and until now
    nothing checked it — a rec citing a Contested note could declare 3 and reach the
    user labelled *Established*, bypassing every grade calibration the prose validator
    applies (honesty contract rule 2: confidence is part of the answer).

    The strictest (weakest) grade among the cited notes is the ceiling — the same rule
    ``validator._grade_issue`` already applies to a sentence's inline citations, so the
    structured field and the prose it accompanies cannot disagree. An unknown grade
    ranks 0 (fail-closed); ``_rec_ok`` has already guaranteed the ids are non-empty
    and citable.

    Overclaiming is CORRECTED, not dropped: the rationale's wording was independently
    grade-calibrated against these same notes by the blocking validator at the choke
    point, so the action and its prose are sound and only the label overreached —
    dropping the rec would throw away real, honest value to punish one wrong integer.
    Evidence below Probable is dropped instead: there is no honest label for it on a
    surface whose whole purpose is to tell the user to do something today.
    """
    declared = int(rec["evidence_grade"])
    ranks = [
        manifest.GRADE_RANK.get(manifest.grade_of(nid) or "", 0) for nid in rec["research_note_ids"]
    ]
    floor = min(ranks)
    if floor < _MIN_SHIPPABLE_RANK:
        return None
    return min(declared, floor)


def _rec_ok(rec: object, known: set[str]) -> TypeGuard[dict]:
    """True iff one rec is well-formed, citable, and safe (else it is dropped).

    Structure only — the DECLARED ``evidence_grade`` is merely checked to be in the
    shippable band here; whether the citations actually support it is
    ``_provable_grade``'s job.
    """
    if not isinstance(rec, dict):
        return False
    if any(field not in rec for field in _REQUIRED_FIELDS):
        return False
    if rec.get("evidence_grade") not in _VALID_GRADES:
        return False
    note_ids = rec.get("research_note_ids") or []
    if not note_ids or any(nid not in known for nid in note_ids):
        return False
    if not _INLINE_CITE_RE.search(rec.get("rationale", "")):
        return False
    blob = f"{rec.get('action', '')} {rec.get('rationale', '')} {rec.get('expected_effect', '')}"
    return not _BANNED_RE.search(blob)


_INSERT_SQL = """
    INSERT INTO recommendation
      (user_id, date, rank, action, rationale, expected_effect, category, evidence_grade,
       research_note_ids, signal_source, raw_llm_prompt, raw_llm_response)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
"""


def _persist(user_id: UUID, day: date, recs: list[dict], *, prompt: str, raw: str) -> int:
    """Replace ``user_id``'s recommendation rows for ``day`` with ``recs``.

    The audit columns (``raw_llm_prompt`` / ``raw_llm_response``) are always
    written — the whole point of the schema fix.
    """
    with tenant_transaction(user_id) as cur:
        cur.execute("DELETE FROM recommendation WHERE user_id = %s AND date = %s", (user_id, day))
        for rank, rec in enumerate(recs, start=1):
            cur.execute(
                _INSERT_SQL,
                (
                    user_id,
                    day,
                    rank,
                    rec["action"],
                    rec["rationale"],
                    rec.get("expected_effect"),
                    rec["category"],
                    int(rec["evidence_grade"]),
                    list(rec["research_note_ids"]),
                    rec.get("signal_source", ""),
                    prompt,
                    raw,
                ),
            )
    return len(recs)
