-- 0009_outcome_ledger — WP-C2: make the challenge ledger's honesty structural.
--
-- `challenge_outcome` was ported from legacy in 0001 with legacy's shape, and that
-- shape encodes two claims the rebuild will not make (CHALLENGES.md §2.1, §2.6,
-- §7 decision 1):
--
--   * `adherence` conflated "did they show up" with "did the metric move", so one
--     number answered two questions and neither could be trusted; and
--   * `downstream` recorded deltas on OTHER metrics as an effect of THIS challenge,
--     while up to four challenges ran concurrently. Legacy's prose said
--     "observational, not proof" — but the column name said the opposite, and the
--     data structure is what the next reader (and the next LLM prompt) believes.
--
-- So the caveat moves out of the prose and into the schema:
--
--   adherence        the BEHAVIOUR rate — days the commitment was met / days elapsed
--   improvement_pct  the METRIC move — final vs the frozen baseline, direction-aware
--   co_occurring     what else moved during the window, explicitly UNATTRIBUTED
--   confounds        illness days · concurrent challenges · regression-to-mean risk
--   data_confidence  'ok' | 'insufficient_data' — a thin baseline is LABELLED, never
--                    a silent NULL that makes the outcome disappear
--
-- `challenge.status` also gains its vocabulary as a CHECK, including `expired`.
-- Legacy marked a window that ran out unmet as "completed"; a lifecycle that cannot
-- say "this ended and was not met" can only lie about it (§2.3 makes the same point
-- for program rungs).
--
-- Data safety: nothing in the application has ever written `challenge_outcome` or
-- `challenge` — WP-C1 is pure functions with no persistence, and CHALLENGES.md
-- records that zero application code existed before it. The one `downstream` value
-- that could conceivably exist is preserved under an explicit `legacy_note` key
-- rather than dropped, because "we assume it is empty" is not the same as "we
-- checked", and the cost of being wrong is someone's history.
--
-- Privileges: the app role's grants are table-level (`provision_app_role`), and a
-- table-level GRANT covers columns added later — so no new grant is needed here.
-- `tests/db/test_app_role.py` proves that rather than assuming it.
--
-- Replay-safety: every ADD/DROP is IF (NOT) EXISTS and the CHECKs are dropped by
-- name first. The two RENAMEs cannot be — Postgres has no `RENAME COLUMN IF EXISTS`
-- and the conditional form needs a DO block, which the runner's ';' splitter cannot
-- carry (`provision_app_role`'s docstring makes the same point). They are safe
-- regardless: `migrate._apply_one` runs a whole file plus its ledger row in ONE
-- transaction, so a file cannot half-apply and be replayed.

-- ── challenge_outcome: split adherence from improvement (§2.6) ───────────────
-- `delta_pct` becomes `improvement_pct` and gains a DIRECTION: positive always
-- means "moved the way this challenge wanted". A signed raw delta cannot mean that
-- for a `good="down"` metric — a −40 % alcohol change is the challenge working, and
-- a ledger that files it as a negative result would teach the generation layer
-- exactly the wrong lesson (#61 added the first such metrics).
ALTER TABLE challenge_outcome RENAME COLUMN delta_pct TO improvement_pct;

-- ── challenge_outcome: co-occurring, NOT downstream (§2.1, §7 decision 1) ────
-- The rename IS the fix. With 2–4 challenges live at once, a delta on some other
-- metric cannot be attributed to any one of them; `confounds.concurrent_challenges`
-- travels alongside so the count is impossible to read without.
ALTER TABLE challenge_outcome RENAME COLUMN downstream TO co_occurring;
ALTER TABLE challenge_outcome ALTER COLUMN co_occurring TYPE JSONB
  USING CASE WHEN co_occurring IS NULL THEN NULL
             ELSE jsonb_build_object('legacy_note', co_occurring) END;

-- ── challenge_outcome: the confound flags and the sufficiency gate (§2.1) ────
ALTER TABLE challenge_outcome ADD COLUMN IF NOT EXISTS confounds JSONB NOT NULL
  DEFAULT '{}'::jsonb;
ALTER TABLE challenge_outcome ADD COLUMN IF NOT EXISTS data_confidence TEXT NOT NULL
  DEFAULT 'ok';
ALTER TABLE challenge_outcome DROP CONSTRAINT IF EXISTS challenge_outcome_confidence_chk;
ALTER TABLE challenge_outcome ADD CONSTRAINT challenge_outcome_confidence_chk
  CHECK (data_confidence IN ('ok', 'insufficient_data'));

-- The ledger is read as "this owner's outcomes, newest first" (the Insights rollup
-- and the WP-C5 coach context); 0003's `(user_id)` index cannot order it.
CREATE INDEX IF NOT EXISTS challenge_outcome_user_ended_idx
  ON challenge_outcome (user_id, ended_at DESC);

-- ── challenge: the lifecycle vocabulary, `expired` included (§2.3) ──────────
ALTER TABLE challenge DROP CONSTRAINT IF EXISTS challenge_status_chk;
ALTER TABLE challenge ADD CONSTRAINT challenge_status_chk
  CHECK (status IN ('suggested', 'active', 'completed', 'expired', 'abandoned'));

-- ── say it in the database, not only here ───────────────────────────────────
-- These four are the ones a reader can get wrong at a glance, and the whole point
-- of the migration is that they stop meaning the same thing. `\d+` should be able
-- to answer it without anyone finding this file.
COMMENT ON COLUMN challenge_outcome.adherence IS
  'Behaviour rate: days the commitment was met / days elapsed. NOT whether the metric moved.';
COMMENT ON COLUMN challenge_outcome.improvement_pct IS
  'Percent move of THIS challenge''s own target metric, baseline -> final, signed so '
  'positive = the direction the challenge wanted. The only before/after we claim.';
COMMENT ON COLUMN challenge_outcome.co_occurring IS
  'Deltas on OTHER metrics during the window: co-occurring and UNATTRIBUTED. Never '
  'presented as caused by this challenge (CHALLENGES.md 7.1).';
COMMENT ON COLUMN challenge_outcome.confounds IS
  'Structured reasons to distrust this outcome: illness days, concurrent challenges, '
  'regression-to-the-mean risk.';
