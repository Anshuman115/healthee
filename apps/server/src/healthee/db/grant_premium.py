"""Grant (or revoke) one owner's premium entitlement by hand — the pre-billing path.

    uv run python -m healthee.db.grant_premium <user-uuid> --months 12          # DRY RUN
    uv run python -m healthee.db.grant_premium <user-uuid> --months 12 --apply
    uv run python -m healthee.db.grant_premium <user-uuid> --revoke --apply

A committed ops module, run like the migration runner and modelled on
``db/claim_sentinel.py`` — same dry-run-by-default shape, same argument, same reason:
**the operator naming the UUID is the authorisation.** It is not reachable from any
request path and never will be; §12.7's whole model is that entitlement is decided from
server-owned state, so the one thing that must not exist is an HTTP route that grants it.

## Why this exists before billing does

``MULTI_USER.md`` §12.6 splits 6.6 into (a) the gate with entitlement flipped by an
admin/config path and (b) the real provider + webhooks. This is (a)'s half of the
flip, and without it the gate is undeployable rather than merely incomplete: today's
only owner authenticates with the legacy shared token and resolves to the SENTINEL,
which has no ``subscription`` row — so shipping the gate with no way to write one
would take the live owner's entire AI layer away, silently, because "not premium" is
the default. Running this once is the step that prevents that (``infra/DEPLOY.md``).

When 6.6b lands, a signature-verified webhook writes the same row with
``provider``/``provider_ref`` set; this stays for comps, support, and the operator's
own account. Both write the SAME table, which is the point — one source of truth
(§12.7), not a config flag the webhook path would not know about.

## What it refuses

An owner with no ``app_user`` row: an unverified UUID may be a typo, and entitling a
stranger by fat-finger is a real cost. Same refusal, same reasoning as
``claim_sentinel``.

## Why the term is mandatory

``--months`` has no default. ``core.entitlement`` refuses a row with no end instant on
purpose ("granted once, forgotten" is §12.7's loophole), so an operator has to say how
long — and a default would be this module quietly picking a subscription length.
``--revoke`` is the other half: it writes ``canceled`` with the period ended NOW rather
than deleting the row, because the history of who had access when is worth keeping.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID

from psycopg import Cursor
from psycopg.rows import TupleRow

from healthee.core.db import admin_connection
from healthee.core.entitlement import Subscription, evaluate
from healthee.core.logging import configure_logging, get_logger

log = get_logger(__name__)

# Days per month for the term arithmetic. A calendar month would be more correct and
# is not worth a dateutil dependency for a hand-run comp: 30 days is stated here so
# nobody has to reverse-engineer why a 12-month grant ends 5 days early.
_DAYS_PER_MONTH = 30

# Admin connection, so this is the ONE writer the RLS policy and the app role's
# revoked write privileges both leave room for. `%s`-parameterised like everything
# else; the table is not a tenant read here (the operator acts across owners).
_UPSERT_SQL = (
    "INSERT INTO subscription (user_id, status, plan, current_period_end, granted_by, note, "
    "  updated_at) VALUES (%s, %s, %s, %s, %s, %s, now()) "
    "ON CONFLICT (user_id) DO UPDATE SET status = EXCLUDED.status, plan = EXCLUDED.plan, "
    "  current_period_end = EXCLUDED.current_period_end, granted_by = EXCLUDED.granted_by, "
    "  note = EXCLUDED.note, updated_at = now()"
)

_READ_SQL = (
    "SELECT status, plan, trial_end, current_period_end FROM subscription WHERE user_id = %s"
)


class GrantRefusedError(Exception):
    """The grant cannot be made safely — refuse rather than guess at the owner."""


@dataclass(frozen=True)
class GrantPlan:
    """Exactly what would be written, for the operator to read before ``--apply``."""

    user_id: UUID
    email: str | None
    status: str
    plan: str | None
    current_period_end: datetime
    before: str


def _identity(cur: Cursor[TupleRow], user_id: UUID) -> tuple[bool, str | None]:
    """``(has a row, email)``. Two facts, one query — and they are NOT the same fact:
    the sentinel owner's row carries ``email = NULL`` (§8), so "no email" must not
    read as "no such owner" or the one account this module has to work for is refused.
    """
    cur.execute("SELECT email FROM app_user WHERE id = %s", (user_id,))
    row = cur.fetchone()
    return (row is not None, row[0] if row else None)


def _current(cur: Cursor[TupleRow], user_id: UUID) -> str:
    """A one-line description of the entitlement being replaced."""
    cur.execute(_READ_SQL, (user_id,))
    row = cur.fetchone()
    if row is None:
        return "no subscription row"
    stored = Subscription(status=row[0], plan=row[1], trial_end=row[2], current_period_end=row[3])
    verdict = evaluate(stored)
    return f"{stored.status} (premium={verdict.premium}, ends {stored.current_period_end})"


def plan_grant(
    cur: Cursor[TupleRow], user_id: UUID, months: int, *, revoke: bool, now: datetime
) -> GrantPlan:
    """What would change, or raise ``GrantRefusedError``. Never writes."""
    exists, email = _identity(cur, user_id)
    if not exists:
        raise GrantRefusedError(
            f"no app_user row for {user_id} — that owner has never signed in. Entitling an "
            "unverified UUID is a typo away from paying for a stranger; provision them "
            "first (sign in once with Supabase), then re-run."
        )
    if revoke:
        return GrantPlan(user_id, email, "canceled", None, now, _current(cur, user_id))
    if months < 1:
        raise GrantRefusedError("--months must be at least 1 (or use --revoke)")
    return GrantPlan(
        user_id=user_id,
        email=email,
        status="active",
        plan=f"comp_{months}mo",
        current_period_end=now + timedelta(days=months * _DAYS_PER_MONTH),
        before=_current(cur, user_id),
    )


def _report(grant_plan: GrantPlan, *, applied: bool) -> None:
    """Log exactly what would change, and to whom — the operator's confirmation surface."""
    log.info(
        "%s entitlement for %s", "APPLIED" if applied else "DRY RUN — planned", grant_plan.user_id
    )
    log.info("  email:   %s", grant_plan.email or "(none — the sentinel owner has no email)")
    log.info("  before:  %s", grant_plan.before)
    log.info("  after:   %s (plan=%s)", grant_plan.status, grant_plan.plan or "-")
    log.info("  through: %s", grant_plan.current_period_end.isoformat())
    if not applied:
        log.info("Re-run with --apply to write it. Nothing has changed.")


