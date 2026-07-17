"""AST guard: no module under `healthee` may resolve a CALENDAR DAY on the server.

The completeness half of `tests/db/test_day_window_anchoring.py` and
`tests/analytics/test_baseline_anchoring.py`. Those prove the anchors we KNOW about
are the owner's; this proves no new one appears — the check that would have caught
6.4a's miss on the day it was made.

6.4a swept SQL `current_date` -> `USER_TODAY_SQL` and left the Python twins in
place, because a grep for `current_date` cannot see `date.today()`. Both express
the same defect: a calendar day resolved against the SERVER's clock rather than the
owner's. In a container running TZ=UTC that is nobody's local day, and it ships a
confidently wrong number — an owner at UTC+14 had their current day fall outside
their own 30-day baseline (`n=29`), silently.

**Banned**, because in this codebase they have no correct use:

- ``date.today()``      — the server process's calendar date. The owner's day is
                          ``core.tenancy.user_today(tz)``; there is no third answer.
- ``datetime.now()``    — a NAIVE local datetime. Every instant here is tz-aware.
- ``datetime.utcnow()`` — naive, and deprecated in 3.12.

**Deliberately allowed**: ``datetime.now(tz=...)`` — an aware INSTANT. That is the
distinction the whole audit turns on. A heart-rate sample's timestamp, a fasting
window's elapsed minutes and a feed's staleness are durations between instants, and
UTC is exactly right for them; only a *calendar day* needs the owner's zone. This
guard therefore keys on `date.today()`/naive-`now()`, never on `tz=UTC` itself —
banning UTC outright would be the same mistake wearing the opposite hat.
"""

from __future__ import annotations

import ast
from pathlib import Path

import healthee

_SRC = Path(healthee.__file__).parent

# call → why it is banned, quoted verbatim in the failure so the fix is obvious.
_BANNED: dict[str, str] = {
    "date.today": "the SERVER's date, not the owner's — use core.tenancy.user_today(tz)",
    "datetime.now": "naive local datetime — use datetime.now(tz=...) for an instant, "
    "or core.tenancy.user_today(tz) for a calendar day",
    "datetime.utcnow": "naive and deprecated — use datetime.now(tz=UTC)",
}

# The ONE module allowed to call `datetime.now(tz=...)`-free helpers: none. An entry
# here is a hole in the guarantee, not a convenience — justify it or fix the code.
_ALLOWLIST: dict[str, str] = {}


def _dotted_name(node: ast.expr) -> str | None:
    """`date.today` from a `date.today()` call's func node, else None."""
    if isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name):
        return f"{node.value.id}.{node.attr}"
    return None


def _violations(tree: ast.AST) -> list[tuple[int, str, str]]:
    """(line, call, reason) for each banned day-anchor call in ``tree``.

    ``datetime.now`` is a violation ONLY when called with no arguments: with a
    `tz`/`tzinfo` it is an aware instant, which is correct and common here.
    """
    out: list[tuple[int, str, str]] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        name = _dotted_name(node.func)
        if name not in _BANNED:
            continue
        if name == "datetime.now" and (node.args or node.keywords):
            continue  # aware instant — the allowed form
        out.append((node.lineno, name, _BANNED[name]))
    return out


def _scanned_files() -> list[Path]:
    return [
        p
        for p in sorted(_SRC.rglob("*.py"))
        if not any(a in p.relative_to(_SRC).as_posix() for a in _ALLOWLIST)
    ]


def test_no_module_resolves_a_calendar_day_on_the_server_clock() -> None:
    """No `date.today()` / naive `now()` anywhere under `healthee`."""
    found: list[str] = []
    for path in _scanned_files():
        tree = ast.parse(path.read_text(), filename=str(path))
        found += [
            f"{path.relative_to(_SRC)}:{line}: {call}() — {why}"
            for line, call, why in _violations(tree)
        ]
    assert not found, "server-clock day anchors (the 6.4a class of bug):\n" + "\n".join(found)


def test_the_guard_scans_the_real_tree() -> None:
    """A guard that scans nothing passes forever — pin that it sees the codebase."""
    files = _scanned_files()
    assert len(files) > 50, f"only {len(files)} modules scanned — the walk is broken"
    assert any(p.name == "baselines.py" for p in files), "analytics/baselines.py not scanned"


def test_guard_flags_the_exact_bug_this_audit_found() -> None:
    """The real defect, verbatim from `baselines.py` before the fix, must be caught."""
    src = "def f(tz):\n    end_date = end_date or date.today()\n"
    assert [(2, "date.today", _BANNED["date.today"])] == _violations(ast.parse(src))


def test_guard_flags_naive_now_and_utcnow() -> None:
    assert len(_violations(ast.parse("x = datetime.now()\n"))) == 1
    assert len(_violations(ast.parse("x = datetime.utcnow()\n"))) == 1


def test_guard_allows_an_aware_instant() -> None:
    """The load-bearing exemption: an INSTANT in UTC is correct, not a violation.

    A guard that flagged these would be deleted within a week for crying wolf over
    `data_health_payload`'s staleness maths — and the real day-anchor bugs would go
    back to being invisible.
    """
    assert _violations(ast.parse("x = datetime.now(tz=UTC)\n")) == []
    assert _violations(ast.parse("x = datetime.now(UTC)\n")) == []
    assert _violations(ast.parse("x = datetime.now(tz=ZoneInfo(tz))\n")) == []
