-- 0004_tenant_keys — Phase 6.3a: fold user_id into every natural tenant key.
--
-- 0003 added the `user_id` column additively and changed NOTHING about the keys,
-- so two users could not yet hold the same (metric, ts) / (day, metric) / (start_ts)
-- row: the OLD single-tenant uniqueness was still global. This migration rebuilds
-- each natural key with `user_id` prepended, which is what actually makes the data
-- multi-tenant — and it lands together with the code change that retargets every
-- `ON CONFLICT` to the new key (MULTI_USER.md §8: the two cannot be split without
-- breaking every upsert, because a conflict target must match a real constraint).
--
-- Scope note: only NATURAL-key tables are folded. `manual_entry` / `gps_track` /
-- `challenge` / `program` / `challenge_outcome` keep their surrogate PKs (their
-- 0003 user_id column + index suffice), and `profile` keeps `id = 1` — its re-key
-- by user_id is 6.3c.
--
-- Dependent-FK safety (verified against the local DB before writing): none of the
-- keys rebuilt below is referenced by any foreign key. The only FKs in the schema
-- are 0003's `user_id -> app_user(id)` and `gps_point.track_id -> gps_track.id` /
-- `challenge_outcome.challenge_id -> challenge.id`, which reference SURROGATE keys
-- this migration does not touch. So the DROP/ADD cycles have no cascade fallout.
--
-- Replay-safety: every constraint is dropped by name with IF EXISTS before being
-- (re-)added, so a partially-applied file is safe to re-run. Plain statements only
-- (no DO blocks) — the runner splits on ';' and psycopg3 executes one at a time.

-- ── sample (hypertable) ─────────────────────────────────────────────────────
-- PROBED before writing: dropping and re-adding the PRIMARY KEY on the TimescaleDB
-- hypertable SUCCEEDS (no unique-index fallback needed). Timescale only requires
-- that the partition column `ts` be part of any unique key — (user_id, metric, ts)
-- keeps it, so the constraint is accepted and applied to every chunk.
ALTER TABLE sample DROP CONSTRAINT IF EXISTS sample_pkey;
ALTER TABLE sample ADD CONSTRAINT sample_pkey PRIMARY KEY (user_id, metric, ts);

-- ── sleep_session ───────────────────────────────────────────────────────────
ALTER TABLE sleep_session DROP CONSTRAINT IF EXISTS sleep_session_pkey;
ALTER TABLE sleep_session ADD CONSTRAINT sleep_session_pkey PRIMARY KEY (user_id, start_ts);

-- ── workout ─────────────────────────────────────────────────────────────────
ALTER TABLE workout DROP CONSTRAINT IF EXISTS workout_pkey;
ALTER TABLE workout ADD CONSTRAINT workout_pkey PRIMARY KEY (user_id, start_ts);

-- ── derived_daily ───────────────────────────────────────────────────────────
ALTER TABLE derived_daily DROP CONSTRAINT IF EXISTS derived_daily_pkey;
ALTER TABLE derived_daily ADD CONSTRAINT derived_daily_pkey PRIMARY KEY (user_id, day, metric);

-- ── weight_log ──────────────────────────────────────────────────────────────
ALTER TABLE weight_log DROP CONSTRAINT IF EXISTS weight_log_pkey;
ALTER TABLE weight_log ADD CONSTRAINT weight_log_pkey PRIMARY KEY (user_id, ts);

-- ── kv ──────────────────────────────────────────────────────────────────────
-- Per-user job markers / cached LLM text. The cache KEY itself stays un-namespaced
-- here (that is 6.3c) — the tenant separation is the key fold.
ALTER TABLE kv DROP CONSTRAINT IF EXISTS kv_pkey;
ALTER TABLE kv ADD CONSTRAINT kv_pkey PRIMARY KEY (user_id, key);

-- ── illness_flag ────────────────────────────────────────────────────────────
ALTER TABLE illness_flag DROP CONSTRAINT IF EXISTS illness_flag_pkey;
ALTER TABLE illness_flag ADD CONSTRAINT illness_flag_pkey PRIMARY KEY (user_id, date);

-- ── gps_point ───────────────────────────────────────────────────────────────
-- track_id already scopes a point to one track (and so to one owner), but the
-- explicit user_id in the key lets RLS gate the table in 6.5 without a join.
ALTER TABLE gps_point DROP CONSTRAINT IF EXISTS gps_point_pkey;
ALTER TABLE gps_point ADD CONSTRAINT gps_point_pkey PRIMARY KEY (user_id, track_id, ts);

-- ── recommendation (UNIQUE fold; BIGSERIAL PK untouched) ────────────────────
-- The old constraint name is PostgreSQL's generated default (verified with \d+).
ALTER TABLE recommendation DROP CONSTRAINT IF EXISTS recommendation_date_rank_key;
ALTER TABLE recommendation DROP CONSTRAINT IF EXISTS recommendation_user_key;
ALTER TABLE recommendation ADD CONSTRAINT recommendation_user_key UNIQUE (user_id, date, rank);

-- ── finding (UNIQUE fold; UUID PK untouched) ────────────────────────────────
ALTER TABLE finding DROP CONSTRAINT IF EXISTS finding_kind_metric_a_metric_b_event_kind_lag_days_key;
ALTER TABLE finding DROP CONSTRAINT IF EXISTS finding_user_key;
ALTER TABLE finding ADD CONSTRAINT finding_user_key
  UNIQUE (user_id, kind, metric_a, metric_b, event_kind, lag_days);