def run(
    user_id: UUID, months: int, *, revoke: bool, apply: bool, granted_by: str, note: str
) -> int:
    """Plan the grant, report it, and write it only when ``apply``. Returns an exit code."""
    now = datetime.now(tz=UTC)
    with admin_connection() as conn, conn.cursor() as cur:
        grant_plan = plan_grant(cur, user_id, months, revoke=revoke, now=now)
        if apply:
            cur.execute(
                _UPSERT_SQL,
                (
                    grant_plan.user_id,
                    grant_plan.status,
                    grant_plan.plan,
                    grant_plan.current_period_end,
                    granted_by,
                    note or None,
                ),
            )
    _report(grant_plan, applied=apply)
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Grant or revoke an owner's premium entitlement.")
    parser.add_argument("user_id", type=UUID, help="the owner's UUID (app_user.id)")
    parser.add_argument(
        "--months", type=int, default=0, help="term length; required unless --revoke"
    )
    parser.add_argument("--revoke", action="store_true", help="end access now (writes 'canceled')")
    parser.add_argument("--apply", action="store_true", help="actually write it (default: dry run)")
    parser.add_argument("--by", default="ops", help="who granted it — stored in granted_by")
    parser.add_argument("--note", default="", help="why — stored in note")
    return parser


def main(argv: list[str] | None = None) -> int:
    """CLI entry point. 0 = planned or applied, 2 = refused."""
    args = _parser().parse_args(argv)
    try:
        configure_logging()
        return run(
            args.user_id,
            args.months,
            revoke=args.revoke,
            apply=args.apply,
            granted_by=args.by,
            note=args.note,
        )
    except GrantRefusedError as exc:
        log.error("refused: %s", exc)
        return 2


if __name__ == "__main__":
    sys.exit(main())
