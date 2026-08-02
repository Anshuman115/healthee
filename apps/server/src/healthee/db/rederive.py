"""Re-derive an owner's stored nights and days — the backfill / repair tool.

    uv run python -m healthee.db.rederive                      # every active owner, 42 d
    uv run python -m healthee.db.rederive --days 40
    uv run python -m healthee.db.rederive --user <uuid> --days 40
    uv run python -m healthee.db.rederive --user <uuid> --all  # their whole history
    uv run python -m healthee.db.rederive --all --rescore-tracks   # + redo GPS estimates

A committed ops module, run like the migration runner. It exists for the two moments a
derived layer legitimately needs rebuilding: after a migration or a science fix changes
what a derivation computes, and after an incident leaves the derived layer behind the
raw one.

## Why this is a CLI and not a function nothing calls (#107)

The capability used to live in ``derive.derive_all_nights`` — a real function, correct,
exported, and called by **nothing** in the running system. That is worse than absent
code: a reader greps, finds a night pass, and concludes nights are derived. They were
not, for two weeks, in production.

So the rule this module encodes is that the repair path is *reachable* and *identical*.
It routes through :func:`derive.derive_batch`, the same entry point the ingest push
uses, which is what makes it impossible for the repair path and the live path to
disagree about the order nights and days are derived in.

## Why it is not dry-run-by-default

``claim_sentinel`` and ``grant_premium`` are dry-run first because they are
irreversible and re-key or entitle a *person*. This one recomputes derived rows from
raw samples that it never touches, so running it is idempotent by construction: the
worst outcome of running it needlessly is that the same numbers get written again. A
confirmation step for an idempotent recompute is friction that makes an operator skip
the tool during the incident it was written for.

## The default window

42 days — the longest trailing window any derivation reads (``derive/recovery.py``
takes a 42-day autonomic baseline; sleep debt reads 14, SRI and VO2max 7). Rebuilding
that span rebuilds every input a day in it can need. ``--all`` is the unbounded form
for a science change that moved historical values.

## GPS tracks come along, and when they need `--rescore-tracks`

A recorded session's VO2max is derived by the DAY pass since #111, so an ordinary run
backfills every track no push ever scored — this module needed no new capability for it,
which is the property #107 bought. What an ordinary run will NOT do is recompute a track
that already carries an estimate: that gate is what keeps a re-push from re-reading every
fix and re-running the DEM. ``--rescore-tracks`` forgets the estimates in the window so
the gate fires again — the flag to reach for after a change to the estimator itself, and
not otherwise.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from datetime import date, timedelta
from uuid import UUID

from healthee.core.db import close_pool, tenant_connection
from healthee.core.logging import configure_logging, get_logger
from healthee.core.tenancy import Tenant, active_users, user_today
from healthee.derive import derive_batch, stored_nights
from healthee.derive.gps_scoring import forget_track_estimates

log = get_logger(__name__)

# See the module docstring: the longest trailing window any derivation reads. A CLI
# default, not a science constant — no derivation reads THIS number.
DEFAULT_WINDOW_DAYS = 42

# The oldest day `--all` will walk. Not "no bound at all": the day pass is a query per
# day, so an unbounded run on an owner with a typo'd historical sample would grind
# through decades. 2020-01-01 predates any strap this product has ever read.
_ALL_SINCE = date(2020, 1, 1)


class RederiveRefusedError(Exception):
    """The owner cannot be resolved — refuse rather than re-derive the wrong person."""


@dataclass(frozen=True)
class Rederived:
    """What one owner's re-derive covered, for the operator's log."""

    tenant: Tenant
    nights: int
    days: list[date]
    tracks_forgotten: int = 0


def day_range(today: date, days: int | None) -> list[date]:
    """The local days to re-derive, oldest first, ending on the owner's today.

    ``days=None`` is ``--all`` and starts at :data:`_ALL_SINCE`. Ending on TODAY rather
    than yesterday is deliberate: today's rows are the ones a stalled derive layer is
    missing right now, and every derivation is safe to run against a partial day (it
    computes over whatever samples exist, exactly as the next sync's push would).
    """
    start = _ALL_SINCE if days is None else today - timedelta(days=days - 1)
    if start > today:
        raise RederiveRefusedError(f"--days must be at least 1 (got a start of {start})")
    return [start + timedelta(days=i) for i in range((today - start).days + 1)]


def owners(user_id: UUID | None) -> list[Tenant]:
    """The owners to re-derive: one named, or every active owner.

    Resolved through ``core.tenancy.active_users`` rather than a query of its own, so
    "who does the system work for" has one definition here too. A named owner who is
    not active is refused rather than silently skipped — an operator who typed a UUID is
    owed an answer about that UUID.
    """
    active = active_users()
    if user_id is None:
        return active
    named = [tenant for tenant in active if tenant.id == user_id]
    if not named:
        raise RederiveRefusedError(
            f"no ACTIVE app_user row for {user_id} — check the UUID, or reactivate the "
            "owner first. Refusing rather than re-deriving nothing and reporting success."
        )
    return named


def rederive_owner(tenant: Tenant, days: int | None, *, rescore_tracks: bool = False) -> Rederived:
    """Re-derive one owner's window: their stored nights, then their days.

    One transaction for the whole owner (``tenant_connection`` commits on clean exit),
    so a failure part-way leaves the derived layer as it was rather than half-rebuilt.
    The order comes from :func:`derive.derive_batch` — this module does not get its own
    opinion about it.

    GPS tracks are re-derived by that same day pass and need nothing here: since #111 a
    day scores the recorded sessions that start inside it, so a track no push ever scored
    is backfilled by an ordinary run. ``rescore_tracks`` is only for a SCIENCE change —
    it forgets the estimates in the window first, which re-opens the day pass's own
    freshness gate instead of teaching this module a second rule about when to score.
    """
    window = day_range(user_today(tenant.tz), days)
    forgotten = 0
    with tenant_connection(tenant.id) as conn:
        with conn.cursor() as cur:
            nights = stored_nights(cur, tenant.id, tenant.tz, window[0])
            if rescore_tracks:
                forgotten = forget_track_estimates(cur, tenant.id, tenant.tz, window)
        derive_batch(conn, tenant.id, tenant.tz, nights, window)
    return Rederived(tenant=tenant, nights=len(nights), days=window, tracks_forgotten=forgotten)


def run(user_id: UUID | None, days: int | None, *, rescore_tracks: bool = False) -> int:
    """Re-derive every selected owner. Returns an exit code (0 = done)."""
    selected = owners(user_id)
    log.info(
        "re-deriving %d owner(s) over %s",
        len(selected),
        "their whole history" if days is None else f"the last {days} local days",
    )
    for tenant in selected:
        result = rederive_owner(tenant, days, rescore_tracks=rescore_tracks)
        log.info(
            "  %s (%s): %d night(s), %d day(s) %s → %s, %d GPS track(s) re-scored",
            result.tenant.id,
            result.tenant.tz,
            result.nights,
            len(result.days),
            result.days[0].isoformat(),
            result.days[-1].isoformat(),
            result.tracks_forgotten,
        )
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m healthee.db.rederive",
        description="Rebuild the derived layer: every stored night, then every day, "
        "in dependency order.",
    )
    parser.add_argument("--user", type=UUID, default=None, help="one owner's UUID (default: all)")
    parser.add_argument(
        "--days",
        type=int,
        default=DEFAULT_WINDOW_DAYS,
        help=f"how many local days back to rebuild (default: {DEFAULT_WINDOW_DAYS})",
    )
    parser.add_argument(
        "--all", action="store_true", help="rebuild the owner's whole history instead"
    )
    parser.add_argument(
        "--rescore-tracks",
        action="store_true",
        help="also recompute GPS tracks that already carry an estimate (a science change)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """CLI entry point. 0 = done, 2 = refused.

    The pool is closed on the way out, and that is not tidiness. This is the first ops
    module to use the app pool (its siblings connect as the admin, which is a plain
    `psycopg.connect`), and a pool left open keeps its maintenance threads alive: the
    process then spends ~15 s printing `couldn't stop thread` warnings AFTER a
    completely successful repair. An operator reading that during an incident has every
    reason to think the tool failed.
    """
    args = _parser().parse_args(argv)
    configure_logging()
    try:
        return run(args.user, None if args.all else args.days, rescore_tracks=args.rescore_tracks)
    except RederiveRefusedError as exc:
        log.error("refused: %s", exc)
        return 2
    finally:
        close_pool()


if __name__ == "__main__":
    sys.exit(main())
