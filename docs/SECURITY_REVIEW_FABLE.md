All five reviews are complete. Here's the consolidated, no-spin security assessment of the backend.

Healthee backend — security review

I ran five parallel deep-dives (auth/identity, tenant isolation & DB, API surface & validation, the LLM coach layer, and secrets/logging/infra), each reading the actual code and confirming behavior by execution where it mattered. Bottom line first, then the findings, then what's genuinely well built.

The one-sentence verdict

The isolation architecture is unusually well-designed and well-tested — but two things undercut it right now: prod runs the database as a superuser (so the RLS backstop is inert), and the ingest path accepts physically impossible numbers with no bounds. Neither needs an attacker to hurt you, and one privacy leak (the Telegram briefing) fires automatically the moment a second user exists.

The good news: there is no SQL injection, no cross-tenant identity override, no plaintext-token storage, and no stack-trace leakage. The design intent is honest and mostly enforced in code. The gaps are concentrated in (a) operational deploy state, (b) input bounds, and (c) abuse/cost controls that were always planned but not yet built.

Must-fix before a second user exists

These are the ones where "multi-user" turns a latent issue into a live breach:

1. The morning briefing broadcasts every user's health data to one global Telegram chat. jobs/briefing.py:54 → core/notify.py:34. The scheduler is already per-user, but send_telegram always posts to the single TELEGRAM_CHAT_ID. The day owner #2 is provisioned, their recovery/HRV/sleep/weight lands daily in the operator's private chat. This is a privacy breach by construction, not a bug. Fix: per-tenant chat id, or gate the send to the sentinel user until per-user channels exist.

2. Prod runs the app as a Postgres superuser, so RLS protects nothing. core/config.py:198 (blank POSTGRES_APP_* falls back to admin creds) + core/db.py:89. The code does warn loudly at startup, and this is already tracked as "DEPLOY #2 PENDING" — but until you set POSTGRES_APP_USER/POSTGRES_APP_PASSWORD and redeploy, all of the excellent RLS work from migration 0008 is decoration, and isolation rests solely on the explicit WHERE user_id = %s filters. Recommend making it a hard boot refusal (not just a log line) once signups are near.

3. Health samples accept NaN, Infinity, and 1e308 with zero bounds. ingest/models.py:47 — verified by execution: value: float takes all three. These flow straight into baselines, VO2max, TRIMP, recovery, and the coach's context, and NaN serializes back to the mobile app as invalid JSON. One malformed device push permanently poisons the "honest numbers" the whole product is built on. Fix: Field(allow_inf_nan=False) on every float, plus per-metric physiological ranges (HR 20–260, SpO₂ 50–100, etc.), dropping out-of-range samples the same way unknown metrics are already dropped.

4. Unbounded ingest payloads behind a 600 MB body limit. ingest/models.py:139 (no list caps) + infra/nginx/healtheeapi.conf:39 (client_max_body_size 600M). Worse, emit_sleep_minutes runs a generate_series insert per hypnogram stage from attacker-chosen start/end, so a single session spanning "years" materializes millions of rows in one statement. Trivial single-request memory/disk exhaustion. Fix: cap list lengths, drop the nginx limit to a few MB (scope 600M only to the Gadgetbridge upload path if that's why it's there), and bound the hypnogram span.

High-value, not blocking

