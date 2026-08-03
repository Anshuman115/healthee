"""Re-derive an owner's stored nights and days — the backfill / repair tool.

    uv run python -m healthee.db.rederive                      # every active owner, 42 d
    uv run python -m healthee.db.rederive --days 40
    uv run python -m healthee.db.rederive --user <uuid> --days 40
    uv run python -m healthee.db.rederive --user <uuid> --all  # their whole history
    uv run python -m healthee.db.rederive --all --rescore-tracks   # + redo GPS estimates
    uv run python -m healthee.db.rederive --all --purge-stale vo2max_estimate           # preview
    uv run python -m healthee.db.rederive --all --purge-stale vo2max_estimate --apply   # remove

A committed ops module, run like the migration runner. It exists for the two moments a
derived layer legitimately needs rebuilding: after a migration or a science fix changes
what a derivation computes, and after an incident leaves the derived layer behind the
raw one.

## Why this is a CLI and not a function nothing calls (#107)

The capability used to live in ``derive.derive_all_nights`` — a real function, correct,
exported, and called by **nothing** in the running system. That is worse than absent code:
a reader greps, finds a night pass, and concludes nights are derived. They were not, for
two weeks, in production. So the rule this module encodes is that the repair path is
*reachable* and *identical*: it routes through :func:`derive.derive_batch`, the same entry
point the ingest push uses, which makes it impossible for the repair path and the live
path to disagree about the order nights and days are derived in.

## What a recompute alone could NOT repair (#118)

That sentence is only true of a science fix that CHANGES a number. A fix that **narrows**
what gets written — a new gate, a tightened validity range, a withdrawn metric — was not
repaired by this tool at all: ``derived_daily`` is upsert-only and nothing deletes from
it, so the new code declined to write, every old wrong row survived, and the run reported
success having changed nothing. It cost 109 live-and-wrong ``vo2max_estimate`` rows on
production; ``db/stale_derived.py`` carries the full account and the discriminator. Two
things follow, each defaulted in the safe direction: **detection is unconditional** (every
run reports, per metric, how many rows in the window it did NOT rewrite — the check nobody
ran by hand for two weeks), and **removal is not** (``--purge-stale <metric …>`` names what
may go and previews it; ``--apply`` deletes).

## What a recompute used to DESTROY, and no longer does (#121)

Until #121 this tool actively made one number worse. The strap's own daily step counter
arrived on the push and was written straight into ``derived_daily.steps_total``, after
the derive pass, with nothing else holding it — so a re-derive recomputed that cell from
the per-minute sample sum (the stream our own code called "possibly frozen/incomplete")
and the device's count was gone for good. The documented repair procedure replaced an
authoritative measurement with a worse one, permanently, every time it ran.

The counter now lands in ``device_daily_total`` as raw data this tool never touches, and
``derive/device_totals.py`` re-reads it on every pass — so a re-derive is idempotent for
steps and distance too, rather than lossy. ⛔ It does NOT recover the 142 production days
whose counter was already overwritten: nothing anywhere holds those numbers.

## Why the RECOMPUTE is not dry-run-by-default, and why the PURGE is

``claim_sentinel`` and ``grant_premium`` are dry-run first because they are irreversible
and re-key or entitle a *person*. The recompute recomputes derived rows from raw samples
it never touches, so it is idempotent by construction: the worst outcome of running it
needlessly is that the same numbers get written again, and a confirmation step for that
is friction that makes an operator skip the tool during the incident it was written for.

That argument does not extend one inch to the purge, and the asymmetry is deliberate
rather than an oversight. A delete is not recoverable from the raw samples the way a
recompute is — the whole point of purging a row is that today's code *cannot* reproduce
it — so getting it wrong costs a restore, not a re-run. The purge therefore joins its
siblings (preview first, ``--apply`` second) and is bounded three ways rather than one:
owner, day window, and a metric list this module will not invent for you. There is
deliberately no "purge everything" spelling.

## The default window

42 days — the longest trailing window any derivation reads (``derive/recovery.py``
takes a 42-day autonomic baseline; sleep debt reads 14, SRI and VO2max 7). Rebuilding
that span rebuilds every input a day in it can need. ``--all`` is the unbounded form
for a science change that moved historical values — and the form to reach for when
purging, since the rows a narrowing change orphaned are usually older than 42 days.

## GPS tracks come along, and when they need `--rescore-tracks`

A recorded session's VO2max is derived by the DAY pass since #111, so an ordinary run
backfills every track no push ever scored — this module needed no new capability for it,
which is the property #107 bought. What an ordinary run will NOT do is recompute a track
that already carries an estimate: that gate keeps a re-push from re-reading every fix and
re-running the DEM. ``--rescore-tracks`` forgets the estimates in the window so the gate
fires again — reach for it after a change to the estimator itself, and not otherwise. It
is also what ``stale_derived.GATED_METRICS`` demands before the purge touches
``vo2max_submax`` — an already-scored track is not re-attempted, so its row only looks
stale.
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence
from dataclasses import dataclass, field
from datetime import date, timedelta
from uuid import UUID

from healthee.core.db import close_pool, tenant_connection
from healthee.core.logging import configure_logging, get_logger
from healthee.core.tenancy import Tenant, active_users, user_today
from healthee.db.stale_derived import (
    GATED_METRICS,
    describe,
    gated_off,
    open_gates,
    purge_stale,
    stale_counts,
)
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
    # Rows in the window this run did NOT rewrite, per metric — the unconditional check.
    stale: dict[str, int] = field(default_factory=dict)
    # The subset of `stale` the operator named with --purge-stale (empty when none was).
    purgeable: dict[str, int] = field(default_factory=dict)
    # What --apply actually deleted. `None` means the destructive path never ran, which
    # is a different state from "ran and removed nothing" and stays distinguishable.
    purged: dict[str, int] | None = None


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


def purge_metrics(
    metrics: Sequence[str], *, applying: bool, gates: frozenset[str]
) -> tuple[str, ...]:
    """Validate the purge request, or refuse it. Returns the metrics that may be removed.

    Two refusals, both about an operator getting something they did not ask for:

    ``--apply`` with nothing to purge is a typo, not a request to delete nothing quietly.
    Someone typed the word that makes this tool destructive; they are owed an answer about
    why nothing happened.

    A :data:`stale_derived.GATED_METRICS` name whose gate is still shut would delete rows
    that are perfectly current — the run simply never re-attempted them. That is the single
    way this feature could destroy correct data, so it is a refusal with the fix in the
    message, not a caveat in the docs.
    """
    if applying and not metrics:
        raise RederiveRefusedError(
            "--apply does nothing without --purge-stale <metric …>. Name what may be "
            "removed; a run cannot ask to delete 'whatever it found'."
        )
    for metric in metrics:
        flag = GATED_METRICS.get(metric)
        if flag is not None and flag not in gates:
            raise RederiveRefusedError(
                f"{metric} is scored once and this run did not re-attempt it, so its rows "
                f"only LOOK stale. Re-run with {flag} to recompute them first, then purge."
            )
    return tuple(metrics)


def rederive_owner(
    tenant: Tenant,
    days: int | None,
    *,
    rescore_tracks: bool = False,
    purge: Sequence[str] = (),
    applying: bool = False,
) -> Rederived:
    """Re-derive one owner's window: their stored nights, then their days, then the check.

    One transaction for the whole owner (``tenant_connection`` commits on clean exit),
    so a failure part-way leaves the derived layer as it was rather than half-rebuilt.
    The order comes from :func:`derive.derive_batch` — this module does not get its own
    opinion about it.

    The stale scan and the purge run in that SAME transaction, and they have to: they ask
    "what did this run not write", which ``stale_derived`` answers by comparing against
    the transaction's own instant. It also means a purge is atomic with the rebuild that
    justified it — there is no window in which the old rows are gone and the new ones are
    not yet there.

    GPS tracks are re-derived by that same day pass and need nothing here: since #111 a
    day scores the recorded sessions that start inside it, so a track no push ever scored
    is backfilled by an ordinary run. ``rescore_tracks`` is only for a SCIENCE change —
    it forgets the estimates in the window first, which re-opens the day pass's own
    freshness gate instead of teaching this module a second rule about when to score.
    """
    window = day_range(user_today(tenant.tz), days)
    span = (window[0], window[-1])
    forgotten = 0
    with tenant_connection(tenant.id) as conn:
        with conn.cursor() as cur:
            nights = stored_nights(cur, tenant.id, tenant.tz, window[0])
            if rescore_tracks:
                forgotten = forget_track_estimates(cur, tenant.id, tenant.tz, window)
        derive_batch(conn, tenant.id, tenant.tz, nights, window)
        with conn.cursor() as cur:
            gated = gated_off(open_gates(rescore_tracks=rescore_tracks))
            stale = stale_counts(cur, tenant.id, span, ignore=gated)
            purged = purge_stale(cur, tenant.id, span, purge) if applying and purge else None
    return Rederived(
        tenant=tenant,
        nights=len(nights),
        days=window,
        tracks_forgotten=forgotten,
        stale=stale,
        purgeable={metric: stale[metric] for metric in purge if metric in stale},
        purged=purged,
    )


def _log_coverage(result: Rederived) -> None:
    """What the run rebuilt, for the operator's log."""
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


