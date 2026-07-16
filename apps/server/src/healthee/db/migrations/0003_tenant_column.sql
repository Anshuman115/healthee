-- 0003_tenant_column — Phase 6.2 tenant column (multi-user / GA groundwork).
--
-- STRICTLY ADDITIVE + non-breaking. Adds a `user_id` tenant column, its FK to
-- app_user, and a (user_id, …) secondary index to every data table, and inserts
-- the sentinel legacy owner that all pre-auth single-tenant rows belong to. It
-- CHANGES NOTHING about existing PKs, UNIQUE constraints, or `ON CONFLICT`
-- targets — the PK/UNIQUE fold-in, `ON CONFLICT` retargeting, the profile
-- re-key, and the USER_TZ removal are deferred to 6.3 (they must change together
-- with the ~119-site query threading). All existing upserts keep working
-- unchanged; new writes that omit user_id keep working via the column DEFAULT
-- (MULTI_USER.md §8/§11).
--
-- The NOT NULL DEFAULT backfills every existing row to the sentinel automatically
-- (PG11+ metadata-only, no table rewrite). Constraints are named so DROP … IF
-- EXISTS makes a partial prior run safe to replay. This transitional scaffold
-- (column DEFAULT) gets dropped in 6.5 once every writer supplies user_id
-- explicitly and RLS is enabled.

-- ── sentinel owner ─────────────────────────────────────────────────────────
-- The pre-auth legacy owner; all existing single-user data belongs to it. The
-- FK DEFAULTs below reference this row, so it MUST exist before the columns are
-- added. Timezone is Asia/Kolkata — the current single-tenant USER_TZ
-- (derive/_common.py) — so 6.3 day boundaries don't shift when tz goes per-user.
-- In 6.4 this id is re-keyed to the real Supabase UUID via the ON UPDATE CASCADE
-- FKs (one UPDATE app_user … cascades to every data row).
INSERT INTO app_user (id, email, status, timezone)
VALUES ('00000000-0000-0000-0000-000000000000', NULL, 'active', 'Asia/Kolkata')
ON CONFLICT (id) DO NOTHING;

-- ── sample (hypertable) ─────────────────────────────────────────────────────
-- FK on the TimescaleDB hypertable is supported (a hypertable may reference a
-- plain table); verified against the local DB, so `sample` keeps its FK.
ALTER TABLE sample ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE sample DROP CONSTRAINT IF EXISTS sample_user_fk;
ALTER TABLE sample ADD CONSTRAINT sample_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS sample_user_idx ON sample (user_id, metric, ts DESC);

-- ── sleep_session ───────────────────────────────────────────────────────────
ALTER TABLE sleep_session ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE sleep_session DROP CONSTRAINT IF EXISTS sleep_session_user_fk;
ALTER TABLE sleep_session ADD CONSTRAINT sleep_session_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS sleep_session_user_idx ON sleep_session (user_id, start_ts DESC);

-- ── workout ─────────────────────────────────────────────────────────────────
ALTER TABLE workout ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE workout DROP CONSTRAINT IF EXISTS workout_user_fk;
ALTER TABLE workout ADD CONSTRAINT workout_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS workout_user_idx ON workout (user_id, start_ts DESC);

-- ── derived_daily ───────────────────────────────────────────────────────────
ALTER TABLE derived_daily ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE derived_daily DROP CONSTRAINT IF EXISTS derived_daily_user_fk;
ALTER TABLE derived_daily ADD CONSTRAINT derived_daily_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS derived_daily_user_idx ON derived_daily (user_id, metric, day DESC);

-- ── weight_log ──────────────────────────────────────────────────────────────
ALTER TABLE weight_log ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE weight_log DROP CONSTRAINT IF EXISTS weight_log_user_fk;
ALTER TABLE weight_log ADD CONSTRAINT weight_log_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS weight_log_user_idx ON weight_log (user_id, ts DESC);

