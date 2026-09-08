"""`admin_connection`'s "complete list" is DERIVED, not trusted — `AUTH_AUDIT.md` F1.

`core/db.admin_connection` opens the one connection that is not subject to the tenant
policies: the admin owns the tables and `0008` deliberately does not `FORCE` RLS, so
every owner's rows are visible on it. Its docstring therefore opens *"### Who may call
this, and why — the complete list"* and names them.

It named four. There were five — `db/grant_premium.py` is a legitimate caller (the app
role holds `SELECT` and nothing else on `subscription` BY DESIGN, so the grant tool has
to be on the admin) and it was simply missing. Nothing was exploitable; the defect is
that **a list which says "complete" and is not is exactly the artefact a future reader
trusts instead of grepping**, on the one function where grepping is the whole point.

So this test greps. A new caller that does not add itself to the docstring fails the
build, and a docstring entry for a caller that no longer exists fails it too — the
reverse direction, which is what stops the list rotting into decoration the other way.
"""

from __future__ import annotations

import re
from pathlib import Path

import healthee

_SRC = Path(healthee.__file__).parent
_TESTS = Path(__file__).resolve().parents[1]

# The one caller that lives in the test tree. Named explicitly rather than found by a
# scan of `tests/`, because a scan there would also match this file and every future
# test that merely mentions the function.
_TEST_CALLER = "tests/contracts/seed.py"

# `with admin_connection()` — the CALL, not the import and not a prose mention. Anchored
# on `with` because that is the only way this context manager is ever used, and because
# `core/config.py`'s docstring names the function in a sentence about who may use it.
_CALL = re.compile(r"\bwith\s+admin_connection\s*\(")


def _callers_in(root: Path, *, relative_to: Path, skip: set[str]) -> set[str]:
    found: set[str] = set()
    for path in root.rglob("*.py"):
        rel = path.relative_to(relative_to).as_posix()
        if rel in skip:
            continue
        if _CALL.search(path.read_text()):
            found.add(rel)
    return found


def _documented_callers() -> set[str]:
    """The paths the docstring's list names, parsed out of it."""
    doc = (_SRC / "core" / "db.py").read_text()
    start = doc.index("### Who may call this, and why — the complete list")
    end = doc.index("Anything else belongs on the app pool", start)
    section = doc[start:end]
    return set(re.findall(r"`((?:db|tests)/[\w/]+\.py)", section))


def test_the_docstring_lists_every_module_that_opens_an_admin_connection() -> None:
    """A caller absent from the list is a privileged connection nobody reviewed."""
    actual = _callers_in(
        _SRC,
        relative_to=_SRC,
        skip={"core/db.py"},  # the definition itself
    )
    actual |= (
        {_TEST_CALLER} if _CALL.search((_TESTS / "contracts" / "seed.py").read_text()) else set()
    )
    documented = _documented_callers()
    assert documented, "the docstring's caller list could not be parsed at all"
    undocumented = sorted(actual - documented)
    assert not undocumented, (
        f"these modules open an admin connection and are not in `core/db.admin_connection`'s "
        f"'complete list': {undocumented}. Add each with its one-line reason, or move the "
        f"work onto the app pool."
    )


def test_the_docstring_lists_nothing_that_no_longer_calls_it() -> None:
    """The reverse direction. A list that names a caller which has moved off the admin
    connection overstates the privilege in use, which is the same lie pointing the other
    way."""
    actual = _callers_in(_SRC, relative_to=_SRC, skip={"core/db.py"}) | {_TEST_CALLER}
    stale = sorted(_documented_callers() - actual)
    assert not stale, f"the caller list names modules that no longer call it: {stale}"


def test_the_scan_actually_finds_callers() -> None:
    """The premise of both absence assertions above — asserted, never assumed.

    A regex that matched nothing would make "no undocumented callers" and "no stale
    entries" both trivially true, which is `test_rls.py`'s recorded lesson.
    """
    actual = _callers_in(_SRC, relative_to=_SRC, skip={"core/db.py"})
    assert len(actual) >= 4, f"the scan found only {sorted(actual)}"
    assert "db/migrate.py" in actual
