"""The ``briefing`` chain step — the morning "daily-insight" Telegram message.

A short grounded summary of where the user stands today, generated THROUGH the
choke point (``grounded_ask`` → v2 context, cited, blocking-validated) and sent
via ``core.notify`` (which never raises and no-ops cleanly when Telegram is
unconfigured). Honest by construction: a flat or below-par day is reported as
such, and if the model can't ground a claim the choke point returns its honest
fallback — which we still send, plainly, rather than inventing an upbeat line.
"""

from __future__ import annotations

from datetime import date
from uuid import UUID

from healthee.core.logging import get_logger
from healthee.core.notify import send_telegram
from healthee.core.tenancy import user_today
from healthee.insights.client import LLMClient
from healthee.insights.grounded import grounded_ask

log = get_logger(__name__)

BRIEFING_METRICS = ["recovery_score", "hrv_sleep_avg", "sleep_health_score_4dim", "mvpa_min"]

BRIEFING_TASK = (
    "Give me a SHORT morning briefing (3–5 lines) on where I stand today, using my "
    "real numbers: my recovery/readiness and what training intensity that supports; "
    "the ONE thing most off my personal baseline; and today's single most useful "
    "action. Be honest — if it's a flat or below-par day, say so plainly, no "
    "cheerleading. Cite [note_id] for every health claim. No diagnosis, no alarmism."
)


def send_briefing(
    user_id: UUID, tz: str, day: date | None = None, *, client: LLMClient | None = None
) -> dict:
    """Generate ``user_id``'s grounded briefing and Telegram it. Returns a status dict.

    ``day`` defaults to the OWNER's local today (from their ``tz``), not a global one.
    ``client`` is injectable for tests. Errors from generation propagate to the
    supervised chain runner; the Telegram send itself never raises (``core.notify``).
    """
    day = day or user_today(tz)
    result = grounded_ask(
        BRIEFING_TASK,
        user_id,
        tz,
        metrics=BRIEFING_METRICS,
        context_days=14,
        client=client,
    )
    message = _compose(day, result.text)
    sent = send_telegram(message)
    log.info(
        "briefing[%s] %s: sent=%s validated=%s refused=%s",
        user_id,
        day,
        sent,
        result.validated,
        result.refused,
    )
    return {
        "ok": True,
        "day": day.isoformat(),
        "sent": sent,
        "validated": result.validated,
        "refused": result.refused,
    }


def _compose(day: date, body: str) -> str:
    """Date-stamped header + the grounded body (never presented as undated)."""
    return f"healthee briefing — {day.isoformat()}\n\n{body}"
