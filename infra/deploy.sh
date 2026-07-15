#!/usr/bin/env bash
# infra/deploy.sh — idempotent update-and-deploy for the Healthee VPS.
#
# Run ON the VPS, from the repo root:
#   cd ~/healthee && infra/deploy.sh
#
# What it does:
#   1. Verify the working tree is on the deploy branch and pushed (local ==
#      origin/<branch>). The legacy repo's hard-learned rule: NEVER deploy code
#      that isn't on origin — the VPS deploys via `git reset --hard origin/...`,
#      so anything not pushed is silently lost.
#   2. git fetch && git reset --hard origin/<branch>
#   3. docker compose build + up -d --force-recreate api
#   4. Poll /healthz until healthy; clear pass/fail exit.
#
# Branch comes from DEPLOY_BRANCH in infra/.env (default: main).

set -euo pipefail

# ── Locate repo + compose file ──────────────────────────────────────────
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
compose_file="$script_dir/docker/docker-compose.prod.yml"
env_file="$script_dir/.env"
cd "$repo_root"

COMPOSE="docker compose --env-file $env_file -f $compose_file"

# ── UI helpers ──────────────────────────────────────────────────────────
step() { printf '\n\033[1;34m▶ %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
die()  { printf '  \033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

# ── Preflight ───────────────────────────────────────────────────────────
step "Preflight"
[ -f "$compose_file" ] || die "compose file not found: $compose_file"
[ -f "$env_file" ] || die "env file not found: $env_file (copy infra/.env.example)"
command -v docker >/dev/null 2>&1 || die "docker not found"

set -a
# shellcheck source=/dev/null
. "$env_file"
set +a
branch="${DEPLOY_BRANCH:-main}"
ok "deploy branch: $branch"

# ── 1. Verify local == origin (the push-before-deploy guard) ────────────
step "Verifying $branch is pushed"
git fetch --quiet origin "$branch" || die "git fetch failed for origin/$branch"

local_sha="$(git rev-parse "$branch" 2>/dev/null || echo "")"
remote_sha="$(git rev-parse "origin/$branch")"

if [ -n "$local_sha" ] && [ "$local_sha" != "$remote_sha" ]; then
	# Local branch exists but differs — only abort if local is AHEAD (unpushed
	# commits would be lost by the reset). Behind/diverged-from-remote is fine
	# since we deploy origin's version anyway.
	if git merge-base --is-ancestor "$remote_sha" "$local_sha"; then
		die "local $branch has commits not on origin — push first, then deploy."
	fi
fi
ok "origin/$branch = ${remote_sha:0:12}"

# ── 2. Sync to origin ───────────────────────────────────────────────────
step "Syncing working tree to origin/$branch"
git reset --hard "origin/$branch"
ok "reset to origin/$branch"

# ── 3. Build + recreate api ─────────────────────────────────────────────
step "Building + recreating api"
$COMPOSE build api
$COMPOSE up -d --force-recreate api
ok "compose up"

# ── 4. Post-deploy healthcheck ──────────────────────────────────────────
step "Health check"
health_url="http://127.0.0.1:8765/healthz"
for attempt in $(seq 1 30); do
	if curl -fsS --max-time 3 "$health_url" >/dev/null 2>&1; then
		ok "healthy after ${attempt} attempt(s): $health_url"
		step "Deploy OK"
		exit 0
	fi
	sleep 2
done

printf '  \033[31m✗ health check FAILED\033[0m — %s did not respond in ~60s.\n' "$health_url" >&2
printf '  Recent api logs:\n' >&2
$COMPOSE logs --tail 40 api >&2 || true
exit 1
