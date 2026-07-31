"""Row access for `program` and for the `challenge` rows that are its rungs.

WP-C4. The ladder's SQL, and only its SQL — the same split ``store``/``lifecycle``
already have, for the same reason: the rules read as rules when they are not
interleaved with statements.

**Why the rung SQL is here rather than in ``store``.** ``store``'s docstring claims to
be the one place challenge SQL lives, and this is the deliberate exception it names.
Every ladder operation spans BOTH tables in one breath — activate a rung *and* clear
the program's hold, insert a deload *and* renumber the rungs behind it — so splitting
by table would put one logical write in two modules and leave neither readable. The row
SHAPE is not duplicated: :data:`store.COLUMNS` / :data:`store.SELECT` / :func:`store.row`
are shared, so a column added by a future migration reaches both readers or neither.

Everything is owner-scoped. Every statement carries ``AND user_id = %s`` even where
`0008`'s RLS would also filter it, because the explicit predicate is the clarity and the
index use and RLS is the backstop (ENGINEERING_STANDARDS §2; the AST guard in
``tests/db`` fails the build without it). ``program_id`` is never trusted as a scope on
its own — a rung read carries the owner as well as the program, so a program id guessed
from another tenant selects nothing rather than somebody else's ladder.

Nothing here decides anything. "Should this rung activate" is ``ladder``'s question;
"what is stored" is this module's.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, LiteralString, cast
from uuid import UUID

from healthee.challenges import store
from healthee.derive._common import Cur

# The `program` row shape, named explicitly for the same reason `store.COLUMNS` is: a
# column added by a future migration must not silently change an API response.
COLUMNS = (
    "id",
    "created_at",
    "title",
    "why",
    "goal",
    "goal_metric",
    "category",
    "weeks",
    "status",
    "adopted_at",
    "completed_at",
    "ended_at",
    "ended_reason",
    "hold_reason",
)

_SELECT = ", ".join(COLUMNS)  # a module constant of column names, never input

# The statuses a rung may hold before it has been reached and after it has ended. Named
# here because three modules compare against them and a bare string in a WHERE clause is
# where a vocabulary starts drifting from `0010`'s CHECK.
LOCKED = "locked"
STANDARD = "standard"
DELOAD = "deload"


def row(values: tuple) -> dict[str, Any]:
    """One ``program`` row as a mapping."""
    return dict(zip(COLUMNS, values, strict=True))


def fetch(cur: Cur, user_id: UUID, program_id: int) -> dict[str, Any] | None:
    """One of ``user_id``'s programs, or ``None``.

    ``None`` covers both "no such program" and "someone else's program", and the caller
    must not distinguish them (MULTI_USER.md §10 — a 404 that becomes a 403 for the rows
    that exist confirms another tenant's ids).
    """
    # `_SELECT` is the module's own column-name constant, never caller input — the only
    # interpolation this codebase allows (standards §2). Bounds stay `%s`.
    query = cast(LiteralString, f"SELECT {_SELECT} FROM program WHERE user_id = %s AND id = %s")
    cur.execute(query, (user_id, program_id))
    found = cur.fetchone()
    return row(found) if found else None


def by_status(cur: Cur, user_id: UUID, statuses: tuple[str, ...], limit: int = 20) -> list[dict]:
    """``user_id``'s programs in any of ``statuses``, newest first (windowed)."""
    query = cast(  # `_SELECT` is a module constant — see `fetch`
        LiteralString,
        f"SELECT {_SELECT} FROM program WHERE user_id = %s AND status = ANY(%s) "
        "ORDER BY created_at DESC LIMIT %s",
    )
    cur.execute(query, (user_id, list(statuses), limit))
    return [row(found) for found in cur.fetchall()]


def active_program(cur: Cur, user_id: UUID) -> dict[str, Any] | None:
    """The owner's one live ladder, or ``None``.

    Singular by rule, not by luck: ``ladder.MAX_ACTIVE_PROGRAMS`` is 1 and
    ``programs.adopt`` enforces it. The ``LIMIT 1`` is what stops a violation of that
    rule from becoming a silently arbitrary answer here.
    """
    found = by_status(cur, user_id, ("active",), limit=1)
    return found[0] if found else None


def count_active_programs(cur: Cur, user_id: UUID) -> int:
    """How many ladders ``user_id`` currently has running — the one-program cap's input."""
    cur.execute("SELECT count(*) FROM program WHERE user_id = %s AND status = 'active'", (user_id,))
    found = cur.fetchone()
    return int(found[0]) if found else 0


# ── the rungs ─────────────────────────────────────────────────────────────────


def rungs(cur: Cur, user_id: UUID, program_id: int) -> list[dict[str, Any]]:
    """Every rung of one ladder, in ``rung_index`` order.

    Ordered, not sorted afterwards, because the order IS the ladder: ``ladder`` reads
    "the last settled rung" and "the next locked one" off this sequence, and a caller
    that re-sorted would be free to disagree with the index the renumbering maintains.
    """
    query = cast(  # `store.SELECT` is a module constant — see `fetch`
        LiteralString,
        f"SELECT {store.SELECT} FROM challenge WHERE user_id = %s AND program_id = %s "
        "ORDER BY rung_index",
    )
    cur.execute(query, (user_id, program_id))
    return [store.row(found) for found in cur.fetchall()]


def insert_program(cur: Cur, user_id: UUID, program: dict) -> int:
    """Persist one generated ladder as ``suggested``; returns its id (WP-C4b).

    ``status`` is hardcoded for the same reason ``store.insert_suggested`` hardcodes it:
    generating is not starting. Every rung goes in ``locked`` beside it
    (:func:`insert_rung`), and ``programs.adopt`` is the only thing that sets either
    running — which is what recalibrates rung 1 against the owner's baseline at the moment
    they actually commit.

    ``goal``/``goal_metric``/``weeks`` are DERIVED, never authored: ``program_screen``
    computes them from the corpus target and the rung windows, so no model number reaches
    this statement except the rung targets that passed the gates.
    """
    cur.execute(
        "INSERT INTO program (user_id, title, why, goal, goal_metric, category, weeks, status) "
        "VALUES (%s,%s,%s,%s,%s,%s,%s,'suggested') RETURNING id",
        (
            user_id,
            program["title"],
            program["why"],
            program["goal"],
            program["goal_metric"],
            program["category"],
            int(program["weeks"]),
        ),
    )
    found = cur.fetchone()
    if found is None:
        raise RuntimeError("INSERT ... RETURNING id produced no row")
    return int(found[0])


def delete_suggested_programs(cur: Cur, user_id: UUID) -> int:
    """Clear ``user_id``'s un-adopted ladders and their rungs; returns how many went.

    A regeneration REPLACES what is on offer, exactly as ``store.delete_suggestions``
    does for standalone challenges and for the same reason: a designed-but-unadopted
    ladder was calibrated against a baseline that has since moved, and rung 1 of it is a
    number about a person who is no longer here.

    **The rungs are deleted explicitly**, and that is not belt-and-braces:
    ``challenge.program_id`` is a bare ``BIGINT`` with no foreign key (`0001`), so nothing
    in the database would take them with the program. Only the ``app_user`` cascade ever
    cleans them up otherwise, and a locked rung whose program has gone is invisible
    history nothing can explain. Active programs are untouched — the ``status`` predicate
    is inside the subquery so a live ladder's rungs cannot be caught by it.
    """
    cur.execute(
        "DELETE FROM challenge WHERE user_id = %s AND program_id IN "
        "  (SELECT id FROM program WHERE user_id = %s AND status = 'suggested')",
        (user_id, user_id),
    )
    cur.execute("DELETE FROM program WHERE user_id = %s AND status = 'suggested'", (user_id,))
    return cur.rowcount


def mark_adopted(cur: Cur, user_id: UUID, program_id: int, at: datetime) -> bool:
    """Move a suggested program to ``active``. False ⇒ it was not still ``suggested``.

    The status predicate is IN THE STATEMENT for the same reason ``store.mark_adopted``
    puts it there: two adopt requests racing on one suggestion would both pass a prior
    check, and the second would restart a ladder the first had already begun.
    """
    cur.execute(
        "UPDATE program SET status = 'active', adopted_at = %s, hold_reason = NULL "
        "WHERE user_id = %s AND id = %s AND status = 'suggested'",
        (at, user_id, program_id),
    )
    return cur.rowcount == 1


def mark_ended(
    cur: Cur, user_id: UUID, program_id: int, status: str, reason: str | None, at: datetime
) -> bool:
    """Close an active program as ``completed`` / ``stalled`` / ``abandoned``.

    ``completed_at`` is stamped ONLY for ``completed`` — the same rule
    ``store.mark_finished`` follows, and for the same reason: a stalled ladder was never
    completed, and writing the completion timestamp anyway is the small confident lie
    `0009` and `0010` both added vocabulary to avoid. ``ended_at`` carries the instant for
    every terminal state, and ``hold_reason`` is cleared because a program that has ended
    is not waiting for anything.
    """
    cur.execute(
        "UPDATE program SET status = %s, ended_at = %s, ended_reason = %s, "
        "  completed_at = %s, hold_reason = NULL "
        "WHERE user_id = %s AND id = %s AND status = 'active'",
        (status, at, reason, at if status == "completed" else None, user_id, program_id),
    )
    return cur.rowcount == 1


def set_hold(cur: Cur, user_id: UUID, program_id: int, reason: str | None) -> None:
    """Record (or clear) why the next rung has not been activated.

    Written rather than recomputed at read time so the reason a surface shows is the one
    the advancement step actually acted on. ``None`` clears it, and clearing is not
    optional: a stale hold on a running ladder would tell the owner their program is
    paused while it is not.
    """
    cur.execute(
        "UPDATE program SET hold_reason = %s WHERE user_id = %s AND id = %s",
        (reason, user_id, program_id),
    )


def activate_rung(  # noqa: PLR0913 — one parameter per frozen fact, each named
    cur: Cur,
    user_id: UUID,
    rung_id: int,
    adopted_at: datetime,
    ends_at: datetime,
    baseline_value: float | None,
    target_value: float,
) -> bool:
    """Start a locked rung. False ⇒ it was not still ``locked``.

    The four values are frozen together in ONE statement because they are one fact: the
    target this rung was recalibrated to, the baseline it will be judged against, when it
    started and when it ends. Writing them separately would leave a window in which a
    rung is live against a target with no matching baseline — the anchor the whole
    before/after rests on (``lifecycle.adopt`` makes the same argument).

    ``target_value`` moving here is NOT a violation of ``bounds``' reject-never-clamp
    rule. That rule protects the model's COPY from disagreeing with the stored number,
    and the copy carries no number by construction (``bounds.copy_issue`` enforces it) —
    which is exactly why ``store.set_target`` may already move a live target when the
    adapter recalibrates. ``ladder`` recalibrates against the owner's CURRENT baseline
    for the same reason and under the same gate.
    """
    cur.execute(
        "UPDATE challenge SET status = 'active', adopted_at = %s, ends_at = %s, "
        "  baseline_value = %s, target_value = %s "
        "WHERE user_id = %s AND id = %s AND status = 'locked'",
        (adopted_at, ends_at, baseline_value, target_value, user_id, rung_id),
    )
    return cur.rowcount == 1


def shift_rungs_after(cur: Cur, user_id: UUID, program_id: int, rung_index: int) -> int:
    """Make room at ``rung_index + 1`` by pushing every later rung one step along.

    Renumbering is the price of modelling a deload as an INSERTED rung, and it is a
    price worth paying: ``rung_index`` is an ORDERING, not an identity. Every rung keeps
    its ``id``, the outcome ledger keys on that id and stores no index at all, and the
    resulting sequence is exactly the chronological order the ladder was actually
    climbed — which is the story the ledger has to be able to tell.
    """
    cur.execute(
        "UPDATE challenge SET rung_index = rung_index + 1 "
        "WHERE user_id = %s AND program_id = %s AND rung_index > %s",
        (user_id, program_id, rung_index),
    )
    return cur.rowcount


def insert_rung(  # noqa: PLR0913 — a row insert states every column it writes
    cur: Cur,
    user_id: UUID,
    program_id: int,
    rung_index: int,
    source: dict,
    *,
    target_value: float,
    kind: str,
) -> int:
    """Persist one ``locked`` rung copied from ``source``; returns its id.

    Every copied field is one the source row already carries, and that is the whole
    design of the deload: **no new prose is authored here.** A deload rung reuses the
    failed rung's ``title`` / ``why`` / ``how_to`` / ``expected_outcome`` /
    ``research_note_ids`` verbatim, so nothing ungrounded can enter through this door —
    text written here would bypass Gate B entirely, and there is no LLM in this path to
    ground it. ``kind='deload'`` is what says the rung is a step back; the copy does not
    have to, and the target is not in it by construction (``bounds.copy_issue``).

    ``difficulty`` is copied for the same reason: it was the label the model chose for
    this ask, and mechanically downgrading it would file a judgement nobody made.
    """
    cur.execute(
        "INSERT INTO challenge (user_id, gen_date, title, why, category, difficulty, "
        "  metric, comparator, target_value, cadence, window_days, expected_outcome, "
        "  how_to, research_note_ids, status, program_id, rung_index, kind) "
        "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'locked',%s,%s,%s) RETURNING id",
        (
            user_id,
            source.get("gen_date"),
            source["title"],
            source["why"],
            source["category"],
            source["difficulty"],
            source["metric"],
            source["comparator"],
            float(target_value),
            source["cadence"],
            int(source["window_days"]),
            source.get("expected_outcome"),
            source.get("how_to"),
            list(source.get("research_note_ids") or []),
            program_id,
            rung_index,
            kind,
        ),
    )
    found = cur.fetchone()
    if found is None:
        raise RuntimeError("INSERT ... RETURNING id produced no row")
    return int(found[0])
