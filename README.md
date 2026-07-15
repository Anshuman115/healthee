# Healthee

An honest, self-hosted AI health companion. Data comes off an Amazfit Helio
Strap over a reverse-engineered BLE protocol; a Flutter app holds 60 days of
history and runs analytics on-device; a Python backend owns the full history,
the evidence-graded science layer, and the grounded intelligence. It never
flatters: every claim cites a graded research corpus, every number carries its
confidence, and "not enough data" always beats an optimistic guess.

**Clean-rebuild monorepo.** The previous implementation is archived at
`../healthee-legacy` (reference only; prod runs from it until Phase 6 cutover).

| Path | What |
|---|---|
| `apps/server` | Python 3.13 backend — FastAPI · psycopg3 · TimescaleDB |
| `apps/mobile` | Flutter app — Riverpod · local 60-day store · device analytics |
| `packages/knowledge` | The evidence base — graded research notes |
| `packages/contracts` | API contract snapshots + golden fixtures (server ↔ mobile) |
| `infra` | Docker, nginx, deploy, backup — [deployment & backup](infra/) |
| `docs` | [Architecture](docs/ARCHITECTURE.md) · [Engineering standards](docs/ENGINEERING_STANDARDS.md) |

Start with `CLAUDE.md`, then `docs/ENGINEERING_STANDARDS.md` — the standards
are binding for every diff.

## Getting started

```sh
scripts/setup-dev.sh        # enable git hooks (Conventional Commits + gates)
cd apps/server && uv sync   # install the server toolchain (Python 3.13 via uv)
```

From the repo root, the [`Makefile`](Makefile) wraps the common tasks:

| Command | What it does |
|---|---|
| `make setup` | Enable the git hooks (`scripts/setup-dev.sh`) |
| `make lint` | File-length gate · `ruff check` · `ruff format --check` · `pyright` |
| `make test` | `pytest` with a coverage report |
| `make fix` | `ruff check --fix` + `ruff format` |
| `make ci` | Everything CI runs (lint + test) |

Server-only, from `apps/server/`: `uv run pytest`, `uv run ruff check`,
`uv run pyright`. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for commit
conventions, the branch strategy, and how the hooks and CI gates fit together.

### Deploying

Production infra lives in [`infra/`](infra/): the server `Dockerfile`, the
`docker-compose.prod.yml` stack (TimescaleDB + api), the nginx vhost, an
idempotent `deploy.sh` (push-before-deploy guarded), and a systemd-timed
Postgres backup with a rehearsed [restore drill](infra/backup/RESTORE.md).
Copy `infra/.env.example` to `infra/.env` first.
