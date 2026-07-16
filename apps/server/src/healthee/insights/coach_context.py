"""The coach's CONTEXT — history-rich, not a snapshot (WP5b / COACH_PROMPT.md).

COACH_PROMPT.md requires the coach reason over the person's *history and routines*,
not just today: a wide (≥30-day) metric window with trends + baselines, and the
recent logged-intervention history (fasting/caffeine/alcohol/meditation/workouts)
with enough depth to reveal a recurring schedule. Almost all of that already lives
in the v2-native ``build_context`` (today snapshot, trends, recent-daily pivot,
sleep sessions, the manual-entry log over the window, baselines, anomalies,
personal findings) — we reuse it wholesale (standards §Duplication) at a wider
default window and add today's recovery so "what should I do today?" respects it.
"""

from __future__ import annotations

from uuid import UUID

from healthee.core.db import transaction
from healthee.insights.context import build_context
from healthee.insights.retrieval import evidence_section
from healthee.read.recovery import recovery_score_payload

# Default metric/history window for the coach — wide enough for trends + baselines
# and to expose a recurring intervention schedule (COACH_PROMPT.md history rule).
DEFAULT_COACH_DAYS = 30


def build_coach_context(
    question: str,
    user_id: UUID,
    tz: str,
    *,
    days: int = DEFAULT_COACH_DAYS,
) -> str:
    """The full coach context markdown: ``user_id``'s history/trends/logs + their recovery.

    The owner is REQUIRED (6.4b): it defaulted to the sentinel until the routers had a
    real authenticated user to thread down, and a default owner on a context builder is
    exactly how one tenant's data reaches another tenant's prompt.
    """
    context = build_context(user_id, tz, days=days, question=question)
    with transaction() as cur:
        recovery = recovery_score_payload(cur, user_id, tz)
    parts = [context, _recovery_block(recovery)]
    return "\n\n".join(p for p in parts if p)


def _recovery_block(recovery: dict | None) -> str:
    """Today's recovery so intensity advice respects it (deterministic, not LLM)."""
    if not recovery:
        return ""
    factors = ", ".join(
        f"{name} {vals.get('sub')}" for name, vals in (recovery.get("factors") or {}).items()
    )
    return (
        "## Today's recovery [recovery_readiness] — let it set intensity advice\n"
        f"- Recovery {recovery['recovery']}/100, live readiness {recovery['readiness']} "
        f"({recovery['band']}).\n"
        f"- Factor sub-scores: {factors}.\n"
        f"- Built-in guidance: {recovery.get('guidance', '')}\n"
        "- Rule of thumb: low recovery ⇒ advise rest/easy and protect sleep; moderate ⇒ "
        "Zone 2 only; high ⇒ pushing is fine."
    )


def coach_evidence(question: str) -> str:
    """Top-ranked evidence notes for the current question (same retrieval as insights)."""
    evidence_md, _ids = evidence_section(question, [])
    return evidence_md
