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

## What counts as arrival: the night, and only later anything else

The gate opens on a ``sleep_session`` of kind ``main`` that **WOKE on day D**. That is
the row the morning's analysis is actually about, and it cannot exist before an ingest
wrote it, so its presence is proof the phone has synced since the night.

**An earlier version of this gate accepted any sample measured on day D, and that was
wrong in a way this owner would have hit the same night it shipped.** A local day
begins at midnight; a chronic short sleeper is awake then. Opening the app at 00:54
syncs an hour of post-midnight heart rate — all of it stamped day D — and the gate
opens on it. Sleep 02:00-06:00, don't reopen the app, and 10:30 computes the day
without its night: the original defect, intact, wearing the fix as a hat. Data
measured on a day is not the same fact as the day being answerable, and only the
second one is this module's question.

## The strap-off fallback, and why it is a caller's decision

Requiring the night flatly would mean an owner who took the strap off got no chain at
all that day — and "you recorded no sleep last night" is a true and useful thing for a
day to say, not a reason to skip it. So ``allow_without_night`` widens the gate to any
sample measured on the day, and the scheduler turns it on at ``SLEEP_FALLBACK``
(14:00 local), never earlier.

The hour is a judgement, not a measurement, and is named as one: by early afternoon a
night that was going to be handed over has been. It lives in ``scheduler.py`` as one
constant beside the other fire times, because it is a policy about clocks and this
module deliberately knows nothing about clocks — it is handed a day and a boolean.

The cost of the split is one thing worth stating plainly: a strap-off day's chain now
lands at 14:00 rather than 10:30. That is the trade — a few hours' latency on the days
with no night, to stop fabricating on the days that have one.

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

# The NIGHT is the first arm and the only one that counts early in the day; the
# second is the strap-off fallback and is switched off by the caller until then.
# `OR` short-circuits, so a day whose night has landed never touches `sample`.
#
# Both arms carry `user_id` explicitly even though RLS already scopes the connection —
# the policy is the security boundary, the predicate is what lets the planner use the
# owner index instead of scanning the chunk. (`/api/sleep` breached its budget 165x on
# exactly this distinction.)
#
# `kind = 'main'` and not any session: a 02:00 nap ends on day D and would otherwise
# announce that D's night had arrived. Waiting for the real one is the whole point.
_ARRIVED_SQL = """
SELECT EXISTS (SELECT 1 FROM sleep_session
                WHERE user_id = %s AND kind = 'main'
                  AND end_ts >= %s AND end_ts < %s)
    OR (%s AND EXISTS (SELECT 1 FROM sample
                        WHERE user_id = %s AND ts >= %s AND ts < %s))
"""


def day_data_arrived(user_id: UUID, day: date, tz: str, allow_without_night: bool = False) -> bool:
    """True once the owner's local ``day`` is ready to be answered for.

    Ready means **the night that woke on ``day`` is in the database**. Only when
    ``allow_without_night`` — which the scheduler turns on at ``SLEEP_FALLBACK``, not
    before — does any sample measured on the day also count.

    The half-open bracket is ``_day_bounds_utc``'s, so a row timestamped at the next
    local midnight belongs to tomorrow and cannot open today's gate — and a
    future-dated row cannot open it either, which matters because this decides whether
    a day is ready to be ANSWERED (``docs/AS_OF_DAY.md``: nothing measured after day D
    may inform day D's answer).
    """
    start_utc, end_utc = _day_bounds_utc(day, tz)
    with tenant_transaction(user_id) as cur:
        cur.execute(
            _ARRIVED_SQL,
            (user_id, start_utc, end_utc, allow_without_night, user_id, start_utc, end_utc),
        )
        row = cur.fetchone()
    if row is None:  # unreachable; see the module docstring
        raise RuntimeError("the arrival gate query returned no row")
    return bool(row[0])
