"""The metered allowance — a ROLLING, per-owner, per-feature, per-WINDOW ledger.

Two priced windows run on this one mechanism, and ``api.gate`` owns both numbers:

* a **premium** owner's included coach questions — ``PRICING.md`` §0's decided cap, 20
  per rolling 30 local days;
* a **free** owner's metered taste, which §1a now prices at **zero** on every feature.
  The path stays live because the table stays live: re-granting a taste is a number in
  ``gate.FREE_ALLOWANCE``, not a rewrite of this module.

``api.gate`` is the only caller, and it decides entitlement first, so exactly one of those
two windows applies to any one request.

## Rolling, not calendar — and why that is a different mechanism

``core.rate_limit`` counts requests inside the owner's local CALENDAR day and resets at
their midnight. Reusing that shape here would have been a lie about the promise: an owner
who asked their last question at 23:50 on Monday would get another ten minutes later. The
window is anchored to the USE, not to the clock — a question asked at 21:00 local Monday
comes back at 21:00 local Monday-a-week-later — which is also why the premium cap is a
rolling 30 days rather than a calendar month: a month would let an owner spend the whole
cap on the 31st and the whole cap again on the 1st.

A rolling window cannot be one integer. It needs the INSTANTS of the recent uses, because
"how many in the last seven days" is only answerable from when they were. So the stored
value is a short list of use instants (epoch seconds, UTC), pruned to those still inside
the window and truncated to the newest ``limit`` — currently one number, in one row.

## Why this storage shape is not the leaky one

The obvious encoding puts a date in the kv KEY, which leaves a row per owner per period
forever — the leak #77 had just finished cleaning out of this very table (``0012``), where
``jobs.chain``'s marker was folded from ``job:chain_done:<day>`` into one self-resetting
row. It is not reintroduced here: the key is ``allowance:<feature>:<window_days>d`` with
no date in it, the timestamps live in the VALUE, and the value is bounded twice over —
every write drops entries that have aged out of the window AND keeps at most ``limit`` of
them. Standards §Performance: unbounded data is windowed.

**The window length is in the key, and it has to be**, because a stored instant means
nothing without it: a use recorded ten days ago is outside a 7-day window and inside a
30-day one. One key shared by both would let a lapsed premium owner's questions be read
under the free window and a re-granted free taste be read under the premium one — each
side silently spending the other's ledger. It is a fixed per-tier constant, not a date, so
the row count stays bounded: one row per owner per (feature, window) that owner has ever
used, a couple of dozen bytes each. ``0015`` deleted the old un-suffixed rows.

``limit`` is passed in on every call rather than stored, so lowering it later tightens the
next write instead of needing a migration, and raising it takes effect immediately.

## A refused attempt is NOT recorded — the one place this inverts ``rate_limit``

``rate_limit.spend`` increments on refusals too, because it counts *requests* and a caller
hammering a closed door is exactly what its number should show. Doing that here would be a
bug with teeth: every refused attempt would push a fresh instant into the window, the
window would never roll, and an owner who tapped twice would be locked out **forever**.
This ledger records only the uses that were actually granted.

## Concurrency: a row lock, not one self-modifying statement

``rate_limit`` does its whole spend in one ``INSERT … ON CONFLICT DO UPDATE`` so that two
racing requests cannot both read "one used" and both proceed. That trick does not survive
the change of shape. This operation is a *set edit* — prune, decide, maybe append — that
must also report **whether it appended**, and a statement returning only the new value
cannot say: two requests in the same second would leave a stored list containing "now"
either way, and both callers would read that as a grant. So the serialization is explicit:
``SELECT … FOR UPDATE`` inside one transaction, which makes the second request wait for
the first to commit and then read the truth. Correctness by a lock a reader can see beats
correctness by an invariant a reader has to reconstruct — and this path runs about once a
week per free owner, not once per request.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger

log = get_logger(__name__)

# The DEFAULT window — seven LOCAL days (see `_resets_at`), not 168 hours. It is a
# default and not the only value: `api.gate` passes 30 for the premium coach cap. The
# priced windows live there, next to the tables that price them; this is the fallback for
# a caller that does not care, and the one §1a's metered taste was written against.
WINDOW_DAYS = 7

# The kv key namespace. The owner is deliberately not in the string — `kv`'s PRIMARY KEY
# already carries it (the argument `insights.cache` and `core.rate_limit` both make) — and
# neither is any date, which is the shape `0012` existed to remove. The WINDOW is in it
# (see the module docstring): the same instants mean different things under different
# window lengths, so one key for both would have the two tiers spending each other's rows.
_KEY_PREFIX = "allowance"

# The value is `"<epoch-s>,<epoch-s>,…"`, oldest first. Whole seconds: the window is a
# week, sub-second resolution would buy nothing, and integers round-trip exactly where a
# float count of microseconds would not.
_SEPARATOR = ","

# Create the row if it is missing so the lock below always has something to hold. An empty
# value is a real state (no uses on record) and decodes to an empty window.
_CLAIM_SQL = (
    "INSERT INTO kv (user_id, key, value) VALUES (%s, %s, '') ON CONFLICT (user_id, key) DO NOTHING"
)
_LOCK_SQL = "SELECT value FROM kv WHERE user_id = %s AND key = %s FOR UPDATE"
_READ_SQL = "SELECT value FROM kv WHERE user_id = %s AND key = %s"
_WRITE_SQL = "UPDATE kv SET value = %s WHERE user_id = %s AND key = %s"


@dataclass(frozen=True)
class Verdict:
    """What one attempt found, and when the next slot opens.

    ``used`` is the number of uses ON RECORD inside the window *after* this call — so it
    includes this attempt when it was granted and does not when it was refused, because a
    refusal is never recorded (see the module docstring).

    ``resets_at`` is the instant the owner may use the feature again: when the window is
    full, the moment the oldest recorded use ages out; when a slot is still free, ``now``.
    It travels because "try again later" with no *when* is the vague refusal standards
    §Errors forbids, and because a locked card that can name the day is an honest one.
    """

    allowed: bool
    used: int
    limit: int
    resets_at: datetime
    retry_after_s: int


def spend(
    user_id: UUID,
    tz: str,
    feature: str,
    limit: int,
    now: datetime | None = None,
    *,
    window_days: int = WINDOW_DAYS,
) -> Verdict:
    """Record one use of ``feature`` against ``user_id``'s rolling window, if one is free.

    ``tz`` is the OWNER's zone: the window's days are theirs, not the server's, and this
    repo has shipped the calendar-date-vs-instant bug three times by assuming otherwise.
    """
    now = _instant(now)
    key = _key(feature, window_days)
    with tenant_transaction(user_id) as cur:
        cur.execute(_CLAIM_SQL, (user_id, key))
        cur.execute(_LOCK_SQL, (user_id, key))
        row = cur.fetchone()
        if row is None:  # the INSERT above guarantees it; RLS would hide a row, not drop one
            raise RuntimeError(f"allowance row for {feature} vanished between insert and lock")
        window = _in_window(_decode(row[0]), tz, now, window_days)
        allowed = len(window) < limit
        if allowed:
            window = (window + [now])[-limit:] if limit > 0 else []
        cur.execute(_WRITE_SQL, (_encode(window), user_id, key))
    if not allowed:
        log.info(
            "allowance spent: %s has used %d of %d for %s in %d days",
            user_id,
            len(window),
            limit,
            feature,
            window_days,
        )
    return _verdict(
        allowed=allowed, window=window, limit=limit, tz=tz, now=now, window_days=window_days
    )


def peek(
    user_id: UUID,
    tz: str,
    feature: str,
    limit: int,
    now: datetime | None = None,
    *,
    window_days: int = WINDOW_DAYS,
) -> Verdict:
    """The same answer WITHOUT recording anything — for reporting, never for gating.

    ``GET /api/entitlement`` uses it to say which metered features are available right now.
    A gate must call :func:`spend`: deciding on a read and recording afterwards is the
    check-then-act race the lock inside :func:`spend` exists to close.
    """
    now = _instant(now)
    with tenant_transaction(user_id) as cur:
        cur.execute(_READ_SQL, (user_id, _key(feature, window_days)))
        row = cur.fetchone()
    window = _in_window(_decode(row[0] if row else ""), tz, now, window_days)
    return _verdict(
        allowed=len(window) < limit,
        window=window,
        limit=limit,
        tz=tz,
        now=now,
        window_days=window_days,
    )


def refund(
    user_id: UUID,
    tz: str,
    feature: str,
    now: datetime | None = None,
    *,
    window_days: int = WINDOW_DAYS,
) -> None:
    """Give back the most recent recorded use — for an attempt that delivered nothing.

    A premium owner's questions are counted and finite; losing one to a refusal, a
    transport failure or the honest fallback would mean billing a slot for an answer we
    did not deliver, which is the honesty contract applied to the meter.
    ``core.rate_limit.refund`` established the pattern, and as there, the callers name
    their own no-value outcomes; this module only knows how to un-record.

    ``window_days`` must be the one the charge was made under — the caller carries it
    (``gate._CHARGED_ATTR``) rather than re-deriving it, because a subscription that
    changed mid-request would re-derive the wrong one and refund a row nobody wrote.

    It can only ever REMOVE an instant, so it cannot mint allowance, and it removes only
    one still inside the window — a refund cannot reach into a window that has rolled.
    """
    now = _instant(now)
    key = _key(feature, window_days)
    with tenant_transaction(user_id) as cur:
        cur.execute(_LOCK_SQL, (user_id, key))
        row = cur.fetchone()
        if row is None:
            return
        window = _in_window(_decode(row[0]), tz, now, window_days)
        if window:
            window.pop()
        cur.execute(_WRITE_SQL, (_encode(window), user_id, key))


def _verdict(
    *, allowed: bool, window: list[datetime], limit: int, tz: str, now: datetime, window_days: int
) -> Verdict:
    """Shape the answer. The OLDEST recorded use is what decides when the next slot opens."""
    full = bool(window) and len(window) >= limit
    resets_at = _resets_at(window[0], tz, window_days) if full else now
    return Verdict(
        allowed=allowed,
        used=len(window),
        limit=limit,
        resets_at=resets_at,
        retry_after_s=max(0, math.ceil((resets_at - now).total_seconds())),
    )


def _resets_at(use: datetime, tz: str, window_days: int) -> datetime:
    """When a use made at ``use`` leaves the window — ``window_days`` LOCAL days later.

    Built by moving the owner's local calendar date forward and keeping the wall-clock
    time, not by adding N×24 hours: across a DST transition those are different instants,
    and what an owner is promised reads "next Monday evening", not "in 168 hours". Same
    construction as ``core.rate_limit._next_local_midnight``, for the same reason — and it
    is the reason ``window_days`` is threaded through rather than read from a constant:
    thirty days must be thirty LOCAL days in exactly the way seven already was.
    """
    zone = ZoneInfo(tz)
    local = use.astimezone(zone)
    return datetime.combine(local.date() + timedelta(days=window_days), local.time(), tzinfo=zone)


def _in_window(uses: list[datetime], tz: str, now: datetime, window_days: int) -> list[datetime]:
    """The recorded uses that have not yet rolled out, oldest first."""
    return [use for use in uses if now < _resets_at(use, tz, window_days)]


def _instant(now: datetime | None) -> datetime:
    """The attempt's instant in UTC — absolute, so a stored use survives a zone change."""
    return (now or datetime.now(tz=UTC)).astimezone(UTC)


def _decode(value: str) -> list[datetime]:
    """Parse the stored list. A malformed entry is dropped and logged, never trusted.

    Failing OPEN here is deliberate and bounded: the worst case is one extra free call for
    one owner whose row somebody corrupted, weighed against a hard failure on every AI
    request that owner makes.
    """
    uses: list[datetime] = []
    for part in value.split(_SEPARATOR):
        if not part:
            continue
        try:
            uses.append(datetime.fromtimestamp(int(part), tz=UTC))
        except ValueError:
            log.warning("allowance ledger holds an unparseable instant %r — dropping it", part)
    return sorted(uses)


def _encode(uses: list[datetime]) -> str:
    return _SEPARATOR.join(str(int(use.timestamp())) for use in sorted(uses))


def _key(feature: str, window_days: int) -> str:
    return f"{_KEY_PREFIX}:{feature}:{window_days}d"


__all__ = ["WINDOW_DAYS", "Verdict", "peek", "refund", "spend"]
