"""Row access for `challenge` — the only place challenge SQL lives.

Split from :mod:`healthee.challenges.lifecycle` so the *rules* (when may a
challenge be adopted, what ends it, what does the owner see) read as rules rather
than as SQL with rules mixed in. Everything here is owner-scoped: every statement
carries ``AND user_id = %s`` even though `0008`'s RLS would also filter it, because
the explicit predicate is the clarity and the index use, and RLS is the backstop
(ENGINEERING_STANDARDS §2; the AST guard in ``tests/db`` fails the build without it).

Nothing here decides anything. A function that answers "should this happen" belongs
in ``lifecycle``; a function that answers "what is stored" belongs here.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, LiteralString, cast
from uuid import UUID

from healthee.derive._common import Cur

# The row shape the engine and the API both work in. Named explicitly rather than
# `SELECT *` so a column added by a future migration cannot silently change the
# shape of an API response.
_COLUMNS = (
    "id",
    "created_at",
    "gen_date",
    "title",
    "why",
    "category",
    "difficulty",
    "metric",
    "comparator",
    "target_value",
    "cadence",
    "window_days",
    "expected_outcome",
    "how_to",
    "research_note_ids",
    "status",
    "adopted_at",
    "ends_at",
    "completed_at",
    "abandoned_at",
    "baseline_value",
    "program_id",
    "rung_index",
)

_SELECT = ", ".join(_COLUMNS)  # a module constant of column names, never input


def _row(values: tuple) -> dict[str, Any]:
    """One ``challenge`` row as the mapping ``evaluate``/``adapt`` already take."""
    return dict(zip(_COLUMNS, values, strict=True))


def fetch(cur: Cur, user_id: UUID, challenge_id: int) -> dict[str, Any] | None:
    """One of ``user_id``'s challenges, or ``None``.

    ``None`` covers both "no such challenge" and "someone else's challenge", and
    the caller must not distinguish them: a 404 that becomes a 403 for the rows
    that exist confirms another tenant's ids (MULTI_USER.md §10).
    """
    # `_SELECT` is the module's own column-name constant, never caller input — the
    # only interpolation this codebase allows (standards §2). Bounds stay `%s`.
    query = cast(LiteralString, f"SELECT {_SELECT} FROM challenge WHERE user_id = %s AND id = %s")
    cur.execute(query, (user_id, challenge_id))
    row = cur.fetchone()
    return _row(row) if row else None


def list_by_status(
    cur: Cur, user_id: UUID, statuses: tuple[str, ...], limit: int = 50
) -> list[dict[str, Any]]:
    """``user_id``'s challenges in any of ``statuses``, newest first.

    ``limit`` is not optional in spirit: every list read is windowed
    (standards §Performance, "unbounded data is windowed"), and a finished-challenge
    list grows without bound over a life of use.
    """
    query = cast(  # `_SELECT` is a module constant — see `fetch`
        LiteralString,
        f"SELECT {_SELECT} FROM challenge WHERE user_id = %s AND status = ANY(%s) "
        "ORDER BY created_at DESC LIMIT %s",
    )
    cur.execute(query, (user_id, list(statuses), limit))
    return [_row(row) for row in cur.fetchall()]


def count_active(cur: Cur, user_id: UUID) -> int:
    """How many challenges ``user_id`` currently has running — the cap's input."""
    cur.execute(
        "SELECT count(*) FROM challenge WHERE user_id = %s AND status = 'active'", (user_id,)
    )
    row = cur.fetchone()
    return int(row[0]) if row else 0


def mark_adopted(
    cur: Cur,
    user_id: UUID,
    challenge_id: int,
    adopted_at: datetime,
    ends_at: datetime,
    baseline_value: float | None,
) -> bool:
    """Move a suggestion to ``active``. False ⇒ it was not still ``suggested``.

    The status predicate is IN THE STATEMENT, not a read-then-write in the caller:
    two adopt requests racing on the same suggestion would both pass a prior check
    and the second would reset the first's baseline — the anchor the whole
    before/after rests on. Here the loser updates zero rows and is told so.
    """
    cur.execute(
        "UPDATE challenge SET status = 'active', adopted_at = %s, ends_at = %s, "
        "  baseline_value = %s "
        "WHERE user_id = %s AND id = %s AND status = 'suggested'",
        (adopted_at, ends_at, baseline_value, user_id, challenge_id),
    )
    return cur.rowcount == 1


def set_target(cur: Cur, user_id: UUID, challenge_id: int, target_value: float) -> bool:
    """Move a live challenge's target. False ⇒ it was not active.

    The VALUE is never a caller's: ``lifecycle.apply_adaptation`` recomputes it from
    the owner's own rows before calling here (CHALLENGES.md §5.2 — a client may
    *request* an adaptation, it can never dictate the number). This function is one
    step away from that rule, which is why it says so.
    """
    cur.execute(
        "UPDATE challenge SET target_value = %s "
        "WHERE user_id = %s AND id = %s AND status = 'active'",
        (target_value, user_id, challenge_id),
    )
    return cur.rowcount == 1


def mark_abandoned(cur: Cur, user_id: UUID, challenge_id: int, at: datetime) -> bool:
    """End an active challenge at the owner's request. False ⇒ it was not active."""
    cur.execute(
        "UPDATE challenge SET status = 'abandoned', abandoned_at = %s "
        "WHERE user_id = %s AND id = %s AND status = 'active'",
        (at, user_id, challenge_id),
    )
    return cur.rowcount == 1


def mark_finished(cur: Cur, user_id: UUID, challenge_id: int, status: str, at: datetime) -> bool:
    """Close an active challenge as ``completed`` or ``expired``. False ⇒ not active.

    ``completed_at`` is stamped ONLY for ``completed``. An expired challenge was
    never completed, and writing the completion timestamp anyway is precisely the
    small confident lie `0009` added the status for — when it ended is already
    exact in ``ends_at``, and the freeze instant is the outcome row's ``ended_at``.
    """
    completed_at = at if status == "completed" else None
    cur.execute(
        "UPDATE challenge SET status = %s, completed_at = %s "
        "WHERE user_id = %s AND id = %s AND status = 'active'",
        (status, completed_at, user_id, challenge_id),
    )
    return cur.rowcount == 1
