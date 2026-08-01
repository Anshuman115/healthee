-- 0013_challenge_program_fk — tie a rung to its ladder in the DATABASE.
--
-- `0001` declared `challenge.program_id BIGINT` with no foreign key (legacy's shape,
-- ported), so nothing in the database says a rung belongs to a program. WP-C4b's
-- `program_store.delete_suggested_programs` therefore deletes the rungs in APPLICATION
-- CODE and says so in its own docstring — a structural guarantee written as a habit,
-- which is the class of thing that survives exactly as long as everyone remembers it.
--
-- ## ON DELETE CASCADE — the rungs go with the ladder
--
-- The alternative is `SET NULL`, and it is worse in every case that can actually occur:
-- a rung is not a challenge that happens to be numbered. It carries `rung_index` (an
-- ORDERING inside one ladder, meaningless without it) and it is `locked` until the
-- ladder activates it, and `lifecycle.adopt` refuses anything that is not `suggested`.
-- So an orphaned rung is invisible to the feed, unadoptable by the owner, and
-- unreachable by `ladder` — silent litter that nothing can explain. An orphaned ACTIVE
-- rung would be worse: a live commitment nobody adopted, whose `challenge_outcome`
-- would then enter the ledger as a standalone result and mis-teach the next generation.
--
-- The cost of CASCADE is that deleting a program destroys its rungs and (via `0009`'s
-- `challenge_outcome.challenge_id` FK) their outcomes. That is acceptable because of
-- WHEN a program is ever deleted: only `delete_suggested_programs`, which deletes
-- `suggested` ladders whose rungs are all `locked` and have never run, so there is no
-- history to lose. A ladder that ENDED is never deleted — it is marked `completed` /
-- `stalled` / `abandoned` (`0010` added the vocabulary precisely so it would not have
-- to be). The other deletion path is the `app_user` cascade (§4.5), where the whole
-- owner is going anyway.
--
-- ## ON UPDATE CASCADE — not optional in this repo
--
-- `MULTI_USER.md` §3.2 mandates it for FKs to `app_user`, and the same argument holds
-- one table down: a FK without one does not silently skip a re-key, it ERRORS. `0006`
-- had to go back and add it for `device_token` after exactly that, and §12.2's
-- `subscription` sketch omitted it and would have broken `claim_sentinel` a second
-- time. Written in from the start here.
--
-- ## Not a composite (user_id, program_id) FK
--
-- That would also make a cross-tenant rung structurally impossible, but it needs a
-- UNIQUE (user_id, id) on `program` carried forever for a case no code path can reach:
-- every rung insert takes its owner from the same transaction that fetched or created
-- the program (`program_store`), and `0008`'s RLS plus the explicit `AND user_id = %s`
-- already fail that read closed. Noted as considered, not silently skipped.
--
-- ## Existing rows
--
-- Checked against prod before writing: `challenge`, `program` and every `program_id`
-- are empty there (the challenges track is unshipped), so the constraint lands on rows
-- that cannot violate it. If some deployment does hold a dangling `program_id`, this
-- ALTER FAILS LOUDLY rather than repairing it — nulling it would silently convert an
-- owner's rung into a standalone commitment and deleting it would erase a commitment
-- they made. Neither is a decision a migration gets to take on health data.
--
-- Replay-safe: the constraint is dropped by name first, as `0006` does.

ALTER TABLE challenge DROP CONSTRAINT IF EXISTS challenge_program_id_fkey;
ALTER TABLE challenge ADD CONSTRAINT challenge_program_id_fkey FOREIGN KEY (program_id)
  REFERENCES program(id) ON UPDATE CASCADE ON DELETE CASCADE;

COMMENT ON COLUMN challenge.program_id IS
  'The ladder this challenge is a rung of, or NULL for a standalone commitment. '
  'ON DELETE CASCADE: rungs are meaningless without their program, and the only '
  'program ever deleted is an un-adopted suggestion whose rungs never ran.';
