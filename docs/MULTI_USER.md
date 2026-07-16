# Healthee — Multi-User / Multi-Tenancy Design & Migration Plan

Turn the single-tenant app (one strap, one user, one timezone) into a real
multi-tenant framework: every user has their own strap, timezone, data,
derived metrics, analytics, findings, recs, coach, and challenges — fully
isolated. This is **Phase 6** of the blueprint (the `multi-user` branch stub).

Status: DESIGN (2026-07-16). Nothing here is built yet. Decisions marked **[D#]**
need a call before the phase they gate.

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
   the default user (id 1 = you) keeps functioning until the flip.

---

## 2. The single-tenant couplings we are removing (grounded audit)

| Coupling | Where | Fix |
|---|---|---|
| One shared bearer token, no identity | `core/auth.py` `require_token()` returns `None` | Auth resolves + returns a `user_id` (JWT session / device token) |
| ~~`profile` locked to one row~~ **DONE 6.3c** | `0001_initial.sql`: `id INTEGER PK DEFAULT 1 CHECK (id = 1)` | `0005`: `id` dropped; `user_id` is the PK |
| No tenant column on any data table | all 15 data tables (`sample`, `derived_daily`, `sleep_session`, `workout`, `weight_log`, `manual_entry`, `illness_flag`, `recommendation`, `finding`, `challenge`, `program`, `challenge_outcome`, `gps_track`, `gps_point`, `kv`) | add `user_id`; fold into every PK/UNIQUE |
| ~~`WHERE id=1` profile reads~~ **DONE 6.3c** | `derive/_common.py`, `analytics/biological_age.py`, `read/history.py`, `jobs/recs_context.py` | all four now filter on `user_id` alone |
| Hardcoded timezone | `USER_TZ = "Asia/Kolkata"` — **63 references** | per-user `profile.timezone`, threaded |
| ~~Global nightly chain~~ **DONE 6.3c** (fire times: 6.4) | `jobs/scheduler.py` fires ONE chain; `jobs/chain.py` dedups per-day via a global `kv` key | `_fire` sweeps `active_users()`; dedup is per-owner via the `kv` PK |
| ~~Global cache keys~~ **MOOT — see §6** | `insights/coaching.py DAILY_ACTION_KEY`, `chain _DONE_KEY:{day}` | superseded by `0004`'s `kv` PK `(user_id, key)`; keys are NOT namespaced |
| Ingest has no owner | `/ingest/helio` writes samples unattributed | device token → `user_id`; write under it |
| ~119 query sites assume "the user" | read ~59 · derive ~30 · analytics ~17 · insights ~8 · jobs ~5 | thread `user_id` (see §5) |

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

There is **no local `credential` table and no session table** — Supabase handles
login, refresh, reset, verification, OAuth. Intra-DB FKs from health tables to
`app_user` still hold (both are in the Contabo DB); the only relationship without a
DB-level FK is Contabo `app_user` ↔ Supabase `auth.users` (cross-DB — kept
consistent by JIT-provision + the delete webhook).

### 3.2 Tenant column on every data table

Add `user_id UUID NOT NULL REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE
CASCADE` to all 16 data tables and fold it into the key. **This section is the
target end-state**; it lands in two steps (§8): the column + FK + `(user_id, …)`
index are additive in **6.2** (`0003`, done), and the key-fold below (PKs/UNIQUE)
moves to **6.3** so it changes together with the `ON CONFLICT` code.

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

### 3.3 Row-Level Security (isolation guarantee)

```sql
ALTER TABLE sample ENABLE ROW LEVEL SECURITY;
CREATE POLICY sample_tenant ON sample
  USING (user_id = current_setting('healthee.user_id')::uuid);
-- …one policy per table.
```

The app sets `SET LOCAL healthee.user_id = <uuid>` at the start of each request's
transaction. Then even a query that forgets `WHERE user_id` cannot see another
tenant's rows. This is the "real framework" isolation backstop. **[D3]**

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
3. `SET LOCAL healthee.user_id = <uuid>` on the request transaction (RLS §3.3).
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

### 4.5 Deletion / GDPR
A Supabase **auth delete webhook** → purge that UUID's health data (cascade via
the `app_user` FK). Data export is already free (own-your-data).

