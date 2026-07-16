-- 0008_row_level_security — the isolation backstop (§3.3, resolves [D3]).
--
-- Every tenant table gets RLS + one policy keyed on the `healthee.user_id` GUC,
-- which `core.db.tenant_transaction()` sets (via `set_config(..., true)`) at the
-- start of each request's / job's transaction. A query that forgets `WHERE
-- user_id = %s` then cannot see another owner's rows: the explicit filters stay
-- (clarity + index use, §5), this is what sits underneath them.
--
-- The policy shape is exact, and each part of it was probed against a real
-- hypertable and a real NOSUPERUSER NOBYPASSRLS role before being written:
--
--   * `FOR ALL` + `WITH CHECK` — NOT `USING`-only. A USING-only policy governs
--     SELECT/UPDATE/DELETE but leaves INSERT ungoverned, which would break every
--     upsert in the codebase (and let a write land under any owner).
--   * `NULLIF(current_setting('healthee.user_id', true), '')` — mandatory. Once a
--     custom GUC has been touched in a session, `current_setting(x, true)` returns
--     the EMPTY STRING rather than NULL, and a bare `''::uuid` ERRORS instead of
--     failing closed. NULLIF turns both "never set" and "set to empty" into NULL,
--     and `user_id = NULL` is NULL ⇒ no rows, no error. Fails closed either way.
--   * No `FORCE ROW LEVEL SECURITY`. FORCE only matters when the CONNECTING role
--     owns the table; the app role (6.5b-1) owns nothing, so plain ENABLE already
--     subjects it to the policy. The admin/owner is deliberately NOT subject —
--     `migrate`, `provision_app_role`, `claim_sentinel` and the test reset need to
--     see across owners, and `claim_sentinel`'s post-check would silently pass on
--     a filtered connection.
--
-- The identity tables (`app_user`, `device_token`) get NO policy on purpose: the
-- app must resolve WHO you are before it can know the owner to scope to, and the
-- scheduler's `active_users()` sweep must see every owner. `schema_migrations` is
-- admin-only already.
--
-- Hypertables: `sample`'s chunks inherit the parent's policy (verified on a real
-- chunk), so nothing extra is needed for TimescaleDB.
--
-- Replay-safe: ENABLE ROW LEVEL SECURITY is idempotent, and each policy is dropped
-- with IF EXISTS before being created. One statement per `;`, no DO blocks (the
-- runner splits on `;` and psycopg3 executes one statement at a time).

ALTER TABLE sample ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sample_tenant ON sample;
CREATE POLICY sample_tenant ON sample FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE sleep_session ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sleep_session_tenant ON sleep_session;
CREATE POLICY sleep_session_tenant ON sleep_session FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE workout ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS workout_tenant ON workout;
CREATE POLICY workout_tenant ON workout FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE derived_daily ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS derived_daily_tenant ON derived_daily;
CREATE POLICY derived_daily_tenant ON derived_daily FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE weight_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS weight_log_tenant ON weight_log;
CREATE POLICY weight_log_tenant ON weight_log FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE kv ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS kv_tenant ON kv;
CREATE POLICY kv_tenant ON kv FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE manual_entry ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS manual_entry_tenant ON manual_entry;
CREATE POLICY manual_entry_tenant ON manual_entry FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE illness_flag ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS illness_flag_tenant ON illness_flag;
CREATE POLICY illness_flag_tenant ON illness_flag FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE recommendation ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS recommendation_tenant ON recommendation;
CREATE POLICY recommendation_tenant ON recommendation FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE finding ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS finding_tenant ON finding;
CREATE POLICY finding_tenant ON finding FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE challenge ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS challenge_tenant ON challenge;
CREATE POLICY challenge_tenant ON challenge FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE program ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS program_tenant ON program;
CREATE POLICY program_tenant ON program FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE challenge_outcome ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS challenge_outcome_tenant ON challenge_outcome;
CREATE POLICY challenge_outcome_tenant ON challenge_outcome FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE gps_track ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gps_track_tenant ON gps_track;
CREATE POLICY gps_track_tenant ON gps_track FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE gps_point ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gps_point_tenant ON gps_point;
CREATE POLICY gps_point_tenant ON gps_point FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

ALTER TABLE profile ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profile_tenant ON profile;
CREATE POLICY profile_tenant ON profile FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);
