# Deploy runbook — Healthee

For the human at 2am. Everything here is run **on the VPS** (`ssh contabo`), from
the repo root, and all of it assumes:

```sh
cd <the repo checkout>    # find it: `ls -d ~/healthee*` — confirm `infra/deploy.sh` is there
COMPOSE="docker compose --env-file infra/.env -f infra/docker/docker-compose.prod.yml"
```

> The live checkout is **`~/healthee-new`** (confirmed 2026-07-17 from the running
> container's own compose label:
> `docker inspect healthee-api --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}'`
> → `/home/afkcodes/healthee-new/infra/docker`). `~/healthee` **also exists** but is
> the legacy checkout — both dirs are real, which is why `ls` alone can't tell them
> apart; ask the running container. `deploy.sh` itself doesn't care: it locates the
> repo from its own path.

Related: `infra/backup/RESTORE.md` (restore drill) · `infra/.env.example` (every
var, annotated) · `docs/MULTI_USER.md` §3.3a (the app role) / §4.4b (owner
onboarding) / §8 (the data migration).

> **If you are deploying Phase 6 for the first time, do NOT start at section A.**
> Read **section B** first. It is a credential change and a schema change, and
> the order matters.

---

## A. Routine deploy (the happy path)

```sh
git push                      # ON YOUR LAPTOP, first. The VPS deploys from origin.
infra/deploy.sh --dry-run     # read the plan
infra/deploy.sh               # do it
```

`deploy.sh` is the only supported way to deploy. It:

1. **Preflights** and reads `infra/.env` (`DEPLOY_BRANCH`, default `main`).
2. **Refuses** if the local branch has commits not on origin — the VPS deploys
   via `git reset --hard origin/<branch>`, so unpushed work is silently lost.
3. `git reset --hard origin/<branch>`.
4. **Builds** the api image (the scheduler shares it).
5. **Backs up** the DB via `backup/pg_dump_backup.sh`. A failed backup **aborts
   the deploy**.
6. **Stops** `api` + `scheduler`. ⏱ **The outage starts here.**
7. **Migrates**: `$COMPOSE run --rm api python -m healthee.db.migrate`.
8. **Provisions** the app role — every deploy, idempotently (see B). Skipped when
   `POSTGRES_APP_*` are unset.
9. **Recreates** `api` **and** `scheduler`.
10. Polls `/healthz`, then reports **which DB role the app connected as**.

### Why there is an outage

