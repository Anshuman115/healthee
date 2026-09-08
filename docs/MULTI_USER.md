# Healthee — Multi-User / Multi-Tenancy Design & Migration Plan

Turn the single-tenant app (one strap, one user, one timezone) into a real
multi-tenant framework: every user has their own strap, timezone, data,
derived metrics, analytics, findings, recs, coach, and challenges — fully
isolated. This is **Phase 6** of the blueprint, built in **this clean-rebuild
monorepo** (not the legacy repo's abandoned `multi-user` branch).

Status: **BUILT — 6.1 → 6.5 have shipped to `main`** (migrations `0002`→`0008`).
The server is genuinely multi-tenant: every tenant read and write is owner-scoped,
per-user timezone is live end-to-end, and Postgres RLS is the backstop underneath.
This document is therefore **both** the design record and the description of what
runs — each section states its own status; **[D#]** decisions carry theirs inline
([D1]/[D2]/[D3] taken, [D4]/[D5] still open).

**What is NOT done, stated plainly** (details at the linked sections):

- **The legacy shared-token branch is live** (§4.4a). Auth is dual and
  transitional; it cannot be removed until the Phase-2 mobile app ships Supabase
  login. **`SIGNUPS_OPEN=true` must not be set before then** (§4.4b, §12.7).
- **RLS only protects prod once `POSTGRES_APP_*` is set there** (§3.3). The
  policies are in the schema, but a pool that falls back to the admin superuser
  bypasses them.
- **6.6 premium gating is built as far as *entitlement*, not *billing*** (§12).
  `subscription`, `is_premium`, `require_ai_access` (`api/gate.py`), the nightly
  chain's skip and the metered allowance all run (6.6a + 6.6a-2 — the free half of
  which is now priced at zero, with the same ledger carrying premium's coach cap); what is
  missing is the provider, checkout and webhooks ([D4]/[D5]), so entitlement is
  written by `db/grant_premium.py` or `SELF_HOST_UNLOCKED` and by nothing else.
  *(This bullet claimed none of it existed until 6.6a-2 corrected it — §12's own
  status block had been updated and this summary had not.)*
- **General request rate-limiting and per-user backup/export** are not built
  (§11, 6.5). Two *specific* per-owner budgets do exist on the surfaces that spend
  money (`core/rate_limit.py`: generation, and the daily-action reveal).

---

## 0a. Infrastructure topology (chosen stack)

```
  Web app (Cloudflare Pages)  ─┐        ┌─ Supabase Auth ── (login, JWT, refresh,
  Flutter app (mobile)        ─┤        │   OAuth, reset) — issues the access JWT
                               │        │
        sign in ──────────────────────►─┘
        (get Supabase JWT)     │
                               ▼
                    Cloudflare (DNS · CDN · TLS · WAF/rate-limit)
                               │  api.healthee…  (proxied)
                               ▼
              ┌──────────  Contabo VPS  ──────────────────────┐
              │  FastAPI (verifies Supabase JWT → user UUID)   │
              │  + scheduler (per-user nightly chain)          │──► OpenRouter (LLM)
              │  TimescaleDB (ALL health data, RLS by UUID)    │──► Stripe/Polar (webhooks)
              └────────────────────────────────────────────────┘
   Helio strap ──BLE──► Flutter app ──POST /ingest (device token)──►  (Contabo API)
```

- **Cloudflare** — DNS, CDN, TLS, and the WAF/edge rate-limiting (a useful extra
  layer for the paywall-abuse + signup-abuse concerns); **Pages** hosts the web app.
- **Supabase** — managed **auth only** (§4). Its Postgres holds identity; it is NOT
  the health DB.
- **Contabo VPS** — the FastAPI API + scheduler + **TimescaleDB (all health data)**,
  same docker-compose deploy as today. The API is a *resource server*: it verifies
  Supabase JWTs, it does not issue them.
- **OpenRouter** (LLM) and **Stripe/Polar** (billing) are outbound integrations from
  the API; their secrets live in the API env on Contabo.
- **Two clients** (web on Pages, Flutter mobile) share one auth (Supabase) and one
  API (Contabo). Watch: **CORS** (allow the Pages origin), and keep the Supabase JWT
  secret / OpenRouter key / billing-webhook secret server-side only.

---

## 1. Principles

1. **Full isolation.** A user can only ever read/write their own rows. No
   endpoint, job, cache entry, or LLM context ever crosses users. Enforced in
   TWO layers: every query filters by `user_id` (app layer) AND Postgres
   Row-Level Security (defense-in-depth, so a missed `WHERE` can't leak).
2. **The science is tenant-agnostic.** `derive/` and `analytics/` operate on a
   user's data set; the formulas do not change. Multi-user is a *scoping* change,
   not a science change — porting rule still holds.
3. **One database, row-level tenancy.** A `user_id` column on every data table,
   NOT a schema-per-user or DB-per-user split (those break the single pool and
   multiply ops cost for no benefit at this scale). TimescaleDB hypertables keep
   working; queries gain `AND user_id = %s`.
4. **Ship in additive phases.** Each phase leaves `main` green and prod working;
   the legacy single tenant keeps functioning until the flip. *(Held: the tenant
   is now the **sentinel owner UUID** rather than `id = 1` — `0003` seeds it and
   `0005` re-keyed `profile` by owner, so `id = 1` no longer exists anywhere.)*

---

## 2. The single-tenant couplings we are removing (grounded audit)

**Every row in this table is now closed.** The audit is preserved as the record of
what was wrong and where; the "Fix" column describes shipped code.

| Coupling | Where | Fix |
|---|---|---|
| ~~One shared bearer token, no identity~~ **DONE 6.4b** | `core/auth.py` `require_token()` returns `None` | `core/request_auth.py` resolves + returns a `RequestUser` (Supabase JWT / device token); `core/auth.py` is **deleted**. The shared token survives as one transitional branch → the sentinel (§4.4a) |
| ~~`profile` locked to one row~~ **DONE 6.3c** | `0001_initial.sql`: `id INTEGER PK DEFAULT 1 CHECK (id = 1)` | `0005`: `id` dropped; `user_id` is the PK |
| ~~No tenant column on any data table~~ **DONE 6.2/6.3a** | all 15 data tables (`sample`, `derived_daily`, `sleep_session`, `workout`, `weight_log`, `manual_entry`, `illness_flag`, `recommendation`, `finding`, `challenge`, `program`, `challenge_outcome`, `gps_track`, `gps_point`, `kv`) — 16 with `profile` | `0003` added `user_id` + FK + index; `0004` folded it into every PK/UNIQUE and retargeted every `ON CONFLICT` |
| ~~`WHERE id=1` profile reads~~ **DONE 6.3c** | `derive/_common.py`, `analytics/biological_age.py`, `read/history.py`, `jobs/recs_context.py` | all four now filter on `user_id` alone |
| ~~Hardcoded timezone~~ **DONE 6.3b/6.4a/6.4c** | `USER_TZ = "Asia/Kolkata"` — **63 references** | per-user `app_user.timezone` (not `profile`), threaded as `tz: str`; `USER_TZ` and `scheduler.TZ` are both gone |
| ~~Global nightly chain~~ **DONE 6.3c** (fire times: 6.4) | `jobs/scheduler.py` fires ONE chain; `jobs/chain.py` dedups per-day via a global `kv` key | `_fire` sweeps `active_users()`; dedup is per-owner via the `kv` PK |
| ~~Global cache keys~~ **MOOT — see §6** | `insights/coaching.py DAILY_ACTION_KEY`, `chain _DONE_KEY:{day}` | superseded by `0004`'s `kv` PK `(user_id, key)`; keys are NOT namespaced |
| ~~Ingest has no owner~~ **DONE 6.4b** | `/ingest/helio` writes samples unattributed | device token → `user_id`, written under it; an unknown token is 401 (§7) |
| ~~~119 query sites assume "the user"~~ **DONE 6.3a/6.3b** | read ~59 · derive ~30 · analytics ~17 · insights ~8 · jobs ~5 | `user_id` threaded (§5); the AST guard `tests/db/test_tenant_read_scoping.py` fails the build on any new unscoped tenant SQL |

---

## 3. Data model

**Two databases (chosen stack):** identity lives in **Supabase** (its own
Postgres, `auth.users`, UUID ids); all **health data lives in the Contabo
TimescaleDB** (self-hosted, as today). The tenant key everywhere is the **Supabase
user UUID** — see §0a Topology and §4.

### 3.1 Local identity mirror (Contabo DB)

Supabase owns credentials/passwords/sessions. Our DB keeps a thin mirror keyed by
the Supabase UUID, for profile + the app's own concerns — **no password storage
here**:

```sql
CREATE TABLE app_user (                          -- mirror of the Supabase user
  id          UUID PRIMARY KEY,                  -- = Supabase auth.users.id (sub)
  email       CITEXT,                            -- mirrored for convenience/joins
  status      TEXT NOT NULL DEFAULT 'active',
  timezone    TEXT NOT NULL DEFAULT 'UTC',       -- IANA name, per-user
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Rows are JIT-provisioned on first authenticated request (see §4), and/or via a
-- Supabase auth webhook on signup/delete (delete → cascade-purge health data).

CREATE TABLE device_token (                       -- per-strap/app INGEST credential
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL,                       -- store only the hash
  label       TEXT,                                -- "Ashish's Helio strap"
  last_seen   TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX device_token_hash_idx ON device_token (token_hash);
```
> `device_token.user_id` also carries **`ON UPDATE CASCADE`** (added in `0006`) — it
> was the one FK to `app_user` outside `0003`'s sweep, and without it the 6.4c
> sentinel re-key errors as soon as the owner has a paired device (§8).

There is **no local `credential` table and no session table** — Supabase handles
login, refresh, reset, verification, OAuth. Intra-DB FKs from health tables to
`app_user` still hold (both are in the Contabo DB); the only relationship without a
DB-level FK is Contabo `app_user` ↔ Supabase `auth.users` (cross-DB — kept
consistent by JIT-provision + the delete webhook).

### 3.2 Tenant column on every data table — **DONE** (`0003` + `0004`)

`user_id UUID NOT NULL REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE`
is on all 16 data tables and folded into the key. It landed in two steps (§8): the
column + FK + `(user_id, …)` index additively in **6.2** (`0003`), then the key-fold
below (PKs/UNIQUE) in **6.3a** (`0004`) so it changed together with the `ON CONFLICT`
code. **`0007` then dropped the transitional column DEFAULT** — a writer that omits
the owner now raises `NotNullViolation` instead of silently attributing the row to
the sentinel. The list below describes the shipped keys.

- `sample`: PK `(user_id, metric, ts)`; hypertable stays partitioned on `ts`,
  add index `(user_id, metric, ts DESC)`.
- `derived_daily`: PK `(user_id, day, metric)`.
- `sleep_session` / `workout`: PK `(user_id, start_ts)`.
- `weight_log`: PK `(user_id, ts)`.
- `kv`: PK `(user_id, key)` (jobs/cache markers become per-user).
- `manual_entry` / `finding` / `gps_track`: keep UUID/serial PK, add `user_id`
  + index; extend the UNIQUE constraints (`finding` UNIQUE →
  `(user_id, kind, metric_a, metric_b, event_kind, lag_days)`).
- `illness_flag`: PK `(user_id, date)`.
- `recommendation`: UNIQUE `(user_id, date, rank)`.
- `challenge` / `program`: add `user_id` + index; `challenge_outcome` inherits via
  `challenge_id` FK (no direct column needed, but add one for RLS simplicity).
- `gps_point`: inherits the track's user via `track_id` FK; add `user_id` too so
  RLS can gate it without a join.
- `profile`: **DONE in 6.3c** (`0005`) — dropped the `id` column (taking
  `CHECK (id = 1)` and the old PK with it); `user_id` is now the PRIMARY KEY (1:1
  with `app_user`; name/height/sex/dob stay here). This also fixed a live
  cross-tenant corruption: `upsert_profile` conflicted on `(id)` without setting
  `user_id`, so a second owner's push overwrote the first owner's demographics —
  the owner is now the conflict target.

### 3.3 Row-Level Security (isolation guarantee) — **DONE, 6.5b-2** (`0008`)

**Resolves [D3].** What shipped, per tenant table (all 16), and why each part:

```sql
ALTER TABLE sample ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sample_tenant ON sample;         -- replay-safe
CREATE POLICY sample_tenant ON sample FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);
```

Every clause was **probed against a real hypertable and a real `NOSUPERUSER
NOBYPASSRLS` role before being written** — none of it is inherited from the sketch
this section used to carry, which was wrong in three separate ways:

- **`FOR ALL` + `WITH CHECK`, not `USING`-only.** A `USING`-only policy (what the
  old sketch had) governs SELECT/UPDATE/DELETE and leaves **INSERT completely
  ungoverned** — it would have broken every upsert in the codebase and let a write
  land under any owner. `WITH CHECK` is the write half.
- **`NULLIF(…, '')` is mandatory.** Once a custom GUC has been touched in a session,
  `current_setting(x, true)` returns the **empty string, not NULL** — and a bare
  `''::uuid` **ERRORS** (`invalid input syntax for type uuid`) instead of failing
  closed. Since `tenant_transaction` sets the GUC and the transaction end reverts it
  to `''`, every pooled connection reaches that state constantly. `NULLIF` maps both
  "never set" and "set to empty" to NULL, and `user_id = NULL` is NULL ⇒ **no rows,
  no error**.
- **No `FORCE`.** `FORCE ROW LEVEL SECURITY` only binds a table's **owner**. The app
  role owns nothing (§3.3a), so plain `ENABLE` already binds it — and the admin
  staying *unbound* is load-bearing, not an oversight (see below).
- `set_config(...)`, **not** `SET LOCAL`: `SET` is a utility statement and takes **no
  bind parameters**, so `SET LOCAL healthee.user_id = %s` is impossible and the only
  alternative would be interpolating a UUID into SQL. `set_config(name, value, true)`
  is an ordinary function — it parameterizes cleanly, and `is_local=true` gives
  exactly SET-LOCAL semantics (the owner reverts at commit and cannot leak to the
  next borrower of the pooled connection).
- `sample`'s **chunks inherit** the parent hypertable's policy — verified, nothing
  extra needed for TimescaleDB.

**`core.db.tenant_transaction(user_id)` is the ONE way tenant data becomes visible**
to the app role; `tenant_connection(user_id)` is its connection-scoped form (the
ingest push + `db/rederive.py`, which hand a *connection* to a collaborator).
The consequence is deliberate and worth stating plainly: **a tenant read on plain
`transaction()` now returns zero rows and raises nothing.** Failing closed is the
right default, but it means a missed call site shows a user "no data" rather than
erroring — which is why the **whole test suite now runs as the least-privilege role**
(`tests/conftest.py::app_role_pool`), turning that mistake into a failing test.

**The identity tables get NO policy** (`app_user`, `device_token`) — a decision, not
an omission: the app must resolve *who you are* before it can know an owner to scope
to, and the scheduler's `active_users()` sweep must see **every** owner or their
nightly chain silently stops. Their protection is the grant list in
`provision_app_role`. `schema_migrations` is not granted to the app role at all.

**`migrate` / `provision_app_role` / `claim_sentinel` / `seed.reset` stay on the
admin**, which is unbound by the policies. For `claim_sentinel` this is the sharp
case: its FK cascades would still move the rows under RLS (a cascade runs as the
constraint, not under the caller's policies), but its **verification SELECTs would be
filtered to nothing and report a partial re-key as a success** — a silent false pass,
which is precisely the failure that tool exists to prevent.

**A TimescaleDB bug had to be worked around** (reproduced on 2.26.4): `SELECT
DISTINCT ON (…)` over a policied table fails with `InternalError: unsupported subplan
type for SkipScan: Result` — `/api/today`'s `latest_derived_many` is exactly that
shape, so it 500s the moment policies are live. A STABLE-function wrapper around the
owner lookup was probed and fails identically. Fix: `provision_app_role` sets
`timescaledb.enable_skipscan = off` **on the app role** (the admin bypasses RLS, never
meets the bug, and keeps the optimization). Measured cost, not assumed: median
0.111 ms → 0.127 ms on the affected query, same index scan either way; no hypertable
query does `DISTINCT ON` at all.

**Proved by defeating it** (`tests/db/test_rls.py`), which is the bar §13 [D3] sets:
a query with the `user_id` filter **removed** returns only the owner's row; an unset
owner and an empty-string owner each return 0 rows without erroring; a cross-owner
INSERT/UPDATE/DELETE cannot land; the ordinary upsert still works; every one of the
16 tables is asserted to have RLS + exactly one policy, driven off **the database's
own list** of tables referencing `app_user` (so a tenant table added next month is
covered the day it is created). `test_the_app_pool_is_never_privileged` asserts the
premise all of it rests on. Mutation-verified: dropping one policy, disabling RLS on
one table, removing the `NULLIF`, or reverting one `tenant_transaction` back to
`transaction` each turn tests red.

**⚠ Deploy implication: RLS only actually protects once `POSTGRES_APP_*` is set in
prod.** Until then the pool falls back to the admin superuser, which `rolbypassrls` —
the policies are live in the schema but inert on that connection, and
`core.db._warn_if_privileged` says so in the startup log. Follow §3.3a's deploy order;
confirm the log reads `connected as least-privilege role`.

#### 3.3a The app role — the prerequisite (**DONE, 6.5b-1**)

The policies above are inert against a superuser, and the app **was** one. Probed
on the live DB before writing any of them:

```
healthee  superuser=true  bypassrls=true
```

A `rolsuper`/`rolbypassrls` role bypasses RLS unconditionally — `FORCE ROW LEVEL
SECURITY` does not reach it either. Shipping §3.3 onto that connection would have
produced green tests and **zero isolation**. So the role split lands first:

- **Two credential sets.** `POSTGRES_USER`/`POSTGRES_PASSWORD` keep their existing
  meaning — the owner/admin (migrations, `claim_sentinel`, `provision_app_role`,
  the test reset), reached only via `core.db.admin_connection()`. The new
  `POSTGRES_APP_USER`/`POSTGRES_APP_PASSWORD` are what the request/job pool
  (`core.db.get_pool`) connects as.
- **Fallback.** App creds unset ⇒ the pool uses the admin creds, i.e. today's
  behaviour — so the code is safe to merge and deploy before the role exists. It is
  not silent: the pool queries `pg_roles` at open and logs a prominent WARNING
  naming the role and stating that RLS cannot apply to it.
- **The role** (`python -m healthee.db.provision_app_role`, run as the admin,
  idempotent, password from the env only): `LOGIN NOSUPERUSER NOBYPASSRLS
  NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION`, `SELECT/INSERT/UPDATE/DELETE`
  on the 16 tenant tables + `app_user` + `device_token`, `USAGE, SELECT` on the
  three BIGSERIAL sequences, plus `ALTER DEFAULT PRIVILEGES` so a table added by a
  future migration is granted automatically. **No TRUNCATE, no DDL, no ownership.**
- **Consequence for 6.5b-2 (confirmed in `0008`):** because the app role is a
  non-superuser that does **not own** the tables, plain `ENABLE ROW LEVEL SECURITY`
  sufficed — `FORCE` is only needed when the *connecting* role owns them. The admin
  staying unbound turned out to be load-bearing rather than merely acceptable: see
  §3.3 on `claim_sentinel`'s post-check.

Proved by connecting as the role, not by inspection: `tests/db/test_app_role.py`
provisions it, writes + reads the `sample` hypertable (the row lands in a
`_timescaledb_internal` chunk, whose privileges are inherited from the parent — so
it is proved, not assumed), draws from the sequences, renders `/api/today`, and
asserts it **cannot** TRUNCATE / DROP / ALTER and that `rolsuper` and
`rolbypassrls` are false in `pg_roles`.

##### Deploy order (⚠ a PROD CREDENTIAL CHANGE — the wrong order is an outage)

1. **Deploy the code.** The fallback keeps the running app alive.
2. **Provision the role as the admin**, password in the environment:
   `POSTGRES_APP_USER=healthee_app POSTGRES_APP_PASSWORD='<secret>' docker compose
   --env-file infra/.env -f infra/docker/docker-compose.prod.yml exec api python -m
   healthee.db.provision_app_role`
3. **Set both vars** in `infra/.env`, then restart api + scheduler (`infra/deploy.sh`).
4. **Confirm** the startup log says `connected as least-privilege role`.

Setting the vars before step 2 means the app cannot authenticate at all. Full
details in `infra/.env.example`.

---

## 4. Identity & auth — **Supabase Auth** (managed)

### 4.1 Supabase owns the auth lifecycle
Email/password + OAuth + magic-link, JWT issuance, **refresh-token rotation**,
email verification, password reset — all Supabase. We build **none** of it. The
web app (Cloudflare Pages) and the Flutter app use the Supabase client SDK to sign
in and hold the session.

**Chosen sign-in method: social login — Google + Apple** (Apple is required by App
Store guideline 4.8 once any other social login is offered). Each is a Supabase
dashboard toggle (enable provider + OAuth client IDs) plus one client call
(`supabase.auth.signInWithOAuth(Provider.google/apple)`); the mobile side lands in
Phase 2. **This is a config + client concern only — the backend is provider-blind
by design (§4.2): it verifies whatever Supabase issues, so the access JWT from a
Google/Apple sign-in flows through `verify_supabase_jwt` unchanged (`sub` = the
Supabase UUID, `email` from the social identity). Nothing in Phase 6.1 changes.**
Email/password stays available as a fallback via the same code path.

### 4.2 The backend is a resource server (verifies, never issues)
FastAPI **verifies** the Supabase access JWT on every `/api/*` request — check the
signature (Supabase JWKS / project JWT secret), `exp`/`aud`/`iss`, then take
`sub` = the user **UUID** = our tenant id. No login/register/refresh endpoints on
our side; those calls go straight to Supabase.

### 4.3 Ingest uses our own device token
Supabase access tokens are short-lived (~1h) → unusable for background BLE sync.
At device pairing (an authenticated `POST /api/device`), the backend mints a
long-lived **device token**, stores only its hash (§3.1), returns it once; the app
sends it on `/ingest/*`, mapping to one user UUID. This replaces today's single
global `REALTIME_INGEST_TOKEN`.

### 4.4 The `current_user()` dependency
1. `/api/*`: verify Supabase JWT → UUID. `/ingest/*`: look up device-token hash → UUID.
2. **JIT-provision:** if there's no local `app_user` row for that UUID yet, create
   it + a default profile (first-request onboarding — no webhook needed for the
   happy path).
3. the owner is set on each request's transaction by `core.db.tenant_transaction`
   (`set_config('healthee.user_id', <uuid>, true)` — `SET LOCAL` takes no bind
   parameters; RLS §3.3).
4. return `RequestUser(id: UUID, timezone)` injected into handlers.

### 4.4a Dual auth — the 6.4b transition (**TEMPORARY**, `core/request_auth.py`)

The mobile app is Phase 2 and has **not** been rebuilt: it still authenticates with
the single shared `REALTIME_INGEST_TOKEN`. Hard-requiring a Supabase JWT on `/api/*`
would therefore break the live app on the next prod deploy. So 6.4b ships **dual
auth** in `core/request_auth.py` (its own module precisely because it is scaffolding
to be demolished, not part of the permanent `supabase_auth` resource-server code):

| Presented | Resolves to |
|---|---|
| Supabase JWT | that real user, JIT-provisioned — `RequestUser(id, timezone)` from `app_user` |
| the legacy shared token | the **sentinel** owner + the sentinel's `app_user.timezone` |
| anything else | 401 |

**Ordering rule — a rejected JWT can never become sentinel access.** The legacy
`hmac.compare_digest` comparison runs FIRST and the Supabase branch is the `return`
after it, so a malformed/expired/tampered/alg-swapped JWT raises 401 with nothing
downstream of it to grant anything. Fall-through is structurally unrepresentable
rather than merely guarded — deliberately not a JWT-first design with a "does this
look like a JWT?" shape heuristic, which would be a guard to maintain and would
misroute a shared token that happened to be JWT-shaped. A blank
`REALTIME_INGEST_TOKEN` authorizes nobody through the legacy branch (fails closed).

**Why this is not an escalation:** the shared token already grants exactly this one
tenant's data today, so the legacy branch reproduces current behaviour byte-for-byte.
`/api/me` + `/api/device` are pointedly **excluded** — minting a device token is
minting a long-lived credential, and accepting the shared secret there would let its
holder forge a permanent per-user token that outlives the transition.

**Removal condition:** the legacy branch goes when the Phase-2 app ships Supabase
login, or at **6.5**, whichever is first. A shared token that maps to a real tenant
MUST NOT survive into public signups (§12.7 — the server is the trust boundary).

### 4.4b The signup gate — server-enforced invite-only (**resolves [D1]**)

`current_user` → `_provision_user` JIT-provisions an `app_user` row on first sight.
**That provisioning is gated in `core/supabase_auth.py`** — not at Supabase. The
config flag `signups_open` previously claimed this protection and enforced nothing;
`_provision_user`'s docstring asserted invite-gating "is enforced at Supabase", which
is a *dashboard toggle, not a control this server owns* (§12.7: the server is the
trust boundary, every client is adversarial).

**What it protects is cost, not isolation.** A stranger's tenant is empty and stays
isolated. But since 6.4c the scheduler runs a nightly LLM `run_chain` for **every
active owner**, so uncontrolled signup is uncontrolled LLM spend — and `PRICING.md`
§6 calls free-tier cost control existential.

| Presented | Outcome |
|---|---|
| verified JWT, **existing** `app_user` row | **always 200** — gating creates accounts, it never gates access |
| verified JWT, new owner, `signups_open=true` | provisioned, 200 |
| verified JWT, new owner, email on `signup_allowlist` | provisioned, 200 |
| verified JWT, new owner, neither (incl. no `email` claim) | **403**, and **no row is written** |
| the legacy shared token | the sentinel — whose row `0003` already seeds, so the gate cannot touch it |

- **`signup_allowlist`** is a comma-separated, case-insensitive list (pydantic-settings,
  `core/config.py`). Matching is lowercased to mirror `app_user.email`'s **CITEXT**
  semantics. Empty allowlist + closed signups = nobody new (the default posture).
- The **email comes from the verified JWT claim** — trustworthy *because* the signature
  was checked first (Supabase populates it from the authenticated identity). A token
  with no email is refused while signups are closed: it cannot be on a list it has no
  name for.
- **403, not 401.** They authenticated fine; they simply may not create an account. A
  401 would mean "your credentials failed" and invite a retry of a login that already
  succeeded. The body is clear and secret-free; the refusal is logged with the email +
  UUID (an operator needs to see blocked attempts), never the token.
- Refusal happens **before any write** — a refused signup leaves no `app_user` row.

**Bootstrap procedure — the owner's first sign-in → claim.** This is the deadlock the
allowlist exists to resolve: `db/claim_sentinel.py` refuses a target who has never
signed in (it needs their `app_user` row), but with signups closed they could never
*get* a row. So:

1. put the owner's email in `SIGNUP_ALLOWLIST` (infra `.env`) and restart the API;
2. have them sign in once with Supabase — the gate lets them through and JIT-provisions
   their row under their real UUID;
3. `uv run python -m healthee.db.claim_sentinel <their-uuid>` (dry run — confirm the
   printed email is the right human), then re-run with `--apply` (§8);
4. optionally clear the allowlist again. They keep working: they now have a row, and an
   existing owner is never gated.

**Public signup must NOT be opened before the Phase-2 app ships Supabase login.** The
legacy shared-token branch (§4.4a) cannot die until then, and a shared secret that
resolves to a real tenant must never coexist with public signups (§12.7) — anyone
holding it would read and write that tenant's health data. `signups_open=true` is
therefore gated on that removal, not merely on this flag existing.

### 4.5 Deletion / GDPR
**Neither half of this is built.** It is written as the plan, and the plan is all it is.

A Supabase **auth delete webhook** → purge that UUID's health data (cascade via
the `app_user` FK). There is no webhook route, no purge module in `db/`, and
`SUPABASE_SERVICE_ROLE_KEY` (`core/config.py`) is read by nothing. So deleting the
Supabase account today leaves the entire local health record in place forever. The
19 `ON DELETE CASCADE` FKs are the mechanism and nothing calls it;
`db/claim_sentinel.py` is the shape the admin-run first version should take.

This paragraph used to end "Data export is already free (own-your-data)". **There is
no export endpoint.** `/api/history` is the closest thing and it clamps to `MAX_DAYS`
(`read/history.py`), which is a read, not an export. The sentence is corrected rather
than deleted because a plan-of-record document claiming a shipped capability is how an
auditor stops looking.

**This resolves [D2]** (session model — Supabase handles refresh/rotation) and
moves **[D1]** to a Supabase setting (disable public signup / use the allowlist for
invite-only). Password hashing lib is moot (Supabase). The backend gains one dep:
a JWT-verify library (`pyjwt` + JWKS, or Supabase's helper) — look up the current
version at add-time.

---

## 5. Threading `user_id` through the code (~119 sites)

**Status: DONE** (6.3a writes · 6.3b reads · 6.4b the request edge). The
mechanical-but-wide pass, done cleanly, NOT via a global/thread-local — this is
how it is threaded today:

- **Request path:** handlers get `RequestUser` from the dependency and pass
  `user.id` down into the read/analytics service functions. The read services
  already take a `cur`; they gain a `user_id` param (or a small `Ctx(cur,
  user_id, tz)` object — mirrors the existing `TodayReads` preload pattern, so
  the signature churn is one object, not N params).
- **Jobs path:** the chain/derive/analytics functions take `user_id` explicitly
  (they already take a `cur`/`conn`).
- **SQL:** every `cur.execute` on a tenant table gains `AND user_id = %s`. RLS
  (§3.3) is the backstop, but the explicit filter stays (clarity + index use).
- **Timezone:** replace the `USER_TZ` constant with `tz` carried on the request
  user / passed into derive+analytics; `AT TIME ZONE %s` already parameterizes it
  (the code was written for this — the constant is the only blocker).

Guardrail (**shipped, 6.3b**): `tests/db/test_tenant_read_scoping.py` is an **AST
completeness guard** — not a grep — over every tenant-table `execute` call lacking a
`user_id` reference. Belt-and-braces with RLS: RLS makes a missed filter return
nothing, the guard makes it fail the build.

---

## 6. Per-user jobs

**Status: DONE** (6.3c: the per-owner sweep · 6.4c: per-user fire times).

- **Scheduler** (`jobs/scheduler.py`): a **tick loop**. It does not compute a next
  fire instant and sleep to it; it wakes every `_TICK_INTERVAL_S` (5 min) and asks
  of each `active_users()` owner: *is their local wall clock past `DAILY_FIRE`
  (10:30 in **their** `app_user.timezone`), and has their chain not already run for
  their local day?* If so, `run_chain(tenant.id, tenant.tz, their_local_day)`.
  `core/tenancy.active_users()` returns a frozen `Tenant(id, tz)` per active owner
  (deliberately NOT `RequestUser` — that would couple the science/jobs layers to
  auth; 6.4b converts `RequestUser` → `Tenant` at the edge). One owner's failure is
  isolated in `Sweeper._run_for` (logged + Telegram-notified, sweep continues); a
  failure of the owner *lookup* propagates, since that is an outage rather than one
  tenant's problem.
- **Why a tick, not a timer** (6.4c): `next_fire()` returns *tomorrow* once an
  instant has passed, and the loop fired the single earliest job. Extended
  per-owner, that fires owner A at their 10:30, then recomputes and sees owner B's
  identical 10:30 as already past → B is deferred to tomorrow, **every day,
  forever** (simulated over 3 days: A fires 3×, B fires 0×). A tick asks a question
  about the *present*, where "already past" is the condition to RUN, so it cannot
  express that bug. It is also self-healing by construction: a missed tick, a
  container restart, a slow run, or an owner who signs up *after* their own fire
  time all resolve on the next tick.
- **Idempotence is the marker's job, not the loop's.** `run_chain`'s per-owner
  per-day `kv` marker is what makes a repeating tick safe; the scheduler holds no
  dedup of its own.
- **One chain per owner per local day** — the 10:30/10:45/11:00 stagger is **gone**.
  It was not spreading LLM load (fixed order, fixed offsets, and the sweep already
  ran every owner back-to-back inside one timer); `run_chain` already sequences
  correlate → recs → warm → briefing *with* the dependency, so the stagger only
  re-implemented that ordering with `sleep()`. `chain.run_step`/`STEP_NAMES` were
  orphaned by the collapse and deleted.
- **The `warm` step** (`chain.step_warm` → `insights/coaching.warm_lines`): the
  `/api/today` **action** and the sleep-**tonight** line are cache-only on the read
  path (`cached_line` never generates — standards §Performance), so they only exist
  if something warms them off that path. Nothing did: `warm_daily_action` /
  `warm_sleep_tonight` shipped with **zero production callers**, and both lines were
  null forever. They are now a supervised chain step, after `recs` (it shares
  `correlate`'s findings, so a `correlate` failure **skips** it) and before
  `briefing`. A `warm` failure is **non-fatal**: a missing line is a degraded card,
  and aborting would cost the owner their briefing over a one-liner. Cost: **2** LLM
  calls per owner per local day — the merged morning call (#95: the briefing body and
  the action from ONE generation, `insights/morning.py`) and the sleep-tonight line —
  bounded by the per-day `kv` cache (a forced re-run spends nothing). It was 2 lines in
  2 calls with the briefing paying for a third downstream; the `briefing` step now
  usually sends warmed text and spends none. It still generates for itself when nothing
  was warmed (a `correlate` failure skipped `warm`, or the merged call could not ground
  itself), so the saving is conditional and the briefing arriving is not.
- **Retry budget** (`_ATTEMPT_BUDGET = 3`, in-memory): the marker is only set once
  correlate succeeds, so a *failing* chain stays unmarked — under a 5-minute tick it
  would otherwise be retried ~150× per owner-day (150 Telegram alerts + 150 re-sent
  briefings, since briefing runs even when correlate fails). The budget keeps the
  transient-blip retry and bounds the storm; exhaustion is announced once. It is NOT
  idempotence (the marker is), and it lives in memory deliberately: a restart is
  itself a good reason to try again.
- **No global fire zone**: `scheduler.TZ` is deleted. An owner's own timezone is now
  the only zone in play for them.
- **Per-user timezone**: `run_chain` defaults `day` to **that owner's** local today,
  computed from their `app_user.timezone`.
- The better end-state at scale remains **ingest-triggered per-user chains** (each
  strap syncs on its own schedule) with this tick as the straggler sweep. Noted, not
  built.
- **Chain dedup** (`jobs/chain.py`) and the **kv cache** (`insights/cache.py`):
  **keys are NOT namespaced by user, and must not be.** This supersedes the
  original plan (`job:chain_done:{user_id}:{day}`, `DAILY_ACTION_KEY:{user_id}`),
  which was written when `kv` was keyed on `key` alone. `0004` folded the owner
  into the **`kv` PRIMARY KEY `(user_id, key)`** and every read filters by owner, so
  two users' same-named entries are already distinct rows and cannot collide.
  Prefixing the string would state the tenant twice — once in the key column and
  again inside the key. Don't re-add it.
- **The chain marker is a HIGH-WATER MARK — one row per owner, not one per day**
  (#77, `0012`). It was `job:chain_done:<local-day>`, which put the day in the key
  and so left one row per owner per day in `kv` forever with nothing to sweep it
  (365/owner/year; prod had accumulated 16 by 2026-08-01). The day now lives in the
  **value** under a constant key — the shape `core/rate_limit.py` had already chosen —
  and the read is `stored >= day` ("the chain has run *through* this day") with a
  `greatest()` on the write, so the mark cannot move backwards and a deliberate
  `force=True` re-run of an earlier day cannot un-dedup today. `0012` folded the
  existing rows to each owner's newest day and deleted them; `deploy.sh` migrates with
  api+scheduler **stopped**, so no code ever reads a shape it does not understand.

---

## 7. Ingest attribution

**Status: DONE** (6.4b). `/ingest/helio` authenticates with a **device token** →
`user_id`; an unknown token is 401. `ingest_helio`
threads that id into every upsert (`upsert_samples`, `upsert_sleep`, …) so raw +
typed + derived rows are written under the owner.

**Transitional (same shape as §4.4a):** `ingest_user` also accepts the **legacy
shared token**, resolving it to the sentinel — the un-rebuilt app holds no device
token to send. Only an *unrecognised* token is 401; attribution is never guessed,
because ingesting under the wrong owner is silent cross-tenant corruption of health
data. The per-user device token becomes the sole ingest credential when the Phase-2
app ships pairing.

---

## 8. Data migration / backfill

Split across two migrations so **6.2 is strictly additive and non-breaking** — the
key rebuild is coupled to the query-threading code and moves to 6.3.

**6.2 — additive tenant column (`0003_tenant_column`, DONE):**
1. Identity tables (`app_user`, `device_token`) already exist from 6.1
   (`0002_identity`). 6.2 inserts the **sentinel legacy owner**
   `00000000-0000-0000-0000-000000000000` (tz `Asia/Kolkata` = today's single-tenant
   `USER_TZ`, so day boundaries don't shift when tz goes per-user in 6.3) via
   `ON CONFLICT (id) DO NOTHING`. No local `credential` table — Supabase owns auth.
2. `ALTER TABLE … ADD COLUMN user_id UUID NOT NULL DEFAULT '<sentinel>'` on every
   data table. The `NOT NULL DEFAULT` **backfills** all existing rows to the
   sentinel in one metadata-only step (PG11+, no table rewrite) — no separate
   nullable→UPDATE→NOT-NULL dance. New writes that omit `user_id` keep working via
   the DEFAULT: this is the transitional scaffold that keeps 6.2 non-breaking
   (**dropped in `0007` — see below; that transition is over**).
3. Add the FK to `app_user` (`ON UPDATE CASCADE ON DELETE CASCADE`) and a
   `(user_id, …)` secondary index per table. The FK **survives on the `sample`
   hypertable** (verified — a hypertable may reference a plain table).
4. **Change NOTHING** about existing PKs, UNIQUE constraints, or `ON CONFLICT`
   targets, and leave `profile`'s `id INTEGER PK DEFAULT 1 CHECK (id = 1)` intact
   (column + FK + index only). No code reads `user_id` yet.

**6.3 — fold into the keys (coupled with the ~119-site query threading):**
rebuild PK/UNIQUE to include `user_id`, retarget every `ON CONFLICT`, re-key
`profile` by `user_id` (drop `CHECK (id = 1)`, merge demographics), and remove the
`USER_TZ` constant. These MUST change together with the read/derive/analytics/
insights/jobs/ingest queries, so they cannot land in 6.2 without breaking every
upsert (the conflict target would no longer match a unique constraint).

**6.4c — the sentinel claim (`db/claim_sentinel.py`, DONE):** a committed one-off ops
module, run like the migration runner and **never** from the auth path — "the first
user to sign in claims all the data" would be a catastrophic security hole. The
operator naming the UUID *is* the authorisation.

    uv run python -m healthee.db.claim_sentinel <target-uuid>            # DRY RUN
    uv run python -m healthee.db.claim_sentinel <target-uuid> --apply    # for real

**Operating procedure:** run the dry run first (it is the default; `--apply` is the
only way to change anything), read the printed plan — source id, target id, the
target's **email**, and per-table row counts — confirm that email is the right human,
then re-run with `--apply`. The target UUID is a CLI argument on purpose: it is
auditable in the command and the shell history, and cannot be silently inherited from
a stale env var.

**Mechanism:** one `UPDATE app_user SET id = <target> WHERE id = <sentinel>`. Every FK
to `app_user(id)` carries `ON UPDATE CASCADE`, so every dependent row moves atomically
and no table can be missed — a hand-written list of per-table UPDATEs can silently
miss a table added later; the cascade cannot, because the database enumerates them.
(`0006` closes the one gap: `device_token`'s FK came from `0002` with no update
action, i.e. NO ACTION, so the re-key *errored* for any owner with a paired device.)

**Identity:** the sentinel row holds `email = NULL` + the legacy tz; the target's
JIT-provisioned row holds their real ones. A naive cascade would leave the survivor
wearing the sentinel's values and lose the real email — and resolve every day boundary
in a zone the owner doesn't live in. So the claim captures the target's email/timezone,
parks their device tokens on the sentinel, deletes their row to free the PK, and stamps
those fields onto the re-keyed row in the same statement.

**Refuses rather than guesses:** target == sentinel · target has never signed in (no
`app_user` row — an unverified UUID may be a typo, and this is not undoable by a
re-run) · target already owns data (a merge is a judgement call about whose numbers
are whose, not this tool's). Nothing to move ⇒ says so and exits 0, so a re-run after
success is a clean no-op.

**Post-check (the real net):** in the SAME transaction, assert zero rows anywhere
still belong to the sentinel — driven off the database's own list of tables
referencing `app_user`, so it catches a missed table regardless of mechanism — and
that the sentinel row is gone. Any failure rolls the entire re-key back: a partial
claim would scatter one person's history across two owners, which is silent wrongness
rather than an honest gap.

**`0007` — drop the transitional `user_id` DEFAULT (DONE):** `ALTER TABLE <t> ALTER
COLUMN user_id DROP DEFAULT` on all 16 tenant tables. **`NOT NULL` is kept** — the
column stays mandatory; what changes is that the caller must say *whose* row it is
instead of being handed a guess.

The scaffold's job is finished: 6.3a made every writer set the owner explicitly, and
the AST guard (`tests/db/test_tenant_read_scoping.py`) now fails the build on any
tenant SQL that doesn't reference `user_id`. With multi-user live the DEFAULT had
turned from a convenience into a **hazard**: a writer that forgot `user_id` would
silently attribute one person's health data to the sentinel. Dropping it converts
that silent misattribution into a loud `NotNullViolation` at the first write.
Verified before shipping: **no production writer relied on it** (the guard already
implied this; grepped to confirm). Replay-safe — `DROP DEFAULT` on a column with no
default is a no-op.

The two tests that encoded the scaffold (`…_backfills_to_sentinel`) now assert the
**inverse** invariant — a write omitting `user_id` raises — plus a per-table check,
driven off `information_schema`, that no tenant `user_id` carries a default at all.

RLS + policies landed in 6.5b-2 (`0008`, §3.3).

Because prod is one user, backfill is trivial and reversible (the column is
additive; the sentinel owns everything). Snapshot the DB before the 6.3 key
rebuild.

---

## 9. Mobile (Phase 2, greenfield — build multi-user-native)

The app is being rebuilt from scratch, so it should be multi-user from day one:
a **login screen** (Google/Apple social sign-in via the Supabase client SDK →
Supabase session/JWT, §4.1), secure session storage, a **device pairing** step
that stores the per-user device token for background ingest, and per-user local
store (the 60-day tier is namespaced by user). No migration cost here because
there is no legacy app to convert — just design it in.

---

## 10. Testing & isolation proof

**Status: BUILT.** What guards tenancy today, in `apps/server/tests/db/` unless
noted (the full suite is **728 tests**, green under `TZ=UTC` and `TZ=Asia/Kolkata`):

| Guard | File | Proves |
|---|---|---|
| AST completeness guard | `test_tenant_read_scoping.py` | no tenant SQL anywhere lacks `user_id` — a *new* unscoped query fails the build |
| RLS, proved by defeating it | `test_rls.py` | an unfiltered read is still owner-scoped; unset + empty-string owners return nothing without erroring; cross-owner writes denied; all 16 tables policied |
| The app role is constrainable | `test_app_role.py` | `rolsuper`/`rolbypassrls` are false — the premise RLS rests on |
| Service-layer leakage | `test_service_leakage.py` | read services never cross owners |
| Read isolation | `test_read_isolation.py` | A sees only A's rows |
| HTTP isolation | `test_http_isolation.py` | both owners see their own over the wire; carries a permanent mutation test |
| Job write isolation | `test_job_write_isolation.py` | the chain writes under the right owner |
| Auth matrix | `tests/test_request_auth.py` | every rejected JWT is asserted to never reach the sentinel branch |
| Ingest attribution | `tests/integration/test_ingest_attribution.py` | device token → owner; unknown → 401 |
| Citations resolve | `tests/test_source_citations.py` | every `[[id]]` resolves in the manifest |
| AI gate completeness | `tests/premium/test_ai_gate.py` | every mounted route is gated or in a reasoned free allowlist — driven off the app's own route table, so a new AI endpoint cannot ship open |
| The paywall refuses a direct call | `tests/premium/test_ai_gate.py` | every AI route 402s a free owner and spends zero model calls; a client claiming premium is still refused |
| The AI fields are OMITTED | `tests/premium/test_locked_payloads.py` | `/api/today` + `/api/sleep/consistency` carry no AI key at all for a free owner — asserted on the raw response **text** |
| The jobs spend nothing on a free owner | `tests/premium/test_chain_spend.py` | a real chain against a real DB makes ZERO stub-model calls, leaves no warmed line and no `recommendation` row; two owners with opposite entitlement do not leak |
| Entitlement is not app-settable | `tests/db/test_app_role.py` | the app role cannot INSERT/UPDATE/DELETE `subscription` — it can only SELECT it |
| One generation budget, both doors | `tests/premium/test_generation_budget.py` | exhausting it through the endpoint blocks the coach's `create_challenge` (#78) |

The **whole suite runs as the least-privilege role** (`tests/conftest.py::app_role_pool`)
— it did not before 6.5b-2, which would have left every policy unexercised (§13 [D3]).
The two-tenant seed is **`tests/contracts/seed_owner_b.py`**, deliberately layered
*over* `seed.py` rather than extending it as this section originally planned: `seed.py`
is the single-owner fixture the committed contract snapshots are taken from, so
touching it would move every snapshot. Owner B writes at the **same natural keys** as
A with values impossible for A — so an unscoped read returns an absurd number rather
than accidentally the right one. Multi-tz is first-class: A is `Asia/Kolkata`, B is
`America/Chicago`, and the full-suite-under-TZ=UTC-and-IST discipline holds.

**Not built:** login/refresh/expiry tests are Supabase's concern, not ours (§4.1 — we
only verify). Per-user science-parity fixtures were not needed: the science is
tenant-agnostic (§1.2) and its fixtures are pure functions over one owner's window.

---

## 11. Phased rollout (each phase = its own reviewed PR, main stays green)

**All five phases have shipped to `main`.** The "Ships when" column is kept as the
acceptance bar each was held to, not as pending work.

| Phase | Scope | Ships when |
|---|---|---|
| **6.1 Identity ✅** | `app_user` + `device_token` tables (`0002_identity`) + `core/supabase_auth.py` (VERIFY the Supabase JWT — HS256, pinned algs; JIT-provision `app_user`; mint/resolve hash-only device tokens) + thin `/api/me` + `/api/device`. No local credentials/argon2/login-endpoints (Supabase owns them). Additive — existing shared-token auth untouched, nothing reads `user_id` yet. | login works; existing endpoints unaffected |
| **6.2 Schema ✅** | Migration §8 (`0003`): **additive only** — add `user_id` (`NOT NULL DEFAULT <sentinel>` = backfill) + FK + `(user_id, …)` index to every data table, and the sentinel owner (tz `Asia/Kolkata`). No PK/UNIQUE/`ON CONFLICT` change, `profile` id=1 PK kept, no code reads it yet. | schema migrated, all tests green on the sentinel owner with ZERO code changes |
| **6.3 Thread scoping ✅** | Shipped in three slices. **6.3a** (`0004`): folded `user_id` into every natural PK/UNIQUE, retargeted every `ON CONFLICT`, made every tenant WRITE set the owner; added `core/tenancy.SENTINEL_USER_ID`. **6.3b**: scoped every tenant READ with `AND user_id = %s`, killed the seven duplicate `Asia/Kolkata` constants for `SENTINEL_TZ` threaded as `tz: str`, and added the AST completeness guard (`tests/db/test_tenant_read_scoping.py` — any new unscoped tenant SQL now fails the build) + read-isolation tests. **6.3c** (`0005`): re-keyed `profile` by `user_id` (dropped `id`/`CHECK (id = 1)`, retargeted `upsert_profile`'s conflict to the owner — it was silently overwriting another owner's demographics), per-user job sweep (`active_users()` → `Tenant`, per-owner local day, isolated failures), and the two-tenant seed + cross-tenant leakage suite (§10). Cache-key namespacing was **dropped as redundant** (see §6). Everything still resolves to the sentinel by default. | every query scoped; single-user behavior identical (contract snapshots byte-identical) |
| **6.4 Flip identity ✅** | Shipped in slices. **6.4a**: `USER_TODAY_SQL`/`user_today()` — the owner's day boundary, killing the `current_date` anchor. **6.4b ✅**: the auth flip — dual auth (§4.4a) in `core/request_auth.py`; all 11 routers inject `user: CurrentUser` per-endpoint and pass `user.id`/`user.timezone` (router-level `require_token` gone, `core/auth.py` deleted as orphaned); the sentinel hardwires cleared from `surfaces`/`coach_tools`/`notable`/`coaching`/`coach_context` (threaded from the router, so the coach and every insight act for the REQUESTING user); `/ingest/helio` attributed by device token → owner (§7), unknown token → 401. Tests: HTTP-level cross-tenant leakage both-owners-see-their-own (`tests/db/test_http_isolation.py`, incl. a permanent mutation test), the auth matrix (`tests/test_request_auth.py` — every rejected JWT asserted to never reach the sentinel branch), ingest attribution (`tests/integration/test_ingest_attribution.py`). **6.4c ✅**: per-user scheduler fire times — `jobs/scheduler.py` is now a **tick loop** running each owner's `run_chain` at 10:30 in **their own** `app_user.timezone`, deduped by `run_chain`'s per-owner per-day marker (§6); the global `scheduler.TZ`, the 10:30/10:45/11:00 stagger, and the orphaned `chain.run_step`/`STEP_NAMES` are gone. Plus `db/claim_sentinel.py` — the committed, **dry-run-by-default** one-off that re-keys the sentinel owner to the real Supabase UUID via the single cascading `UPDATE app_user SET id = …`, preserving the target's real email/timezone and post-checking (in-transaction) that no row anywhere still belongs to the sentinel; `0006` gives `device_token` the `ON UPDATE CASCADE` its 0002 definition lacked, without which the cascade *errors* for any owner who ever paired a device (§8). | second real user works end-to-end, isolated |
| **6.5 Harden ✅** | Shipped in slices. **Signup gate ✅** ([D1], §4.4b): `signups_open` is enforced by the SERVER — it was a dead flag, and `_provision_user` wrongly claimed Supabase enforced it — gating creation of a NEW `app_user` row on `signups_open` OR the new `signup_allowlist`, refusing **403** before any write; the allowlist is also the owner's bootstrap into `claim_sentinel`. **`0007` ✅**: dropped the transitional `user_id` DEFAULT on all 16 tenant tables (§8) — a forgotten owner is now a loud `NotNullViolation`, not silent misattribution to the sentinel; `NOT NULL` kept. **6.5b-1 ✅**: the app-role split (§3.3a) — the pool connects as a least-privilege `NOSUPERUSER NOBYPASSRLS` role that owns no tables, without which the policies below would have been theatre. **6.5b-2 ✅** (`0008`, resolves [D3], §3.3): `ENABLE ROW LEVEL SECURITY` + one `FOR ALL`/`WITH CHECK` policy on all 16 tenant tables, keyed on the `healthee.user_id` GUC that `core.db.tenant_transaction()` sets via `set_config(..., true)`; every `transaction()`/`connection()` site triaged into tenant / identity-only / admin, and plain `connection()` deleted as orphaned. Identity tables (`app_user`, `device_token`) stay unpolicied by decision; `migrate`/`claim_sentinel`/`provision_app_role`/`seed.reset` stay on the unbound admin. **The whole test suite now runs as the least-privilege role** — it did not before, which would have left every policy unexercised. `tests/db/test_rls.py` proves the backstop by defeating it (an unfiltered read is still owner-scoped; unset + empty-string owners return nothing without erroring; cross-owner writes denied), mutation-verified. **Remaining:** removing the legacy shared-token branch (blocked on the Phase-2 app shipping Supabase login, §4.4a); **rate-limiting everywhere except generation** — WP-C3b/C4b shipped the first limiter in the codebase (`core/rate_limit.py` + `challenges/budget.py`: 3 generations per owner per their local day, charged by both the endpoint and the coach's `create_challenge`), so what is still unbuilt is a per-TURN coach limit and any bound at all on the other routes; per-user backup/export. | isolation proven; GA-ready |

| **6.6a Entitlement ✅** | The AI paywall, step (a) of §12.6. `0011_subscription` (+ RLS policy, + the app role's SELECT-only grant) · `core/entitlement.py` — the ONE rule, pure and injectable-`now` · `api/gate.py` — `AIGate` taken in place of `CurrentUser` on the coach, the four insight routes, `/api/notable`, the whole challenges/programs surface and both generation endpoints, 402 with a locked-card body · field OMISSION on `/api/today` and `/api/sleep/consistency` · `GET /api/entitlement` · the nightly chain skipping `recs`/`warm`/`briefing` for a free owner while keeping the two deterministic steps (closes the cost hole, #48) · `db/grant_premium.py` + `SELF_HOST_UNLOCKED` as the pre-billing entitlement paths (§12.6a) · and #78, one generation budget shared by the endpoint and the coach (`challenges/budget.py`). **Not in it:** billing/webhooks ([D4]/[D5]). | a free owner's chain spends zero LLM calls; every AI route 402s a direct call; `/api/today` has no `action` key at all |
| **6.6a-2 Metered allowance ✅** | The rolling ledger. `core/allowance.py` — a ROLLING per-owner-per-feature-per-**window** ledger on `kv` (the use *instants* in the VALUE, the window in the key, no date anywhere, bounded to `limit` entries) · `api/gate.py`'s two tables as the only executable copies of `PRICING.md` §0/§1a, checked inside `AIGate` after entitlement, 402 carrying `resets_at` + `Retry-After` when spent · charge-in-the-dependency / `refund_ai_use` in the handler, so a refusal, a transport failure or the honest fallback never costs a question · `POST /api/today/action`, the reveal door that generates rather than reading the cache, bounded by a second per-day `core/rate_limit` budget · `GET /api/entitlement`'s `locked` list peeks the ledger. | **Shipped 6.6a-2 as §1a's free "taste"; re-pointed 2026-08-02** — the free table went to all-zero and the same machinery now carries premium's 20-questions-per-30-days cap. A midnight does not reset it, a refused turn does not consume it, and the two windows do not share a `kv` row |

Rough order-of-magnitude: 6.1 small, 6.2 small-medium (mostly SQL), **6.3 is the
big one** (the ~119-site threading), 6.4 medium, 6.5 medium, 6.6a medium. Each is a Fable-
directs / Opus-implements track with review + the two-tenant isolation tests.

---

## 12. Premium gating & subscriptions (AI features are paid)

> **Status: STEP (a) IS BUILT — 6.6a + 6.6a-2, `0011_subscription`.** The
> `subscription` table, `core/entitlement.py` (`is_premium`), the `api/gate.py`
> dependency, the field omission on `/api/today` + `/api/sleep/consistency`,
> `GET /api/entitlement`, the nightly chain's skip, **and the metered free allowance**
> (`core/allowance.py` + `api/gate.py`'s `FREE_ALLOWANCE`, 6.6a-2) all exist and are
> enforced. What is NOT built is **step (b)** — billing, webhooks, a provider
> ([D4]/[D5] are still open).
>
> Entitlement is written today by the committed ops module `db/grant_premium.py`
> (dry-run by default, like `claim_sentinel`) or, deployment-wide, by
> `SELF_HOST_UNLOCKED` — see §12.6a. **`infra/DEPLOY.md` §B6 is a hard prerequisite
> for shipping this to prod**: an owner with no row loses the AI layer silently.

All **AI features** are gated behind an active subscription; the honest
data/tracking layer stays free. Entitlement is a per-user attribute, so it rides
on the §3–§4 identity work.

### 12.1 Free vs Premium (the exact line)

**Free (the tracking + honest numbers):** all raw + derived metrics, charts,
history, baselines/anomalies, personal **findings** (deterministic correlations/
cutoffs — not LLM), recovery/sleep/VO2max/cardio-load numbers, data-health,
manual logging, workouts, GPS. The app is fully useful as an honest tracker.

**Premium (everything through the LLM choke point):**
- `POST /api/coach` (the conversational coach) — and it is the ONE surface capped for a
  paying owner too: **20 questions per rolling 30 local days** (`PRICING.md` §0, decided
  2026-08-02), because at $0.179 a question it is the only one whose cost scales with use
- `GET /api/sleep/insight` · `/api/activity/insight` · `/api/metric/insight` ·
  `/api/activity/workout/insight` · `/api/notable`
- `/api/today`'s AI fields: the daily **`action`** line + **`recommendations`**
- **Challenges / programs** — the whole system (adopt · auto-track · outcome ledger
  · AI-generated suggestions) is premium (owner decision 2026-07-16)
- The **Notable-shift feed** (`/api/notable`) — fully premium
- The nightly AI generation (recs · briefing · notable · daily-action)

Rule of thumb: **anything through `insights/grounded_ask` is premium**, PLUS the
challenges/programs system and the Notable feed. Free keeps the deterministic
honest tracker: metrics, baselines, per-card anomaly flags, and personal findings
shown as plain stats.

### 12.2 Entitlement model

```sql
CREATE TABLE subscription (
  user_id            UUID PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
  status             TEXT NOT NULL DEFAULT 'none',   -- none|trialing|active|past_due|canceled|expired
  plan               TEXT,                            -- monthly|annual|…
  provider           TEXT,                            -- stripe|revenuecat|apple|google
  provider_ref       TEXT,                            -- customer/subscription id
  trial_end          TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

`is_premium(user)` = `status IN ('trialing','active')` OR (`past_due` within a
grace window) AND `current_period_end > now()`. **The server is the sole source
of truth** — never trust a client claim of premium.

**As built (`core/entitlement.py`), because the sentence above is ambiguous and one
reading of it is unsatisfiable.** Taken with Python's precedence, "`past_due` within a
grace window AND `current_period_end > now()`" can never be true: a row only becomes
`past_due` once the period it was paid for has run out. So the deadline moves with the
status instead —

| status | premium while |
|---|---|
| `active` | `now < current_period_end` |
| `trialing` | `now < trial_end` (falling back to `current_period_end` if unset) |
| `past_due` | `now < current_period_end + GRACE_DAYS` (7) |
| `canceled` · `expired` · `none` · no row | never |

A row with **no end instant at all is not premium**, whatever its status — "granted
once, forgotten" is §12.7's loophole and failing closed is the only safe reading.
`canceled` ends access immediately by decision: a provider that means "cancels at
period end" is mapped by the webhook layer (6.6b) to a row that is still `active` with
the final `current_period_end`, so this module stays literal.

Two columns the sketch above has no room for are in the built table: `granted_by` and
`note`, the audit trail for a hand-made entitlement — 6.6a has no provider, so the only
writer is an operator. And the FK carries **`ON UPDATE CASCADE`** as well as
`ON DELETE CASCADE`: without it `db/claim_sentinel.py`'s single re-keying `UPDATE`
*errors* for any owner who has a row, which is exactly the defect `0006` had to go back
and fix for `device_token`.

**Privilege, not promise:** the app role holds **SELECT and nothing else** on
`subscription` (`db/provision_app_role.py::_grant_read_only`). A request path cannot
mint entitlement even if someone later writes SQL that tries — which closes §12.7's
"client-supplied proof of payment" row at the database rather than in code review. The
REVOKE is load-bearing: `ALTER DEFAULT PRIVILEGES` grants the app role full DML on any
table a future migration creates, so "we did not grant it" is not the same statement as
"the role does not have it".

### 12.3 The gate (three enforcement points)

1. **AI endpoints** → `api/gate.py`'s `AIGate` dependency, taken **in place of**
   `CurrentUser` rather than beside it, so an endpoint cannot take the owner's
   identity without also taking the gate. Not premium ⇒ **HTTP 402** with
   `{"locked": true, "feature": …, "upgrade": …}` — the app renders a locked card,
   not an error. Gated: `/api/coach`, the four insight routes, `/api/notable`, the
   whole challenges + programs surface (feeds included — a stored challenge is
   AI-authored content), and both generation endpoints.
   **The metered allowance (6.6a-2) lives inside that same dependency**, checked after
   entitlement, and since 2026-08-02 it prices BOTH tiers from two tables in
   `api/gate.py` — the only executable copies of `PRICING.md` §0/§1a:
   * `FREE_ALLOWANCE` — **every entry is 0**. The free tier has no AI at all, so a
     non-premium owner is refused on the first call to every AI route. The table stays at
     zero rather than being deleted so that re-granting a taste is a number, not a
     rewrite. **Absent from it ⇒ hard-locked** (fail closed).
   * `PREMIUM_ALLOWANCE` — `{coach: 20}` per rolling `PREMIUM_WINDOW_DAYS = 30` LOCAL
     days. **Absent from it ⇒ unlimited** (fail open — they paid). The two defaults are
     opposite by design; the cards and the daily action are uncapped because they are
     $0.0084 and a fixed $1.27/owner/month, already inside the price.

   So "premium removes the limit" is **no longer true** and the 402 says so: a capped
   subscriber gets `limit`/`used`/`resets_at`, a `Retry-After` header, a sentence naming
   the day it reopens, and **no `upgrade` URL** — they are not being sold anything.
   `core/allowance.py` is the rolling ledger, one `kv` row per owner per (feature,
   window) holding the *instants* of recent uses; the key is
   `allowance:<feature>:<window>d` with no date in it (that is the shape `0012` removed),
   and the window is in the key because the same instants mean different things under a
   7-day and a 30-day count. A refused attempt is never recorded, or the window could
   never roll. Charge-then-refund, so a refusal, a transport failure or the honest
   fallback gives the question back (`gate.refund_ai_use`) — **a slot is never billed for
   an answer we did not deliver.**
   One surface was added rather than widened: `POST /api/today/action`, because
   `/api/today` never generates, so *revealing* an unwarmed line means generating it on
   demand.
   `tests/premium/test_ai_gate.py` walks every mounted route's real dependency tree
   and fails the build on any route that is neither gated nor in a reasoned free
   allowlist, so a new AI endpoint cannot ship open.
2. **`/api/today`** (and `/api/sleep/consistency`) → serve the free data always;
   **OMIT** the AI fields entirely for non-premium and add a `locked` marker.
   *Omitted, not nulled* — §12.7 is explicit that the data must not be in the
   response at all, and the two statements here disagreed. §12.7 wins.
   `/api/sleep/consistency`'s `tonight` line is the second such field and appears in
   neither this section nor `PRICING.md` §1a; it rides the same `daily_action`
   entitlement because it is the same generator (`insights.coaching.warm_lines`).
3. **Jobs** → `jobs/chain.py` looks up `is_premium` once per owner per chain and
   **skips `recs`, `warm` and `briefing`** for a free owner — no LLM tokens spent on
   output nobody can see. `correlate` and `challenges` still run for everyone: both
   are deterministic and free to run, `correlate`'s findings are a FREE-tier feature
   (`PRICING.md` §1a), and `challenges` only closes out commitments that already
   exist — a lapse must not freeze somebody's live challenge forever. The skips are
   named `skipped` with a reason, never silently absent.
   *Not built:* the one-off generation on subscribe. It belongs with the webhook
   (6.6b); today an owner granted premium picks the AI layer up at their next
   nightly chain, or immediately via `run_chain(..., force=True)`.

`GET /api/entitlement` returns the user's premium state + the locked-feature list
so the app knows what to show as upgradeable. It is deliberately **ungated** — a
locked-out owner is exactly who needs to read it — and uncached, so a refund shows
up on the next poll rather than at the end of a TTL.

Since **#116** it also returns **`included`**: one entry per feature in
`PREMIUM_ALLOWANCE` carrying `limit` / `used` / `remaining` / `window_days`, plus
`resets_at` + `retry_after_s` **once the window is full** (null while slots remain —
nothing is being waited for). It exists because a cap that is *stated* in `PRICING.md`
§0 and *enforced* in the gate was, until then, observable only by being refused — and
§0's own argument for stating a number is that "'unlimited' with a silent throttle is
the dishonest version of the same thing". Three properties, all of them load-bearing:
`api/allowance_report.py` **peeks** (`core/allowance.peek`), so polling a balance can
never spend one; the list is built by iterating `PREMIUM_ALLOWANCE` itself, so the cap
stays single-sourced and a feature capped later needs no edit here; and it is **empty
for a non-premium owner** and carries **no entry for an uncapped feature** — a meter
reading zero is the exact inversion of both "they were never sold this" and "they paid,
so it is unlimited". It is a *subscriber's* meter and never an upsell: `locked` answers
"what would paying get me", `included` answers "what did paying get me, and how much of
it is left", which is why the capped subscriber stays absent from `locked`.

### 12.4 Billing integration **[D4]**

Web billing (no store IAP). Server owns entitlement; the provider drives it via
**signature-verified webhooks** only:
- **Stripe** (Billing/Checkout) — direct, mature; you handle tax or add Stripe Tax.
- **Polar** — Merchant-of-Record (handles global sales tax/VAT for you), built for
  indie/dev products; supports subscriptions, one-time, and **pay-what-you-want**
  (which is how *donations* map to an unlock). Stripe-backed under the hood.
- **Donations** unlock via the same path: a one-time payment (Stripe one-time or
  Polar PWYW) at or above a defined threshold grants premium for a defined term —
  the entitlement rule is explicit (**[D5]**: does a donation grant permanent or
  time-boxed premium, and the minimum amount?), never "any payment = forever".

Flow: `POST /billing/webhook` verifies the provider's signature, then updates the
`subscription` row on `checkout.completed` / `subscription.renewed` / `canceled` /
`expired` / `refunded` / `dispute`. A nightly reconcile (in the per-user sweep)
hard-expires anyone past `current_period_end`. The client may start a checkout
(returns a session URL) but entitlement is ONLY ever set from a verified webhook
or a server→provider API confirmation — never from anything the client sends back.

### 12.5 Trials & grace
Optional free trial (`trial_end`); a dunning grace window on `past_due` before
hard-lock, so a failed renewal doesn't instantly wall a paying user out.

### 12.6 Phasing
Fits as **Phase 6.6** (needs the §4 user model). Built in two steps: (a) **DONE
(6.6a)** — the gate + `subscription` table + `is_premium` with entitlement flipped by
an admin/config path (so gating works before billing exists), then (b) wire the real
provider + webhooks. The app's locked-card UX can ship against (a). The metered free
allowance is 6.6a-2 and is the one piece of (a) still outstanding.

### 12.6a The admin/config entitlement path — and why the sentinel is NOT premium by default

Step (a) needs *some* way to say "this person is entitled" before a provider exists.
There are two in 6.6a, and they answer different questions:

* **`db/grant_premium.py`** — "this particular person paid / was comped." A committed
  ops module, dry-run by default, run like `claim_sentinel` with the owner's UUID as an
  argument: **the operator naming the UUID is the authorisation**. It writes the same
  `subscription` row a webhook will later write, so there is still exactly one source of
  truth. `--months` has no default (a term is mandatory), it refuses a UUID with no
  `app_user` row, and `--revoke` writes `canceled` rather than deleting the history.
* **`SELF_HOST_UNLOCKED`** (default false) — "this whole deployment is somebody's own
  box." Every owner on it is entitled. It exists because the paywall's justification is
  *our* LLM bill on *our* hosted service (`PRICING.md` §6.1), and that argument does not
  survive contact with a self-hoster running their own OpenRouter key — which is the
  product's stated brand. The server cannot distinguish the two deployments, so the
  operator declares it; that is server-owned config, not a client claim. Both entry
  points log a WARNING on every boot when it is set, so a hosted box that trips it says
  so in `docker compose logs`. **It must reach the scheduler container as well as the
  api** — otherwise a self-hosted install serves the AI layer over HTTP while its
  nightly chain silently generates nothing.

**Rejected: "the sentinel owner is premium by default."** It is tempting, because it
would make the deploy a no-op for today's single live owner, and there is a real
argument for it (a self-hosted install is by definition the owner's own). It was
rejected on three grounds:

1. **It would be a second source of truth for entitlement.** §12.7's model is that
   entitlement is looked up per request *from the table*. `if user_id == SENTINEL:
   return True` means `is_premium` has two answers, only one of which is auditable and
   revocable — and no webhook, refund or reconcile could ever touch the other.
2. **It would tie a permanent grant to a shared secret.** The sentinel is whoever holds
   `REALTIME_INGEST_TOKEN` (§4.4a). Wiring "premium forever" to a secret that is
   explicitly transitional, and whose whole removal plan exists because it is too
   powerful, is the shape of grant this section exists to prevent.
3. **It would vanish at the worst moment, silently.** `claim_sentinel` re-keys the
   sentinel to the owner's real Supabase UUID (§8). The day that runs, a sentinel-keyed
   default stops matching and the owner loses the AI layer — during an unrelated ops
   action, with nothing failing. A `subscription` row moves with them instead
   (`ON UPDATE CASCADE`), which is the behaviour anyone would expect.

The cost of rejecting it is exactly one documented command at deploy time
(`infra/DEPLOY.md` §B6), and that command is auditable in the shell history in a way a
compiled-in constant never is.

### 12.7 Anti-bypass — closing every loophole

**Threat model:** this is a hosted multi-tenant service — the **server is the
trust boundary; every client is adversarial**. A paywall only holds if entitlement
is decided and enforced *entirely server-side, per request, from server-owned
state*. The client is never trusted for anything that gates access; it only
*renders* what the server already decided.

| Loophole | Closure |
|---|---|
| **Client flips its own "premium" flag** (patched app, devtools) | Client-side entitlement is display-only. The server enforces every AI call; a lying client still gets **402**. Never gate in the UI alone. |
| **Direct API calls** bypassing the locked UI (`curl /api/coach`) | `require_premium` runs on the **server endpoint**, not the screen. Same for the 4 insight routes + `/api/notable`. |
| **Sniff `/api/today`** to read AI fields the app "hides" | Server **omits** `action`/`recommendations` from the payload for non-premium (null + `locked:true`) — the data is not in the response at all, so there's nothing to sniff. |
| **Read pre-generated AI content** from another path/DB | The job **never generates** AI content for free users, so there is nothing stored to leak. Any endpoint reading stored recs/insights also runs `require_premium`. |
| **Forge/replay a billing webhook** to self-grant premium | Verify the provider's **webhook signature** (Stripe/Polar signing secret); reject unsigned/invalid. Idempotency key per event blocks replay. Body is untrusted until the signature checks out. |
| **Client-supplied "proof of payment"** | Entitlement is set ONLY from a verified webhook or a **server→provider API** confirmation. The client may pass a checkout-session id, which the server **re-verifies against the provider**, never trusts. |
| **Forged/stolen JWT** claiming premium | Entitlement is **looked up server-side per request** from the `subscription` table — NOT a trusted JWT claim. A forged/stale token can't grant access. Short access-token TTL + strong signing secret + refresh rotation. |
| **Keep access after cancel/refund/chargeback** | Handle the **full lifecycle** (cancel/expire/refund/dispute → revoke); `is_premium` checks `current_period_end > now()` every call; nightly reconcile hard-expires stragglers. Never "granted once, forgotten". |
| **Cross-tenant read** to reach a premium user's generated content | §3.3 Row-Level Security + per-query `user_id` filter — a free user can't reach a premium user's rows regardless of entitlement. |
| **Trial farming** (many accounts for free trials) | One trial per email + payment-method (provider dedup); optionally require card-on-file to start; signup rate-limiting. Or ship without a trial. |
| **Account/credential sharing** (one sub, many people) | Not fully preventable (industry-wide), but bounded: tie the sub to the account, **cap concurrent device tokens per user**, flag anomalous parallel/multi-region use. Documented as "reasonable limits", not airtight. |
| **Donation-unlock abuse** (a 1¢ donation → forever premium) | The donation→entitlement rule is **explicit and server-enforced** (threshold + term, [D5]); processed through the same signature-verified webhook, not a client claim. |

**One-line invariant:** *no AI response bytes ever leave the server for a request
whose `user_id` is not **entitled** — enforced at the endpoint AND in the jobs, from
server-owned entitlement **and a server-owned usage ledger**, with RLS underneath.*
If that holds there is no gate to crack from the client side; the only remaining
surface is the billing webhook, closed by signature verification.

> The word `premium` became `entitled` with 6.6a-2, and 2026-08-02 changed which half
> does the work. *Entitled* = premium **and inside `PREMIUM_ALLOWANCE`'s count** (or
> inside a free allowance, which is now empty). Both halves are server-owned state read
> per request: entitlement from the `subscription` table, usage from the `kv` ledger the
> app role can write only for its own tenant (RLS). Neither is ever a client claim, so
> the loophole table above is unchanged — a lying client gets 402 whether it is claiming
> premium it does not have or claiming questions it has already used, which
> `test_a_client_claiming_premium_is_still_refused` and `test_premium_cap.py` assert
> against a *spent* ledger and not only against a missing subscription. **The ledger is
> now the thing that can NARROW the gate as well as widen it**, and that is the one
> substantive change to this section: an owner who is genuinely premium can still be
> refused, from server-owned state, and no client claim reaches that decision either.

**How 6.6a tests it** (`tests/premium/`, plus `tests/jobs/test_chain_supervision.py`):
the endpoint half by calling every gated route directly as a free owner and asserting
402 *and* a stub model call count of zero; the jobs half by running the real chain
against a real database and asserting the stub was never called at all; the omission by
asserting on the raw response **text**, not the parsed dict; the "read pre-generated
content" row by checking that a free owner's chain leaves no warmed coaching line and
no `recommendation` row behind; and the two-owner case by running one free and one
premium chain and asserting neither leaked into the other. The completeness guard walks
the application's own route table, so an AI endpoint added later cannot ship ungated.

---

## 13. Decisions needed

- **[D1] Signup model — TAKEN (6.5, §4.4b):** invite-gated by a config flag now,
  self-serve flippable later — as recommended, and now actually **built and enforced
  in the server** rather than assumed of a Supabase dashboard toggle. A new owner is
  provisioned only when `signups_open` is true OR their verified email is on
  `signup_allowlist`; otherwise **403**, before any write. Default posture: closed +
  empty allowlist = nobody new. Flipping to self-serve is one env var — but **not
  before** the Phase-2 app ships Supabase login and the legacy shared-token branch
  dies (§4.4a, §12.7), and not before the free-tier AI cost levers land
  (`PRICING.md` §6.3: uncontrolled signup is uncontrolled LLM spend).
- **[D2] Session model:** stateless JWT with rotating refresh tokens (simplest,
  no session table) vs server-side sessions (revocable, needs a table)?
  *Recommend:* JWT access + refresh-rotation, a small `session` table only if you
  want instant revoke.
- **[D3] RLS now or later — RESOLVED (both steps SHIPPED; §3.3/§3.3a).** Enable RLS
  as the isolation backstop, but a probe before writing any policy found the
  premise was false: **the app connected to Postgres as a SUPERUSER**
  (`healthee: rolsuper=true, bypassrls=true`). With `ENABLE` + `FORCE ROW LEVEL
  SECURITY` and a policy in place, an owner-scoped query still returned **every**
  row, and an **unset** `healthee.user_id` returned every row instead of failing
  closed — superusers bypass RLS entirely, and `FORCE` does not touch them. So
  shipping §3.3 as written would have been **security theatre**: green tests, zero
  protection, and a documented guarantee that did not exist. The work splits:
  - **6.5b-1 (DONE)** — the prerequisite: make the app connect as a non-superuser,
    non-owner role (§3.3a). Correct on its own merits regardless of RLS: an app
    that can `DROP TABLE` is a problem by itself.
  - **6.5b-2 (DONE, `0008`)** — the policies + the per-transaction owner, on top of
    a role that can actually be constrained by them. Plain `ENABLE` was enough, as
    predicted (the app role does not own the tables). Two things the plan got wrong
    and the probe caught: the sketched `USING`-only policy would have left **INSERT
    ungoverned**, and `SET LOCAL` **cannot take a bind parameter** — it is
    `set_config(..., true)`. A third only appeared under RLS: a TimescaleDB SkipScan
    planner bug that 500s `DISTINCT ON` on a policied table. All three in §3.3.

  **The durable lesson:** an isolation mechanism must be verified by *defeating*
  it — asserting that a wrong/unset tenant sees **nothing**. A test that only
  checks "the right tenant sees their rows" passes identically against no
  isolation at all. The app-role attributes are asserted from `pg_roles` in
  `tests/db/test_app_role.py` for exactly this reason, and `tests/db/test_rls.py`
  is written entirely in that shape.

  **The second-order version of the same lesson, learned here:** the tests must run
  as a role the mechanism can actually constrain. `POSTGRES_APP_*` is unset in dev
  and CI, so the suite would have run as the admin superuser and every RLS test
  would have passed against inert policies — 6.5b-1's exact failure, one level up.
  `tests/conftest.py::app_role_pool` puts the whole suite on the least-privilege
  role, and `test_the_app_pool_is_never_privileged` fails if that ever stops being
  true.
- **[D4] Billing provider (premium gating, §12):** **Stripe** vs **Polar**
  (Merchant-of-Record — handles global tax for you) vs **donations**
  (Stripe one-time / Polar pay-what-you-want) — or a mix. *Recommend:* Polar if
  you want tax handled for you, Stripe for maximum control; either way entitlement
  is set only from signature-verified webhooks (§12.4/§12.7). Gate + `subscription`
  table can land before this is chosen (admin/config entitlement flag).
- **[D5] Donation → entitlement rule (§12.4):** does a donation grant **permanent**
  or **time-boxed** premium, and what is the **minimum amount**? Must be explicit so
  a token payment can't unlock forever. *Recommend:* a threshold that grants a fixed
  term (e.g. 12 months), renewable by donating again.
- **Auth libs — RESOLVED in 6.1:** no password-hashing dep (argon2 is moot —
  Supabase owns credential hashing); the backend only VERIFIES tokens, so it added
  `pyjwt` alone (`core/supabase_auth.py`). ~~Confirm before 6.1~~ done.
