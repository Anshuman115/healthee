-- 0014_profile_srpa — the owner answers Jurca's activity question themselves (#108).
--
-- Jurca 2005's non-exercise CRF model takes five inputs. Four of them (age, sex, BMI,
-- resting HR) we measure. The fifth is a SELF-REPORTED five-level physical-activity
-- category, and until now we synthesised it from step cadence — banding the trailing
-- 7 days of MVPA-equivalent minutes at 10/20/60/180 min/wk.
--
-- That crosswalk was never published by anyone, and it crosses two different constructs.
-- Jurca's NASA levels are stated in terms of DELIBERATE EXERCISE ("Aerobic exercise such
-- as run/walk for 1 to 3 hours per week"), with level 1 explicitly covering "Little
-- activity other than walking for pleasure". A cadence detector sees minutes above 100
-- steps/min and cannot tell the two apart. Measured on the real owner: 159 min/wk of
-- MVPA-equivalent, every minute of it moderate (zero vigorous), 107 of it on a single
-- day, from someone who states plainly that he does not exercise — scored SR-PA-3 and
-- paid 5.5 years of biological age for walking.
--
-- NULLABLE, and nullable is the load-bearing part. `derive/vo2max.py` WITHHOLDS the
-- estimate while this is NULL rather than defaulting to 0: the reference category is not
-- "unknown", it is the claim "you are inactive", and inventing that is the same defect
-- one direction over. So no backfill and no DEFAULT — every existing owner starts
-- unanswered and gets the "here is what we need" state until they answer.
--
-- Replay-safe (IF NOT EXISTS) and non-blocking: adding a nullable column with no default
-- is a catalogue-only change in PG11+, no table rewrite. `migrate._apply_one` runs the
-- whole file plus its ledger row in ONE transaction.

ALTER TABLE profile ADD COLUMN IF NOT EXISTS srpa SMALLINT;

-- Named so a later migration can find it; the range is Jurca's five levels, 0-4.
ALTER TABLE profile DROP CONSTRAINT IF EXISTS profile_srpa_range;

ALTER TABLE profile ADD CONSTRAINT profile_srpa_range CHECK (srpa BETWEEN 0 AND 4);