The migrations are **not backwards-compatible**. `0004` folds `user_id` into the
natural keys (old code's `ON CONFLICT (day, metric)` then matches no constraint)
and `0007` drops the `user_id` DEFAULT (old owner-less INSERTs become
`NotNullViolation`). Old code **cannot** serve the new schema, so there is no
zero-downtime path — leaving the containers up during the migration would just
mean erroring mid-write. The api is down from step 6 to step 9, on purpose. For a
routine deploy with no pending migrations that is a container restart (seconds).

### What "healthy" looks like

```
▶ Health check
  ✓ healthy after 3 attempt(s): http://127.0.0.1:8765/healthz

▶ Verifying the DB identity the app pool connected as
  ✓ RLS is real — the pool is on the least-privilege role (NOSUPERUSER NOBYPASSRLS).

▶ Deploy OK
```

Anything other than `Deploy OK` (exit 0) means it did not finish. Two non-fatal
warnings you may see, both explained below: the app role being **skipped**, and
the pool being on a role that **BYPASSES Row-Level Security**.

### If it fails

- **Backup failed** → nothing was stopped or changed. Fix the backup first
  (`RESTORE.md`, `BACKUP_DIR` free space, `db` running); do not skip it.
- **Migration failed** → `api` + `scheduler` are **stopped and must stay
  stopped**. The schema may be half-moved, and old code cannot serve the new one
  regardless. Read the error, fix forward, re-run `deploy.sh` (the runner records
  each file in `schema_migrations`, so applied migrations are skipped on the
  re-run and each file is applied in its own transaction — a failed file rolled
  back cleanly).
- **Health check failed** → the script dumps the last api + scheduler logs and
  exits 1. Start there.

### Rollback

**There are no down-migrations.** Once `0002`→`0008` have applied, rolling the
*code* back does not roll the *schema* back, and the old code cannot run against
the new schema. So a post-migration rollback is a **restore**, not a checkout:

1. `$COMPOSE stop api scheduler`
2. Restore the pre-deploy dump — **`infra/backup/RESTORE.md` § "Real restore"**.
   The dump `deploy.sh` took in step 5 is the newest file in `$BACKUP_DIR`.
3. Deploy the previous known-good commit: point `DEPLOY_BRANCH` at it (or reset
   the branch on origin — the guard deploys origin's version) and re-run
   `deploy.sh`.

Before any migration has applied, a rollback is just step 3.

> ⚠ **Unverified — ask before relying on it.** There is a known
> rename-based rollback to the *pre-cutover legacy stack* (stop the new
> containers, `docker rename healthee-db-legacy healthee-db` + api/scheduler,
> start). **Nothing in this repo describes it**, so the exact container names and
> steps are not verifiable here and are deliberately not written out. If you need
> it, check the live box (`docker ps -a | grep legacy`) and confirm before acting.
> That path also predates `0002`→`0008` — the legacy stack has its own DB volume,
> so any data written after the cutover would not be in it.

---

## B. The ONE-TIME Phase 6 cutover

Prod's DB is at **`0001`**. `main` needs **`0002`→`0008`**. This is both a schema
change and a **credential change**. Read all of B before running anything.

### B1. Env that must be in `infra/.env` BEFORE you deploy

Compose now passes these through; it previously did not, so they may be absent on
prod even if they look familiar. Annotated in full in `infra/.env.example`.

The table below is checked against `core/config.py::Settings` by
`tests/test_env_templates.py` only as far as the *templates* go — the wording here
is maintained by hand, so it is re-read against `Settings` whenever a var is added.

| Var | If missing / blank |
|---|---|
| `SUPABASE_JWT_SECRET` | Auth **fails closed** — every Supabase JWT is refused. The server silently degrades to **legacy-token-only**: it stays up and the old app keeps working, so this failure is invisible unless you test a real login. |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-side Supabase calls unavailable. |
| `SUPABASE_PROJECT_REF` | The `iss` check is **skipped** (intended for dev/self-signed tokens — on prod, set it). |
| `SUPABASE_JWT_AUD` | Defaults to `authenticated` (the Supabase default). |
| `SIGNUPS_OPEN` | Defaults to `false` — the correct posture. **See B5 before changing it.** |
| `SIGNUP_ALLOWLIST` | Empty ⇒ nobody new can sign up. This is also what makes owner onboarding possible (B4) — the claim cannot be run without it. |
| `DEFAULT_MODEL` / `COACH_MODEL` | **Required whenever `OPENROUTER_API_KEY` is set.** A blank id is forwarded to OpenRouter verbatim and comes back **400** — on every LLM surface, *including the nightly chain* in the scheduler. **The api and scheduler now REFUSE TO START** in that state (`core/config._require_model_ids_when_ai_key_is_set`), so `deploy.sh`'s `/healthz` wait fails and you see it here rather than in Telegram a week later. Blank key + blank ids is still fine: that is "no AI layer", a valid configuration. |
| `LLM_TIMEOUT_S` / `LLM_MAX_RETRIES` | Default to `60` / `1` (compose supplies those defaults). Unset in *code* the SDK would use 600 s × 3 attempts = a 30-minute hang, and the scheduler's tick loop is single-threaded, so one stuck call costs every later owner their chain. Raise the timeout only for a slow reasoning-tier `DEFAULT_MODEL`. |
| `LLM_LOW_BALANCE_USD` | Defaults to `20`. The balance below which the **scheduler** warns to Telegram (`jobs/llm_watch.py`). Warning only — nothing stops spending. Blank/0 leaves only the `exhausted` alert, which fires when every call is already 402ing. See **E** for why this exists. |
| `LOG_LEVEL` | Defaults to `INFO`. |
| `POSTGRES_APP_USER` / `POSTGRES_APP_PASSWORD` | The app falls back to the **admin** credentials, which bypass RLS. Loud startup WARNING. **Read B2 before setting these.** |

### B2. The credential ORDER (wrong order = the app cannot reach Postgres at all)

The app role must **exist** before the app is told to connect as it. `deploy.sh`
now provisions the role on every run, but it only does so when
`POSTGRES_APP_USER`/`POSTGRES_APP_PASSWORD` are set — the same vars the app pool
reads. So:

1. **Deploy once with the app vars UNSET.** The admin-cred fallback keeps the app
   alive; provisioning is skipped; you get the `BYPASSES Row-Level Security`
   warning. That is expected at this step.
   ```sh
   infra/deploy.sh
   ```
2. **Set both** in `infra/.env`:
   ```sh
   # openssl rand -base64 48 | tr -d '/+=' | head -c 32
   POSTGRES_APP_USER=healthee_app
   POSTGRES_APP_PASSWORD=<secret>
   ```
3. **Deploy again.** This run provisions the role (as the admin, password from
   the env) and then starts the app on it.
   ```sh
   infra/deploy.sh
   ```
4. **Confirm** the final step prints:
   `✓ RLS is real — the pool is on the least-privilege role`.

Setting the vars *before* the role exists means the app tries to authenticate as
a role Postgres has never heard of: total failure, not degradation.

**Why it re-provisions every deploy:** a role provisioned by *older* code lacks
`timescaledb.enable_skipscan=off`, and without that setting `/api/today` **500s
for every user** under RLS (a TimescaleDB 2.26.4 planner bug — see
`db/provision_app_role.py`). Re-provisioning keeps the role current and un-drifts
a role someone hand-altered. It is idempotent and quiet.

### B3. What `0002`→`0008` do to LIVE data

`deploy.sh` takes a backup immediately before this. The outage is the migration
window (§A "Why there is an outage"). One line each — full detail in
`MULTI_USER.md` §8:

| | |
|---|---|
| `0002` | Identity tables (`app_user`, `device_token`). Additive. |
| `0003` | Adds `user_id` to all 16 data tables and **backfills every existing row to the sentinel owner** (`00000000-…-0000`) + FK + index. That backfill is *correct*: all of it is the owner's data. Metadata-only, no table rewrite. |
| `0004` | Folds `user_id` into every natural key (PK/UNIQUE rebuild). **This is the breaking one** — old `ON CONFLICT` targets stop matching. |
| `0005` | Re-keys `profile` by owner (drops the `id INTEGER PK CHECK (id = 1)` single-row coupling). Drops a column. |
| `0006` | `device_token`'s FK → `ON UPDATE CASCADE`, so the claim's re-key doesn't error for an owner with a paired device. |
| `0007` | Drops the transitional `user_id` DEFAULT (`NOT NULL` stays). A writer that forgets the owner now raises instead of silently misattributing data. |
| `0008` | Row-Level Security + policies on every tenant table. |

After this, prod's data all belongs to the **sentinel** owner. It works — the
legacy token resolves to the sentinel — but it is not yet *your account*. That is
B4.

### B4. Owner onboarding — the claim (`MULTI_USER.md` §4.4b, §8)

**The deadlock this resolves:** `claim_sentinel` refuses a target who has never
signed in (it needs their `app_user` row, and re-keying a life of health data
onto a typo'd UUID is not undoable). But with signups closed they can never *get*
a row. The allowlist is the way out.

1. Put the owner's email in `infra/.env`:
   ```sh
   SIGNUP_ALLOWLIST=owner@example.com
   ```
2. Restart so the API sees it:
   ```sh
   infra/deploy.sh
   ```
3. **They sign in once** via the app/web with Supabase. The gate lets them
   through and JIT-provisions their `app_user` row under their real UUID. Get
   that UUID (Supabase dashboard, or the API's provisioning log line).
4. **Dry run first** — it prints the target's **email**, so you confirm you are
   handing the data to the right *human*, not just to a UUID that parsed:
   ```sh
   $COMPOSE run --rm api python -m healthee.db.claim_sentinel <uuid>
   ```
   Read the plan: source id, target id, target email, per-table row counts.
5. If and only if that email is right:
   ```sh
   $COMPOSE run --rm api python -m healthee.db.claim_sentinel <uuid> --apply
   ```
   One transaction; it post-checks that **nothing** anywhere still belongs to the
   sentinel, and rolls the whole thing back if anything does.
6. Optionally clear `SIGNUP_ALLOWLIST` and redeploy. They keep working — an
   owner who already has a row is never gated.

It refuses rather than guesses: target == sentinel · target never signed in ·
target already owns data (a merge is a judgement call, not this tool's to make).
Nothing to move ⇒ it says so and exits 0, so a re-run after success is a no-op.

### B5. ⛔ Do NOT set `SIGNUPS_OPEN=true`

Not until the **Phase-2 mobile app ships Supabase login**. The legacy shared
token (`REALTIME_INGEST_TOKEN`) still resolves to a real tenant — the sentinel /
the owner after B4 — and the live app authenticates with it. A shared secret that
resolves to a real tenant must never coexist with open signups: anyone holding it
reads and writes that tenant's health data. That is exactly the hole
`MULTI_USER.md` §12.7 exists to close. Opening signups is gated on **removing the
legacy token branch**, not on the flag existing.

(Uncontrolled signup is also uncontrolled LLM spend — every active owner gets a
nightly chain. Since 6.6a the chain **skips the LLM steps for a non-premium owner**,
which is the structural half of that bound; the signup gate is still the other half.)

---

### B6. ⛔ ENTITLE THE OWNER BEFORE THE 6.6a GATE REACHES PROD

**This is the one step that breaks the live owner if you skip it.** Migration `0011`
adds the `subscription` table, and from that deploy on **every AI surface refuses an
owner who has no active row**: the coach, the four insight cards, `/api/notable`, the
challenges and programs system, `/api/today`'s `action` and `recommendations`, and the
nightly recs/warm/briefing. "Not premium" is the default and it is silent — the API
stays green, the tracker keeps working, and the AI layer simply stops.

Today's owner authenticates with the legacy shared token and resolves to the
**sentinel** (`00000000-0000-0000-0000-000000000000`) unless B4's claim has already
re-keyed them. They have no `subscription` row. So, in the same maintenance window:

```sh
cd ~/healthee-new/infra/docker

# 1. migrate (0011 creates the table; 0009/0010 may also still be pending)
docker compose -f docker-compose.prod.yml exec api python -m healthee.db.migrate

# 2. re-run the app-role provisioner. NOT optional: 0011 is a new table, so the
#    default privileges hand the app role full DML on it, and this is what REVOKEs
#    the writes back down to SELECT (entitlement must not be app-settable).
docker compose -f docker-compose.prod.yml exec api python -m healthee.db.provision_app_role

# 3. find the owner's UUID (the sentinel, or their real id if B4 already ran)
docker compose -f docker-compose.prod.yml exec db \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT id, email FROM app_user;"

# 4. DRY RUN — read the plan (before/after, the email, the end date)
docker compose -f docker-compose.prod.yml exec api \
  python -m healthee.db.grant_premium <owner-uuid> --months 120

# 5. apply
docker compose -f docker-compose.prod.yml exec api \
  python -m healthee.db.grant_premium <owner-uuid> --months 120 --apply --by owner \
  --note "product owner, pre-billing"
```

Verify in the running image, not the repo:

```sh
curl -fsS -H "Authorization: Bearer $REALTIME_INGEST_TOKEN" \
  http://127.0.0.1:8765/api/entitlement          # → {"premium": true, "locked": [], ...}
curl -fsS -H "Authorization: Bearer $REALTIME_INGEST_TOKEN" \
  http://127.0.0.1:8765/api/today | grep -c '"action"'   # → 1 (0 means locked)
```

**The alternative, for a self-hosted box only:** set `SELF_HOST_UNLOCKED=true` in
`infra/.env` (it is passed to BOTH the `api` and `scheduler` services). That entitles
every owner on the deployment, which is right when the operator pays their own
OpenRouter bill and wrong on the hosted service — both containers log a WARNING on
every boot when it is set, so an accidental one is visible in `docker compose logs`.

Rollback of just this step: `grant_premium <uuid> --revoke --apply` (writes `canceled`;
the row and its history are kept).

---

## C. Verification checklist (after any deploy)

- [ ] **`deploy.sh` exited 0** and printed `▶ Deploy OK`.
- [ ] **`/healthz`** →
      `curl -fsS http://127.0.0.1:8765/healthz` (it does a real `SELECT 1`, so a
      200 means the DB is reachable too).
- [ ] **Public** → `curl -fsS https://healtheeapi.afk.codes/healthz` (proves
      nginx → 127.0.0.1:8765 too).
- [ ] **The DB role line** → the script's last step. `connected as least-privilege
      role` = RLS is real. `BYPASSES Row-Level Security` = the fallback is active;
      not fatal, but RLS is isolating nothing — go to B2.
      By hand: `$COMPOSE logs api | grep -i 'db pool'`.
- [ ] **A real authenticated read** →
      `curl -H "Authorization: Bearer <token>" https://healtheeapi.afk.codes/api/today`
      → **200**. This is the check that catches the RLS/skipscan failure and any
      tenant-scoping break; `/healthz` cannot. Do it after every Phase 6 deploy.
- [ ] **Migrations are where you think** →
      `$COMPOSE run --rm api python -m healthee.db.migrate` again; it should say
      `no pending migrations`. (It is a no-op when nothing is pending.)
- [ ] **The scheduler is actually up and on the new code** →
      `$COMPOSE ps scheduler` (Up, not Restarting) and
      `$COMPOSE logs --tail 30 scheduler`. A crash-looping scheduler leaves
      `/healthz` green and the nightly chain dead.
- [ ] **Failures surface in Telegram**, not in the terminal: every supervised
      chain step reports there on failure (`TELEGRAM_BOT_TOKEN` /
      `TELEGRAM_CHAT_ID`; blank ⇒ silent no-op — so a blank token means job
      failures go **nowhere**). The nightly chain runs on IST timers, so the real
      proof of a scheduler deploy arrives the next morning.
- [ ] **`/readyz`** → `curl -sS http://127.0.0.1:8765/readyz | python3 -m json.tool`.
      This is the probe that knows about the **AI layer**; `/healthz` deliberately
      does not (see **E**). Read the `llm` block:
      `transport` is `unknown` until this process has made an LLM call — that is
      honest, not a fault, and it turns `ok` after the first one;
      `balance` must be `ok`, and `balance_checked: false` means we could **not
      measure** it (`balance_error` says why — a 401 there means the key is dead).
      A `503` here with `db: ok` is an AI-layer outage, not a server outage: do
      **not** restart anything, go top up or rotate the key.
- [ ] **The scheduler's LLM watch is armed** →
      `$COMPOSE logs --tail 50 scheduler`. Within one tick of start it probes the
      balance; if it is low or the key is dead you get a Telegram message, and if
      everything is fine you get **nothing** (edge-triggered by design).

---

## D. Rotating a secret

All app secrets live in **`infra/.env` on the box** (git-ignored — they are never
in the repo, and `git reset --hard` during a deploy does not touch `.env`). The
pattern is the same for all of them: **edit `infra/.env`, then restart the process
that reads it.** A code deploy is *not* required — the value is read at process
start, so a restart is enough. What differs per secret is (1) how you mint the new
value and (2) which process reads it.

Editing `.env` alone changes nothing on a running container — it is read once at
start. Always restart afterward (below), or the old value stays live.

### D1. Telegram bot token (`TELEGRAM_BOT_TOKEN`)

Read by the **scheduler** (it sends the nightly chain + failure alerts) — not the
api. So only the scheduler needs the restart.

1. **Mint it in BotFather** (Telegram): message `@BotFather` → `/token` (reissue for
   the existing bot) or `/newbot` (a brand-new bot — also gives a new username).
   `/revoke` kills the old token immediately; a reissue via `/token` also
   invalidates the previous one. **Rotation is the only thing that kills an
   already-leaked token** — changing the code that logs it does not.
2. **Edit `infra/.env`** on the box: set `TELEGRAM_BOT_TOKEN=<new>`. (If you made a
   *new* bot, send it a message first and update `TELEGRAM_CHAT_ID` too — a fresh
   bot cannot message you until you start a chat with it.)
3. **Restart the scheduler:**
   ```sh
   $COMPOSE up -d --force-recreate scheduler
   ```
4. **Confirm** — send a test line, and confirm the token is no longer printed in
   the log (the api pins httpx to WARNING since `f3776ac`, so the request URL — and
   the token in it — should not appear at all):
   ```sh
   $COMPOSE logs --tail 50 scheduler | grep -i telegram    # status lines, no token
   $COMPOSE logs scheduler | grep -c 'bot[0-9]'             # want 0 — no token in the URL
   ```

> The token sits in the Telegram **URL path** (`api.telegram.org/bot<TOKEN>/…`),
> which is why an HTTP client that logs request URLs leaks it. Treat any token that
> has ever appeared in a log or a terminal as burned — rotate it.

### D2. The other secrets — same shape, different mint + restart

| Secret | Where you get the new value | Restart |
|---|---|---|
| `OPENROUTER_API_KEY` | openrouter.ai → Keys → create; delete the old key there to revoke it. | `api` **and** `scheduler` (both make LLM calls). |
| `POSTGRES_APP_PASSWORD` | You choose it (`openssl rand -base64 48 \| tr -d '/+=' \| head -c 32`). **Not** a self-service rotation: the role's password lives in Postgres too, so `deploy.sh` must re-run to re-provision the role with the new value — see **B2**. Editing `.env` alone will lock the app out (`.env` says X, Postgres still expects Y). | Run `infra/deploy.sh` (it re-provisions, then restarts). |
| `SUPABASE_JWT_SECRET` | Supabase dashboard → Project → **Settings → API → JWT Settings → JWT Secret**. Rotating it there invalidates every issued token, so every user re-logs in. | `api`. |
| `SUPABASE_SERVICE_ROLE_KEY` | Same page → **Project API keys → `service_role`** (Reveal / Roll). This key bypasses RLS — treat it like a root password. | `api`. |
| `REALTIME_INGEST_TOKEN` | You choose it — but it is the **legacy shared token the strap app authenticates with**, so rotating it requires updating the app's build/config in lockstep or ingestion stops. Do not rotate casually before Phase 2. | `api`. |

### D3. What is `POSTGRES_APP_PASSWORD`? (the "app-role password")

Postgres has **two** roles for Healthee, on purpose:

- the **admin** role (superuser) — runs migrations, `TRUNCATE`, the role
  provisioning. It **bypasses Row-Level Security** (superusers always do).
- the **app** role (`POSTGRES_APP_USER` / `POSTGRES_APP_PASSWORD`, a *non*-superuser)
  — what the running API connects as to serve requests. Because it is **not** a
  superuser, RLS policies actually apply to it, so a query that forgets the tenant
  filter returns *nothing* instead of another user's rows.

`POSTGRES_APP_PASSWORD` is **a value you invent**, not one issued by a service — it
is the password for that second role. It has to match in two places (the Postgres
role and `infra/.env`), which is why changing it is a `deploy.sh` re-provision, not
a plain `.env` edit (**B2**). While it is unset, the app falls back to the admin
role and **RLS protects nothing** — fine with one owner, a hard blocker before a
second. See `docs/MULTI_USER.md` §3.3a.

### D4. What is `SUPABASE_PROJECT_REF`, and where do I get it?

Supabase is the managed **auth** provider (it issues the login JWT; our server only
*verifies* it — see `docs/MULTI_USER.md` §4). The **project ref** is your Supabase
project's short id — the `abcdefghijklmnop` in your project URL
`https://abcdefghijklmnop.supabase.co`. Find it in the Supabase dashboard: **Project
Settings → General → Reference ID** (or just read it out of the project URL / the
API URL on **Settings → API**).

It is **not a secret** (it is in every request URL to your project), so it is safe
to commit to `.env` and to name here. We use it to build the expected token issuer
`https://<ref>.supabase.co/auth/v1` and **reject** a JWT whose `iss` doesn't match —
so a valid-looking token minted by a *different* Supabase project is refused. Leave
it blank and that issuer check is **skipped** (intended only for dev / self-signed
tokens); on prod, set it. Restart `api` after adding it.

---

## E. The OpenRouter account — spend limits, keys, and how a dead AI layer surfaces

### E1. What happened (2026-08-01), because the fix only makes sense with it

The account hit its **$200 ceiling**. Every LLM call 402'd — the coach, every insight
card, the entire nightly chain — and `/healthz` returned `{"status":"ok","db":"ok"}` for
the duration. Nobody found out from monitoring; an unrelated eval run happened to die and
that is how it surfaced. It is the same shape as every earlier incident in this repo:
**`/healthz` was green in every broken state.**

Two causes, and both have a cheap fix below: there was **no spend limit**, and **eval/dev
work shared the production key** — the grounding-eval harness (`tests/grounding_eval/`,
~$3/arm) was draining the balance production runs on.

### E2. ⛔ Set a spend limit on the key (openrouter.ai → Keys)

Each OpenRouter key can carry a **credit limit**. Set one on the production key. It does
not prevent the outage — it *bounds* it, and more importantly it makes an eval key
incapable of emptying the account:

- **production key** — limit ≈ a month of expected spend (`docs/PRICING.md` §3.1 has the
  measured numbers). Set in `infra/.env` as `OPENROUTER_API_KEY`; rotation is **D2**.
- **eval/dev key** — a **separate key with a small limit** (a few dollars covers several
  harness arms). It lives in `apps/server/.env` on the dev machine and **never** on the
  VPS. A drained eval key then costs you an eval run, not the live AI layer.

Same rule for any other key that runs experiments. The production key belongs to exactly
one thing: the production containers.

### E3. What the server now does about it

Three pieces, none of which ever spends a token to check:

| Piece | Where | What it does |
|---|---|---|
| Transport record | `insights/transport_health.py` | Every real completion records ok/failed. **3 consecutive failures** = an outage; one 402 is a blip and is ignored. Stores the failure *kind* + HTTP status only — never the provider's message, which can contain the model id. |
| Balance probe | `insights/credits.py` | `GET /api/v1/credits` — **free, no tokens**. Also proves the key still works (a revoked key 401s here). TTL-cached. |
| The watcher | `jobs/llm_watch.py` (runs in the **scheduler**) | Pushes to the same Telegram channel as chain failures. **Edge-triggered**: once on the way in, once on recovery — never every tick. |

What you will actually receive, and how fast:

- **`⛔ LLM transport DOWN`** — within one scheduler tick (**≤ 5 min**) of the third
  consecutive failed call in that container. Names the kind (`credit` / `auth` /
  `rate_limit` / `timeout`) and whether waiting will help.
- **`⚠️ OpenRouter credits LOW`** — within the hour, at `LLM_LOW_BALANCE_USD`. This is
  the one that means you never see the others.
- **`⛔ OpenRouter credits EXHAUSTED`** / **`⚠️ balance check FAILED`** — same cadence.
  The second one matters: an *unmeasurable* balance is reported as **unknown**, never as
  fine. A monitoring feature that fails quiet is worse than none.
- **`✅ … recovered` / `healthy again`** — so a silent channel means "still broken", not
  "nobody is watching".

The pull-side view is **`GET /readyz`** (unauthenticated, no dollar figures — the amounts
go to Telegram). See the checklist in **C** for how to read it.

### E4. Why `/healthz` was deliberately left alone

Because a 503 on `/healthz` means *restart this container*, and that is all it may ever
mean: it is wired to the Docker healthcheck and to nginx. If it went 503 on a provider
outage, Docker would restart the API in a loop over something no restart can fix —
trading a dead AI layer for a flapping read API. `core/config.py` records the same
argument for the blank-model-id check. So the AI-layer signal lives on `/readyz`, which
nothing restarts on, and the **push** (Telegram) is what actually reaches a human.
