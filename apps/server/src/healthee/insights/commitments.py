"""What the owner said they would do — the coach's memory between conversations.

The coach is STATELESS: the client sends the whole thread on every turn and the
server keeps nothing, so every conversation starts cold. It cannot know what it
already advised and it cannot follow up on anything the owner agreed to. That is
the difference between grounded Q&A and a coach (`docs/COACH_ROADMAP.md` C1).

## Agreements, not transcripts

What has durable value is not what was SAID, it is what was AGREED. A transcript
would keep the most and prove the least; a commitment is one sentence, an optional
metric, and a date to look at it again. Everything else the coach re-derives from
data it already reads — and the roadmap's honesty guard says it must: the coach
never *remembers* a number, because a remembered number can be stale and a queried
one cannot.

## ⛔ Nothing here observes whether they did it

`status` moves only when a person says so. This app has no completion signal — the
whole `SuggestionRow` argument, one layer down — and a status inferred from a
metric moving would be exactly the claim the product refuses to make. A
commitment that was never resolved reads as `open` for ever, which is honest: we
asked, and we do not know.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from typing import Any
from uuid import UUID

from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger
from healthee.core.tenancy import user_today

log = get_logger(__name__)

#: How far ahead a check-in may be set. A behaviour change needs days to show in a
#: metric, and a horizon past this is a promise nobody will keep track of.
MIN_HORIZON_DAYS = 3
MAX_HORIZON_DAYS = 90

#: The default when the coach names none: long enough for a weekly pattern to exist.
DEFAULT_HORIZON_DAYS = 14

#: How many open commitments one owner may carry.
#:
#: Not a storage bound — a bound on what a person can actually hold in their head.
#: Five things you have agreed to change at once is not five commitments, it is a
#: list you have stopped reading, and the coach's own rule is that specific beats
#: comprehensive.
MAX_OPEN = 5

OPEN = "open"
KEPT = "kept"

#: How many resolved-kept commitments are read back as evidence. A short panel,
#: like every other evidence block: the newest few are the ones a conversation is
#: plausibly about, and a wide net over one person's history is a machine for
#: finding a coincidence.
EVIDENCE_LIMIT = 3


@dataclass(frozen=True)
class Commitment:
    """One agreement, as the coach is reminded of it."""

    id: int
    stated: str
    metric: str | None
    check_in_on: date
    created_at: Any

    def due(self, today: date) -> bool:
        """Whether it is time to ask about this one."""
        return self.check_in_on <= today


def open_commitments(user_id: UUID, limit: int = MAX_OPEN) -> list[Commitment]:
    """The owner's open agreements, soonest check-in first."""
    with tenant_transaction(user_id) as cur:
        cur.execute(
            "SELECT id, stated, metric, check_in_on, created_at FROM coach_commitment "
            "WHERE user_id = %s AND status = %s ORDER BY check_in_on LIMIT %s",
            (str(user_id), OPEN, limit),
        )
        rows = cur.fetchall()
    return [Commitment(r[0], r[1], r[2], r[3], r[4]) for r in rows]


def record(user_id: UUID, tz: str, stated: str, metric: str | None, days: int | None) -> dict:
    """Store one agreement. Returns the stored row, or a named refusal.

    The horizon is clamped rather than rejected: a coach that said "14 days" when
    the owner said "a month" is a small wrong, and refusing the whole commitment
    over it loses the agreement entirely.
    """
    stated = (stated or "").strip()
    if not stated:
        return {"ok": False, "reason": "no_commitment", "error": "say what they agreed to"}
    horizon = _clamp_horizon(days)
    today = user_today(tz)
    with tenant_transaction(user_id) as cur:
        cur.execute(
            "SELECT count(*) FROM coach_commitment WHERE user_id = %s AND status = %s",
            (str(user_id), OPEN),
        )
        row = cur.fetchone()
        if row is not None and row[0] >= MAX_OPEN:
            return {
                "ok": False,
                "reason": "too_many_open",
                "error": f"they are already carrying {MAX_OPEN} open commitments. Ask "
                "which one to drop before adding another — a list nobody reads is not "
                "a commitment.",
            }
        cur.execute(
            "INSERT INTO coach_commitment (user_id, stated, metric, check_in_on) "
            "VALUES (%s, %s, %s, %s) RETURNING id, check_in_on",
            (str(user_id), stated[:500], metric, today + timedelta(days=horizon)),
        )
        stored = cur.fetchone()
    if stored is None:  # INSERT ... RETURNING always yields the row it wrote
        raise RuntimeError("coach_commitment insert returned no id")
    return {
        "ok": True,
        "commitment": {
            "id": stored[0],
            "stated": stated,
            "metric": metric,
            "check_in_on": stored[1].isoformat(),
        },
    }


def resolve(user_id: UUID, commitment_id: int, status: str) -> dict:
    """Close one agreement with what the OWNER said became of it.

    The owner is a predicate on the UPDATE, so closing somebody else's matches no
    row rather than being rejected — the same shape `device_token` revocation uses,
    for the same reason.
    """
    if status not in _RESOLUTIONS:
        return {"ok": False, "reason": "bad_status", "error": f"one of {sorted(_RESOLUTIONS)}"}
    with tenant_transaction(user_id) as cur:
        cur.execute(
            "UPDATE coach_commitment SET status = %s, resolved_at = now() "
            "WHERE id = %s AND user_id = %s AND status = %s RETURNING id",
            (status, commitment_id, str(user_id), OPEN),
        )
        row = cur.fetchone()
    if row is None:
        return {"ok": False, "reason": "not_open", "error": "no open commitment with that id"}
    return {"ok": True, "commitment_id": row[0], "status": status}


#: What an owner can say became of a commitment. **No `succeeded`/`failed`** — those
#: would be verdicts on a person, and nothing here measured anything.
_RESOLUTIONS = frozenset({"kept", "missed", "dropped"})


def _clamp_horizon(days: int | None) -> int:
    if days is None:
        return DEFAULT_HORIZON_DAYS
    try:
        asked = int(days)
    except (TypeError, ValueError):
        return DEFAULT_HORIZON_DAYS
    return max(MIN_HORIZON_DAYS, min(asked, MAX_HORIZON_DAYS))


def kept_with_metric(user_id: UUID, limit: int = EVIDENCE_LIMIT) -> list[Commitment]:
    """Commitments the owner said they KEPT, that name a metric, newest first.

    Both filters are the honest ones. `kept` because a missed or dropped
    commitment is not a behaviour change and its metric moving says nothing; a
    metric because a before/after needs something to compare, and the nullable
    column is exactly where "I'll get to bed earlier" lives.

    `created_at` orders them: the commitment's own date is when the change starts,
    and it is what `commitment_outcome` anchors its windows on.
    """
    with tenant_transaction(user_id) as cur:
        cur.execute(
            "SELECT id, stated, metric, check_in_on, created_at FROM coach_commitment "
            "WHERE user_id = %s AND status = %s AND metric IS NOT NULL "
            "ORDER BY created_at DESC LIMIT %s",
            (str(user_id), KEPT, limit),
        )
        rows = cur.fetchall()
    return [Commitment(r[0], r[1], r[2], r[3], r[4]) for r in rows]
