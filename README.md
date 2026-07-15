# Healthee

**An honest, self-hosted AI health companion.** Data comes off an Amazfit Helio
Strap over a reverse-engineered BLE protocol; a Python backend owns the full
history, an evidence-graded science layer, and a grounded AI coach; a Flutter app
(in progress) puts it on your wrist with 60 days of local history.

Healthee's one promise: **it never flatters.** Every interpretive claim is grounded
in a graded research corpus, every number carries its data confidence, and *"not
enough data"* always beats an optimistic guess. It exists to tell you the truth
about your body and nudge you toward the next real improvement — not to hand out
green rings.

> **Status:** the backend is **complete and deployable** (Phase 1 — rebuilt clean,
> 227 tests green against a real TimescaleDB, validated end-to-end on 4 months of
> real data). The Flutter app rebuild (Phase 2) is next. This is a clean rebuild;
> the previous implementation is archived separately as reference.

---

## Contents
- [What it does](#what-it-does)
- [Architecture](#architecture)
- [The data flow](#the-data-flow)
- [The honesty contract](#the-honesty-contract)
- [Tech stack](#tech-stack)
- [Repository layout](#repository-layout)
- [API surface](#api-surface)
- [Self-hosting guide](#self-hosting-guide)
- [Development](#development)
- [Roadmap](#roadmap)
- [Documentation](#documentation)

---

## What it does

- **Collects** every signal the strap exposes over BLE — per-minute heart rate,
  steps, HRV, SpO₂, stress, skin temperature, respiratory rate, plus sleep
  sessions and workout summaries — with a reverse-engineered Huami/ZeppOS client.
- **Derives** an evidence-graded science layer: resting HR, overnight HRV, VO₂max
  (Jurca non-exercise + GPS submaximal), MVPA, cardio load (Banister TRIMP) and
  strain, a 4-dimension sleep-health score, sleep regularity (Phillips SRI), sleep
  need/debt, a recovery score, and a Gompertz biological-age estimate — each
  method cited to primary research.
- **Analyzes** it honestly: personal baselines (median ± MAD), anomaly flags,
  correlations (Spearman + Mann-Whitney with Benjamini-Hochberg FDR), and a
  personal caffeine/alcohol cutoff finder.
- **Grounds** every word: an AI coach and daily insights that must cite the
  research corpus or say the evidence isn't there — enforced by a blocking
  validator, not a hopeful prompt.

## Architecture

Three tiers. Everything the user sees works offline; everything interpretive is
grounded in research.

```
 Amazfit Helio Strap ──BLE (RE'd Huami/ZeppOS)──▶  Mobile app  ──POST /ingest/helio──▶   Server (FastAPI)
   sensors + firmware buffers                       (Flutter)                             ├─ ingest   → TimescaleDB
   hr · steps · hrv · spo2 · stress                 · BLE kit                             ├─ derive   (science layer)
   temp · resp · sleep · workouts                   · 60-day local store                  ├─ analytics(baselines · corr
                                                     · on-device analytics                │            · anomalies · cutoffs)
                                                     · offline-first UI  ◀─GET /api/*──────┤─ insights (grounded LLM + coach)
                                                                                           ├─ jobs     (supervised chain)
                                                                                           └─ Telegram · OpenRouter · backups
                             packages/knowledge (graded research corpus) grounds every claim
```

- **Strap** — the sensor. Keep-on-device ACKs + per-metric watermarks make partial
  syncs safe and resumable.
- **Server** — the canonical brain: full history, the science layer, and the
  grounded intelligence. FastAPI + psycopg3 + TimescaleDB. This repo's `apps/server`.
- **Mobile** (Phase 2) — collector *and* analytical node: renders from local data
  instantly, reconciles with the server after each push. Offline degrades (no LLM,
  no full history) but never dies. This repo's `apps/mobile`.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full design and phase
plan, and [`docs/INTELLIGENCE.md`](docs/INTELLIGENCE.md) for how the grounding works.

## The data flow

1. **Collect & push.** The app authenticates to the strap (ECDH), pages every
   fetch type with gap-skip and version-guarded parsers, and pushes new samples,
   sleep sessions, workouts, and daily totals to `POST /ingest/helio`.
2. **Ingest.** The server validates the payload against a metric whitelist and
   upserts idempotently (pipelined `executemany`, fresh-gated sleep-minute
   emission), then triggers derivation for the days the push touched — all in one
   transaction.
3. **Derive.** The science layer recomputes the day's and night's metrics into
   `derived_daily` in dependency order (MVPA → activity/calories → VO₂max → cardio
   load → sleep debt → recovery). Ported verbatim from the validated implementation
   and parity-tested.
4. **Analyze.** Scheduled jobs recompute baselines, anomalies, correlations, and
   personal cutoffs into the `finding` table — reading the canonical tables
   directly (no legacy compatibility views).
5. **Ground & speak.** Every LLM surface — the coach, daily insights, notable
   shifts, and daily recommendations — passes through one grounded-ask choke point:
   a deterministic safety pre-classifier, manifest-ranked research retrieval, then
   a **blocking** validator that refuses to ship any claim not resolvable to a real
   research note. Unvalidated text never reaches the user.
6. **Serve.** The read API assembles it into `GET /api/today`, `/api/sleep`,
   `/api/activity`, etc. — reads answer in well under 100 ms.
7. **Supervise & survive.** The daily chain (correlate → recs → briefing) runs
   in-process, supervised: any step failure is logged and reported to Telegram,
   never silently swallowed. Nightly `pg_dump` ships a backup off-box.

## The honesty contract

These five principles are product law, enforced in code (see
[`docs/INTELLIGENCE.md`](docs/INTELLIGENCE.md)):

1. **Never lies, never flatters** — every interpretive sentence cites the research
   corpus or doesn't ship (blocking validator at the grounded-ask choke point).
2. **Confidence is part of the answer** — every number carries coverage, freshness,
   origin, and evidence grade.
3. **Nudge, don't please** — measured outcomes, not streak theater.
4. **Science is a pipeline** — graded notes, calibrated language, safety directives
   as hard guardrails the LLM can't override.
5. **The user owns the data** — self-hosted, on-device history, off-box backups.

## Tech stack

| Layer | Stack |
|---|---|
| **Server** | Python 3.13 · FastAPI · psycopg3 · **TimescaleDB** (Postgres 17) · uv · pytest · ruff · pyright |
| **Intelligence** | OpenRouter (LLM) behind a grounded-ask choke point + blocking citation validator |
| **Mobile** (Phase 2) | Flutter · Riverpod · on-device SQLite (60-day tier) |
| **Knowledge** | Markdown research corpus with per-claim evidence grades + a generated manifest |
| **Infra** | Docker Compose · nginx (TLS via certbot) · systemd-timed `pg_dump` backups |
| **CI** | GitHub Actions — file-length gate · ruff · pyright · pytest (against a TimescaleDB service) · gitleaks |

## Repository layout

```
apps/server/          Python backend
  src/healthee/
    core/             config · one pooled DB · auth · notify · logging
    db/               schema + numbered migrations + runner
    ingest/           /ingest/helio payload validation + upserts
    derive/           the science layer (RHR·HRV·VO2max·MVPA·TRIMP·sleep·recovery…)
    analytics/        baselines · correlations · anomalies · cutoffs · bio-age
    read/             per-endpoint read services (canonical-table reads)
    insights/         grounded-ask choke point · blocking validator · coach · insight endpoints
    jobs/             scheduler + the supervised event chain (correlate→recs→briefing)
    api/              app wiring + thin routers
  tests/              unit · integration (seeded DB) · contract snapshots
apps/mobile/          Flutter app (Phase 2)
packages/knowledge/   graded research corpus (notes/ + sports-science/) + generated manifest
packages/contracts/   API contract snapshots shared server↔mobile
infra/                Dockerfile · compose (dev + prod) · nginx · deploy.sh · backup
docs/                 architecture · engineering standards · intelligence · coach prompt & roadmap
```

## API surface

All endpoints require a `Bearer <REALTIME_INGEST_TOKEN>` header except `/healthz`.

**Health & ingest**
- `GET  /healthz` — liveness + DB readiness (503 if the DB is unreachable)
- `POST /ingest/helio` — the app's sync push (samples, sleep, workouts, daily totals, profile)

**Today & metrics**
- `GET /api/today` — the home screen: recovery, VO₂max, cardio load, sleep, MVPA,
  bio-age, sparklines, recommendations, and more
- `GET /api/history?metric=&days=` — a metric's daily history
- `GET /api/profile`

**Sleep** — `GET /api/sleep` · `/api/sleep/health_score` · `/api/sleep/consistency` · `/api/sleep/insight`
**Activity** — `GET /api/activity` · `/api/activity/workout` · `/api/activity/insight` · `/api/activity/workout/insight`
**Insights** — `GET /api/metric/insight?metric=` · `/api/notable`
**Coach** — `POST /api/coach` — the grounded, history-aware AI coach
**Logging** — `POST /api/log` · `GET /api/log/recent`
**GPS workouts** — `POST /api/workout/gps` · `GET /api/workout/gps` · `GET /api/workout/gps/{track_id}`

Response shapes are snapshot-tested in `packages/contracts` so the mobile client's
expectations can't silently break.

## Self-hosting guide

Healthee is designed to run on a single small VPS. The database is never exposed
to the internet; the API is reachable only through nginx over TLS.

### Prerequisites
- A Linux VPS with Docker + Docker Compose.
- A domain name pointing at it (for TLS), e.g. `healtheeapi.example.com`.
- The Amazfit Helio Strap + the Flutter app built with your device's pairing key
  (Phase 2; until then the backend accepts pushes from any client with the token).

### 1. Clone & configure
```sh
git clone https://github.com/<you>/healthee.git ~/healthee && cd ~/healthee
cp infra/.env.example infra/.env
# edit infra/.env — generate real secrets:
#   openssl rand -base64 48 | tr -d '/+=' | head -c 32   # for each token
```
Set at minimum `POSTGRES_PASSWORD` and `REALTIME_INGEST_TOKEN`. Optional:
`OPENROUTER_API_KEY` (enables the AI coach + insights — the app works without it,
just without generated text) and `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` (daily
briefing + job-failure alerts).

**Environment variables** (`infra/.env`):

| Var | Purpose |
|---|---|
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | database credentials |
| `POSTGRES_HOST` / `POSTGRES_PORT` | `db` / `5432` for the compose stack |
| `REALTIME_INGEST_TOKEN` | Bearer token gating every `/ingest/*` and `/api/*` call |
| `API_HOST` / `API_PORT` | in-container bind (`0.0.0.0` / `8765`) |
| `OPENROUTER_API_KEY` | optional — enables the grounded LLM (coach, insights, recs) |
| `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` | optional — daily briefing + failure alerts |
| `DEPLOY_BRANCH` | branch `deploy.sh` deploys (default `main`) |
| `BACKUP_DIR` / `BACKUP_RETENTION_DAYS` / `OFFBOX_CMD` | backup location, retention, off-box copy hook |

### 2. Bring up the stack
```sh
COMPOSE="docker compose --env-file infra/.env -f infra/docker/docker-compose.prod.yml"
$COMPOSE build api
$COMPOSE up -d db        # TimescaleDB, internal-only (never published to the host)
$COMPOSE run --rm api python -m healthee.db.migrate   # apply the schema
$COMPOSE up -d api scheduler
curl -fsS http://127.0.0.1:8765/healthz               # → {"status":"ok","db":"ok"}
```
The `api` service binds to `127.0.0.1:8765` only. The `scheduler` service runs the
daily chain (correlate 10:30, recs 10:45, briefing 11:00, IST).

### 3. Put nginx + TLS in front
Install the provided vhost and get a certificate:
```sh
sudo cp infra/nginx/healtheeapi.conf /etc/nginx/sites-available/healtheeapi.conf
sudo ln -s /etc/nginx/sites-available/healtheeapi.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d healtheeapi.example.com       # adds the TLS block in place
```
The vhost reverse-proxies `https://<domain>` → `127.0.0.1:8765`, trusts Cloudflare
real-IP ranges, and allows large upload bodies.

### 4. Updates
Push to your deploy branch, then on the VPS:
```sh
cd ~/healthee && infra/deploy.sh
```
`deploy.sh` refuses to deploy code that isn't pushed to `origin` (the VPS deploys
via `git reset --hard origin/<branch>`), rebuilds the `api` image, recreates it,
and polls `/healthz`.

### 5. Backups (do this)
A nightly, off-box `pg_dump` is the single most important thing you can set up.
```sh
sudo cp infra/backup/healthee-backup.{service,timer} /etc/systemd/system/
sudo systemctl enable --now healthee-backup.timer
```
It dumps gzipped to `BACKUP_DIR`, prunes past `BACKUP_RETENTION_DAYS`, and runs
`OFFBOX_CMD` (e.g. an `rclone`/`scp` to another host) if set. **Rehearse the
restore** — see [`infra/backup/RESTORE.md`](infra/backup/RESTORE.md) for the
scratch-DB dry run and the disaster-recovery steps.

## Development

```sh
scripts/setup-dev.sh          # enable git hooks (Conventional Commits + gates)
cd apps/server && uv sync     # install the toolchain (Python 3.13 via uv)
```
From the repo root, the [`Makefile`](Makefile) wraps the common tasks:

| Command | Does |
|---|---|
| `make lint` | file-length gate · ruff · format check · pyright |
| `make test` | pytest (with coverage) |
| `make fix`  | ruff `--fix` + format |
| `make ci`   | everything CI runs (lint + test + knowledge-check) |
| `make db-up` / `db-down` | local dev TimescaleDB (port 5544) |
| `make knowledge` | regenerate the research manifest |

Integration tests need a reachable TimescaleDB (they auto-skip without one); CI
provides a service container. **All engineering standards are binding** — 400-line
file cap, no swallowed errors, tests in the same PR, science ported verbatim: see
[`docs/ENGINEERING_STANDARDS.md`](docs/ENGINEERING_STANDARDS.md) and
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## Roadmap

- **Phase 1 — server core** ✅ done, deployable.
- **Phase 2 — mobile core**: BLE layer, the 60-day local tier, features rebuilt clean.
- **Phase 3 — on-device tier**: local mirror + `/api/sync/down` + offline-first.
- **Phase 4 — device analytics**: provisional metrics on-device, parity-tested.
- **Phase 5 — companion intelligence**: per-card confidence, weekly review, coach
  memory → outcome ledger → proactive → goal-oriented planning
  (see [`docs/COACH_ROADMAP.md`](docs/COACH_ROADMAP.md)), knowledge reconciliation.
- **Phase 6 — cutover**: point production at this repo; archive the legacy one.

## Documentation

| Doc | What |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Target architecture + the phase/work-package plan |
| [docs/INTELLIGENCE.md](docs/INTELLIGENCE.md) | How grounding works: the choke point, validator, retrieval, coverage |
| [docs/ENGINEERING_STANDARDS.md](docs/ENGINEERING_STANDARDS.md) | Binding quality gates (sizes, errors, tests, performance budgets) |
| [docs/COACH_PROMPT.md](docs/COACH_PROMPT.md) | The canonical coach system prompt + rationale |
| [docs/COACH_ROADMAP.md](docs/COACH_ROADMAP.md) | The coach's companion features (memory · ledger · proactive · goals) |
| [docs/KNOWLEDGE_RECONCILIATION.md](docs/KNOWLEDGE_RECONCILIATION.md) | Plan to unify the two research corpora without losing content |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Commit conventions, branch strategy, hooks, CI |

---

*Healthee is a personal, self-hosted project. It is not a medical device and does
not provide medical advice; it refuses diagnosis, medication, and emergency
questions by design and points you to a clinician.*
