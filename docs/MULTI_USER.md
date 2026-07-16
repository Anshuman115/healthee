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
| `profile` locked to one row | `0001_initial.sql`: `id INTEGER PK DEFAULT 1 CHECK (id = 1)` | `users` table; `profile.user_id` FK unique |
| No tenant column on any data table | all 15 data tables (`sample`, `derived_daily`, `sleep_session`, `workout`, `weight_log`, `manual_entry`, `illness_flag`, `recommendation`, `finding`, `challenge`, `program`, `challenge_outcome`, `gps_track`, `gps_point`, `kv`) | add `user_id`; fold into every PK/UNIQUE |
| `WHERE id=1` profile reads | `derive/_common.py`, `analytics/biological_age.py`, `read/history.py`, `jobs/recs_context.py` | key profile by `user_id` |
| Hardcoded timezone | `USER_TZ = "Asia/Kolkata"` — **63 references** | per-user `profile.timezone`, threaded |
| Global nightly chain | `jobs/scheduler.py` fires ONE chain; `jobs/chain.py` dedups per-day via a global `kv` key | loop over active users; per-user cache keys |
| Global cache keys | `insights/coaching.py DAILY_ACTION_KEY`, `chain _DONE_KEY:{day}` | `…:{user_id}:{day}` |
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

Add `user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE` to all 15
data tables and fold it into the key:

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
- `profile`: drop `CHECK (id=1)`; becomes `user_id BIGINT PRIMARY KEY REFERENCES
  app_user(id)` (1:1 with app_user; name/height/sex/dob move here or merge into
  `app_user`).

### 3.3 Row-Level Security (isolation guarantee)

```sql
ALTER TABLE sample ENABLE ROW LEVEL SECURITY;
CREATE POLICY sample_tenant ON sample
  USING (user_id = current_setting('healthee.user_id')::bigint);
-- …one policy per table.
```

The app sets `SET LOCAL healthee.user_id = <id>` at the start of each request's
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

- **Scheduler** (`jobs/scheduler.py`): the daily timer fires a step that now
  **iterates active users**: `for u in active_users(): run_step(step, user=u)`.
  Alternatively (better at scale) trigger a user's chain off *their* ingest
  (each strap syncs on its own schedule/timezone) — event-driven, not a global
  cron. Recommended: ingest-triggered per-user chain + a nightly sweep for
  stragglers.
- **Chain dedup** (`jobs/chain.py`): the `kv` marker key becomes
  `job:chain_done:{user_id}:{day}` and reads/writes go through the per-user `kv`
  PK.
- **Cache** (`insights/coaching.py`): `DAILY_ACTION_KEY` → `…:{user_id}`; the
  Today endpoint reads the current user's cached line.
- **Per-user timezone** means "today" and the nightly fire time differ per user —
  the scheduler computes each user's local day from `profile.timezone`.

---

## 7. Ingest attribution

`/ingest/helio` authenticates with a **device token** → `user_id`. `ingest_helio`
threads that id into every upsert (`upsert_samples`, `upsert_sleep`, …) so raw +
typed + derived rows are written under the owner. The app already sends a token;
multi-user makes it a *per-user device* token instead of one global secret.

---

## 8. Data migration / backfill

One numbered migration, done online-safe:
1. Create `app_user`, `credential`, `device_token`; insert **you** as user 1
   (email + argon2 hash + a device token that replaces today's shared token).
2. `ALTER TABLE … ADD COLUMN user_id BIGINT` **nullable** on every data table.
3. Backfill: `UPDATE … SET user_id = 1`.
4. `ALTER COLUMN user_id SET NOT NULL`; add FKs; rebuild PK/UNIQUE constraints to
   include `user_id`; add `(user_id, …)` indexes; enable RLS + policies.
5. Migrate `profile` (drop `CHECK(id=1)`, key by user_id).

Because prod is one user, backfill is trivial and reversible (the column is
additive until step 4). Snapshot the DB before step 4.

---

## 9. Mobile (Phase 2, greenfield — build multi-user-native)

The app is being rebuilt from scratch, so it should be multi-user from day one:
a **login screen** (email/password → JWT), secure token storage, a **device
pairing** step that stores the per-user device token for background ingest, and
per-user local store (the 60-day tier is namespaced by user). No migration cost
here because there is no legacy app to convert — just design it in.

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
| **6.1 Identity** | `app_user`/`credential`/`device_token` tables + `auth.py` (register/login/refresh/device) + argon2 + JWT. Seed you as user 1. No behavior change (nothing reads user_id yet). | login works; existing endpoints unaffected |
| **6.2 Schema** | Migration §8: add `user_id` everywhere (nullable→backfill=1→NOT NULL + keys + FKs + indexes). No code reads it yet. | schema migrated, all tests green on user 1 |
| **6.3 Thread scoping** | `RequestUser`/`Ctx` object; thread `user_id`+`tz` through read/derive/analytics/insights/jobs/ingest; per-user `kv`/cache; kill the `USER_TZ` constant. Still resolves to user 1 by default. | every query scoped; single-user behavior identical |
| **6.4 Flip identity** | `current_user()` returns the real authenticated user; ingest device-token attribution; per-user scheduler; per-user timezone live. | second real user works end-to-end, isolated |
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
  user_id            BIGINT PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
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
- **Auth hashing/JWT libs:** argon2 (`argon2-cffi`) + `pyjwt` (look up current
  versions at add-time per standards). Confirm before 6.1.
