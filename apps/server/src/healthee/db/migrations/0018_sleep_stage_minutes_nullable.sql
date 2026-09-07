-- 0018_sleep_stage_minutes_nullable — a night with no stage breakdown stops being a
-- night of zero sleep (A5/A6/A13).
--
-- ## The defect
--
-- `sleep_session.rem_min` / `light_min` / `deep_min` / `wake_min` were `INTEGER NOT NULL
-- DEFAULT 0`. The storage layer had **no way to say "the strap staged nothing"**, so the
-- only value available for that state was 0 — and 0 is also the correct answer for a
-- night that genuinely recorded no REM. Two different facts, one representation.
--
-- The zeros are not made in `read/`. They are made one layer lower, at ingest:
-- `ingest/models.SleepIn` defaulted all four fields to `0`, and `ingest/upsert.py`
-- inserted them unconditionally. By the time the read layer saw the row, the fact that
-- there had been no breakdown was gone — which is why the `(light or 0) + (deep or 0) +
-- (rem or 0)` guards scattered through `read/sleep_extras.py` and `read/sleep_page.py`
-- were dead code: the schema forbade the NULL they were guarding against.
--
-- Downstream, `duration_min` summed the three sleep stages, so an unstaged night reported
-- a total sleep time of **0 minutes**; the app's stacked stage chart painted four
-- zero-height segments, pixel-identical to a night of literal zero sleep; and the client's
-- `?? night.stages.total` fallback replaced a correct server-side withhold of `tst_min`
-- with that same zero. `read/recovery.py`'s sleep signal, 200 lines away, already read the
-- same quantity and treated a zero stage-sum as absence — one codebase, two answers about
-- what zero means there.
--
-- ## ⛔ The existing zeros are NOT repaired by this migration, and cannot be
--
-- Every row already in the table has four non-null stage columns. A night the strap staged
-- as 0 minutes of REM and a night the strap did not stage at all are **the same four
-- bytes**, and no column anywhere else in the schema distinguishes them: there is no
-- `has_breakdown` marker, no ingest audit row, and `stages` (the hypnogram) is `NOT NULL
-- DEFAULT '[]'` for the same reason, so an empty array is equally ambiguous.
--
-- So no backfill is attempted and none would be honest. Rewriting historical zeros to NULL
-- would delete real measurements of stageless sleep; leaving them is the position this
-- migration takes, and it is stated here rather than discovered later. **This change is
-- forward-only**: a session pushed after it can say "not measured", and every session
-- pushed before it keeps whatever it said. Same shape as `0017`'s device-counter loss —
-- a distinction that was never recorded cannot be recovered by recording it now.
--
-- ## Why nullable rather than a `has_breakdown` boolean
--
-- A boolean would be a second field that can disagree with the first, and the repo has
-- paid for exactly that twice (#83's two grade fields, #118's two answers to "is this
-- current"). One representation, one meaning: NULL is "not measured", a number is a
-- measurement. `COALESCE(EXCLUDED.col, sleep_session.col)` in the upsert then has
-- something real to test, which is the other half of the fix — a partial re-push can no
-- longer clobber a complete row with defaults, because "omitted" and "genuinely zero"
-- stopped being the same value on the wire.
--
-- Widening a column is safe for every existing reader: nothing is rewritten, no row moves,
-- and the table is not rewritten by DROP NOT NULL / DROP DEFAULT (catalogue-only changes).
--
-- Replay-safe; `migrate._apply_one` runs the file plus its ledger row in ONE transaction.

ALTER TABLE sleep_session ALTER COLUMN rem_min DROP NOT NULL;
ALTER TABLE sleep_session ALTER COLUMN rem_min DROP DEFAULT;
ALTER TABLE sleep_session ALTER COLUMN light_min DROP NOT NULL;
ALTER TABLE sleep_session ALTER COLUMN light_min DROP DEFAULT;
ALTER TABLE sleep_session ALTER COLUMN deep_min DROP NOT NULL;
ALTER TABLE sleep_session ALTER COLUMN deep_min DROP DEFAULT;
ALTER TABLE sleep_session ALTER COLUMN wake_min DROP NOT NULL;
ALTER TABLE sleep_session ALTER COLUMN wake_min DROP DEFAULT;
