"""The metered free allowance — a ROLLING seven-day, per-owner, per-feature ledger.

``PRICING.md`` §1a promises a free owner *"a metered taste of premium — 1 coach question
+ 1 daily-action reveal per rolling 7 days"*. 6.6a shipped the hard gate and deliberately
shipped no allowance constant with it ("a constant claiming an allowance nothing reads is
the same failure as a comment claiming a gate"); this module is the thing that reads it.

``api.gate`` is the only caller: entitlement is decided first, and this is consulted only
for an owner who is *not* premium. A premium owner never touches this table.

## Rolling, not calendar — and why that is a different mechanism

``core.rate_limit`` counts requests inside the owner's local CALENDAR day and resets at
their midnight. Reusing that shape here would have been a lie about the promise: a free
owner who asked their question at 23:50 on Monday would get a second one ten minutes
later. §1a says *rolling*, so the window is anchored to the USE, not to the clock — a
question asked at 21:00 local Monday comes back at 21:00 local Monday-a-week-later.

A rolling window cannot be one integer. It needs the INSTANTS of the recent uses, because
"how many in the last seven days" is only answerable from when they were. So the stored
value is a short list of use instants (epoch seconds, UTC), pruned to those still inside
the window and truncated to the newest ``limit`` — currently one number, in one row.

## Why this storage shape is not the leaky one

The obvious encoding puts a date in the kv KEY, which leaves a row per owner per period
forever — the leak #77 had just finished cleaning out of this very table (``0012``), where
``jobs.chain``'s marker was folded from ``job:chain_done:<day>`` into one self-resetting
row. It is not reintroduced here: the key is ``allowance:<feature>`` with no date in it,
the timestamps live in the VALUE, and the value is bounded twice over — every write drops
entries that have aged out of the window AND keeps at most ``limit`` of them. One row per
owner per metered feature for the life of the account, a couple of dozen bytes. Standards
§Performance: unbounded data is windowed.

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

# The window §1a specifies. Seven LOCAL days (see `_resets_at`), not 168 hours.
WINDOW_DAYS = 7

# The kv key namespace. The owner is deliberately not in the string — `kv`'s PRIMARY KEY
# already carries it (the argument `insights.cache` and `core.rate_limit` both make) — and
# neither is any date, which is the shape `0012` existed to remove.
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


def spend(user_id: UUID, tz: str, feature: str, limit: int, now: datetime | None = None) -> Verdict:
    """Record one use of ``feature`` against ``user_id``'s rolling window, if one is free.

    ``tz`` is the OWNER's zone: §1a's seven days are theirs, not the server's, and this
    repo has shipped the calendar-date-vs-instant bug three times by assuming otherwise.
    """
    now = _instant(now)
    key = _key(feature)
    with tenant_transaction(user_id) as cur:
        cur.execute(_CLAIM_SQL, (user_id, key))
        cur.execute(_LOCK_SQL, (user_id, key))
        row = cur.fetchone()
        if row is None:  # the INSERT above guarantees it; RLS would hide a row, not drop one
            raise RuntimeError(f"allowance row for {feature} vanished between insert and lock")
        window = _in_window(_decode(row[0]), tz, now)
        allowed = len(window) < limit
        if allowed:
            window = (window + [now])[-limit:] if limit > 0 else []
        cur.execute(_WRITE_SQL, (_encode(window), user_id, key))
    if not allowed:
        log.info(
            "free allowance spent: %s has used %d of %d for %s",
            user_id,
            len(window),
            limit,
            feature,
        )
    return _verdict(allowed=allowed, window=window, limit=limit, tz=tz, now=now)


def peek(user_id: UUID, tz: str, feature: str, limit: int, now: datetime | None = None) -> Verdict:
    """The same answer WITHOUT recording anything — for reporting, never for gating.

    ``GET /api/entitlement`` uses it to say which metered features are available right now.
    A gate must call :func:`spend`: deciding on a read and recording afterwards is the
    check-then-act race the lock inside :func:`spend` exists to close.
    """
    now = _instant(now)
    with tenant_transaction(user_id) as cur:
        cur.execute(_READ_SQL, (user_id, _key(feature)))
        row = cur.fetchone()
    window = _in_window(_decode(row[0] if row else ""), tz, now)
    return _verdict(allowed=len(window) < limit, window=window, limit=limit, tz=tz, now=now)


def refund(user_id: UUID, tz: str, feature: str, now: datetime | None = None) -> None:
    """Give back the most recent recorded use — for an attempt that delivered nothing.

    The taste is one call a week; losing it to a refusal, a transport failure or the honest
    fallback would mean an owner paid their whole allowance for a sentence that said "I
    can't answer that". ``core.rate_limit.refund`` established the pattern, and as there,
    the callers name their own no-value outcomes; this module only knows how to un-record.

    It can only ever REMOVE an instant, so it cannot mint allowance, and it removes only
    one still inside the window — a refund cannot reach into a window that has rolled.
    """
    now = _instant(now)
    key = _key(feature)
    with tenant_transaction(user_id) as cur:
        cur.execute(_LOCK_SQL, (user_id, key))
        row = cur.fetchone()
        if row is None:
            return
        window = _in_window(_decode(row[0]), tz, now)
        if window:
            window.pop()
        cur.execute(_WRITE_SQL, (_encode(window), user_id, key))


def _verdict(
    *, allowed: bool, window: list[datetime], limit: int, tz: str, now: datetime
) -> Verdict:
    """Shape the answer. The OLDEST recorded use is what decides when the next slot opens."""
    full = bool(window) and len(window) >= limit
    resets_at = _resets_at(window[0], tz) if full else now
    return Verdict(
        allowed=allowed,
        used=len(window),
        limit=limit,
        resets_at=resets_at,
        retry_after_s=max(0, math.ceil((resets_at - now).total_seconds())),
    )


def _resets_at(use: datetime, tz: str) -> datetime:
    """When a use made at ``use`` leaves the window — ``WINDOW_DAYS`` LOCAL days later.

    Built by moving the owner's local calendar date forward and keeping the wall-clock
    time, not by adding 168 hours: across a DST transition those are different instants,
    and what an owner is promised reads "next Monday evening", not "in 168 hours". Same
    construction as ``core.rate_limit._next_local_midnight``, for the same reason.
    """
    zone = ZoneInfo(tz)
    local = use.astimezone(zone)
    return datetime.combine(local.date() + timedelta(days=WINDOW_DAYS), local.time(), tzinfo=zone)


def _in_window(uses: list[datetime], tz: str, now: datetime) -> list[datetime]:
    """The recorded uses that have not yet rolled out, oldest first."""
    return [use for use in uses if now < _resets_at(use, tz)]


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


def _key(feature: str) -> str:
    return f"{_KEY_PREFIX}:{feature}"


__all__ = ["WINDOW_DAYS", "Verdict", "peek", "refund", "spend"]
