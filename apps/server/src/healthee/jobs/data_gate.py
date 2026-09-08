"""Has the owner's day actually reached us yet? — the scheduler's arrival gate.

``scheduler.py``'s docstring claimed, for as long as it existed, that firing at 10:30
local meant the chain ran *"AFTER a typical late wake + app push, so recs/briefing
don't compute on last night's not-yet-synced sleep"*. Nothing checked. A grep of that
module for ``fresh``/``synced``/``has_data`` returned one constant, the retry budget.
The claim was a comment about a clock, and a clock cannot know whether a phone opened.

It is not hypothetical. The app's auto-sync fires only on a foreground transition, so
an owner who has not opened the app by their 10:30 has handed us nothing since
yesterday — and the chain ran anyway, deriving recommendations and writing a briefing
about a night no row in this database described. Then the per-owner per-day dedup
marker (``chain._chain_done``) recorded the day as DONE, so the real sleep arriving at
noon got no chain at all. The day's answer was fixed before its data existed.

That is the stale-as-current lie in its scheduler form, and this module is the check
that ends it: the chain for local day D does not start until something MEASURED on
day D has arrived.

## What counts as arrival, and why these two rows

``sample`` carrying an instant inside day D, **or** a ``sleep_session`` that WOKE on
day D. Either one means the phone has synced since the night: neither row can exist
before an ingest wrote it.

The OR is not belt-and-braces, and each arm covers a real state the other misses:

* **sleep alone is too narrow.** A night the strap was not worn produces no session at
  all. Gating on sleep would mean an owner who takes the strap off for one night gets
  no chain that day — and "you recorded no sleep last night" is a true and useful
  thing for the day to say, not a reason to skip it.
* **samples alone miss a known failure.** The per-minute stream demonstrably stalls
  (see the pager-stall work): a sync can hand over a staged night and no per-minute
  rows. The session is then the only evidence the sync happened.

## What this deliberately does NOT establish

It answers *"has day D's data arrived"*, not *"has ALL of day D's sleep arrived"*.
An owner who opens the app at 06:00, syncs, and then sleeps 06:00-09:00 opens this
gate on the pre-06:00 samples, and their 10:30 chain will not see that later sleep.
Closing that would need the strap to tell us it had nothing further to hand over, and
it does not. Named here rather than papered over: this gate removes the case where we
had *nothing* for the day, which is the one that was actually firing every morning.

## Why an unreadable gate raises rather than returning False

``SELECT EXISTS(...) OR EXISTS(...)`` always returns exactly one row holding one
boolean, so "no row" cannot happen and this module does not pretend to handle it: the
guard raises. An earlier draft returned ``False`` there, reasoning that failing shut is
the safe direction — and the mutation run refuted it, because no test could reach the
branch and the mutation flipping it to ``True`` survived. Unreachable defensive code
that no test can distinguish is the same shape as the ``or 0`` guards the audits found
sitting on ``NOT NULL`` columns: it reads as care and enforces nothing.

Raising is also the better behaviour on its merits. ``Sweeper._run_for`` supervises
this call, so the exception becomes a logged, Telegram-reported failed tick. An
unreadable gate is a failure to report, not a ``False`` to quietly act on — the
difference between "we could not tell whether your data arrived" and "your data has
not arrived", which are exactly the two things this whole module exists to stop
conflating.

Neither table records when a row ARRIVED — ``sample.ts`` and ``sleep_session.end_ts``
are measurement instants — so the question this module can honestly ask is "do we have
it", not "when did it land". For a gate that is the same question: a row present at
tick time got here before now.

## Why the UTC bracket and not ``(ts AT TIME ZONE %s)::date = %s``

The date-cast form is the idiom in ``challenges/series.py``, and it is right there —
those queries group BY local day. Here it would wrap the indexed column in a function,
losing both the index and Timescale's chunk pruning, on a query that runs for every
owner on every 5-minute tick over a hypertable. ``_day_bounds_utc`` is the same one
definition of a local day (half-open, DST-correct) in the sargable form the read layer
already uses for exactly this reason.
"""

from __future__ import annotations

from datetime import date
from uuid import UUID

from healthee.core.db import tenant_transaction
from healthee.derive._common import _day_bounds_utc

# One round trip, and `OR` short-circuits: on an ordinary morning the first `EXISTS`
# answers and the sleep table is never touched. Both arms carry `user_id` explicitly
# even though RLS already scopes the connection — the policy is the security boundary,
# the predicate is what lets the planner use `sample_user_idx` instead of scanning the
# chunk. (`/api/sleep` breached its budget 165x on exactly this distinction.)
_ARRIVED_SQL = """
SELECT EXISTS (SELECT 1 FROM sample
                WHERE user_id = %s AND ts >= %s AND ts < %s)
    OR EXISTS (SELECT 1 FROM sleep_session
                WHERE user_id = %s AND end_ts >= %s AND end_ts < %s)
"""


def day_data_arrived(user_id: UUID, day: date, tz: str) -> bool:
    """True once anything measured on the owner's local ``day`` is in the database.

    The half-open bracket is ``_day_bounds_utc``'s, so a row timestamped at the next
    local midnight belongs to tomorrow and cannot open today's gate — and a
    future-dated row cannot open it either, which matters because this decides whether
    a day is ready to be ANSWERED (``docs/AS_OF_DAY.md``: nothing measured after day D
    may inform day D's answer).
    """
    start_utc, end_utc = _day_bounds_utc(day, tz)
    with tenant_transaction(user_id) as cur:
        cur.execute(_ARRIVED_SQL, (user_id, start_utc, end_utc, user_id, start_utc, end_utc))
        row = cur.fetchone()
    if row is None:  # unreachable; see below
        raise RuntimeError("the arrival gate query returned no row")
    return bool(row[0])
