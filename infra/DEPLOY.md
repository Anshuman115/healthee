# Deploy runbook — Healthee

For the human at 2am. Everything here is run **on the VPS** (`ssh contabo`), from
the repo root, and all of it assumes:

```sh
cd <the repo checkout>    # find it: `ls -d ~/healthee*` — confirm `infra/deploy.sh` is there
COMPOSE="docker compose --env-file infra/.env -f infra/docker/docker-compose.prod.yml"
```

> The checkout path is **not verifiable from this repo**, and the two sources that
> named one disagreed (an older `deploy.sh` header said `~/healthee`; the cutover
> notes say `~/healthee-new`). Neither now claims a path, because a wrong path in a
> runbook is worse than none — it sends a tired operator into an ancient checkout.
> Look before you `cd`. `deploy.sh` itself doesn't care: it locates the repo from
> its own path. Everything else here is verified against the repo.

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

| Var | If missing / blank |
|---|---|
| `SUPABASE_JWT_SECRET` | Auth **fails closed** — every Supabase JWT is refused. The server silently degrades to **legacy-token-only**: it stays up and the old app keeps working, so this failure is invisible unless you test a real login. |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-side Supabase calls unavailable. |
| `SUPABASE_PROJECT_REF` | The `iss` check is **skipped** (intended for dev/self-signed tokens — on prod, set it). |
| `SUPABASE_JWT_AUD` | Defaults to `authenticated` (the Supabase default). |
| `SIGNUPS_OPEN` | Defaults to `false` — the correct posture. **See B5 before changing it.** |
| `SIGNUP_ALLOWLIST` | Empty ⇒ nobody new can sign up. This is also what makes owner onboarding possible (B4) — the claim cannot be run without it. |
| `DEFAULT_MODEL` / `COACH_MODEL` | **Required whenever `OPENROUTER_API_KEY` is set.** A blank id is forwarded to OpenRouter verbatim and comes back **400** — on every LLM surface, *including the nightly chain* in the scheduler. Failures surface in Telegram, not in `/healthz`. |
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
nightly chain.)

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