-- ── kv ──────────────────────────────────────────────────────────────────────
ALTER TABLE kv ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE kv DROP CONSTRAINT IF EXISTS kv_user_fk;
ALTER TABLE kv ADD CONSTRAINT kv_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS kv_user_idx ON kv (user_id, key);

-- ── manual_entry ────────────────────────────────────────────────────────────
ALTER TABLE manual_entry ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE manual_entry DROP CONSTRAINT IF EXISTS manual_entry_user_fk;
ALTER TABLE manual_entry ADD CONSTRAINT manual_entry_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS manual_entry_user_idx ON manual_entry (user_id, ts DESC);

-- ── illness_flag ────────────────────────────────────────────────────────────
ALTER TABLE illness_flag ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE illness_flag DROP CONSTRAINT IF EXISTS illness_flag_user_fk;
ALTER TABLE illness_flag ADD CONSTRAINT illness_flag_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS illness_flag_user_idx ON illness_flag (user_id, date DESC);

-- ── recommendation ──────────────────────────────────────────────────────────
ALTER TABLE recommendation ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE recommendation DROP CONSTRAINT IF EXISTS recommendation_user_fk;
ALTER TABLE recommendation ADD CONSTRAINT recommendation_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS recommendation_user_idx ON recommendation (user_id, date DESC);

-- ── finding ─────────────────────────────────────────────────────────────────
ALTER TABLE finding ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE finding DROP CONSTRAINT IF EXISTS finding_user_fk;
ALTER TABLE finding ADD CONSTRAINT finding_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS finding_user_idx ON finding (user_id, kind);

-- ── challenge ───────────────────────────────────────────────────────────────
ALTER TABLE challenge ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE challenge DROP CONSTRAINT IF EXISTS challenge_user_fk;
ALTER TABLE challenge ADD CONSTRAINT challenge_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS challenge_user_idx ON challenge (user_id, status);

-- ── program ─────────────────────────────────────────────────────────────────
ALTER TABLE program ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE program DROP CONSTRAINT IF EXISTS program_user_fk;
ALTER TABLE program ADD CONSTRAINT program_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS program_user_idx ON program (user_id, status);

-- ── challenge_outcome ───────────────────────────────────────────────────────
ALTER TABLE challenge_outcome ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE challenge_outcome DROP CONSTRAINT IF EXISTS challenge_outcome_user_fk;
ALTER TABLE challenge_outcome ADD CONSTRAINT challenge_outcome_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS challenge_outcome_user_idx ON challenge_outcome (user_id);

-- ── gps_track ───────────────────────────────────────────────────────────────
ALTER TABLE gps_track ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE gps_track DROP CONSTRAINT IF EXISTS gps_track_user_fk;
ALTER TABLE gps_track ADD CONSTRAINT gps_track_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS gps_track_user_idx ON gps_track (user_id, start_ts);

-- ── gps_point ───────────────────────────────────────────────────────────────
ALTER TABLE gps_point ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE gps_point DROP CONSTRAINT IF EXISTS gps_point_user_fk;
ALTER TABLE gps_point ADD CONSTRAINT gps_point_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS gps_point_user_idx ON gps_point (user_id, ts);

-- ── profile ─────────────────────────────────────────────────────────────────
-- ADDITIVE ONLY: add the column + FK + index, but KEEP the existing
-- `id INTEGER PK DEFAULT 1 CHECK (id = 1)` untouched. The PK-flip and
-- demographic merge (key profile by user_id) are deferred to 6.3 — existing code
-- still reads/writes `WHERE id = 1`.
ALTER TABLE profile ADD COLUMN IF NOT EXISTS user_id UUID NOT NULL
  DEFAULT '00000000-0000-0000-0000-000000000000';
ALTER TABLE profile DROP CONSTRAINT IF EXISTS profile_user_fk;
ALTER TABLE profile ADD CONSTRAINT profile_user_fk FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS profile_user_idx ON profile (user_id);
