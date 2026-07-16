-- 0002_identity — Phase 6.1 identity mirror (multi-user / GA groundwork).
--
-- ADDITIVE + non-breaking: introduces the tenant identity tables only. Nothing
-- existing reads them yet — the `user_id` column on the data tables (6.2) and the
-- query threading (6.3) are separate migrations/PRs. All DDL is idempotent
-- (IF NOT EXISTS) so a partial prior run is safe to replay (MULTI_USER.md §3.1).
--
-- Supabase owns credentials/sessions/refresh; `app_user` is a thin local mirror
-- keyed by the Supabase auth.users.id (the `sub` UUID). No passwords are stored
-- here. Rows are JIT-provisioned on the first authenticated request (§4.4).

CREATE EXTENSION IF NOT EXISTS citext;  -- case-insensitive email column

-- ── app_user ───────────────────────────────────────────────────────────────
-- Local mirror of the Supabase user; the tenant key everywhere is this UUID.
CREATE TABLE IF NOT EXISTS app_user (
  id          UUID         PRIMARY KEY,               -- = Supabase auth.users.id (sub)
  email       CITEXT,                                 -- mirrored for convenience/joins
  status      TEXT         NOT NULL DEFAULT 'active',
  timezone    TEXT         NOT NULL DEFAULT 'UTC',    -- IANA name, per-user
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ── device_token ───────────────────────────────────────────────────────────
-- Per-strap/app long-lived INGEST credential (Supabase access tokens are too
-- short-lived for background BLE sync). Only the SHA-256 hash is stored; the raw
-- token is returned once at mint time and never persisted (§4.3).
CREATE TABLE IF NOT EXISTS device_token (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID         NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  token_hash  TEXT         NOT NULL,                  -- SHA-256 hex of the raw token
  label       TEXT,                                   -- "Ashish's Helio strap"
  last_seen   TIMESTAMPTZ,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS device_token_hash_idx ON device_token (token_hash);
