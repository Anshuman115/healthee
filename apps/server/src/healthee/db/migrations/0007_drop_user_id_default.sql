-- 0007_drop_user_id_default — retire the transitional tenant DEFAULT (§8/§11).
--
-- `0003` added `user_id UUID NOT NULL DEFAULT '00000000-…-0000'` to all 16 data
-- tables as a deliberate SCAFFOLD: it backfilled every existing row to the
-- sentinel in one metadata-only step, and it kept legacy-shaped writes (which
-- omitted user_id) working so 6.2 could be strictly additive while 6.3 threaded
-- the owner through ~119 query sites.
--
-- That job is done. 6.3a made every writer set the owner explicitly, and the AST
-- guard (`tests/db/test_tenant_read_scoping.py`) now FAILS THE BUILD on any tenant
-- SQL that doesn't reference user_id — so the scaffold holds nothing up.
--
-- With multi-user live it is now a HAZARD. A writer that forgets `user_id` no
-- longer fails; it silently attributes one person's health data to the sentinel —
-- exactly the silent wrongness this repo exists to prevent. Dropping the DEFAULT
-- converts that into a loud NotNullViolation at the first write.
--
-- NOT NULL is KEPT — only the DEFAULT goes. The column stays mandatory; what
-- changes is that the caller must say whose row it is instead of being handed a
-- guess.
--
-- Replay-safe: `DROP DEFAULT` on a column with no default is a no-op in Postgres,
-- so re-running this file changes nothing. One statement per `;` (psycopg3 runs
-- them one at a time), no DO blocks.

ALTER TABLE sample ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE sleep_session ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE workout ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE derived_daily ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE weight_log ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE kv ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE manual_entry ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE illness_flag ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE recommendation ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE finding ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE challenge ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE program ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE challenge_outcome ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE gps_track ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE gps_point ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE profile ALTER COLUMN user_id DROP DEFAULT;
