#!/usr/bin/env python3
"""File-length quality gate — fails on any *.py or *.dart file over the limit.

Enforces Engineering Standards §1: 400 lines maximum per file (target <=250).
Usable two ways:

  * repo-wide (CI):        python3 scripts/check_file_length.py
  * on a file list (hook): python3 scripts/check_file_length.py path/a.py path/b.dart

Stdlib-only by design so it runs in a git hook with no environment setup.
Generated code, virtualenvs, build output, and the knowledge corpus are
excluded (see EXCLUDED_DIRS / GENERATED_SUFFIXES).

Exit code 0 when everything is within the limit, 1 otherwise.
"""

from __future__ import annotations

import sys
from pathlib import Path

# Standards §1: hard gate at 400 lines. Target is <=250 (advisory, not enforced).
MAX_LINES = 400

CHECKED_SUFFIXES = (".py", ".dart")

# Directories never worth gating: dependencies, build artefacts, generated
# output, and the prose research corpus (packages/knowledge is not source code).
EXCLUDED_DIRS = frozenset(
    {
        ".git",
        ".venv",
        "venv",
        ".dart_tool",
        "build",
        "node_modules",
        "__pycache__",
        ".ruff_cache",
        ".pytest_cache",
        ".mypy_cache",
        "knowledge",  # packages/knowledge — graded research notes, not code
    }
)

# Generated files carry these suffixes; linters own their length, not us.
GENERATED_SUFFIXES = (
    ".g.dart",
    ".freezed.dart",
    ".gr.dart",
    ".config.dart",
    "_pb2.py",
    "_pb2.pyi",
)


def _is_excluded(path: Path) -> bool:
    """True when the path lives under an excluded dir or is generated code."""
    if any(part in EXCLUDED_DIRS for part in path.parts):
        return True
    name = path.name
    return any(name.endswith(suffix) for suffix in GENERATED_SUFFIXES)


def _count_lines(path: Path) -> int:
    """Line count, tolerant of binary/undecodable bytes."""
    with path.open("rb") as handle:
        return sum(1 for _ in handle)


def _iter_repo_files(root: Path) -> list[Path]:
    """Every checked-suffix file under root, minus exclusions."""
    found: list[Path] = []
    for suffix in CHECKED_SUFFIXES:
        for path in root.rglob(f"*{suffix}"):
            if path.is_file() and not _is_excluded(path):
                found.append(path)
    return sorted(found)


def _resolve_targets(args: list[str]) -> list[Path]:
    """A repo-wide sweep with no args, else just the passed files (filtered)."""
    if not args:
        return _iter_repo_files(Path.cwd())
    targets: list[Path] = []
    for arg in args:
        path = Path(arg)
        if path.is_file() and path.suffix in CHECKED_SUFFIXES and not _is_excluded(path):
            targets.append(path)
    return targets


def main(argv: list[str]) -> int:
    """Return 0 if every target file is within MAX_LINES, else 1."""
    targets = _resolve_targets(argv)
    violations: list[tuple[Path, int]] = []
    for path in targets:
        lines = _count_lines(path)
        if lines > MAX_LINES:
            violations.append((path, lines))

    if not violations:
        print(f"file-length gate: OK ({len(targets)} files <= {MAX_LINES} lines)")
        return 0

    print(f"file-length gate: FAILED — {len(violations)} file(s) over {MAX_LINES} lines")
    for path, lines in sorted(violations, key=lambda item: item[1], reverse=True):
        over = lines - MAX_LINES
        print(f"  {path}: {lines} lines (limit {MAX_LINES}, +{over})")
    print("Split by responsibility before this file grows further (standards §1).")
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
