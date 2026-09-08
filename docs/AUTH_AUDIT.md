# Auth audit — authentication, tenancy and row-level security

Read-only audit of `apps/server/src/healthee/api/` (26 modules), `core/tenancy.py`,
`core/request_auth.py`, `core/supabase_auth.py`, `core/db.py`, `core/config.py`,
`core/logging.py`, `core/rate_limit.py`, `db/` insofar as it defines roles, grants and
RLS policies, the ingest path, `infra/nginx/`, and the mobile side's token handling in
`apps/mobile/lib/data/api/`.

This is item 1 of `AUDIT_COVERAGE.md` — *"the only unaudited area where a defect is worse
than a wrong number: it is someone else's data."* The standard applied is that one:
findings are ranked by **whether owner data can cross an owner boundary today**, which is
not the same as how alarming a line of code looks.

**Every finding carries `file:line` and is marked CONFIRMED (code path read end to end,
or measured) or SUSPECTED (looks wrong, could not be proven read-only).** Swept classes
are reported with their evidence, because a clean result that names what it checked is
the only thing that makes the verdict verifiable rather than hopeful.

Prior art checked rather than repeated: `MULTI_USER.md` sections 3.3, 4, 7, 10, 12.7 and
`SECURITY_REVIEW_FABLE.md`. Where a prior finding is still true it is re-confirmed with a
current line number and said to be prior art; where it has been fixed it is recorded in
section F, because "this was fixed" is a result too. `LLM_AUDIT.md` A4/A5/B3 already own
prompt injection and coach-history handling; they are not re-audited here.

**Nothing was changed BY THIS AUDIT.** It recommends; it does not fix. No device, no
production server, no production database and no token were touched, and no secret value
appears anywhere below.

---

## 0. Counts

| Severity | Meaning | Count |
|---|---|---|
| **A — a credential or a row can leave its boundary** | a path exists today by which owner data or an owner's credential reaches someone else | 1 |
| **B — the isolation guarantee is one layer, not two** | nothing crosses today, but the backstop can be inert and nothing refuses to boot | 2 |
| **C — credentials that cannot be taken back** | the kill switches the design names do not exist in code | 4 |
| **D — the ingest path stores what it is given** | unvalidated device input reaching durable storage | 4 |
| **E — unbounded / exposed** | what an unauthenticated or authenticated caller can spend or read | 4 |
| **F — hygiene and drift** | a document, a comment or a guard that claims more than it does | 6 |
| **Swept clean** | classes checked with evidence, no finding raised | 11 classes |

**CONFIRMED 20 · SUSPECTED 1 · Could not determine 3.**

### The headline answers

* **Can a query reach owner data outside the tenancy path? No.** Measured, not argued:
  every one of the **227** SQL statements in `apps/server/src/healthee/` that names a
  tenant table binds `user_id` in a predicate or an INSERT column list — a strictly
  stronger check than the repo's own AST guard runs (F5). And every plain
  `transaction()` call site in the whole server is one of five, all touching only
  `app_user` or `SELECT 1` (section G, sweep 2).
* **Do the RLS policies exist, and does the app role bypass them? The policies exist
  for all 18 tenant tables; the provisioned role is `NOSUPERUSER NOBYPASSRLS` and
  post-checks itself against `pg_roles`. But the server will happily boot as a role
  that *does* bypass them, with only a log line, and both shipped `.env` templates ship
  the blank setting that produces exactly that (B1).** Whether the live deployment sets
  `POSTGRES_APP_*` is a production fact this audit was not permitted to check.
* **Can a token reach a log? On the server, no** — verified by grep over every logging
  call site and every `HTTPException` detail (section G, sweep 5). **On the client, no
  in the pinned dependency versions**, with one place where an upgrade could silently
  change that (F6). **But a token can leave the device entirely** (A1).
* **Is account deletion complete? There is no account deletion.** Not partial — absent
  (C1).
* **Is every route authenticated? Yes, measured.** 44 mounted routes enumerated from the
  live app object; exactly two resolve no identity (`/healthz`, `/readyz`) and both are
  deliberately public and carry no owner data. Section G, sweep 1 prints the table.

---

## A. A credential can leave its boundary

### A1 — the app's one HTTP client follows redirects while carrying the bearer token — CONFIRMED

`apps/mobile/lib/data/api/api_client.dart:29-46`

The `BaseOptions` sets `baseUrl`, three timeouts, `responseType`, `headers` and
`validateStatus` — and does not set `followRedirects`. Dio's default is `true` with
`maxRedirects: 5` (`dio-5.11.0/lib/src/options.dart:730-731`), and the IO adapter passes
both straight to `dart:io`'s `HttpClientRequest`
(`dio-5.11.0/lib/src/adapters/io_adapter.dart:138-139`), which replays the request
headers — `Authorization` included — at whatever host the `Location` names. The header is
attached before the redirect happens, by `ServerSessionInterceptor`
(`apps/mobile/lib/data/api/interceptors.dart:49`), so every authenticated call in the app
is in scope.

**The app already knows this rule and applies it in the other client.**
`apps/mobile/lib/data/api/server_probe.dart:69` sets `followRedirects: false`, and the
library docstring at `server_probe.dart:32-35` names this exact attack in its own words:

> Redirects are **not followed**. A 3xx would otherwise re-send the Authorization header
> to whatever host the `Location` names, which is a token leak triggered by somebody
> else's nginx config.

So the defect is not an unknown risk; it is the stated rule applied to the sign-in probe
(one request, before the token is stored) and not to the client that carries the token
for the rest of the app's life.

