"""Per-owner daily spend limits, on the ``kv`` table.

The first rate limiter in this codebase (``MULTI_USER.md`` §11 lists rate limiting as
unbuilt), and it exists for one reason: WP-C3b/C4b put an endpoint in front of the
grounded generation pipeline, so an owner who holds the button down spends our LLM
budget (``PRICING.md`` §6.3 calls free-tier cost control existential). Everything else
that reaches the choke point is either nightly (deduped per owner per day, ``jobs.chain``)
or cached per day (``insights.cache``); generation is the first surface a client can ask
for on demand, as often as it likes.

## What this is NOT

It is **not** §12.3's free-tier metering (``require_ai_access`` — premium OR one coach
question per rolling seven days). That gate answers *may this person use an AI feature at
all*, it is entitlement, it does not exist yet, and it lands with 6.6. This one answers
*how often may anyone, premium included, spend on this*, and it is abuse/cost protection.
They compose rather than replace: when 6.6 lands, entitlement is checked first and this
budget still bounds a paying owner's spend. Conflating them would either give a free user
a paid allowance or wall a paying one out.

## Why ``kv`` rather than a table of its own

``kv`` is already per-owner (`0004` folded ``user_id`` into its PRIMARY KEY) and it is
already what ``jobs.chain``'s per-day marker and ``insights.cache``'s per-day payload use
for exactly this shape. A new table would need a migration, an RLS policy and a grant to
carry one integer per owner.

## One row per owner per feature, self-resetting — deliberately not one per DAY

The obvious encoding puts the date in the KEY, which leaves one row per owner per day in
``kv`` forever — a small unbounded growth that nothing sweeps. Here the date is in the
VALUE instead (``"<iso-day>:<count>"``) and a spend on a new day overwrites the old count,
so the table carries exactly one row per owner per feature for the life of the account.
Standards §Performance: unbounded data is windowed.

``jobs.chain``'s dedup marker used to be the counter-example this paragraph named
(``job:chain_done:<day>``); #77 folded it into the same one-row-per-owner shape and `0012`
cleaned up the rows it had already left behind. There is now no key in this table that
carries a date.

The whole spend is ONE statement, so two concurrent requests cannot both read "2 used"
and both proceed — the second one's ``ON CONFLICT DO UPDATE`` sees the first's write.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger

log = get_logger(__name__)

# The kv key namespace. The OWNER is deliberately not in the string: `kv`'s PRIMARY KEY
# already carries it and every read filters by it, so prefixing would state the tenant
# twice (the argument `insights.cache` and `jobs.chain` both make).
_KEY_PREFIX = "ratelimit"

# `"<iso-day>:<count>"`. Two fields, one separator, and the day is first so
# `split_part(value, ':', 1)` is the freshness test and `2` is the counter.
_SEPARATOR = ":"

_SPEND_SQL = (
    "INSERT INTO kv (user_id, key, value) VALUES (%s, %s, %s) "
    "ON CONFLICT (user_id, key) DO UPDATE SET value = CASE "
    "  WHEN split_part(kv.value, ':', 1) = %s "
    "  THEN %s || ':' || (split_part(kv.value, ':', 2)::int + 1)::text "
    "  ELSE %s END "
    "RETURNING split_part(value, ':', 2)::int"
)

_REFUND_SQL = (
    "UPDATE kv SET value = %s || ':' || "
    "  greatest(split_part(value, ':', 2)::int - 1, 0)::text "
    "WHERE user_id = %s AND key = %s AND split_part(value, ':', 1) = %s"
)


@dataclass(frozen=True)
class Verdict:
    """What one spend attempt cost and whether it was allowed.

    ``used`` is the count INCLUDING this attempt, so a refusal reports the request that
    was refused rather than the last one that was allowed — the number the owner is told
    has to match the thing that just happened to them.

    ``resets_at`` is the owner's next local midnight, and ``retry_after_s`` the seconds
    to it. Both travel, because "try again later" without a when is the vague refusal
    standards §Errors forbids: a client renders the instant, an HTTP layer sends the
    header.
    """

    allowed: bool
    used: int
    limit: int
    resets_at: datetime
    retry_after_s: int


def spend(user_id: UUID, tz: str, feature: str, limit: int, now: datetime | None = None) -> Verdict:
    """Charge ``user_id`` one unit of ``feature``'s daily budget and say if it was theirs.

    The day is the OWNER's local day (``tz``), not the server's — the same anchor
    ``insights.cache`` and ``jobs.chain`` use, and the calendar-date-vs-instant bug class
    is why it is threaded rather than assumed.

    The counter is incremented even when the verdict is a refusal: it counts REQUESTS,
    and a caller that hammers a closed door is exactly what the number should record.
    Nothing downstream reads it as "spend", so an over-count costs nothing.
    """
    local_now = now.astimezone(ZoneInfo(tz)) if now else datetime.now(tz=ZoneInfo(tz))
    day = local_now.date()
    fresh = f"{day.isoformat()}{_SEPARATOR}1"
    stamp = day.isoformat()
    with tenant_transaction(user_id) as cur:
        cur.execute(_SPEND_SQL, (user_id, _key(feature), fresh, stamp, stamp, fresh))
        found = cur.fetchone()
    if found is None:  # INSERT ... ON CONFLICT ... RETURNING always yields the stored row
        raise RuntimeError(f"rate-limit upsert for {feature} returned no row")
    used = int(found[0])
    resets_at = _next_local_midnight(day, tz)
    if used > limit:
        log.info("rate limit hit: %s used %d of %d for %s today", user_id, used, limit, feature)
    return Verdict(
        allowed=used <= limit,
        used=used,
        limit=limit,
        resets_at=resets_at,
        retry_after_s=max(1, math.ceil((resets_at - local_now).total_seconds())),
    )


def refund(user_id: UUID, tz: str, feature: str, now: datetime | None = None) -> None:
    """Give back one unit — for a request that was refused before it cost anything.

    Generation refuses some requests without ever asking the model (an owner already at
    the challenge cap; an owner with too little data to calibrate against). Those cost two
    cheap queries and no tokens, so charging for them would let somebody lose a day's
    refreshes to a state they can fix in a tap — while the thing this limiter exists to
    bound went unspent. The callers name their own no-cost refusals
    (``challenges.generate.PRE_LLM_REFUSALS``); this module only knows how to un-charge.

    Guarded on the stored day so a refund cannot reach into a counter that has already
    rolled over, and floored at zero so it can never mint budget.
    """
    local_now = now.astimezone(ZoneInfo(tz)) if now else datetime.now(tz=ZoneInfo(tz))
    day = local_now.date().isoformat()
    with tenant_transaction(user_id) as cur:
        cur.execute(_REFUND_SQL, (day, user_id, _key(feature), day))


def _key(feature: str) -> str:
    return f"{_KEY_PREFIX}{_SEPARATOR}{feature}"


def _next_local_midnight(day: date, tz: str) -> datetime:
    """00:00 on the owner's next local day, as an aware instant.

    Constructed from the local calendar date rather than by adding 24 h to now, because a
    DST transition makes those two different answers — and the budget resets with the
    CALENDAR, since the stored counter is keyed on the local date.
    """
    return datetime.combine(day + timedelta(days=1), time(0, 0), tzinfo=ZoneInfo(tz))
