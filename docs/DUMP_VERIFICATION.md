# Verifying the audits against real data

Seven audits raised items marked **could not determine** — questions about what
has actually happened, which reading code cannot answer. The owner's insight was
that the database can answer most of them without a device.

**Method.** `data/prod_dump/healthee_prod_2026-07-15_174246.sql.gz` restored into
a throwaway container. **Read-only queries; counts, dates and yes/no only — no
health rows were printed.** Production was never contacted.

**What this dump is, and its limits.** It is from **2026-07-15, the cutover day**
— 4 months of history (2026-03-13 → 07-15), 459,229 samples, 127 sleep sessions,
103 workouts, 125 derived days, 569 findings. It **predates multi-user**: there
is no `app_user` table, and metric names are the v1 forms (`hr`, not
`heart_rate`). It also predates migration `0017`, so `device_daily_total` does
not exist in it. Anything about *current* behaviour it cannot settle.

---

## Answered

### 1. The TRIMP unit mismatch has a magnitude, and it is ZERO
`BACKEND_AUDIT` A10 found session TRIMP summed per HR **sample** where the daily
one sums per **minute**, and could not size the error without knowing the
strap's in-workout cadence. Two audits called this device-only. It is not — the
cadence is in the `sample` table.

**Measured across 2,017 workout minutes: mean 1.00, median 1, max 1 sample per
minute.** One reading per minute exactly. So the two summations are arithmetically
identical at this cadence and **no historical value was inflated.** The unit
mismatch was real and worth fixing; its consequence was nil.

### 2. No future-dated derived rows
`BACKEND_AUDIT` A11's missing closing edge is **latent, not live** — zero rows
dated beyond the dump date. Fixed on its own merits regardless.

### 3. The fabricated sleep zeros never fired
The defect that cost the most argument today — a night with no stage breakdown
reporting as zero sleep — **never occurred in this data.** Zero of 127 sessions
have an all-zero breakdown, and zero have a NULL stage column. The defect was
real in the code and **latent in practice**.

### 4. Two main sleep sessions on one wake date DO happen
`WRITE_PATH` B7 was marked "needs the device". **Nine wake dates carry more than
one main session**, and **three of those nine span more than 14 hours** — too
long to be one interrupted night, so genuinely separate sleeps filed to one date.
The audit's decision to *detect and warn* rather than silently merge was right,
and this is the evidence it lacked.

### 5. Sixteen zero-step days, and the strap was worn on every one
`FINAL_AUDIT`/C7 asked whether an unworn day is stored as zero steps. **16 of 125
derived days carry `steps_total = 0`, and all 16 have samples on that date** — so
the strap was on the wrist and recording other metrics.

These are not unworn days. They are days the **per-minute step stream produced
nothing while the device was live**, which is the stall `#121` documents. The C7
fix explicitly does **not** cover this case, and said so: it separates *no data*
from *zero*, not *worn-but-silent* from *genuinely still*.

⚠ **This is the strongest evidence yet for re-checking the strap.** The owner
believes the per-minute stream may be healthy again. If it is, these 16 days are
historical damage; if it is not, they are ongoing.

---

## Not answerable from this dump

Because it predates multi-user and `0017`, and is 8 weeks old:

- whether the coach's timeout has charged the owner (needs current prod)
- whether a forced back-fill has run
- whether the chain marker has swallowed a failed step
- whether a regressing step counter has occurred (`device_daily_total` absent)
- whether prod sets `POSTGRES_APP_*` — a one-line operator check, not a query
- whether the profile upsert has erased a date of birth

**A current dump would settle all six.** None needs a device.

---

## What this exercise showed about the method

Two audits called the TRIMP magnitude device-only, and I repeated it. It was
answerable from a table we already had. **"Needs a device" deserves the same
scepticism as any other claim** — the question is what evidence would settle it,
not what instrument feels natural.
