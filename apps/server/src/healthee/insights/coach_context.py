"""The coach's CONTEXT — history-rich, not a snapshot (WP5b / COACH_PROMPT.md).

COACH_PROMPT.md requires the coach reason over the person's *history and routines*,
not just today: a wide (≥30-day) metric window with trends + baselines, and the
recent logged-intervention history (fasting/caffeine/alcohol/meditation/workouts)
with enough depth to reveal a recurring schedule. Almost all of that already lives
in the v2-native ``build_context`` (today snapshot, trends, recent-daily pivot,
sleep sessions, the manual-entry log over the window, baselines, anomalies,
personal findings) — we reuse it wholesale (standards §Duplication) at a wider
default window and add today's recovery so "what should I do today?" respects it.

WP-C5 adds the third block: the person's challenges and their FROZEN OUTCOMES
(``challenge_context``). INTELLIGENCE §4 recorded both as "not present" while the
subsystem did not exist; the ledger half is COACH_ROADMAP C2 — measured personal
evidence, cited as ``[personal_finding:…]`` and never dressed as research. The
caveats that make it honest are structural and argued in that module.
"""

from __future__ import annotations

from uuid import UUID

from healthee.core.db import tenant_transaction
from healthee.insights import pipeline
from healthee.insights.challenge_context import challenge_section
from healthee.read.recovery import (
    STALE_RECOVERY_DIRECTIVE,
    recovery_freshness,
    recovery_score_payload,
)

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
    context = pipeline.user_context(question, user_id, tz, days=days)
    with tenant_transaction(user_id) as cur:
        recovery = recovery_score_payload(cur, user_id, tz)
        challenges = challenge_section(cur, user_id)
    parts = [context, _recovery_block(recovery, tz), challenges]
    return "\n\n".join(p for p in parts if p)


def _recovery_block(recovery: dict | None, tz: str) -> str:
    """The owner's recovery so intensity advice respects it (deterministic, not LLM).

    Headed "Today's recovery" ONLY when it is today's. ``recovery_score_payload`` has
    always carried ``date``; this dropped it and asserted "today", so a stale score set
    the model's intensity ceiling as if it were current (``read/recovery.py``).
    """
    if not recovery:
        return ""
    factors = ", ".join(
        f"{name} {vals.get('sub')}" for name, vals in (recovery.get("factors") or {}).items()
    )
    stale = recovery_freshness(recovery, tz)
    return (
        _recovery_heading(recovery, stale)
        + f"- Factor sub-scores: {factors}.\n"
        + f"- Built-in guidance: {recovery.get('guidance', '')}\n"
        + "- Rule of thumb: low recovery ⇒ advise rest/easy and protect sleep; moderate ⇒ "
        "Zone 2 only; high ⇒ pushing is fine."
    )


def _recovery_heading(recovery: dict, stale: dict | None) -> str:
    """The heading + score line — the two lines that made the "today" claim.

    Live readiness is dropped when the score is stale, not just relabelled: the intraday
    decay only applies on the score's OWN day (``read/recovery._live_readiness`` returns
    the morning value unchanged otherwise), so quoting "live readiness" for an older day
    would name a number that has not decayed against anything.
    """
    if stale is None:
        return (
            "## Today's recovery [recovery_readiness] — let it set intensity advice\n"
            f"- Recovery {recovery['recovery']}/100, live readiness {recovery['readiness']} "
            f"({recovery['band']}).\n"
        )
    return (
        f"## Most recent recovery — from {stale['last_as_of_date']}, "
        f"{stale['age_days']} day(s) ago [recovery_readiness]\n"
        f"- Recovery {recovery['recovery']}/100 ({recovery['band']}) AS OF "
        f"{stale['last_as_of_date']}. {STALE_RECOVERY_DIRECTIVE}\n"
    )


def coach_evidence(question: str) -> str:
    """Top-ranked evidence notes for the current question (the SAME retrieval stage).

    Through ``pipeline.evidence`` rather than ``retrieval.evidence_section`` directly, so
    "same retrieval as insights" is a fact the AST guard in
    ``tests/insights/test_pipeline_shared.py`` enforces rather than a comment.
    """
    evidence_md, _ids = pipeline.evidence(question)
    return evidence_md
