#!/bin/sh
# setup-dev.sh — one command to wire up local development.
#
# Point git at the repo's tracked hooks (dependency-free, in .githooks/).
# Idempotent: safe to re-run. Portable POSIX sh.

set -eu

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

echo "Healthee dev setup"
echo "=================="

# ── git hooks ───────────────────────────────────────────────────────────
git config core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true
echo "  git hooks:   core.hooksPath -> .githooks (commit-msg, pre-commit)"

# ── server env (advisory) ───────────────────────────────────────────────
if command -v uv >/dev/null 2>&1; then
	echo "  server:      run 'make setup-server' or 'cd apps/server && uv sync' to install deps"
else
	echo "  server:      install uv (https://docs.astral.sh/uv/) then 'cd apps/server && uv sync'"
fi

echo
echo "Done. Hooks are active for commits in this clone."
echo "  - commit-msg enforces Conventional Commits + blocks Claude co-author trailers"
echo "  - pre-commit runs the file-length gate, a secret sanity grep, and ruff (if present)"
echo "See CONTRIBUTING.md for the full workflow."
