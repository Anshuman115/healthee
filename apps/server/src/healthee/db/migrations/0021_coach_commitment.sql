-- 0021_coach_commitment — what the owner said they would do, so the coach can ask.
--
-- ## The gap
--
-- The coach is STATELESS. The client sends the whole thread on every turn and the
-- server keeps nothing, so every conversation is a cold start: it cannot know what it
-- already advised, and it cannot follow up on anything the owner agreed to. That is the
-- difference between grounded Q&A and a coach, and `docs/COACH_ROADMAP.md` C1 names it.
--
-- ## Why a commitment and not a transcript
--
-- Storing conversations would keep the most and prove the least. What has durable value
-- is not what was SAID, it is what was AGREED — a sentence with a metric attached and a
-- date to look at it again. Everything else the coach can re-derive from the data it
-- already reads, and the roadmap's honesty guard says it must: memory is observations,
-- never a remembered number, because a number can be re-queried and a remembered one can
-- be stale.
--
-- So this table holds one row per agreement, and the transcript stays on the phone.
--
-- ## ⛔ `metric` is nullable, and that is the honest half
--
-- "I'll get to bed earlier" is a real commitment and names no metric this app tracks.
-- Forcing one would mean inventing an attribution — the coach picking `tst_min` and a
-- later reading being credited to a change nobody measured. A row with no metric is
-- remembered and asked about; it is never scored, and `challenge_outcome` is where
-- scoring lives.
--
-- ## The one-per-behaviour rule reaches here too
--
-- `challenges/commitment.py` refuses a second active commitment on the same behaviour
-- because the outcome ledger cannot attribute two changes over one window. A coach
-- commitment on a metric that already carries a live challenge is that same confound
-- through a new door, so the write path checks it. The database does not: the rule is
-- about ACTIVE rows across two tables and a partial unique index cannot express it, and
-- a constraint that half-expresses a rule is worse than one that does not pretend to.
--
-- Replay-safe; `migrate._apply_one` runs the file plus its ledger row in ONE transaction.

CREATE TABLE IF NOT EXISTS coach_commitment (
  id           BIGSERIAL    PRIMARY KEY,
  user_id      UUID         NOT NULL REFERENCES app_user(id)
                              ON UPDATE CASCADE ON DELETE CASCADE,
  -- What they said they would do, in their own words as the coach heard them.
  stated       TEXT         NOT NULL,
  -- The metric it should move, when there is one. NULL is a real answer — see above.
  metric       TEXT,
  -- When to ask. The coach sets a horizon; a behaviour change needs days to show.
  check_in_on  DATE         NOT NULL,
  -- open | kept | missed | dropped. `open` until the owner says otherwise: this app
  -- does not observe whether somebody did a thing, and a status the data inferred
  -- would be exactly the completion claim the product refuses to make.
  status       TEXT         NOT NULL DEFAULT 'open',
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  resolved_at  TIMESTAMPTZ
);

-- The one read this table has: "what is open for this owner, and what is due?"
CREATE INDEX IF NOT EXISTS coach_commitment_open_idx
  ON coach_commitment (user_id, status, check_in_on);

ALTER TABLE coach_commitment ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS coach_commitment_tenant ON coach_commitment;
CREATE POLICY coach_commitment_tenant ON coach_commitment FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);