**Precondition, stated honestly:** the redirect has to come from the server the owner
signed into. Over HTTPS a network attacker cannot inject one, and `server_url.dart:87-89`
refuses `http://` for anything but loopback. The live shapes are a misconfigured reverse
proxy (the docstring's own scenario), and an owner socially engineered into signing into a
hostile host — which is a supported flow, since the server URL is a free-text field
(`apps/mobile/lib/features/signin/widgets/server_signin_form.dart:108-117`). That is why
this is ranked first: it is the only path found in the whole audit by which a credential
reaches a party that is not already entitled to it.

**Recommend:** `followRedirects: false, maxRedirects: 0` on the `BaseOptions` at
`api_client.dart:29`, and a test that asserts it — the same shape as
`apps/mobile/test/signin/signin_secrecy_test.dart:170-221`, which already drives the real
interceptor stack and pins that the header never reaches a log.

---

## B. The isolation guarantee is one layer, not two

Both entries here describe the same property: the explicit `AND user_id = %s` filters are
complete and proven (section G, sweeps 2 and 3), so **nothing crosses today**. What is at
risk is the *backstop* — the thing that is supposed to catch the filter somebody forgets
next year.

### B1 — the server boots happily as a role that bypasses RLS, and both env templates ship the setting that produces it — CONFIRMED

`apps/server/src/healthee/core/config.py:366-368`

```python
if self.app_role_configured:
    return self._conninfo(self.postgres_app_user, self.postgres_app_password)
return self.admin_db_url
```

A blank `POSTGRES_APP_USER` means the request/job pool connects as the owner/admin role.
A superuser ignores every policy `0008` creates — `FORCE ROW LEVEL SECURITY` does not
bind it either, and `0008` deliberately does not FORCE
(`db/migrations/0008_row_level_security.sql:20-25`). `core/db.py:89-120` detects this from
`pg_roles` and logs a `WARNING` naming the role. It does not refuse to start.

Two things make that more than a theoretical toggle:

* **Both shipped templates default to the unsafe side.** `infra/.env.example:38-39` and
  `apps/server/.env.example:24-25` are `POSTGRES_APP_USER=` / `POSTGRES_APP_PASSWORD=`,
  blank. An operator who copies the template and fills in what is obviously required gets
  the RLS-inert configuration and one log line.
* **The codebase's own precedent says a warning is not enough for the *other* shape of
  this problem.** `config.py:250-297` refuses to start on "AI key set, model id blank",
  and its docstring argues at length that an ambiguity should be refused rather than
  interpreted, explicitly contrasting itself with `_warn_if_privileged` on the grounds
  that the admin fallback is "a documented, deliberately-transitional step of a two-deploy
  bootstrap". That reasoning is sound *while* the bootstrap is in progress. It stops
  being sound at the moment a second owner exists, and nothing in the code marks that
  moment.

`tests/conftest.py:244` (`app_role_pool`, autouse + session-scoped) provisions the real
least-privilege role for the whole suite, and `tests/db/test_rls.py:83-104` asserts the
premise from `pg_roles` so the RLS suite cannot pass vacuously. That is exactly right, and
it is why this is a deployment-state finding and not a test-quality one.

**Recommend:** a `model_validator` that refuses to start with blank `POSTGRES_APP_*`
*unless* an explicit opt-out (`ALLOW_ADMIN_DB_FALLBACK=true`) is set, so the transitional
deploy stays bootable and the transitional state has to be *asked for*. And change the
`.env.example` default to the safe side, with the bootstrap instruction beside it.

### B2 — `app_user.status` is never consulted on the request path: suspension is a no-op — CONFIRMED

`apps/server/src/healthee/core/request_auth.py:64-69` ·
`apps/server/src/healthee/core/supabase_auth.py:168-180`

Both identity lookups select `timezone` alone:

```python
cur.execute("SELECT timezone FROM app_user WHERE id = %s", (str(user_id),))
```

The `status` column exists (`db/migrations/0002_identity.sql:19`, `NOT NULL DEFAULT
'active'`) and exactly one thing in the codebase reads it —
`core/tenancy.py:133`, the scheduler's `active_users()` sweep, whose docstring says
*"Suspended/deleted owners are excluded by `status`, so their chains stop without deleting
their data."*

That sentence is true of the nightly LLM chain and false of everything else. Setting
`status='suspended'` stops the owner's chain and leaves **full `/api/*` read/write and
full `/ingest/*` write access intact**. The only working kill switch is deleting the
`app_user` row, and every FK to it is `ON DELETE CASCADE`
(`db/migrations/0003_tenant_column.sql:37-161`), so the only way to stop an owner is to
destroy their entire health history. Prior art: `SECURITY_REVIEW_FABLE.md` raised this;
it is unchanged.

**Recommend:** `SELECT timezone, status` in both lookups and a 403 for anything but
`active`. Two lines, and it turns a documented column into an actual control.

---

## C. Credentials that cannot be taken back

### C1 — account deletion does not exist anywhere — CONFIRMED

`docs/MULTI_USER.md:460-462` is the whole of it:

> ### 4.5 Deletion / GDPR
> A Supabase **auth delete webhook** → purge that UUID's health data (cascade via the
> `app_user` FK). Data export is already free (own-your-data).

There is no webhook route (the 44-route enumeration in section G has none), no purge
module in `db/` (`claim_sentinel`, `grant_premium`, `migrate`, `provision_app_role`,
`rederive`, `stale_derived` — none delete an owner), and a repo-wide grep for
`purge_user` / `delete_account` / `gdpr` / `data_export` returns only unrelated prose in
comments. `SUPABASE_SERVICE_ROLE_KEY` sits in `core/config.py:85` labelled *"for later
admin/webhook work (delete-user cascade, section 4.5)"* and is read by nothing.

The brief asked whether deletion is complete and warned that a partial delete is the worst
finding available. It is not partial — it is absent, which is a different and in one sense
better state: there is no half-deleted owner, because nobody can start. What it does mean
is that **deleting the Supabase account leaves the entire local health record in place
forever**, with no code path that would ever remove it. The `ON DELETE CASCADE` FKs are
the mechanism; nothing calls it.

