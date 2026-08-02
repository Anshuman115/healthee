"""Rows the CURRENT derivation would not write — finding them, and removing them (#118).

## The failure this closes

Every write to ``derived_daily`` is ``INSERT … ON CONFLICT DO UPDATE``, and nothing in
the product deletes from it. So a science fix that *changes* a number is fully repaired by
a re-derive, and a science fix that **narrows** what gets written is not repaired at all:
the new code declines to write, the old row survives, and the repair tool reports success
having changed nothing.

Measured on production 2026-08-02. #108 made ``profile.srpa`` a hard input to VO₂max, so
with it unanswered the derivation correctly writes no row — and **109 ``vo2max_estimate``
rows** computed under the mis-transcribed activity coding stayed exactly where they were,
the newest dated that same day. The read layer could not save it either: its withholding
asks "is the newest row keyed to today?" (``derive/freshness.py``), and the newest wrong
row *was* today's. The number the owner saw was produced by code that had been deleted.

That is a class, not an incident. Every future gate, tightened validity range or withdrawn
metric leaves the same residue, silently.

## How a row is judged, and why it is a timestamp

The question is "would today's code write this row?", and the only honest way to answer it
is to *run* today's code and see. Value and flags cannot answer it — a re-derive may
legitimately land the identical number — so the discriminator is
``derived_daily.derived_at`` (0016), which both writers of the table re-stamp on every
write, including a no-change one.

Hence the ONE rule these functions encode, and the ONE thing a caller must get right:

    **They must run inside the same transaction as the re-derive.**

``now()`` / ``transaction_timestamp()`` is fixed for a transaction, so every row the batch
wrote carries exactly that instant and :data:`_NOT_WRITTEN_BY_THIS_RUN` reads precisely as
"the re-derive that is still running did not produce this". Called from a fresh
transaction the predicate is true of *everything* and the answer is garbage. That is why
these take a cursor rather than opening a connection of their own — an unrelated
transaction cannot be handed to them by accident, only by choosing to.

## Bounds are not optional

Both functions are bounded by **owner** and by **local-day span**, and :func:`purge_stale`
is additionally bounded by an explicit **metric list** it will not invent. A repair tool
able to empty ``derived_daily`` is a worse hazard than the bug it was written for, so the
delete cannot be asked for in a way that means "everything": the caller names the metrics,
and an empty list deletes nothing (``metric = ANY('{}')`` matches no row).

The owner bound is doubled: the explicit ``user_id = %s`` predicate, and `0008`'s
row-level security on the connection these run on (standards §2 — RLS is the backstop, the
predicate is the filter).
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import date
from typing import LiteralString
from uuid import UUID

from psycopg import Cursor
from psycopg.rows import TupleRow

# A cursor over plain tuple rows, matching the derive layer's convention.
Cur = Cursor[TupleRow]

# The inclusive local-day span a run covers: (oldest, newest).
DaySpan = tuple[date, date]

# "No write in THIS transaction reached this row" — the one definition of stale, shared by
# the scan and the purge so the two can never disagree about what they are talking about.
# A hardcoded constant fragment, safe to interpolate into a query string (standards §2),
# and typed LiteralString so composing it keeps the result one. The owner and day bounds
# are deliberately NOT folded in here: they are spelled out at each call site, where the
# `user_id` predicate is visible to `tests/db/test_tenant_read_scoping.py`'s AST guard.
_NOT_WRITTEN_BY_THIS_RUN: LiteralString = "derived_at < transaction_timestamp()"

# The one thing "stale" cannot speak for: metrics produced behind a COMPUTE-ONCE gate that
# an ordinary re-derive does not re-open, mapped to the flag that re-opens each.
# ``derive/gps_scoring.py`` scores a recorded track at most once (`vo2max_submax IS NULL`),
# so every CORRECTLY scored session's daily row is untouched by a plain run and matches the
# predicate above while being perfectly current. Reporting those would make the stale
# warning cry wolf on every single run, and purging them would delete every GPS-measured
# estimate the product holds. So they are excluded from the report and refused by the purge
# until the gate is re-opened — refused rather than merely documented, because a footnote
# is not a guard. It lives here, next to the predicate, because it is a caveat ON that
# predicate rather than a fact about the CLI.
GATED_METRICS: dict[str, str] = {"vo2max_submax": "--rescore-tracks"}


def open_gates(*, rescore_tracks: bool) -> frozenset[str]:
    """The compute-once gates a run re-opened, named by the flag that re-opens them.

    A set rather than a boolean, and one entry today: a second gated derivation adds a row
    to :data:`GATED_METRICS` and a flag name here, and nothing else has to change.
    """
    return frozenset({"--rescore-tracks"}) if rescore_tracks else frozenset()


def gated_off(gates: frozenset[str]) -> tuple[str, ...]:
    """Metrics whose gate the run did NOT re-open — the ``ignore`` list for the scan."""
    return tuple(metric for metric, flag in GATED_METRICS.items() if flag not in gates)


def stale_counts(
    cur: Cur, user_id: UUID, span: DaySpan, *, ignore: Sequence[str] = ()
) -> dict[str, int]:
    """Per-metric counts of rows in ``span`` that the running re-derive did not write.

    The detection check, and it is deliberately not something an operator has to ask for:
    it is one aggregate over a window that was just rebuilt anyway, so a routine repair
    can afford to run it every time and say what it found. Nobody queried production by
    hand for two weeks; a check that must be requested is a check that does not happen.

    ``ignore`` drops metrics whose derivation sits behind a compute-once gate this run did
    not re-open — for those, "not rewritten" does not mean "not producible", and reporting
    them would make the warning cry wolf on every run. The caller owns that list because
    the caller owns the flag that re-opens the gate.
    """
    cur.execute(
        "SELECT metric, count(*)::int FROM derived_daily "
        "WHERE user_id = %s AND day >= %s AND day <= %s "
        f"AND {_NOT_WRITTEN_BY_THIS_RUN} AND metric <> ALL(%s::text[]) "
        "GROUP BY metric ORDER BY metric",
        (user_id, span[0], span[1], list(ignore)),
    )
    return {row[0]: row[1] for row in cur.fetchall()}


def purge_stale(cur: Cur, user_id: UUID, span: DaySpan, metrics: Sequence[str]) -> dict[str, int]:
    """Delete the named metrics' stale rows in ``span``; return what actually went.

    The counts come from the DELETE's own ``RETURNING`` rather than from a SELECT run
    beside it, so "109 rows removed" is the number of rows removed *by construction* and
    not a second query's opinion of it. A repair that reports an outcome it did not
    achieve is the exact failure this module exists to end.

    Destructive, and therefore never reached by a default: ``db/rederive.py`` requires
    both ``--purge-stale <metric …>`` and ``--apply`` before it calls this. The guarantee
    here is narrower and structural — it removes only rows whose metric the caller named,
    inside the owner and window it was given.
    """
    cur.execute(
        "WITH gone AS ("
        "  DELETE FROM derived_daily "
        "  WHERE user_id = %s AND day >= %s AND day <= %s "
        f"  AND {_NOT_WRITTEN_BY_THIS_RUN} AND metric = ANY(%s::text[]) "
        "  RETURNING metric"
        ") SELECT metric, count(*)::int FROM gone GROUP BY metric ORDER BY metric",
        (user_id, span[0], span[1], list(metrics)),
    )
    return {row[0]: row[1] for row in cur.fetchall()}


def describe(counts: dict[str, int]) -> str:
    """``"sleep_debt_min: 3, vo2max_estimate: 109"`` — an operator-readable breakdown.

    Per metric, because a total alone cannot tell "the fix worked, one metric withdrew its
    rows" apart from "the re-derive is broken and wrote nothing".
    """
    return ", ".join(f"{metric}: {count}" for metric, count in sorted(counts.items()))


__all__ = [
    "GATED_METRICS",
    "Cur",
    "DaySpan",
    "describe",
    "gated_off",
    "open_gates",
    "purge_stale",
    "stale_counts",
]
