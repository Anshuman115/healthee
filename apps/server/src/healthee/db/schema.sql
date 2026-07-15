-- Healthee schema — current-state reference (Rails-schema.rb style).
--
-- This file is the at-a-glance picture of the whole database. It is NOT applied
-- directly: the migration runner (healthee.db.migrate) builds the DB from the
-- numbered files in db/migrations/. Keep this in sync when you add a migration;
-- a test (tests/test_schema_files.py) asserts the table/index set here matches
-- what the migrations declare, so the two can never silently drift.
--
-- Cutover note (Phase 6): definitions are a superset-compatible match of legacy
-- PROD (schema_v2.sql + all applied migrations), so a pg_dump of prod restores
-- into this schema. The v1 compat VIEWs (metric_sample, session) and v1-only
-- tables (sync_run) are intentionally gone — the rebuild reads v2-native.

CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid() on older PG; core on PG13+

-- ── sample ───────────────────────────────────────────────────────────────
-- Raw time-series hypertable: one row per (metric, ts). Re-ingest is idempotent.
CREATE TABLE IF NOT EXISTS sample (
  ts      TIMESTAMPTZ       NOT NULL,
  metric  TEXT              NOT NULL,
  value   DOUBLE PRECISION  NOT NULL,
  PRIMARY KEY (metric, ts)
);
SELECT create_hypertable('sample', 'ts',
  chunk_time_interval => INTERVAL '7 days', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS sample_metric_ts_idx ON sample (metric, ts DESC);

-- ── sleep_session ─────────────────────────────────────────────────────────
-- One typed sleep session (night or nap); stages is the [[startMs,endMs,type],…] hypnogram.
CREATE TABLE IF NOT EXISTS sleep_session (
  start_ts    TIMESTAMPTZ  PRIMARY KEY,
  end_ts      TIMESTAMPTZ  NOT NULL,
  kind        TEXT         NOT NULL DEFAULT 'main',  -- 'main' night sleep | 'nap'
  score       INTEGER,
  avg_hr      INTEGER,
  rem_min     INTEGER      NOT NULL DEFAULT 0,
  light_min   INTEGER      NOT NULL DEFAULT 0,
  deep_min    INTEGER      NOT NULL DEFAULT 0,
  wake_min    INTEGER      NOT NULL DEFAULT 0,
  stages      JSONB        NOT NULL DEFAULT '[]'::jsonb
);
CREATE INDEX IF NOT EXISTS sleep_session_start_idx ON sleep_session (start_ts DESC);

-- ── workout ───────────────────────────────────────────────────────────────
-- One typed workout with device-measured calories/distance/HR.
CREATE TABLE IF NOT EXISTS workout (
  start_ts    TIMESTAMPTZ  PRIMARY KEY,
  sport       INTEGER      NOT NULL DEFAULT 0,
  duration_s  INTEGER      NOT NULL DEFAULT 0,
  calories    INTEGER,
  distance_m  REAL,
  avg_hr      INTEGER,
  max_hr      INTEGER,
  min_hr      INTEGER
);
CREATE INDEX IF NOT EXISTS workout_start_idx ON workout (start_ts DESC);

-- ── derived_daily ─────────────────────────────────────────────────────────
-- Materialized per-day derived metrics for O(1) dashboard reads (filled on ingest).
CREATE TABLE IF NOT EXISTS derived_daily (
  day     DATE              NOT NULL,
  metric  TEXT              NOT NULL,
  value   DOUBLE PRECISION  NOT NULL,
  flags   JSONB             NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (day, metric)
);
CREATE INDEX IF NOT EXISTS derived_daily_metric_day_idx ON derived_daily (metric, day DESC);

-- ── profile ───────────────────────────────────────────────────────────────
-- The single user's profile (id fixed at 1); inputs for energy/distance derivation.
CREATE TABLE IF NOT EXISTS profile (
  id          INTEGER      PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  name        TEXT,
  height_cm   REAL,
  sex         TEXT CHECK (sex IN ('male', 'female')),
  dob         DATE,
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ── weight_log ────────────────────────────────────────────────────────────
-- Body-weight measurements, one row per timestamp (deduped to one per local day).
CREATE TABLE IF NOT EXISTS weight_log (
  ts  TIMESTAMPTZ  PRIMARY KEY,
  kg  REAL         NOT NULL
);

-- ── kv ────────────────────────────────────────────────────────────────────
-- Small key/value store (per-day markers, cached generated text).
CREATE TABLE IF NOT EXISTS kv (
  key    TEXT  PRIMARY KEY,
  value  TEXT  NOT NULL
);

-- ── manual_entry ──────────────────────────────────────────────────────────
-- User-logged events: caffeine/alcohol/meditation/exercise/fasting/habit/etc.
CREATE TABLE IF NOT EXISTS manual_entry (
  id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  kind       TEXT         NOT NULL,
  ts         TIMESTAMPTZ  NOT NULL,
  end_ts     TIMESTAMPTZ,
  name       TEXT,
  amount     DOUBLE PRECISION,
  unit       TEXT,
  severity   INTEGER,
  notes      TEXT,
  flags      JSONB        NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS manual_entry_ts_idx ON manual_entry (ts DESC, kind);

-- ── illness_flag ──────────────────────────────────────────────────────────
-- Early-warning flag: one row per wake-date when skin-temp/RR/HRV deviate enough.
CREATE TABLE IF NOT EXISTS illness_flag (
  date              DATE PRIMARY KEY,
  severity          TEXT NOT NULL CHECK (severity IN ('moderate', 'high')),
  rr_delta_bpm      REAL,
  temp_delta_c      REAL,
  hrv_delta_z       REAL,
  rhr_delta_z       REAL,
  sustained         BOOLEAN NOT NULL DEFAULT FALSE,
  research_note_ids TEXT[] NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS illness_flag_date_idx ON illness_flag (date DESC);

-- ── recommendation ────────────────────────────────────────────────────────
-- AI-synthesized daily recommendations (1–3 ranked actions per date, cite-or-drop).
CREATE TABLE IF NOT EXISTS recommendation (
  id                BIGSERIAL PRIMARY KEY,
  date              DATE NOT NULL,
  rank              INTEGER NOT NULL,
  action            TEXT NOT NULL,
  rationale         TEXT NOT NULL,
  expected_effect   TEXT,
  category          TEXT NOT NULL,
  evidence_grade    INTEGER NOT NULL CHECK (evidence_grade IN (2, 3)),
  research_note_ids TEXT[]  NOT NULL,
  signal_source     TEXT    NOT NULL,
  raw_llm_prompt    TEXT,   -- audit trail (legacy INSERTed these; v2 schema lacked them)
  raw_llm_response  TEXT,   -- audit trail
  adopted           BOOLEAN,
  adopted_at        TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (date, rank)
);
CREATE INDEX IF NOT EXISTS recommendation_date_idx ON recommendation (date DESC);

-- ── finding ───────────────────────────────────────────────────────────────
-- Discovered patterns: pairwise metric correlations, event-effects, personal cutoffs.
CREATE TABLE IF NOT EXISTS finding (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  computed_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  kind          TEXT         NOT NULL,
  description   TEXT         NOT NULL,
  metric_a      TEXT         NOT NULL,
  metric_b      TEXT         NOT NULL DEFAULT '',
  event_kind    TEXT         NOT NULL DEFAULT '',
  lag_days      INTEGER      NOT NULL DEFAULT 0,
  effect_size   DOUBLE PRECISION NOT NULL,
  effect_metric TEXT         NOT NULL,
  p_value       DOUBLE PRECISION NOT NULL,
  q_value       DOUBLE PRECISION,
  n_samples     INTEGER      NOT NULL,
  significant   BOOLEAN      NOT NULL DEFAULT FALSE,
  research_note_ids TEXT[]   NOT NULL DEFAULT ARRAY[]::TEXT[],
  details       JSONB        NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (kind, metric_a, metric_b, event_kind, lag_days)
);
CREATE INDEX IF NOT EXISTS finding_kind_idx ON finding (kind, significant DESC, ABS(effect_size) DESC);
CREATE INDEX IF NOT EXISTS finding_metric_idx ON finding (metric_a, lag_days);

-- ── challenge ─────────────────────────────────────────────────────────────
-- Adoptable, auto-tracked health commitments; a program rung when program_id set.
CREATE TABLE IF NOT EXISTS challenge (
  id                BIGSERIAL PRIMARY KEY,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  gen_date          DATE,
  title             TEXT NOT NULL,
  why               TEXT NOT NULL,
  category          TEXT NOT NULL,
  difficulty        TEXT NOT NULL DEFAULT 'standard',
  metric            TEXT NOT NULL,
  comparator        TEXT NOT NULL,
  target_value      DOUBLE PRECISION NOT NULL,
  cadence           TEXT NOT NULL,
  window_days       INTEGER NOT NULL,
  expected_outcome  TEXT,
  how_to            TEXT,
  research_note_ids TEXT[],
  status            TEXT NOT NULL DEFAULT 'suggested',
  adopted_at        TIMESTAMPTZ,
  ends_at           TIMESTAMPTZ,
  completed_at      TIMESTAMPTZ,
  abandoned_at      TIMESTAMPTZ,
  baseline_value    DOUBLE PRECISION,
  program_id        BIGINT,
  rung_index        INTEGER
);
CREATE INDEX IF NOT EXISTS challenge_status_idx ON challenge (status, created_at DESC);

-- ── program ───────────────────────────────────────────────────────────────
-- Multi-week ladder of challenge "rungs" toward a goal; auto-advances on completion.
CREATE TABLE IF NOT EXISTS program (
  id            BIGSERIAL PRIMARY KEY,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  title         TEXT NOT NULL,
  why           TEXT NOT NULL,
  goal          TEXT,
  goal_metric   TEXT,
  category      TEXT,
  weeks         INTEGER,
  status        TEXT NOT NULL DEFAULT 'suggested',
  current_rung  INTEGER NOT NULL DEFAULT 0,
  adopted_at    TIMESTAMPTZ,
  completed_at  TIMESTAMPTZ
);

-- ── challenge_outcome ─────────────────────────────────────────────────────
-- Frozen learning-loop ledger: a snapshot written when a challenge ends.
CREATE TABLE IF NOT EXISTS challenge_outcome (
  challenge_id  BIGINT PRIMARY KEY REFERENCES challenge(id) ON DELETE CASCADE,
  metric        TEXT,
  category      TEXT,
  difficulty    TEXT,
  cadence       TEXT,
  target        DOUBLE PRECISION,
  baseline      DOUBLE PRECISION,
  final         DOUBLE PRECISION,
  delta_pct     DOUBLE PRECISION,
  improved      BOOLEAN,
  adherence     DOUBLE PRECISION,
  days_active   INTEGER,
  status        TEXT,
  downstream    TEXT,
  ended_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── gps_track ─────────────────────────────────────────────────────────────
-- One phone-recorded outdoor workout track; denormalised summary cols for cheap lists.
CREATE TABLE IF NOT EXISTS gps_track (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  start_ts       TIMESTAMPTZ NOT NULL,
  end_ts         TIMESTAMPTZ NOT NULL,
  source         TEXT NOT NULL DEFAULT 'phone',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  distance_m     DOUBLE PRECISION,
  duration_s     INTEGER,
  avg_hr         INTEGER,
  ele_gain_m     INTEGER,
  vo2max_submax  DOUBLE PRECISION,
  r2             DOUBLE PRECISION
);
CREATE INDEX IF NOT EXISTS gps_track_time_idx ON gps_track (start_ts, end_ts);

-- ── gps_point ─────────────────────────────────────────────────────────────
-- One lat/lng/elevation fix within a gps_track.
CREATE TABLE IF NOT EXISTS gps_point (
  track_id  UUID NOT NULL REFERENCES gps_track(id) ON DELETE CASCADE,
  ts        TIMESTAMPTZ NOT NULL,
  lat       DOUBLE PRECISION NOT NULL,
  lng       DOUBLE PRECISION NOT NULL,
  ele_m     DOUBLE PRECISION,
  PRIMARY KEY (track_id, ts)
);
