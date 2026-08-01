from __future__ import annotations

import ast
import re
from pathlib import Path

import healthee

# The 17 tenant tables (MULTI_USER.md §3.2, + `subscription` from §12.2). `app_user`
# / `device_token` are identity tables keyed BY the user and are deliberately absent.
TENANT_TABLES: frozenset[str] = frozenset({
    "sample", "sleep_session", "workout", "derived_daily", "weight_log", "kv",
    "manual_entry", "illness_flag", "recommendation", "finding", "challenge",
    "program", "challenge_outcome", "gps_track", "gps_point", "profile",
    "subscription",
})  # fmt: skip

# A tenant table named after FROM / JOIN / INTO / UPDATE — i.e. the table the
# statement actually touches, not a word that merely looks like one (the column
# `metric` vs the table `sample`, say).
_TABLE_REF = re.compile(
    r"\b(?:FROM|JOIN|INTO|UPDATE)\s+(" + "|".join(sorted(TENANT_TABLES)) + r")\b",
    re.IGNORECASE,
)

# Statement starts, used to split one string's SQL into individual statements so a
# scoped statement can't vouch for an unscoped neighbour in the same literal.
_STATEMENT_SPLIT = re.compile(r"\b(?=SELECT\b|INSERT\s+INTO\b|UPDATE\b|DELETE\s+FROM\b)", re.I)

# Files whose SQL is exempt, each with the reason. Keep this list SHORT and
# justified — an entry here is a hole in the guarantee, not a convenience.
_ALLOWLIST: dict[str, str] = {
    # The migrations CREATE tenancy (they add `user_id` and backfill it), so they
    # necessarily contain SQL that predates the column they are introducing.
    "db/migrations": "migration SQL defines tenancy; it cannot be scoped by it",
}


def _literal_text(node: ast.AST) -> str | None:
    """The literal text of a string node, or None if it isn't one.

    ``ast`` fuses adjacent implicit-concatenated literals into ONE node, which is
    exactly what the read layer's multi-line SQL needs. An f-string (``JoinedStr``)
    keeps its literal parts; interpolations become a ``%s``-like placeholder, since
    every interpolated fragment in this codebase is a hardcoded METRIC_FILTERS /
    placeholder constant, never a tenant predicate.
    """
    if isinstance(node, ast.Constant):
        return node.value if isinstance(node.value, str) else None
    if isinstance(node, ast.JoinedStr):
        parts = [
            v.value if isinstance(v, ast.Constant) and isinstance(v.value, str) else " ? "
            for v in node.values
        ]
        return "".join(parts)
    return None


def _docstring_nodes(tree: ast.AST) -> set[int]:
    """ids() of the string nodes that are docstrings — prose, never executed SQL.

    ``core/db.py``'s module docstring shows an example ``INSERT INTO sample`` in its
    usage block; without this the guard would fail on documentation.
    """
    out: set[int] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Module | ast.FunctionDef | ast.AsyncFunctionDef | ast.ClassDef):
            body = getattr(node, "body", [])
            if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant):
                out.add(id(body[0].value))
    return out


def _sql_statements(source: str) -> list[str]:
    """Every SQL statement in the file that touches a tenant table.

    Parsed rather than grepped: the AST fuses implicit concatenation (so a
    statement whose `user_id` sits on a later source line than its `FROM` is not a
    false positive) and lets docstrings be excluded.
    """
    tree = ast.parse(source)
    skip = _docstring_nodes(tree)
    out: list[str] = []
    for node in ast.walk(tree):
        if id(node) in skip:
            continue
        text = _literal_text(node)
        if text is None:
            continue
        for stmt in _STATEMENT_SPLIT.split(text):
            if _TABLE_REF.search(stmt):
                out.append(stmt)
    return out


def _is_allowlisted(path: Path) -> str | None:
    posix = path.as_posix()
    for fragment, reason in _ALLOWLIST.items():
        if fragment in posix:
            return reason
    return None


def _source_files() -> list[Path]:
    root = Path(healthee.__file__).parent
    return sorted(p for p in root.rglob("*.py") if _is_allowlisted(p) is None)


def test_every_tenant_table_statement_binds_user_id() -> None:
    """No SQL statement touches a tenant table without also naming ``user_id``.

    This is the mechanical proof that the 6.3a write sweep and the 6.3b read sweep
    are COMPLETE — the property no single-tenant behavioural test can establish.
    """
    offenders: list[str] = []
    for path in _source_files():
        source = path.read_text()
        for stmt in _sql_statements(source):
            if "user_id" in stmt:
                continue
            tables = sorted(set(m.lower() for m in _TABLE_REF.findall(stmt)))
            offenders.append(f"{path.name}: touches {tables} without user_id -> {stmt[:120]!r}")
    assert not offenders, "unscoped tenant-table SQL found:\n" + "\n".join(offenders)


def test_the_guard_actually_detects_an_unscoped_statement() -> None:
    """The guard must FAIL on a planted violation — else it proves nothing.

    A syntactic scanner that silently matches nothing is worse than no test at all:
    it would report green forever while the sweep rotted.
    """
    planted = 'cur.execute("SELECT day, value FROM derived_daily WHERE metric = %s", (m,))'
    found = _sql_statements(planted)
    assert found, "the scanner failed to see a plain tenant-table SELECT"
    assert all("user_id" not in stmt for stmt in found)


def test_the_guard_accepts_a_scoped_statement() -> None:
    """A correctly-scoped statement must pass (no false positives)."""
    scoped = (
        'cur.execute("SELECT day, value FROM derived_daily WHERE user_id = %s AND metric = %s",'
        " (user_id, m))"
    )
    assert all("user_id" in stmt for stmt in _sql_statements(scoped))


def test_guard_covers_the_multi_line_implicit_concat_style() -> None:
    """The read layer writes SQL as adjacent implicit-concatenated literals.

    The scanner must fuse those pieces, or a statement whose `user_id` sits on a
    different source line than its `FROM` would look unscoped (false positive) —
    and the guard would be untrustworthy, hence disabled.
    """
    concatenated = (
        "cur.execute(\n"
        '    "SELECT day, value FROM derived_daily "\n'
        '    "WHERE user_id = %s AND metric = %s",\n'
        "    (user_id, metric),\n"
        ")\n"
    )
    stmts = _sql_statements(concatenated)
    assert stmts, "the scanner failed to see the concatenated statement"
    assert all("user_id" in s for s in stmts), "implicit concat was not fused"