The second sentence of 4.5 is also not true today: there is no export endpoint.
`/api/history` is the closest thing and it clamps to `MAX_DAYS`
(`read/history.py:56-58`), which is a read, not an export. Recorded as F4.

**Recommend:** treat this as the GA blocker it is, and make the first version boring —
an admin-run `db/delete_owner.py` in the shape of `claim_sentinel` (dry-run by default,
`--apply` explicit, an in-transaction post-check that no row anywhere still belongs to the
UUID) is enough to make deletion *possible* and auditable. The webhook can follow.

### C2 — device tokens have no expiry, no revocation and no listing, and minting is unlimited — CONFIRMED

`apps/server/src/healthee/core/supabase_auth.py:196-207` mints; `:210-226` resolves.
`db/migrations/0002_identity.sql:28-36` is the table: `id`, `user_id`, `token_hash`,
`label`, `last_seen`, `created_at`. There is no `revoked_at` and no `expires_at`, and
`resolve_device_token` filters on nothing but the hash:

```python
"UPDATE device_token SET last_seen = now() WHERE token_hash = %s RETURNING user_id"
```

`POST /api/device` (`api/routers/auth.py:54-58`) mints on every call with no cap and no
per-user limit, so one session can create unbounded rows. A lost phone's token grants
`/ingest/*` write access to that owner's health data permanently, and there is no
user-facing or operator-facing way to kill it short of `DELETE FROM device_token`
by hand — which the app role *can* do (it holds DML on `device_token`,
`db/provision_app_role.py:66-86`) but nothing in the codebase does.

The storage side is right and worth saying: only the SHA-256 hash is persisted
(`supabase_auth.py:191-193`), the raw value is returned once and never written, and the
entropy is `secrets.token_urlsafe(32)` (`supabase_auth.py:42`). The gap is lifecycle, not
secrecy. Prior art: `SECURITY_REVIEW_FABLE.md`; unchanged.

**Recommend:** `revoked_at TIMESTAMPTZ`, filtered in `resolve_device_token`, plus
`GET /api/device` and `DELETE /api/device/{id}` scoped to the caller. Revocation without
listing is not usable — an owner cannot revoke a token they cannot see.

### C3 — the legacy shared token is a whole-tenant skeleton key, and its removal condition is prose, not a tripwire — CONFIRMED

`apps/server/src/healthee/core/request_auth.py:72-83` (`_legacy_shared_token`), reached
from `:110-112` for `/api/*` and `:123-124` for `/ingest/*`.

The crypto is done correctly: `hmac.compare_digest`, and a blank
`REALTIME_INGEST_TOKEN` authorizes nobody rather than matching everything (`:81-82`,
asserted at `tests/test_request_auth.py:171`). The ordering argument in the module
docstring is also correct and structurally enforced — the legacy comparison runs first and
the Supabase branch is the `return` that follows, so a rejected JWT cannot fall through
(`tests/test_request_auth.py:120-138` asserts the negative with a spy on the sentinel
resolver, which is the right shape: a bare `assert 401` would not distinguish the
branches).

What is missing is the enforcement of its own deadline. The module docstring at
`request_auth.py:13-17` says it **MUST NOT** survive into public signups, and
`MULTI_USER.md:455-459` says `signups_open=true` is "gated on that removal". Nothing gates
it. `core/config.py:73` (`realtime_ingest_token`) and `:100` (`signups_open`) are
independent fields with no cross-validator between them, while `config.py` already
contains three `model_validator`s that refuse exactly this kind of ambiguity
(`:232-248`, `:250-297`, `:321-329`). One static, never-expiring string that resolves to a
real tenant, shipped inside the APK, coexisting with open signups is the one combination
the design says must never happen — and it is currently prevented by a paragraph.

**Recommend:** a `model_validator` refusing `signups_open=True` while
`realtime_ingest_token` is non-blank. It costs six lines and converts the docstring's
deadline into something that fails a deploy.

### C4 — a 401 never clears the stored session, so the app replays a dead credential forever — CONFIRMED

`apps/mobile/lib/data/api/server_session.dart:101-118`

`Credentials.forgetServerSession()` has exactly one caller — the manual sign-out button
(`server_session.dart:101-107` ← `lib/features/signin/server_signin_controller.dart:50-55`).
A 401 from the main client does four things, none of them that: it drops the affected
cache rows and rethrows (`lib/data/api/cached_account_read.dart:46-51`), renders "Sign in
to your server to use this feature." (`lib/data/api/problem_message.dart:8`), suppresses
retry (`lib/data/api/provider_retry.dart:10-13`), and reports a push failure
(`lib/data/push/push_service.dart:312`). Meanwhile `signedIn` keeps returning true
(`server_session.dart:114-118`).

So a revoked, rotated or expired token leaves the app in the state
`server_session.dart:12-14`'s own docstring says the design exists to prevent: believing
it is signed in and serving 401s to every screen, while re-sending the dead credential on
every screen load and every background sync, with no prompt to re-authenticate. This is
the client half of C2 — it is why revocation, when it lands, will not visibly work.

**Recommend:** on a 401/403 from the main client, mark the session unverified (or clear
it) and route to sign-in. Marking rather than clearing is the gentler option and enough:
the owner is asked once instead of silently looping.

---

## D. The ingest path stores what it is given

`POST /ingest/helio` **is** authenticated — `IngestUser` resolves a device token to its
owner and 401s an unknown one (`api/routers/ingest.py:19`, `core/request_auth.py:115-134`),
and attribution is never guessed. The findings here are about what it accepts once
authenticated. They do not cross an owner boundary; they poison the owner's own numbers,
which is why they sit below section C rather than above it — but the product's premise is
that the numbers are honest, and a boundary that accepts a physically impossible value is
where the dishonesty is born.

