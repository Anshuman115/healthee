-- 0017_device_daily_total — a durable home for the strap's own daily counters (#121).
--
-- ## The defect this table exists to close
--
-- The strap reports live since-midnight totals on BLE 0x0016 — a step count the device
-- accumulated itself, which the app pushes as `daily_totals`. Until this migration those
-- numbers were written STRAIGHT INTO `derived_daily.steps_total` (and `distance_m_daily`)
-- with `flags.source = 'strap_0x16'`, and stored nowhere else. There was no raw table:
-- `DailyTotalIn` went from the HTTP body into a derived cell and stopped.
--
-- `derived_daily` is what a derive pass REBUILDS. `derive/activity.py` recomputes
-- `steps_total` from the per-minute `steps_per_minute` sum, so any derive over that day —
-- the next push that carries one late sample, a `db/rederive` repair run, a backfill —
-- overwrote the device's count with the per-minute one and the device's count was gone.
-- Permanently: there was nothing to restore it from.
--
-- Not a theoretical loss. The per-minute stream demonstrably stalls (the 0xFF-gap pager
-- stall), which is WHY the override was written in the first place; `ingest/upsert.py`
-- called the per-minute sum "possibly frozen/incomplete" and the strap counter
-- "authoritative" in the same docstring. Measured on production 2026-08-02: of 143
-- `steps_total` rows, **142 carried the per-minute sum and exactly one carried
-- `strap_0x16`** — today's, not yet overwritten. We served the number our own code called
-- incomplete on 142 days out of 143 while discarding the one it called authoritative.
--
-- ## ⛔ Those 142 days are NOT recovered by this migration, and cannot be
--
-- This table starts EMPTY. There is deliberately no backfill, because there is nothing to
-- backfill FROM: the strap's numbers for those days existed only in the cell that got
-- overwritten, and two pre-repair production backups were checked — both hold the same
-- overwritten per-minute values. The device does not keep history for them either. Every
-- day before this migration is deployed keeps the per-minute sum, and that is the honest
-- reading of it: the better measurement for those days no longer exists anywhere. This
-- change is forward-only.
--
-- ## The shape
--
-- One row per (owner, local day) — the same grain `DailyTotalIn` carries, and the grain the
-- day pass reads by. Deliberately NOT a `sample` row: `sample` is keyed by an instant, and
-- a since-midnight counter is a statement about a CALENDAR DAY in the owner's zone. Giving
-- it a synthetic instant would re-open the day-vs-instant conversion at every read, for a
-- value that has no instant of its own.
--
-- A later report for the same day REPLACES an earlier one (`ON CONFLICT … DO UPDATE`,
-- `ingest/upsert.upsert_daily_totals`): the counter is a live accumulator, so the newest
-- reading is the most complete one. `reported_at` records when it arrived, and is carried
-- into `derived_daily.flags` so a reader can see how late in the day the count was taken.
--
-- `calories` is stored because the strap sends it and this table's job is to hold what the
-- device said. Nothing derives from it and nothing should: free-living energy is the
-- MET-by-state model in `derive/energy.py` (CLAUDE.md — never a device's own HR-based
-- number). It is kept so the raw report is complete, not so it can be served.
--
-- No index beyond the primary key. Every read is `user_id = … AND day = …`, which the PK
-- `(user_id, day)` serves as a leading prefix; a second index on the same columns would
-- cost every ingest write to speed up nothing.
--
-- RLS exactly as `0008` specifies for every tenant table — same policy shape, same GUC.
-- The app role's grant arrives automatically via `provision_app_role`'s
-- `ALTER DEFAULT PRIVILEGES`, and the table is named in its `_DML_TABLES` list as well so
-- an existing deployment that re-runs the provisioner is covered too.
--
-- Replay-safe (IF NOT EXISTS / DROP POLICY IF EXISTS); `migrate._apply_one` runs the file
-- plus its ledger row in ONE transaction.

CREATE TABLE IF NOT EXISTS device_daily_total (
  day         DATE              NOT NULL,
  steps       INTEGER,
  distance_m  DOUBLE PRECISION,
  calories    DOUBLE PRECISION,
  -- Which instrument reported it, kept with the row rather than hardcoded downstream —
  -- `derive/device_totals.py` copies this into `derived_daily.flags.source`.
  source      TEXT              NOT NULL DEFAULT 'strap_0x16',
  reported_at TIMESTAMPTZ       NOT NULL DEFAULT now(),
  user_id     UUID              NOT NULL
                REFERENCES app_user(id) ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (user_id, day)
);

ALTER TABLE device_daily_total ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS device_daily_total_tenant ON device_daily_total;
CREATE POLICY device_daily_total_tenant ON device_daily_total FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);
