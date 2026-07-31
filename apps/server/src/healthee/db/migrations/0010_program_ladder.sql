-- 0010_program_ladder — WP-C4: give the ladder a vocabulary that can record failure.
--
-- `program` and `challenge.program_id`/`rung_index` were ported from legacy in 0001
-- with legacy's shape, and that shape cannot express the three things CHALLENGES.md
-- §2.3 says a program must be able to say:
--
--   * "this rung has not been reached yet" — legacy wrote `status='locked'`, which
--     0009's CHECK (added before any rung existed) does not allow. Without it a
--     designed-but-unreached rung would have to sit in `suggested`, where the feed
--     lists it and `lifecycle.adopt` would happily take it on its own — snapping the
--     third step out of a ladder and running it as a standalone challenge.
--   * "this rung is a step BACK" — a deload. Legacy had no deload at all, and
--     without a marker one is indistinguishable from a rung the model simply drew
--     lower, which is exactly the difference the outcome ledger has to be able to
--     tell afterwards (§2.3, and the reason a deload is an inserted rung rather than
--     a repeat of the failed one).
--   * "this ladder ended, and not by being finished" — legacy's `program.status` had
--     no CHECK and no terminal state but `completed`/`abandoned`. A ladder that eases
--     forever is its own failure mode, so the give-up condition needs somewhere
--     honest to land: `stalled`, with the reason stored beside it.
--
-- Data safety: nothing in the application has ever written `program` or set
-- `challenge.program_id` — WP-C4 is the first code that does, and no INSERT or UPDATE
-- in `challenges/store.py` has ever named either. So every ADD below lands on an empty
-- table and every CHECK is added to rows that cannot violate it.
--
-- Privileges: the app role's grants are table-level (`provision_app_role`), and a
-- table-level GRANT covers columns added later — 0009 established this and
-- `tests/db/test_app_role.py` proves it rather than assuming it.
--
-- Replay-safety: every ADD/DROP is IF (NOT) EXISTS and every CHECK is dropped by name
-- before it is added. `migrate._apply_one` runs a whole file plus its ledger row in
-- ONE transaction, so a file cannot half-apply and be replayed.

-- ── challenge: a rung that has not been reached is LOCKED, not suggested ─────
-- The status is what makes "you cannot adopt rung 3 on its own" structural rather
-- than a rule somebody has to remember: `lifecycle.adopt` already refuses anything
-- that is not `suggested`, and `store.delete_suggestions` already skips rows with a
-- `program_id`. Both were written for this and neither needs to change.
ALTER TABLE challenge DROP CONSTRAINT IF EXISTS challenge_status_chk;
ALTER TABLE challenge ADD CONSTRAINT challenge_status_chk
  CHECK (status IN ('locked', 'suggested', 'active', 'completed', 'expired', 'abandoned'));

-- ── challenge: standard rung vs deload rung (§2.3, §3) ──────────────────────
-- A deload is modelled as an INSERTED rung rather than a repeat of the failed one,
-- and this column is what makes the insertion legible. The alternative — re-running
-- the failed row at an eased target — cannot be recorded at all: `challenge_outcome`
-- is keyed on `challenge_id` and written `ON CONFLICT DO NOTHING`, so a second
-- attempt on one row either produces no second outcome or overwrites the first.
-- Neither is a story the ledger can tell.
ALTER TABLE challenge ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'standard';
ALTER TABLE challenge DROP CONSTRAINT IF EXISTS challenge_kind_chk;
ALTER TABLE challenge ADD CONSTRAINT challenge_kind_chk
  CHECK (kind IN ('standard', 'deload'));

-- Rungs are always read as "this owner's ladder, in order" (`program_store`), and
-- `challenge_user_idx` is on (user_id, status) — it cannot order a ladder.
CREATE INDEX IF NOT EXISTS challenge_program_rung_idx
  ON challenge (user_id, program_id, rung_index);

-- ── program: the terminal vocabulary, `stalled` included (§2.3) ─────────────
-- `stalled` is the give-up condition's landing place: a ladder whose rungs keep
-- timing out unmet at progressively easier targets is telling us something, and the
-- honest response is to end it and say why rather than grind. It is deliberately NOT
-- `abandoned` — the owner did not quit, the system did, and a ledger that files the
-- two together loses the distinction that matters most for what to offer next.
ALTER TABLE program DROP CONSTRAINT IF EXISTS program_status_chk;
ALTER TABLE program ADD CONSTRAINT program_status_chk
  CHECK (status IN ('suggested', 'active', 'completed', 'stalled', 'abandoned'));

-- ── program: why it ended, and why it is currently paused ───────────────────
-- Two different questions with two different lifetimes. `ended_reason` is terminal
-- and permanent; `hold_reason` is transient and cleared the moment advancement
-- resumes. Storing the hold rather than recomputing it at read time is deliberate:
-- it records what the advancement step actually decided, at the moment it decided
-- it, so a read cannot show a reason the engine never acted on.
ALTER TABLE program ADD COLUMN IF NOT EXISTS ended_at TIMESTAMPTZ;
ALTER TABLE program ADD COLUMN IF NOT EXISTS ended_reason TEXT;
ALTER TABLE program ADD COLUMN IF NOT EXISTS hold_reason TEXT;

-- ── program: drop `current_rung` — the rungs already say where you are ──────
-- A denormalised pointer maintained beside the rows it points at is a second
-- definition of "where in the ladder is this owner" (CLAUDE.md — one canonical
-- definition), and legacy's own `_advance_program` could leave it stale on any of
-- its early returns. The active rung IS the answer, and it is one predicate away.
ALTER TABLE program DROP COLUMN IF EXISTS current_rung;

-- ── say it in the database, not only here ───────────────────────────────────
-- No ';' inside these literals: `migrate._split_statements` is a naive splitter and
-- says so in its own docstring, so a semicolon in a COMMENT string cuts the
-- statement in half. (It cost one run to rediscover.)
COMMENT ON COLUMN challenge.kind IS
  'standard | deload. A deload rung is INSERTED after a rung timed out unmet, at an '
  'eased target (challenges/ladder.py), never a repeat of the failed row.';
COMMENT ON COLUMN program.ended_reason IS
  'Why a terminal program ended, in the owner''s words. Set for stalled and for '
  'abandoned. A completed ladder needs no explanation.';
COMMENT ON COLUMN program.hold_reason IS
  'Transient: why the next rung has not been activated (low recovery, an illness '
  'flag, or a clashing standalone commitment). NULL whenever the ladder is running.';