The brief asked me to follow the `SampleIn.ts` thread. It goes further than the
timestamp.

### D1 — `SampleIn.value` accepts NaN, Infinity and 1e308 — CONFIRMED

`apps/server/src/healthee/ingest/models.py:40-47`

```python
class SampleIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    metric: str
    ts: int  # epoch milliseconds (seconds also tolerated downstream)
    value: float
```

Pydantic v2's `allow_inf_nan` defaults to `True`, and Python's `json` module accepts the
`NaN` / `Infinity` / `-Infinity` literals in a request body, so all three reach
`upsert_samples`, which casts and stores without inspecting the value
(`ingest/upsert.py:83`). From `sample` they flow into baselines, TRIMP, recovery, VO2max
and the coach's context, and a NaN serialises back out as invalid JSON.

**The codebase already knows the correct shape and applies it one directory over.**
`read/gps_request.py:11-35` is the model this one should be: `ConfigDict(allow_inf_nan=
False)`, `Field(max_length=28800)` on the point list, latitude/longitude range checks, and
a `model_validator` requiring monotonic timestamps inside the declared window. The GPS
upload — a *phone*-supplied payload — is bounded to the millimetre. The strap payload,
which is the product's primary data source, is not bounded at all. Prior art:
`SECURITY_REVIEW_FABLE.md` item 3; unchanged.

### D2 — every epoch integer is unbounded: out of range is a 500, in range is a row dated year 9999 — CONFIRMED

`apps/server/src/healthee/ingest/upsert.py:50-63`

```python
def epoch_to_utc(ts: int) -> datetime:
    seconds = ts / 1000 if ts > _MS_THRESHOLD else ts
    return datetime.fromtimestamp(seconds, tz=UTC)
```

The docstring is careful and correct about the ms/seconds ambiguity, and correct that a
birth date must not come through here. It says nothing about range, and there is no
range check. A value outside the platform's `datetime` range raises
`ValueError`/`OverflowError`/`OSError` out of an ingest handler with no
handler for it — a 500 that blames the server for a client's number, the same class of
lie `api/app.py:51-65` was written to fix for `dob`. A value *inside* the range but far
from now writes a `sample` row dated centuries away, which every window and baseline then
has to cope with.

`ProfileIn.dob` is the counter-example in the same file: it carries
`assert_plausible_dob` (`ingest/models.py:149-154`) precisely so an impossible value is a
422 naming the field. `SampleIn.ts`, `SleepIn.start_ts`/`end_ts` and
`WorkoutIn.start_ts` carry nothing.

### D3 — no list is capped, and `emit_sleep_minutes` materialises an attacker-chosen span one row per minute — CONFIRMED

`apps/server/src/healthee/ingest/models.py:162-166` — five lists, all
`Field(default_factory=list)`, none with `max_length`.

`apps/server/src/healthee/ingest/upsert.py:92-115` is the amplifier:

```python
for st in stages:
    start = epoch_to_utc(st[0]).replace(second=0, microsecond=0)
    end = epoch_to_utc(st[1])
    if end <= start:
        continue
    last = end - timedelta(seconds=60)
    cur.execute(
        "INSERT INTO sample (user_id, ts, metric, value) "
        "SELECT %s, g, 'sleep_stage', %s FROM generate_series(%s, %s, interval '1 minute') g "
        ...
```

`start` and `end` come from the payload with nothing between them and `generate_series`.
A single hypnogram stage declaring a span of years materialises tens of millions of rows
in one statement — one request, one owner's quota, unbounded disk and time. Combined with
`infra/nginx/healtheeapi.conf:39`'s `client_max_body_size 600M` (E2) the request side is
unbounded too.

Two smaller things in the same loop: `st[0]`/`st[1]`/`st[2]` are indexed with no length
check, so `stages: [[]]` is an `IndexError` → 500; and `stages` is typed
`list[list[int]]`, so the inner list's arity is never validated.

### D4 — `LogRequest` has none of `GpsTrackIn`'s bounds, and one of its fields is a weight — CONFIRMED

`apps/server/src/healthee/read/logs.py:25-36`

`amount: float | None` with no `allow_inf_nan=False` and no range; `notes: str | None`
with no `max_length`; `minutes: int | None` and `at: int | None` unbounded. Then
`:44` is `datetime.fromtimestamp(req.at / 1000, tz=UTC)` (same unbounded conversion as D2)
and `:60` is `ts - timedelta(minutes=mins)` (an `OverflowError` on a large `minutes`).

The sharp one is `:46-51`: `type: "weight"` writes `float(req.amount or 0)` into
`weight_log.kg`. Weight is an input to VO2max and biological age, and
`MEMORY`/`docs` record that a stale weight is already enough to *withhold* biological age.
A NaN or 1e308 weight is accepted by this endpoint today.

**Recommend for all of D1–D4, as one change:** give the ingest and manual-log models the
treatment `read/gps_request.py` already demonstrates — `ConfigDict(allow_inf_nan=False)`,
`Field(max_length=…)` on every list, per-metric physiological ranges dropped-and-counted
the way unknown metrics already are (`ingest/upsert.py:80-82` is the existing pattern), a
plausible-instant range on `epoch_to_utc` mirroring `assert_plausible_dob`, and a span cap
on a hypnogram stage. `tests/test_ingest_models.py` currently has five tests and none of
them is a bounds test, so the tests come with it.

---

## E. Unbounded and exposed

### E1 — `/docs`, `/redoc` and `/openapi.json` are public, and the route-completeness test excludes them by name — CONFIRMED

`apps/server/src/healthee/api/app.py:88`

```python
app = FastAPI(title="Healthee", version="0.1.0", lifespan=lifespan)
```