def _log_stale(result: Rederived) -> None:
    """What the run did NOT rewrite — the half a silent success used to hide.

    Reported as three distinct outcomes, because "removed 109" and "would remove 109" and
    "found 109 and was not asked to remove any" are three different things to read at 2am.
    """
    if result.purged is not None:
        log.info(
            "    purged %d stale row(s): %s", sum(result.purged.values()), describe(result.purged)
        )
    elif result.purgeable:
        log.warning(
            "    PREVIEW — nothing deleted. %d row(s) would be removed: %s. Re-run with --apply.",
            sum(result.purgeable.values()),
            describe(result.purgeable),
        )
    accounted = result.purged if result.purged is not None else result.purgeable
    left = {metric: n for metric, n in result.stale.items() if metric not in accounted}
    if not left:
        return
    log.warning(
        "    %d row(s) in this window are STALE — today's code would not write them (%s). "
        "Remove with: --purge-stale %s --apply",
        sum(left.values()),
        describe(left),
        " ".join(sorted(left)),
    )


def run(
    user_id: UUID | None,
    days: int | None,
    *,
    rescore_tracks: bool = False,
    purge: Sequence[str] = (),
    applying: bool = False,
) -> int:
    """Re-derive every selected owner. Returns an exit code (0 = done)."""
    selected = owners(user_id)
    log.info(
        "re-deriving %d owner(s) over %s",
        len(selected),
        "their whole history" if days is None else f"the last {days} local days",
    )
    for tenant in selected:
        result = rederive_owner(
            tenant, days, rescore_tracks=rescore_tracks, purge=purge, applying=applying
        )
        _log_coverage(result)
        _log_stale(result)
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
    parser.add_argument(
        "--purge-stale",
        nargs="+",
        metavar="METRIC",
        default=[],
        help="metrics whose rows may be DELETED where this run declined to rewrite them; "
        "previews unless --apply is also given",
    )
    parser.add_argument(
        "--apply", action="store_true", help="actually delete the previewed --purge-stale rows"
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
        purge = purge_metrics(
            args.purge_stale,
            applying=args.apply,
            gates=open_gates(rescore_tracks=args.rescore_tracks),
        )
        return run(
            args.user,
            None if args.all else args.days,
            rescore_tracks=args.rescore_tracks,
            purge=purge,
            applying=args.apply,
        )
    except RederiveRefusedError as exc:
        log.error("refused: %s", exc)
        return 2
    finally:
        close_pool()


if __name__ == "__main__":
    sys.exit(main())
