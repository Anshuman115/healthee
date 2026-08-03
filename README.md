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

> **Status:** the backend is **complete, deployed, and multi-tenant** (Phase 1
> rebuilt clean and Phase 6 multi-user shipped — 728 tests green against a real
> TimescaleDB, validated end-to-end on 4 months of real data). Production runs
> from this repo. The Flutter app rebuild (Phase 2) is next, and it is the gate on
> two things: retiring the transitional shared-token auth, and opening signups.
> This is a clean rebuild; the previous implementation is archived as reference.

---

## Contents
- [What it does](#what-it-does)
- [Architecture](#architecture)
- [The data flow](#the-data-flow)
- [The honesty contract](#the-honesty-contract)
- [Tech stack](#tech-stack)
- [Choosing the model](#choosing-the-model--what-we-measured)
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
  **Multi-tenant**: one database, row-level tenancy (`user_id` on all 16 data
  tables, folded into every key), identity via Supabase (auth-only — the backend
  verifies JWTs, never issues them), and Postgres RLS underneath so a missed
  `WHERE` returns nothing rather than someone else's health data.
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
   shifts, and daily recommendations — is held to one grounded-ask pipeline: a
   deterministic safety pre-classifier, manifest-ranked research retrieval, a
   **hard output guardrail** that blocks documented-forbidden answers regardless of
   their citations, then a **blocking** validator that refuses to ship any claim
   not resolvable to a real research note. Unvalidated text never reaches the user.
   (One body of code, two entry points: `grounded_ask` for the insight surfaces
   and `run_coach` for the coach, which adds a tool loop and nothing else. A stage
   is registered once and reaches both, with a test that fails otherwise. See
   [`docs/INTELLIGENCE.md`](docs/INTELLIGENCE.md) §3–§4.)
6. **Serve.** The read API assembles it into `GET /api/today`, `/api/sleep`,
   `/api/activity`, etc. — reads answer in well under 100 ms.
7. **Supervise & survive.** The daily chain (correlate → recs → warm → briefing) runs
   in-process, supervised: any step failure is logged and reported to Telegram,
   never silently swallowed. Nightly `pg_dump` ships a backup off-box.

## The honesty contract

These five principles are product law, enforced in code (see
[`docs/INTELLIGENCE.md`](docs/INTELLIGENCE.md)):

1. **Never lies, never flatters** — every interpretive sentence cites the research
   corpus or doesn't ship (blocking validator, enforced on every LLM surface).
2. **Confidence is part of the answer** — every number carries coverage, freshness,
   origin, and evidence grade.
3. **Nudge, don't please** — measured outcomes, not streak theater.
4. **Science is a pipeline** — graded notes, calibrated language, and hard output
   guardrails the LLM can't override: a forbidden answer is blocked even when
   perfectly cited and validator-clean.
5. **The user owns the data** — self-hosted, on-device history, off-box backups.

## Tech stack

| Layer | Stack |
|---|---|
| **Server** | Python 3.13 · FastAPI · psycopg3 · **TimescaleDB** (Postgres 17) · uv · pytest · ruff · pyright |
| **Intelligence** | OpenRouter (`gemini-3.5-flash-lite`, [measured](#choosing-the-model--what-we-measured)) behind a grounded-ask choke point + blocking citation validator |
| **Mobile** (Phase 2) | Flutter · Riverpod · on-device SQLite (60-day tier) |
| **Knowledge** | Markdown research corpus with per-claim evidence grades + a generated manifest |
| **Infra** | Docker Compose · nginx (TLS via certbot) · systemd-timed `pg_dump` backups |
| **CI** | GitHub Actions — file-length gate · ruff · pyright · pytest (against a TimescaleDB service) · gitleaks |

## Choosing the model — what we measured

The coach runs on **`google/gemini-3.5-flash-lite`**, the same model as the batch
surfaces. That is a measured choice, not a default, and the measurement changed our
mind twice.

**Everything below is from `tests/grounding_eval/`** — 18 fixed questions across six
kinds, 4 repeats each (72 runs per arm), all at the same commit, scored by the same
blocking validator that gates production. Costs are the providers' published rates,
**not** the harness's printed figure, which uses a stale flat rate.

### The finding that mattered

A cheap model first measured **much worse** than the expensive one, and the reason was
not health knowledge:

| kind | `gemini-3.6-flash` | `deepseek-v4-flash` |
|---|---|---|
| **knowledge** | 6/6 | **3/6** |
| surface | 10/12 | **12/12** |

Where output was **structured**, the cheap model matched or beat the expensive one.
Where it was free-text prose carrying an inline `[note_id]` convention, it failed — and
the failures were all *"Interpretive sentence lacks a citation"*. **That is
instruction-following on our formatting rule, not a knowledge gap.**

So we made the citation impossible to omit rather than possible to forget: the coach now
returns claims as data (`text`, `cites`, `grade`) and the prose is rendered from them
(`insights/coach_answer.py`). Same principle as `derive/vo2max_tier.py`, which cannot
blend two instruments because the code path never sees two, and `derive/device_totals.py`,
which cannot lose the strap's step counter because it derives from it.
**Enforce by structure, not by care.**

The fix lifted **both** models, and cut output tokens 57% (paired, sign established) —
fewer answers need rewriting, so fewer are written twice.

### The three arms, after the fix

| model | ship rate | knowledge | LLM calls/q | input tok/q | **$/question** | 30 q/month |
|---|---|---|---|---|---|---|
| `gemini-3.6-flash` | 100.0% [94.3–100] | 12/12 | 1.7 | 67,433 | $0.1142 | $3.43 |
| **`gemini-3.5-flash-lite`** | **100.0%** [94.3–100] | 12/12 | **1.2** | **46,636** | **$0.0146** | **$0.44** |
| `deepseek-v4-flash-0731` | 98.4% [91.7–99.7] | 12/12 | 1.7 | 65,516 | $0.0060 | $0.18 |

Paired McNemar, flash-lite vs `gemini-3.6-flash`: 72 pairs, **zero discordant**.

**Flash-lite wins on behaviour, not just on rate.** It is 5× cheaper per token but
**7.8×** cheaper in practice, because it reaches the same answer in **1.2 calls instead
of 1.7** and needs 31% less input to do it. `gemini-3.6-flash` spent **1,481 tokens per
question on invisible reasoning** — billed at $7.50/M and never shown to anyone.

### Answer character (proxies, not prose)

⚠ The harness records *whether* an answer shipped and *what it cited* — **not the answer
text**. These are proxies; a real prose comparison needs its own run.

| model | visible output/q | reasoning/q | citations/answer |
|---|---|---|---|
| `gemini-3.6-flash` | 262 tok | 1,481 | 2.41 |
| `gemini-3.5-flash-lite` | 244 tok | 0 | 2.47 |
| `deepseek-v4-flash-0731` | **364 tok** | 389 | **2.68** |

DeepSeek writes the longest, most-cited answers; flash-lite the most concise.
**Correctness is not among these differences** — the validator is the arbiter of that, and
all three cleared it at 98–100%.

### Why not DeepSeek, which is 2.4× cheaper still

1. **Flash-lite is already in production** for every batch surface, so its behaviour is
   evidenced by real traffic. DeepSeek has none.
2. **One model everywhere** collapses the `DEFAULT_MODEL` / `COACH_MODEL` split — one
   rate in every cost calculation, one set of eval numbers. Two tiers is how a stale
   $0.50/M assumption survived months in our own pricing docs.
3. The remaining saving is **$0.26/owner/month at 30 questions** — not worth a second
   unknown.

### What this settles

A coach question went from **$0.1142 to $0.0146**. Thirty of them cost **$0.44**. Every
cost lever we had been arguing over — shrinking the retrieved-notes count, restructuring
the tool loop, capping questions per month — was worth a fraction of one model swap plus
one formatting fix, and two of those three would have cost answer quality.

**Reproduce it:**

```bash
cd apps/server
COACH_MODEL=<model> uv run python -m tests.grounding_eval run --repeats 4 --out arm.json
uv run python -m tests.grounding_eval compare before.json after.json   # free
```

⚠ `run` **truncates and re-seeds** the database it points at — never aim it at data
anyone needs. Point `POSTGRES_*` at a throwaway container. Set
`EVAL_OPENROUTER_API_KEY` to a key with its own small credit limit: this harness once
drained the shared account and took the production AI layer down behind a green
`/healthz`.

## Repository layout

```
apps/server/          Python backend
  src/healthee/
    core/             config · one pooled DB · request/Supabase auth · tenancy · notify · logging
    db/               schema + numbered migrations + runner
    ingest/           /ingest/helio payload validation + upserts
    derive/           the science layer (RHR·HRV·VO2max·MVPA·TRIMP·sleep·recovery…)
    analytics/        baselines · correlations · anomalies · cutoffs · bio-age
    read/             per-endpoint read services (canonical-table reads)
    insights/         grounded-ask choke point · blocking validator · coach · insight endpoints
    jobs/             scheduler + the supervised event chain (correlate→recs→warm→briefing)
    api/              app wiring + thin routers
  tests/              unit · integration (seeded DB) · contract snapshots
apps/mobile/          Flutter app (Phase 2)
packages/knowledge/   graded research corpus (notes/ + sports-science/) + generated manifest
packages/contracts/   API contract snapshots shared server↔mobile
infra/                Dockerfile · compose (dev + prod) · nginx · deploy.sh · backup
docs/                 architecture · engineering standards · intelligence · coach prompt & roadmap
```

## API surface

All endpoints except `/healthz` require a `Bearer` token. Auth is **dual and
transitional** (`core/request_auth.py`):

- **A Supabase JWT** → that real user, JIT-provisioned on first sight (subject to
  the signup gate below). This is the permanent path — the backend is a *resource
  server*: it verifies Supabase's JWT, it never issues one.
- **The legacy shared `REALTIME_INGEST_TOKEN`** → the single sentinel owner. This
  keeps the un-rebuilt app working and **goes away when Phase 2 ships Supabase
  login**. `/api/me` and `/api/device` pointedly reject it: minting a device token
  is minting a long-lived credential.
- Anything else → 401. `/ingest/*` additionally accepts a per-user **device token**
  (stored hash-only), which attributes the push to its owner.

**Do not set `SIGNUPS_OPEN=true` while the shared-token branch is alive** — a
shared secret that resolves to a real tenant must never coexist with public
signups. New accounts are otherwise gated by `SIGNUP_ALLOWLIST` (see
[`docs/MULTI_USER.md`](docs/MULTI_USER.md) §4.4b).

**Health & ingest**
- `GET  /healthz` — liveness + DB (503 if the DB is unreachable). Deliberately narrow:
  it is wired to the container healthcheck, so a 503 here means *restart me*.
- `GET  /readyz` — dependency readiness, including the **AI layer** — last-known LLM
  transport status (from real traffic, never a probe call) and the OpenRouter balance
  state. 503 when the transport is down or the balance is exhausted. Nothing restarts
  on it, and it costs no tokens.
- `POST /ingest/helio` — the app's sync push (samples, sleep, workouts, daily totals, profile)

**Identity** (Supabase JWT only — the shared token is rejected here)
- `GET  /api/me` — the authenticated owner
- `POST /api/device` — mint a device token for background ingest (returned once; stored hash-only)

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
Set at minimum `POSTGRES_PASSWORD` and `REALTIME_INGEST_TOKEN`. If you want the AI
surfaces you need `OPENROUTER_API_KEY` **and** `DEFAULT_MODEL` + `COACH_MODEL` —
they have no defaults, and a prod env missing the model ids is a real failure this
project has already had.

**Environment variables** (`infra/.env` — `infra/.env.example` is the authoritative
list; every var below is a field on `core/config.py`'s settings):

| Var | Purpose |
|---|---|
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | the **admin/owner** credentials — migrations, `claim_sentinel`, `provision_app_role` |
| `POSTGRES_HOST` / `POSTGRES_PORT` | `db` / `5432` for the compose stack |
| `POSTGRES_APP_USER` / `POSTGRES_APP_PASSWORD` | the **least-privilege** role the request/job pool connects as. **Unset ⇒ the pool falls back to the admin, which bypasses RLS** — the policies stay inert and the startup log warns. Set these in prod (see `infra/DEPLOY.md`) |
| `REALTIME_INGEST_TOKEN` | the legacy shared token → the sentinel owner (transitional, see [API surface](#api-surface)) |
| `SUPABASE_JWT_SECRET` / `SUPABASE_JWT_AUD` / `SUPABASE_PROJECT_REF` / `SUPABASE_SERVICE_ROLE_KEY` | verifying the Supabase access JWT (the backend only verifies; it never issues) |
| `SIGNUPS_OPEN` / `SIGNUP_ALLOWLIST` | the server-enforced signup gate. Default: closed + empty = nobody new. **Keep `SIGNUPS_OPEN=false` until Phase 2 ships Supabase login** |
| `SELF_HOST_UNLOCKED` | entitles **every** owner on this deployment to the premium AI layer, with no `subscription` row. Default `false`. For a SELF-HOSTED box, where the LLM bill is the operator's own — the hosted service must leave it false. Logged as a WARNING on every boot when set, and must reach the **scheduler** container too |
| `UPGRADE_URL` | where a locked card sends someone. Carried verbatim in the 402 body and by `GET /api/entitlement`; blank until a billing provider is chosen |
| `API_HOST` / `API_PORT` | in-container bind (`0.0.0.0` / `8765`) |
| `OPENROUTER_API_KEY` | optional — enables the grounded LLM (coach, insights, recs) |
| `DEFAULT_MODEL` / `COACH_MODEL` | **required with `OPENROUTER_API_KEY`** — the model ids; no defaults |
| `LLM_TIMEOUT_S` / `LLM_MAX_RETRIES` | LLM call bounds (`60` / `1`) — the SDK default is a 30-minute hang, so this is not optional tuning |
| `LLM_LOW_BALANCE_USD` | `20` — the OpenRouter balance the scheduler warns below (`infra/DEPLOY.md` §E) |
| `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` | optional — daily briefing, failure alerts, and the LLM-outage/low-balance alerts |
| `LOG_LEVEL` | `INFO` |
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
curl -sS  http://127.0.0.1:8765/readyz                # → the AI layer too (llm.transport / llm.balance)
```
Then **provision the least-privilege role** so RLS actually applies — it is a
two-step bootstrap (provision it as the admin *first*, then set
`POSTGRES_APP_USER`/`POSTGRES_APP_PASSWORD` and restart; setting them first means
the app cannot authenticate at all):
```sh
POSTGRES_APP_USER=healthee_app POSTGRES_APP_PASSWORD='<secret>' \
  $COMPOSE exec api python -m healthee.db.provision_app_role
# now put both vars in infra/.env and restart api + scheduler
```
Confirm the startup log says `connected as least-privilege role`. If it says
`BYPASSES Row-Level Security`, the pool is on the admin and the policies are inert.
Full procedure and the one-time cutover: [`infra/DEPLOY.md`](infra/DEPLOY.md).
The `api` service binds to `127.0.0.1:8765` only. The `scheduler` service ticks
every 5 minutes and runs each owner's daily chain (correlate → recs → warm →
briefing) once per **their own local day**, at 10:30 in **their** `app_user`
timezone — there is no global fire zone and no staggered start times.

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
via `git reset --hard origin/<branch>`), **takes a backup and aborts if it fails**,
stops api + scheduler for a planned outage, runs migrations, provisions the app
role, recreates api **and** scheduler, polls `/healthz`, and checks which DB
identity the pool ended up on. `--dry-run` prints the plan and changes nothing.

> ⚠ **There is no zero-downtime path and no down-migrations.** Old code cannot
> serve the new schema, and rollback is a **restore from a dump**, not a checkout.
> Read [`infra/DEPLOY.md`](infra/DEPLOY.md) — it owns the procedure, the one-time
> cutover, and rollback; [`infra/backup/RESTORE.md`](infra/backup/RESTORE.md) owns
> the restore.

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

- **Phase 1 — server core** ✅ done, deployed.
- **Phase 6 — cutover + multi-user** ✅ done (out of numeric order). Production runs
  from this repo; the legacy stack is stopped. The server is genuinely
  multi-tenant: Supabase auth-only identity, `user_id` on all 16 data tables folded
  into every key, per-user timezone end-to-end, a server-enforced signup gate, a
  least-privilege DB role, and Postgres RLS as the backstop. See
  [`docs/MULTI_USER.md`](docs/MULTI_USER.md). **Outstanding:** the transitional
  shared-token branch (dies with Phase 2), 6.6 premium gating (not built),
  rate-limiting, per-user backup/export.
- **Phase 2 — mobile core**: BLE layer, the 60-day local tier, features rebuilt
  clean, **Supabase login** — the critical path: it is what lets the shared token
  die and signups open.
- **Phase 3 — on-device tier**: local mirror + `/api/sync/down` + offline-first.
- **Phase 4 — device analytics**: provisional metrics on-device, parity-tested.
- **Phase 5 — companion intelligence**: per-card confidence, weekly review, coach
  memory → outcome ledger → proactive → goal-oriented planning
  (see [`docs/COACH_ROADMAP.md`](docs/COACH_ROADMAP.md)), knowledge reconciliation
  (the corpus unification already landed early, with Phase 1).

## Documentation

| Doc | What |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Target architecture + the phase/work-package plan (the summary — it points at the owner doc per subject) |
| [docs/MULTI_USER.md](docs/MULTI_USER.md) | Multi-tenancy: identity, RLS, the app role, per-user jobs, the signup gate |
| [infra/DEPLOY.md](infra/DEPLOY.md) | The deploy procedure, the one-time cutover, rollback |
| [docs/PRICING.md](docs/PRICING.md) | The free/premium line + the LLM cost model |
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
