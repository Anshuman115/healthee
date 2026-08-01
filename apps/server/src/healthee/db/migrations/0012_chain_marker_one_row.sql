-- 0012_chain_marker_one_row — fold the per-day chain markers into one row per owner.
--
-- `jobs/chain.py`'s dedup marker was keyed `job:chain_done:<local-day>`, so `kv` gained
-- ONE ROW PER OWNER PER DAY, forever, and nothing swept it. One owner is 365 rows a
-- year; a thousand owners is 365k rows a year of pure bookkeeping on a table the
-- scheduler reads on every five-minute tick. Measured on prod before writing this:
-- 16 rows, `job:chain_done:2026-07-17` … `job:chain_done:2026-08-01`, one owner, one
-- per day since the cutover deploy — exactly the arithmetic, live and still growing.
--
-- The fix ships in two halves and this is the data half. The code half puts the day in
-- the VALUE under a constant key, which is what `core/rate_limit.py` had already chosen
-- (it documented the divergence from this marker rather than copying the leak) — one
-- row per owner for the life of the account. Standards §Performance: unbounded data is
-- windowed.
--
-- The value carried over is the MAXIMUM day found, not an arbitrary one: the new marker
-- is a high-water mark ("the chain has run through this day"), and taking anything
-- lower would re-run — and re-send the briefing for — days that had already completed.
--
-- No code tolerates the old shape, and it does not have to: `infra/deploy.sh` stops api
-- AND scheduler *before* it migrates and recreates them after (steps 5→8), so this runs
-- with nothing reading `kv`. Old-shape rows exist before it and none after it; a
-- transitional read path would be dead code by the time it landed.
--
-- Replay-safe: the SELECT finds nothing on a second run, and the ON CONFLICT keeps the
-- marker the running code has since advanced. `migrate._apply_one` runs the whole file
-- plus its ledger row in ONE transaction.

-- `\_` escapes the LIKE wildcard: an unescaped `_` matches ANY character, so the naive
-- pattern would also claim a hypothetical `job:chainXdone:…` key.
INSERT INTO kv (user_id, key, value)
  SELECT user_id, 'job:chain_done', max(split_part(key, ':', 3))
    FROM kv
   WHERE key LIKE 'job:chain\_done:%'
   GROUP BY user_id
      ON CONFLICT (user_id, key) DO UPDATE SET value = greatest(kv.value, EXCLUDED.value);

DELETE FROM kv WHERE key LIKE 'job:chain\_done:%';