- The legacy shared token is a whole-tenant skeleton key shipped inside the mobile APK. core/request_auth.py:72. The crypto is done right (constant-time compare, fail-closed, no JWT fall-through), but it's one static, never-expiring string that grants full read/write of the sentinel's entire history, extractable from any copy of the app. The removal condition ("MUST NOT survive into public signups") is prose, not enforcement. Fix: add a model_validator that refuses signups_open=true while the token is set — turn the docstring's deadline into a tripwire.
- User suspension is a no-op for API access. core/supabase_auth.py:168, core/request_auth.py:64. The app_user.status column exists and the nightly job honors it, but the request auth path never reads it. Setting status='suspended' stops the LLM chain but leaves full /api/* and /ingest access intact. The only real kill switch is row deletion (destroys data). Fix: SELECT timezone, status and reject non-active in both auth branches.
- Device tokens have no revocation, expiry, or listing. db/migrations/0002 + supabase_auth.py:196. A stolen phone's token grants ingest-write forever, with no user- or operator-facing way to kill it, and sessions can mint unlimited ones. Fix: add revoked_at, filter it on resolve, and add list/delete endpoints scoped to the user.
- No rate limit or spend cap on any LLM endpoint (the known #48 gap, confirmed open). Every insight endpoint takes refresh=true which bypasses the cache and forces fresh generation; /api/coach runs up to 5 rounds of the priciest model with unbounded per-message content. Any authenticated free-tier user can drain your OpenRouter budget in a loop. This must land before signups.
- The output guard is regex-based and bypassable three ways — all verified by execution: a plain ASCII hyphen defeats the negation window ("You should not stop - push through the chest pain" passes), death-risk claims split across two sentences pass, and spelled-out numbers ("twenty-two percent higher risk of dying") pass. No attacker needed — a verbose model paraphrasing a mortality note emits these naturally, shipping exactly the forbidden projection the product documents against. Fix: add -‐‑ to the exclusion class, run the death-risk rules over a sliding window, and add number-word patterns. The three strings are ready-made regression tests.
- Backups are unencrypted, world-readable, and effectively on-box only. infra/backup/pg_dump_backup.sh:33 — no umask/chmod, gzip-only, OFFBOX_CMD unset. A complete longitudinal health record readable by any local user; VPS loss = plaintext exposure. Fix: umask 077, encrypt with age/gpg before writing, wire a real offsite target.
- nginx has no HSTS, no security headers, and no rate limiting, and the tracked vhost is HTTP-only (TLS lives only on the box, unreviewable). infra/nginx/healtheeapi.conf.
- /docs, /redoc, /openapi.json are exposed unauthenticated in prod (api/app.py:53) — a full recon map of a health API. One-line fix: docs_url=None, redoc_url=None, openapi_url=None.

Medium / hardening

Prompt injection via unvalidated label param and raw manual_entry.notes in every prompt (bounded by the strong deterministic grounding layer, but the label vector is real — insights/surfaces.py:111); forged assistant turns trusted into coach history (coach.py:212); containers run as root with floating :latest image tags and no resource limits; SUPABASE_PROJECT_REF blank silently skips the JWT issuer check with no startup signal; the app role holds DELETE/UPDATE on app_user (a one-statement mass-cascade-delete / tenant-takeover primitive — provision_app_role.py:66); ingest 500s on out-of-range timestamps; secrets sourced into every child process in deploy/backup scripts; dev DB published on 0.0.0.0 with a known password; SUPABASE_JWT_SECRET is a symmetric HS256 key (the server holds a token-minting secret).

What's genuinely well built (not flattery — specifics)

- Tenant isolation is defense-in-depth and proven by tests that try to defeat it. Explicit WHERE user_id = %s on every tenant query plus RLS underneath, and the RLS suite removes the filter and asserts one row, not two. There's an AST completeness guard that parses SQL and fails the build on any tenant-table statement missing user_id — and it's mutation-tested. Two-sided leakage tests at both service and HTTP layers assert A-sees-A and B-sees-B. The test pool runs as a real NOSUPERUSER role, so RLS is actually exercised.
- No SQL injection anywhere — ~165 execute sites, every user-derived value is a bind parameter; the only interpolations are module constants or allowlist-validated; identifiers use sql.Identifier.
- Identity can never be client-overridden — every one of the 13 routers derives the tenant solely from the token, never from a path/body field. Cross-tenant access returns 404, not 403 (no enumeration oracle).
- JWT handling is correct and tested — algorithm pinned to HS256 (rejects alg=none and RS→HS confusion), exp/sub required, aud checked, fails closed on missing secret, constant-time legacy-token compare with no fall-through — and the tests assert the negative (a bad JWT never reaches sentinel resolution).
- The LLM layer's tenant safety is right — tool execution takes user_id from the authenticated request, never from model output; tools reach no arbitrary SQL, filesystem, or network; cache keys are (user_id, key); citation validation is blocking, not advisory, so fabricated note IDs can't ship; the refusal pre-classifier runs before any LLM call, so it can't be jailbroken past.
- Secret-in-logs discipline — the Telegram-token httpx leak is genuinely fixed (httpx logger pinned to WARNING unconditionally), no tokens/JWTs logged, device tokens stored SHA-256-only, conninfo never logged with password. CI runs gitleaks over full history; no committed secrets found.
- Config fails closed where it matters — blank DB password refuses startup, half-set app creds refuse, blank JWT secret rejects all tokens.

Suggested order of work

1. Per-tenant Telegram briefing (#1) + set POSTGRES_APP_* and redeploy (#2) — both are hard blockers before user #2.
2. Ingest bounds: allow_inf_nan=False + physiological ranges + list caps + nginx body limit (#3, #4).
3. LLM rate/spend gate (#48) + the three output-guard regex fixes — before signups open.
4. Legacy-token tripwire, status enforcement, device-token revocation, disable /docs, backup encryption.