No `docs_url=None`, `redoc_url=None`, `openapi_url=None`, and nginx proxies `/`
wholesale (`infra/nginx/healtheeapi.conf:45`), so a full machine-readable map of a
health API — every route, every parameter, every model — is served to anybody. Prior art:
`SECURITY_REVIEW_FABLE.md`; unchanged.

What is new, and is the reason this is a finding rather than a repeat: **the guard that is
supposed to notice an open route cannot see these three.**
`tests/premium/test_ai_gate.py:146-149`:

```python
def _api_routes() -> list[APIRoute]:
    """Every mounted route of ours — FastAPI's own /docs, /openapi.json etc. excluded."""
    generated = {"/openapi.json", "/docs", "/docs/oauth2-redirect", "/redoc"}
    return [r for r in _flatten(create_app().routes) if r.path not in generated]
```

The exclusion is reasonable for a *paywall* completeness check — a docs page is not AI
output. But it means the only route-walking test in the repo has a hard-coded blind spot
at exactly the four routes that are open by default and were never argued for. There are
44 routes of ours plus these four; the test reasons about 44.

**Recommend:** `docs_url=None, redoc_url=None, openapi_url=None` in `create_app()`, and
delete the `generated` set from the test — with the routes gone, the exclusion becomes
unnecessary and the blind spot closes with it.

### E2 — `client_max_body_size 600M`, for a reason that no longer exists — CONFIRMED

`infra/nginx/healtheeapi.conf:38-39`

```
# Multipart uploads (Gadgetbridge .db) can be large once history builds up.
client_max_body_size 600M;
```