**This resolves [D2]** (session model — Supabase handles refresh/rotation) and
moves **[D1]** to a Supabase setting (disable public signup / use the allowlist for
invite-only). Password hashing lib is moot (Supabase). The backend gains one dep:
a JWT-verify library (`pyjwt` + JWKS, or Supabase's helper) — look up the current
version at add-time.

---

## 5. Threading `user_id` through the code (~119 sites)

The mechanical-but-wide pass. Do it cleanly, NOT via a global/thread-local:

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

Guardrail: a lint/test that greps for tenant-table `execute` calls lacking a
`user_id` bind (belt-and-braces with RLS).

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
  correlate → recs → briefing *with* the dependency, so the stagger only
  re-implemented that ordering with `sleep()`. `chain.run_step`/`STEP_NAMES` were
  orphaned by the collapse and deleted.
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

---

## 7. Ingest attribution

`/ingest/helio` authenticates with a **device token** → `user_id`. `ingest_helio`
threads that id into every upsert (`upsert_samples`, `upsert_sleep`, …) so raw +
typed + derived rows are written under the owner. The app already sends a token;
multi-user makes it a *per-user device* token instead of one global secret.

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
   the DEFAULT: this is the transitional scaffold that keeps 6.2 non-breaking (it
   is dropped in 6.5 once every writer supplies `user_id` and RLS is on).
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

**6.4** re-keys the sentinel owner to the real Supabase UUID with a single
`UPDATE app_user SET id = …` that cascades to every data row via the
`ON UPDATE CASCADE` FKs. RLS + policies land in 6.5.

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

- **Two-tenant seed:** extend `tests/contracts/seed.py` to seed users A and B
  with distinct data; every read/insight/coach/recs test asserts A sees ONLY A.
- **Cross-tenant leakage test:** authenticate as A, request B's ids → 404/empty,
  never B's data. Run with RLS on AND (temporarily) off to prove both layers.
- **Per-user parity:** the science parity fixtures run per-user unchanged.
- **Auth tests:** login/refresh/expiry, device-token scoping, invite gating.
- Keep the full-suite-under-TZ=UTC-and-IST discipline; multi-tz is now first-class
  (seed users in different timezones).

---

## 11. Phased rollout (each phase = its own reviewed PR, main stays green)

| Phase | Scope | Ships when |
|---|---|---|
| **6.1 Identity ✅** | `app_user` + `device_token` tables (`0002_identity`) + `core/supabase_auth.py` (VERIFY the Supabase JWT — HS256, pinned algs; JIT-provision `app_user`; mint/resolve hash-only device tokens) + thin `/api/me` + `/api/device`. No local credentials/argon2/login-endpoints (Supabase owns them). Additive — existing shared-token auth untouched, nothing reads `user_id` yet. | login works; existing endpoints unaffected |
| **6.2 Schema** | Migration §8 (`0003`): **additive only** — add `user_id` (`NOT NULL DEFAULT <sentinel>` = backfill) + FK + `(user_id, …)` index to every data table, and the sentinel owner (tz `Asia/Kolkata`). No PK/UNIQUE/`ON CONFLICT` change, `profile` id=1 PK kept, no code reads it yet. | schema migrated, all tests green on the sentinel owner with ZERO code changes |
| **6.3 Thread scoping ✅** | Shipped in three slices. **6.3a** (`0004`): folded `user_id` into every natural PK/UNIQUE, retargeted every `ON CONFLICT`, made every tenant WRITE set the owner; added `core/tenancy.SENTINEL_USER_ID`. **6.3b**: scoped every tenant READ with `AND user_id = %s`, killed the seven duplicate `Asia/Kolkata` constants for `SENTINEL_TZ` threaded as `tz: str`, and added the AST completeness guard (`tests/db/test_tenant_read_scoping.py` — any new unscoped tenant SQL now fails the build) + read-isolation tests. **6.3c** (`0005`): re-keyed `profile` by `user_id` (dropped `id`/`CHECK (id = 1)`, retargeted `upsert_profile`'s conflict to the owner — it was silently overwriting another owner's demographics), per-user job sweep (`active_users()` → `Tenant`, per-owner local day, isolated failures), and the two-tenant seed + cross-tenant leakage suite (§10). Cache-key namespacing was **dropped as redundant** (see §6). Everything still resolves to the sentinel by default. | every query scoped; single-user behavior identical (contract snapshots byte-identical) |
| **6.4 Flip identity** | Shipped in slices. **6.4a**: `USER_TODAY_SQL`/`user_today()` — the owner's day boundary, killing the `current_date` anchor. **6.4b ✅**: the auth flip — dual auth (§4.4a) in `core/request_auth.py`; all 11 routers inject `user: CurrentUser` per-endpoint and pass `user.id`/`user.timezone` (router-level `require_token` gone, `core/auth.py` deleted as orphaned); the sentinel hardwires cleared from `surfaces`/`coach_tools`/`notable`/`coaching`/`coach_context` (threaded from the router, so the coach and every insight act for the REQUESTING user); `/ingest/helio` attributed by device token → owner (§7), unknown token → 401. Tests: HTTP-level cross-tenant leakage both-owners-see-their-own (`tests/db/test_http_isolation.py`, incl. a permanent mutation test), the auth matrix (`tests/test_request_auth.py` — every rejected JWT asserted to never reach the sentinel branch), ingest attribution (`tests/integration/test_ingest_attribution.py`). **6.4c ✅**: per-user scheduler fire times — `jobs/scheduler.py` is now a **tick loop** running each owner's `run_chain` at 10:30 in **their own** `app_user.timezone`, deduped by `run_chain`'s per-owner per-day marker (§6); the global `scheduler.TZ`, the 10:30/10:45/11:00 stagger, and the orphaned `chain.run_step`/`STEP_NAMES` are gone. Still to land: re-key the sentinel owner to the real Supabase UUID. | second real user works end-to-end, isolated |
| **6.5 Harden** | Postgres RLS + policies; cross-tenant leakage tests; self-serve signup/onboarding (or invite gating); rate-limiting; per-user backup/export. | isolation proven; GA-ready |

Rough order-of-magnitude: 6.1 small, 6.2 small-medium (mostly SQL), **6.3 is the
big one** (the ~119-site threading), 6.4 medium, 6.5 medium. Each is a Fable-
directs / Opus-implements track with review + the two-tenant isolation tests.

---

## 12. Premium gating & subscriptions (AI features are paid)

All **AI features** are gated behind an active subscription; the honest
data/tracking layer stays free. Entitlement is a per-user attribute, so it rides
on the §3–§4 identity work.

### 12.1 Free vs Premium (the exact line)

**Free (the tracking + honest numbers):** all raw + derived metrics, charts,
history, baselines/anomalies, personal **findings** (deterministic correlations/
cutoffs — not LLM), recovery/sleep/VO2max/cardio-load numbers, data-health,
manual logging, workouts, GPS. The app is fully useful as an honest tracker.

**Premium (everything through the LLM choke point):**
- `POST /api/coach` (the conversational coach)
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

### 12.3 The gate (three enforcement points)

1. **AI endpoints** → a `require_ai_access(user, feature)` FastAPI dependency
   (composes with `current_user`): allows the request if the user is premium **OR**
   is within the free-tier metered allowance for that feature (the "taste of
   premium" — 1 coach question + 1 daily-action reveal per rolling 7 days, tracked
   server-side per user; see `PRICING.md` §1a). Otherwise **HTTP 402** with
   `{"locked": true, "feature": "ai", "upgrade": "<url>"}` — the app renders a
   locked card, not an error. Recs/insight cards have a zero free allowance (hard
   lock); coach + daily-action carry the weekly taste.
2. **`/api/today`** → serve the free data always; set `action = null` and
   `recommendations = []` with a `"locked": true` marker for non-premium, so the
   page still renders every metric.
3. **Jobs** → the per-user nightly chain checks `is_premium` and **skips** recs/
   briefing/notable/daily-action for free users — no LLM tokens spent on output
   nobody can see. On subscribe, trigger a one-off generation so premium unlocks
   immediately.

`GET /api/entitlement` returns the user's premium state + the locked-feature list
so the app knows what to show as upgradeable.

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
Fits as **Phase 6.6** (needs the §4 user model). Can be built in two steps: (a)
the gate + `subscription` table + `is_premium` with entitlement flipped by an
admin/config flag (so gating works before billing exists), then (b) wire the real
provider + webhooks. The app's locked-card UX can ship against (a).

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
whose `user_id` is not premium — enforced at the endpoint AND in the jobs, from
server-owned entitlement, with RLS underneath.* If that holds there is no gate to
crack from the client side; the only remaining surface is the billing webhook,
closed by signature verification.

---

## 13. Decisions needed

- **[D1] Signup model:** invite-only (you provision accounts) vs public
  self-serve registration? Changes how much onboarding/anti-abuse 6.5 needs.
  *Recommend:* invite-gated by a config flag now, self-serve flippable later.
- **[D2] Session model:** stateless JWT with rotating refresh tokens (simplest,
  no session table) vs server-side sessions (revocable, needs a table)?
  *Recommend:* JWT access + refresh-rotation, a small `session` table only if you
  want instant revoke.
- **[D3] RLS now or later:** enable Postgres Row-Level Security in 6.5 as the
  isolation backstop (recommended — it's the "real framework" guarantee), or rely
  on app-layer filtering only? *Recommend:* do it; it's cheap insurance for
  health data.
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
