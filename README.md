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
| `infra` | Docker, nginx, deploy, backup |
| `docs` | [Architecture](docs/ARCHITECTURE.md) · [Engineering standards](docs/ENGINEERING_STANDARDS.md) |

Start with `CLAUDE.md`, then `docs/ENGINEERING_STANDARDS.md` — the standards
are binding for every diff.
