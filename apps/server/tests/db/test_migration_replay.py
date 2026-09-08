"""D1 + D2 — the two claims every migration header makes, checked instead of trusted.

Every migration from `0004` on carries a *Replay-safety* paragraph, and nothing ever
replayed one. The nearest thing was
`test_db_integration.py::test_second_migrate_run_is_a_no_op`, which proves the LEDGER
skips a recorded file — it never re-executes one, so the `IF NOT EXISTS` /
drop-by-name-first discipline the headers describe was asserted nowhere.

The claim only has to hold after a `schema_migrations` loss (a restore from a partial
dump, a hand-edit): `migrate._apply_one` runs a whole file plus its ledger row on one
connection, so a file cannot half-apply and be replayed. That is why this is hygiene —
and also why it is worth having, because the argument for the discipline is the recovery
path nobody has walked.

## What this proves, and what it does not

It proves each file **re-executes without erroring** against a database it has already
been applied to. It does not prove a replay changes no ROWS: `0012` and `0015` carry
deletes that are idempotent by construction and argued in their own headers, and asserting
row-level identity here would be re-litigating those arguments in the wrong place.

Each replay runs in a transaction that is rolled back, so a file that turned out NOT to be
a no-op cannot damage the run that found out.

## The exceptions are named, and they are asserted to STILL be exceptions

`0009` states its own limit honestly: two `RENAME COLUMN`s, no `RENAME … IF EXISTS` in
PostgreSQL, and the conditional form needs a `DO` block the runner's `;` splitter cannot
carry. A list of skips that is only ever skipped rots into a blanket exemption, so the
list is checked in both directions — the named file must still fail, and every other file
must still pass.

The second test is D2, and it is derived rather than listed (`HOW_WE_VERIFY.md` section
4): the splitter strips `--` before splitting on `;`, so a dash pair inside a
`COMMENT ON COLUMN` string would cut a literal in half. Eleven migrations already carry
long English comments, so this is a hazard waiting on one apostrophe-free sentence with a
dash in it. Walking every committed file beats eight hand-picked cases.
"""

from __future__ import annotations

from pathlib import Path
from typing import LiteralString, cast

import pytest

from healthee.core.db import admin_connection
from healthee.db import migrate

pytestmark = pytest.mark.integration

# Files whose own header says they are NOT replay-safe, with the reason. Asserted to
# still fail, so this cannot quietly become "the ones we gave up on".
_NOT_REPLAY_SAFE: dict[str, str] = {
    "0009_outcome_ledger": (
        "two RENAME COLUMNs — PostgreSQL has no `RENAME … IF EXISTS` and the conditional "
        "form needs a DO block the `;` splitter cannot carry (0009's own header, and it "
        "argues the file cannot half-apply anyway)"
    ),
}


class _RollbackError(Exception):
    """Thrown to make `admin_connection` roll back a successful replay."""


def _replay(path: Path) -> None:
    """Re-execute one migration's statements against the live schema, then roll back.

    Rolled back rather than committed: the whole question is whether a file that has
    already been applied can be applied again, and a file that turns out NOT to be a no-op
    must not damage the run that discovered it.
    """
    statements = migrate._split_statements(path.read_text())
    try:
        with admin_connection() as conn, conn.cursor() as cur:
            for statement in statements:
                # Trusted SQL — committed migration files, exactly as `_apply_one` reads.
                cur.execute(cast("LiteralString", statement))
            raise _RollbackError
    except _RollbackError:
        pass


@pytest.fixture
def migrated(db: None) -> None:  # noqa: ARG001 — gates on DB reachability
    """Every migration applied, which is the state a replay is a replay OF."""
    migrate.apply_migrations()


def _files() -> list[Path]:
    return migrate._migration_files()


def _replayable() -> list[Path]:
    return [p for p in _files() if p.stem not in _NOT_REPLAY_SAFE]


def test_there_are_migrations_to_replay() -> None:
    """The guard against a glob that quietly matched nothing.

    Without it every parametrised case below would vacuously pass and the suite would
    report fourteen proven claims having executed no SQL at all.
    """
    assert len(_files()) >= 19


@pytest.mark.parametrize("path", _replayable(), ids=lambda p: p.stem)
def test_a_migration_re_applies_cleanly(migrated: None, path: Path) -> None:  # noqa: ARG001
    """The `IF NOT EXISTS` / drop-by-name-first discipline, actually exercised.

    This is the recovery path the headers were written for: `schema_migrations` is lost,
    the runner sees every file as pending, and applies them all against a database that
    already has the schema.
    """
    _replay(path)


@pytest.mark.parametrize("stem", sorted(_NOT_REPLAY_SAFE), ids=lambda s: s)
def test_a_named_exception_really_is_still_an_exception(
    migrated: None,  # noqa: ARG001
    stem: str,
) -> None:
    """A skip list that is only ever skipped is a blanket exemption wearing a comment.

    If `0009` is ever rewritten into a replay-safe form, this fails and the entry comes
    out — which is the only thing that keeps the list honest in the other direction.
    """
    path = next(p for p in _files() if p.stem == stem)
    with pytest.raises(Exception, match=r".") as raised:
        _replay(path)
    assert not isinstance(raised.value, _RollbackError), f"{stem} replayed cleanly — drop the entry"


# ── D2: the splitter's own hazard, checked over every committed file ──────────


@pytest.mark.parametrize("path", _files(), ids=lambda p: p.stem)
def test_every_split_statement_has_balanced_quotes(path: Path) -> None:
    """`_split_statements` strips `--` before splitting, so a dash pair in a string cuts it.

    The docstring names both halves of the assumption ("no `;` or `--` inside string
    literals") and `0010` repeats only the semicolon half. The `--` case is the one that
    will bite first: `COMMENT ON COLUMN` strings are ordinary English and a dash pair is
    easy to type.

    The failure is loud rather than silent — an unbalanced quote is a syntax error at
    apply time and the whole file rolls back — which is why this is hygiene. It is still
    worth a derived check: this walks every committed file and every statement in it, so
    it covers the migration nobody has written yet.
    """
    for statement in migrate._split_statements(path.read_text()):
        assert statement.count("'") % 2 == 0, f"unbalanced ' in: {statement[:120]}"
        assert statement.count('"') % 2 == 0, f'unbalanced " in: {statement[:120]}'


def test_the_hazard_is_real_and_the_check_would_see_it() -> None:
    """The check must be able to fail, or it is a comment with a green tick beside it.

    A `COMMENT ON COLUMN` whose English contains a dash pair — nothing exotic, and the
    exact shape eleven committed files are one sentence away from.
    """
    hazard = "COMMENT ON COLUMN t.c IS 'the owner''s own baseline -- not a population one';"

    statements = migrate._split_statements(hazard)

    assert any(s.count("'") % 2 for s in statements), (
        "the splitter cut a string literal and the balanced-quote check did not see it"
    )