The stated reason is a Gadgetbridge database upload. **This application has no multipart
upload route** — the 44-route enumeration (section G, sweep 1) contains no
`UploadFile`, no multipart handler, and a grep for `UploadFile`/`multipart` across
`apps/server/src/` returns nothing. The limit is a legacy carry-over from the previous
implementation, and it currently applies to `/ingest/helio` (D3's amplifier) and
`/api/coach` (E4) equally.

**Recommend:** drop it to a few MB. If a large-upload path is ever added, scope the large
limit to that `location` rather than to `/`.

### E3 — nothing rate-limits at the edge, and only two surfaces rate-limit in the app — CONFIRMED

`infra/nginx/healtheeapi.conf` contains no `limit_req`, no `limit_conn`, no security
headers (`Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options`), and
the tracked vhost is the plain `:80` file — TLS is added by certbot in place on the box
and is therefore not reviewable from the repository.

In the app, `core/rate_limit.py` exists and is correct (one statement, per-owner, per
local day, self-resetting, no unbounded key growth), but it has exactly two callers:
`challenges/budget.py:87` (3 generations per owner per day) and
`api/routers/daily_action.py:125` (3 reveal attempts per day). Nothing else — no read
route, no ingest, nothing unauthenticated.

**What an unauthenticated caller can reach is small and worth stating precisely:**
`/healthz` and `/readyz` only. Both run a `SELECT 1` on the pooled connection
(`api/routers/health.py:44-51`), so the exposure is pool exhaustion at
`_POOL_MAX_SIZE = 10` (`core/db.py:79`), not data. `/readyz` additionally reads
`insights.credits`, which is TTL-cached and cannot amplify into outbound calls
(`insights/credits.py:120-145`), and reports states rather than dollar figures with
error strings built from exception type names and status codes only
(`credits.py:147-163`, `:166-181`) — that is genuinely careful and is swept clean in
section G.

### E4 — `refresh=true` is unmetered for a premium owner on five LLM surfaces — CONFIRMED

`apps/server/src/healthee/api/routers/insights.py:29, 35, 41, 50, 56`

Every insight route takes `refresh: bool = False` and forwards it;
`insights/surfaces.py:62-65` and `:113`, `:159` skip the cache when it is true, which
forces a fresh generation. The gate above them is `InsightUser` / `NotableUser`, and
`api/gate.py:132` is:

```python
PREMIUM_ALLOWANCE: dict[str, int] = {COACH: PREMIUM_COACH_QUESTIONS}
```

By that table's stated semantics — documented at `gate.py:126-130`, "a feature ABSENT
from this table is UNLIMITED" — `INSIGHT` and `NOTABLE` are uncapped for a paying owner,
and `core/rate_limit.py` is not applied to these routes. A premium owner (or anything
holding their credential) polling `?refresh=true` spends the OpenRouter budget in a loop.

The coach itself is **not** in this state any more, and that is a genuine improvement over
the prior review: `POST /api/coach` charges the premium ledger per turn
(`gate.py:243-262`) at 20 per rolling 30 days, and refunds a turn that delivered nothing
(`api/routers/coach.py:61-71`). The gap is the cards, not the conversation.

Adjacent, same route: `CoachRequest.messages` (`api/routers/coach.py:52-58`) caps neither
the list nor each `content` string. `insights/coach.py:368-375` bounds the history to the
last 12 well-formed turns, so the turn *count* is bounded and the per-turn *size* is not —
bounded in practice only by E2's 600 MB.

**Recommend:** either give `INSIGHT` and `NOTABLE` explicit `PREMIUM_ALLOWANCE` entries,
or apply `rate_limit.spend` to `refresh=true` specifically (a refresh is the only thing on
these routes that costs money — a cached read should stay free). And `max_length` on
`CoachMessage.content`.

---

## F. Hygiene and drift

Each of these is a document, a comment or a guard that claims slightly more than it
delivers. None of them is exploitable. They are here because this repository's own
standard is that a comment claiming a guard is not a guard, and because the brief was
explicit that a prior audit was misled by exactly this.

### F1 — `admin_connection`'s "complete list" of callers is not complete — CONFIRMED

`apps/server/src/healthee/core/db.py:239-251` opens *"### Who may call this, and why — the
complete list"* and names four: `db/migrate.py`, `db/provision_app_role.py`,
`db/claim_sentinel.py`, `tests/contracts/seed.py::reset`.

There is a fifth: `db/grant_premium.py:161`. It is a legitimate caller — the app role
holds `SELECT` and nothing else on `subscription` by design
(`db/provision_app_role.py:95-103`), so the grant tool *must* be on the admin — but a list
that says "complete" and is not is precisely the artefact a future reader will trust
instead of grepping.

**Recommend:** add the fifth entry with its one-line reason, which is already written in
`provision_app_role.py:102`.

### F2 — the AST scoping guard accepts `user_id` appearing anywhere in the statement — CONFIRMED, no live instance

`apps/server/tests/db/test_tenant_read_scoping.py:117-123`

```python
for stmt in _sql_statements(source):
    if "user_id" in stmt:
        continue
```

A substring test. `SELECT user_id, value FROM sample WHERE metric = %s` — `user_id` as a
projected column, no predicate — passes the guard while being completely unscoped.
`test_the_guard_actually_detects_an_unscoped_statement` (`:126-134`) plants a statement
with no `user_id` at all, so the planted violation does not exercise this shape.

**No such statement exists today** — I ran a stricter scanner (same AST parsing, same
statement splitting, but requiring `user_id` in a predicate or an INSERT column list) over
all 227 tenant-table statements and it found zero. So this is a guard that is weaker than
its own claim, not a live hole; RLS is the backstop underneath it either way (B1).

**Recommend:** tighten the predicate to `re.search(r"\buser_id\s*(=|\sIN\b)", stmt)` and
add the projection-only shape as a second planted violation, so the guard's own test
covers the case it currently cannot see.

### F3 — `_sentinel_user()` authenticates a nonexistent owner rather than refusing — CONFIRMED

`apps/server/src/healthee/core/request_auth.py:94-101`

```python
tz = _timezone_of(SENTINEL_USER_ID)
if tz is None:
    log.warning("sentinel app_user row is missing — falling back to the compiled-in timezone %s", ...)
    tz = SENTINEL_TZ
return RequestUser(id=SENTINEL_USER_ID, timezone=tz)
```

The docstring calls a missing sentinel row "an anomaly worth logging" — and then proceeds
to authorise the request as an owner who does not exist. This is not hypothetical: it is
the **documented post-condition of `claim_sentinel`**, which re-keys the sentinel row to
the owner's real Supabase UUID (`db/claim_sentinel.py:29-30, 208-211`), after which
`SENTINEL_USER_ID` has no `app_user` row by design.

The consequence is fail-closed-ish rather than dangerous — every tenant read returns zero
rows under RLS, and every tenant write violates the `user_id` FK — but the failure modes
are "the app shows you an empty life" and "a 500 from an FK violation", neither of which
reads as "your credential is no longer valid". Contrast `ingest_user` fifteen lines below
(`:128-133`), which hits the same condition and correctly raises 401 with the reasoning
written out.

**Recommend:** make `_sentinel_user()` raise `unauthorized("Invalid token")` when the row
is absent, matching `ingest_user`. The legacy branch should die with the sentinel row, not
outlive it.

### F4 — `MULTI_USER.md` 4.5 says data export "is already free"; there is no export — CONFIRMED

`docs/MULTI_USER.md:462`. Covered under C1; recorded separately because it is a
standing claim in the plan-of-record document rather than a consequence of the missing
webhook.

### F5 — `DeviceTokenResponse.id` is the owner's id, not the token's — CONFIRMED

`apps/server/src/healthee/api/routers/auth.py:41-58`

```python
class DeviceTokenResponse(BaseModel):
    """A freshly minted device ingest token — returned exactly once."""
    device_token: str
    id: UUID
...
    return DeviceTokenResponse(device_token=raw, id=user.id)
```

`mint_device_token` (`core/supabase_auth.py:196-207`) does not return the row's id, and
`device_token.id` is a `gen_random_uuid()` primary key the caller never learns. So the
field named `id` on a "device token" response is the *user* id. It is not wrong data, but
it is the wrong subject, and it is why C2's revocation endpoint has nothing to address a
token by.

**Recommend:** `RETURNING id` from the insert and return the token's id, which makes C2's
`DELETE /api/device/{id}` possible without a schema change.

### F6 — the client's error path is safe only against the pinned dio, and the pin is a caret — SUSPECTED

`apps/mobile/lib/data/api/interceptors.dart:96-102` hands a raw `DioException` to the
logger. Against `dio 5.11.0` that is safe: `DioException.toString()` emits `type`,
`message` and `error` only (`dio-5.11.0/lib/src/dio_exception.dart:261-268, 321-331`) and
no factory message quotes the URI or headers (`:88-208`). `apps/mobile/pubspec.yaml:51` is
`dio: ^5.11.0` — a caret range, so a future minor could change that message format without
a code change here.

Marked SUSPECTED because it is a property of a dependency's future, not of code that is
wrong today. It is listed because `apps/mobile/test/signin/signin_secrecy_test.dart:170-221`
already drives the real interceptor stack with `AppLog.sink` capturing, including a
401-that-echoes-the-token case — meaning the guard against this **already exists and is
executed**. The note is that the guard is the test, not the pin, and the test is what must
survive a dependency bump.

---

## G. Swept clean — what was checked, and the evidence

Eleven classes checked with no finding raised. Each names how it was established, because
"we looked" is not evidence.

**1 — Every route is authenticated or deliberately public. CLEAR, measured.**
Not read off the routers: enumerated from the live application object, walking each route's
full dependency tree and testing for `request_user` / `ingest_user` / `current_user`. **44
routes. Exactly two resolve no identity: `GET /healthz` and `GET /readyz`.** Both are
deliberately public (`api/routers/health.py:1`, `api/routers/readiness.py:30-34`), and
`/readyz`'s docstring explicitly reasons about being unauthenticated and reports states
rather than amounts. Every other route — including both map-tile routes, `/ingest/helio`,
and every write endpoint — resolves an identity. Twenty of the 44 additionally carry an
`AIGate`.

**2 — `tenant_transaction` is the only path to owner data. CLEAR, confirmed.**
There are eight `with transaction()` sites in the entire server, in five files, and every
one of them touches only an identity table or `SELECT 1`: `api/routers/health.py:45-46`
(`SELECT 1`), `core/supabase_auth.py:168-180` and `:202-226` (`app_user`, `device_token`),
`core/tenancy.py:132-133` (`app_user`, the scheduler sweep), `core/request_auth.py:66-67`
(`app_user`). Nothing else opens a connection: `psycopg.connect` appears once
(`core/db.py:257`, inside `admin_connection`) and `ConnectionPool(` once
(`core/db.py:133`). `admin_connection` has five callers, all ops/DDL modules (F1).
`tenant_connection` has two, both documented multi-cursor units of work
(`ingest/service.py:182`, `db/rederive.py:241`).

**3 — Every tenant query binds its owner. CLEAR, measured with a stricter check than the
repo's own.** I ran an AST scan over `apps/server/src/healthee/` requiring `user_id` in a
*predicate* (`= `, `IN`, `::`) or an INSERT column list — not merely present as a
substring, which is what `test_tenant_read_scoping.py` checks (F2). **227 tenant-table
statements scanned, 0 offenders.**

**4 — Identity can never be supplied by the client. CLEAR, confirmed.** No route takes a
`user_id` from a path parameter, a query parameter or a body. The only `user_id` in any
router signature is `_update_adoption(user_id: UUID, …)`
(`api/routers/recommendations.py:66`), an internal helper called with `user.id`. The one
`user_id` field on a wire model is `AccountIdentity` (`api/routers/history.py:24`), a
*response*. Cross-tenant access returns 404 rather than 403 (`api/routers/gps.py:33-40`),
so there is no enumeration oracle.

**5 — No token, JWT or secret can reach a server log. CLEAR, confirmed.** Every logging
call site mentioning a credential-shaped word was read: `core/request_auth.py:132` logs a
UUID, `core/supabase_auth.py:99` logs `type(exc).__name__` only, `:146` logs the email and
UUID of a refused signup (non-secret, and the point of an invite gate),
`db/provision_app_role.py:365` names the role and explicitly not the password. Every
`HTTPException` detail on the auth path is a static string
(`core/supabase_auth.py:53-66`). `httpx` is pinned to `WARNING` unconditionally
(`core/logging.py:43`) with the Telegram-token-in-URL reason written out, and
`uvicorn.access` is filtered for the tile prefix (`core/logging.py:58-76`,
`api/app.py:77`) because there the path itself is the secret. No token ever appears in a
URL or query string on either side (client: `interceptors.dart:49` and
`server_probe.dart:92` are the only two credential sites, both headers).

**6 — RLS policies exist on every tenant table, and the provisioned role cannot bypass
them. CLEAR, confirmed.** 16 policies in `db/migrations/0008_row_level_security.sql`,
plus `subscription` (`0011:62-64`) and `device_daily_total` (`0017:79-81`) policied in
their own migrations — 18, matching `schema.sql:487-491`. All of the exact
`FOR ALL` + `WITH CHECK` + `NULLIF(current_setting(…), '')` shape, and 0008's header
records that each part was probed against a real hypertable and a real
`NOSUPERUSER NOBYPASSRLS` role before being written. `db/provision_app_role.py:120`
spells out `NOSUPERUSER NOBYPASSRLS` rather than relying on defaults, `:306-328`
post-checks it against `pg_roles` inside the provisioning transaction, and
`_READ_ONLY_TABLES` + an explicit `REVOKE` (`:95-114`) make "a request path cannot mint
entitlement" a privilege rather than a promise. The caveat is B1: all of this is about the
role that *can* be provisioned, not the one the deployment *is* using.

**7 — The RLS test suite is real and cannot pass vacuously. CLEAR, I opened it.**
`tests/db/test_rls.py` asserts what a *wrong or absent* owner sees, not what the right one
sees: an unfiltered `SELECT` returns one row (`:110-129`, both directions), an unfiltered
aggregate is owner-scoped (`:132-143`), an unset and an empty GUC both return nothing
without erroring (`:149-180`), the owner does not outlive its transaction (`:183-197`),
cross-owner INSERT/UPDATE/DELETE are denied (`:203-276`), and the correct upsert still
works (`:237-251`) — without which every other assertion would pass against a policy that
simply denied everything. The completeness check drives off the database catalog
(`:287-313`), not a hand-copied list. And `test_the_app_pool_is_never_privileged`
(`:83-104`) asserts the premise from `pg_roles`, which is what stops the whole file
becoming decoration.

**8 — The paywall route-completeness test is real, recursive, and every allowlist entry
carries a reason. CLEAR, I opened it and reproduced it.**
`tests/premium/test_ai_gate.py:124-143`'s `_flatten` recurses into `original_router`, and
`:152-161` asserts the walk is non-empty before any absence-based assertion runs — the file
documents that walking only the top level once found four routes and made every
completeness claim vacuous. I re-ran the walk independently and got 44 routes, matching.
All 22 `FREE_PATHS` entries (`:83-109`) carry a stated reason, and
`test_the_free_allowlist_has_no_stale_entries` (`:186-190`) closes the reverse direction.
The one structural gap is E1's `generated` exclusion.

**9 — The map-tile FREE_PATHS reasoning holds. CLEAR, confirmed.** The brief asked
specifically. Both entries landed in commit `2f0f487` ("the basemap routes are free, and
say why"), directly after the router. `FREE_PATHS` is the **paywall** allowlist, not an
authentication allowlist, and both routes take `CurrentUser`
(`api/routers/map_tiles.py:42, 61`) — they are authenticated. The stated reason — a
proxied public map tile is context, never owner data or AI output, and paywalling it would
leave a free owner's track drawn on nothing — is correct: the bytes are OpenStreetMap's.
The part of a tile request that *is* personal is the path, and that is handled separately
and in two places (`infra/nginx/healtheeapi.conf:68-77` and
`core/logging.py:58-76` via `api/app.py:77`). Open-relay abuse is refused before any
upstream call (`core/map_tiles.py:87-98` bounds z against the configured range and x/y
against `2^z`), and `MAP_TILE_URL` is validated to http(s)-with-placeholders at config
time (`core/config.py:299-319`), with `file:///etc/passwd` named as the reason.

**10 — The JWT verification is correct and its negatives are asserted. CLEAR, confirmed.**
`algorithms=["HS256"]` pinned (`core/supabase_auth.py:41, 92`), `exp` and `sub` required,
`aud` checked, `iss` checked when the project ref is set, and a blank secret rejects
everything rather than accepting anything (`:86-87`).
`tests/test_supabase_auth.py:67-121` asserts expired / bad-signature / wrong-aud /
missing-aud / `alg=none` / wrong-iss / unconfigured-secret, and
`tests/test_request_auth.py:120-138` asserts with a spy that a rejected JWT never reaches
the sentinel branch — the negative, not just the 401. The signup gate is enforced on the
server (`core/supabase_auth.py:118-147`) with a refused signup writing nothing, and
`tests/test_signup_gate.py` covers the no-email, empty-allowlist and case-folding cases.

**11 — The client's token storage and secrecy discipline. CLEAR, confirmed.** One
credential, one key, in the platform keystore via `flutter_secure_storage`
(`apps/mobile/lib/data/api/credentials.dart:167-179`, `secret_store.dart:31-46`); never
`SharedPreferences` (used only for theme), never a plain file, and the drift cache is keyed
on 18 random bytes rather than on the token
(`apps/mobile/lib/data/api/stored_server_session.dart:17-26`). No `print`/`debugPrint`
anywhere in `lib/`; `AppLog.sink` is `@visibleForTesting` and assigned nowhere in `lib/`
(`apps/mobile/lib/core/logging.dart:58`); `toString()` on the session is
`'StoredServerSession(redacted)'` (`stored_server_session.dart:68`); a `FormatException`
from decoding the stored blob is rethrown as a constant because the malformed input *is*
the secret (`:31-36`). No crash reporter, no analytics SDK, no file logging in
`pubspec.yaml`. The basemap client is explicitly given no session
(`apps/mobile/lib/data/map/basemap_source.dart:82-87`). A full scan for committed secrets
across `apps/mobile` found none — the only matches are labelled test sentinels in
`apps/mobile/test/pairing/pairing_secrecy_test.dart:28-33`, whose whole purpose is to be
strings that appear nowhere else so a match proves a leak. Both `.env.example` files carry
placeholders only, and CI runs gitleaks over full history
(`.github/workflows/ci.yml:174-183`). The gaps found are A1 and C4, and they are about
where the token *goes*, not how it is kept.

---

## H. Could not determine

Three things, each with the reason.

1. **Whether the live deployment sets `POSTGRES_APP_*`, i.e. whether RLS is actually in
   force in production.** This is the single most consequential open question in the
   audit (B1) and it is a production fact. The brief forbids touching the production
   server or database, and correctly so. It is settled by one command an operator runs:
   `SELECT current_user, rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user`
   on the app pool's connection — the same query `core/db.py:102-104` already runs at pool
   open, so the answer is also in the first lines of the API container's log after any
   restart, as either "db pool connected as least-privilege role" or the `SECURITY:`
   warning.

2. **Whether `claim_sentinel` has been run in production, which decides whether F3's path
   is live or dormant.** Same reason. If the sentinel `app_user` row is gone, every
   legacy-shared-token request is currently authenticating as a nonexistent owner.

3. **Whether the deployed TLS configuration carries HSTS or any security header.** The
   tracked vhost (`infra/nginx/healtheeapi.conf`) is the plain `:80` file; certbot rewrites
   it in place on the box (`:10-11`), so the `:443` server block that actually serves
   traffic exists only there and is not in the repository. This is a repository-shape
   problem as much as a security one — the file under review is not the file in force.

---

## Suggested order

Ranked by the audit's own criterion — how close each is to owner data leaving its owner —
not by effort.

1. **A1**, `followRedirects: false` on `api_client.dart:29`. It is one line and it is the
   only credential-egress path found.
2. **B1** boot refusal (with an explicit opt-out so the bootstrap stays bootable) and the
   `.env.example` defaults, plus the operator check in H1 to learn the current state.
3. **B2** (`status` on the request path) and **C3** (the `signups_open` tripwire) — both
   are small validators, and both are hard blockers before a second owner exists.
4. **D1–D4** as one change, modelled on `read/gps_request.py`, with **E2**'s nginx limit
   dropped alongside D3.
5. **C1** deletion, as an admin-run dry-run-by-default tool first; **C2**/**F5**/**C4**
   revocation as one thread, since revocation without listing and without a client that
   notices is three-quarters of a feature.
6. **E1**, **E3**, **E4**, then the F items.

The honest caveat is the one `AUDIT_COVERAGE.md` already states: this means the auth,
tenancy and RLS surface has now been *examined* against the standard. It does not mean no
defect remains — three of the sharpest findings in the earlier audits came from agents
correcting earlier readings, and F2 is an example of a guard in this very area that was
weaker than it read.
