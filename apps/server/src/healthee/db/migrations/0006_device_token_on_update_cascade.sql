-- 0006_device_token_on_update_cascade — close the one FK the re-key cascade misses.
--
-- Phase 6.4c (MULTI_USER.md §8). The sentinel → real-owner re-key is ONE statement:
--
--   UPDATE app_user SET id = <target> WHERE id = <sentinel>
--
-- and it moves every dependent row because every FK to app_user(id) carries
-- ON UPDATE CASCADE. That is the whole point of the mechanism: a hand-written list of
-- per-table UPDATEs can silently miss a table someone adds later, a cascade cannot.
--
-- Except it wasn't quite true. `device_token` is the one FK to app_user written
-- OUTSIDE 0003's sweep — it came from 0002 (`REFERENCES app_user(id) ON DELETE
-- CASCADE`), which specifies no update action, so it defaulted to NO ACTION while the
-- 16 data tables got `ON UPDATE CASCADE ON DELETE CASCADE`. Verified against the live
-- DB: 19 FKs reference app_user; 18 cascade on update (16 tables + 2 hypertable
-- chunks), and `device_token` is the 19th.
--
-- Consequence: the re-key does NOT silently skip device tokens — it ERRORS
-- ("update or delete on table app_user violates foreign key constraint") the moment
-- the sentinel owns one. Loud rather than lossy, but it makes the one-off unrunnable
-- for an owner who has ever paired a device, and it makes the "the cascade cannot
-- miss a table" invariant false. Both are fixed here rather than worked around in the
-- tool, because the invariant is the reason the mechanism is trustworthy.
--
-- MULTI_USER.md §3.2 already mandates ON UPDATE CASCADE for FKs to app_user; this
-- brings the identity table in line. ON DELETE CASCADE is preserved exactly (a
-- deleted user's tokens must still die with them — §4.5).

ALTER TABLE device_token DROP CONSTRAINT IF EXISTS device_token_user_id_fkey;
ALTER TABLE device_token ADD CONSTRAINT device_token_user_id_fkey FOREIGN KEY (user_id)
  REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE;
