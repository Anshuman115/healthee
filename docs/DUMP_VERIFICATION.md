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

---

# Part 2 — current production, read-only

The July dump could not settle six items. Rather than copy the owner's health
history onto a laptop, these were answered with **targeted `SELECT`s on the box**
— counts and dates only, no health rows, no writes, no re-derive.

Current scale: **1 owner · 2026-03-13 → 2026-09-08 · 706,000 samples · 207 sleep
sessions · 32 `device_daily_total` days · 759 findings · subscription active.**

### RLS is genuinely enforced — `AUTH_AUDIT` B1 CLOSED
`pg_roles` carries both identities: `healthee` (superuser, bypasses RLS) and
`healthee_app` (neither). **`pg_stat_activity` shows the live API connected as
`healthee_app` on 4 connections**, with 2 admin connections beside it. The
superuser fallback exists in code and **production is not using it**. The
hardening added this pass makes that structural rather than lucky.

### The date of birth has not been erased — `WRITE_PATH` B2 latent
`dob` present, 1 of 1 profiles. The clobbering upsert was real and never fired.

### The fabricated sleep zeros never fired here either
**0 of 207** sessions carry an all-zero stage breakdown, at 207 sessions rather
than the dump's 127. Latent in code, absent in fact, on current data.

### No future-dated derived rows
Zero, checked against the owner's own timezone.

### ★ The per-minute step stream HAS recovered — the owner was right
The owner said *"i think the perminute works now"*. The data agrees, and dates
the recovery precisely:

| | zero-step days |
|---|---|
| before 2026-08-03 | **16** |
| on/after 2026-08-03 | **1** |

**2026-08-03 is the day `device_daily_total` starts** — the `#121` fix. And the
per-minute stream itself is alive: **3,692 `steps_per_minute` rows across 31 of
the last 30 days.** Provenance now splits 144 days `steps_per_minute`, 32
`strap_0x16`, 4 unlabelled.

⇒ **`#121`'s precedence rule deserves revisiting.** `derive/device_totals.py`
prefers the strap's daily counter *because the per-minute stream stalled*. That
premise is measurably weaker than it was. This is not a defect — it is a
standing rule whose justification has changed, which is exactly the kind of thing
that goes unexamined for years.

### Still open, and why
The **coach-timeout charge** and the **chain marker swallowing a failed step**
cannot be settled by counting: the ledger holds one allowance row and `kv` one
`job:chain_done` marker, neither of which records a *history* of attempts. Both
fixes are in and guarded by tests; whether the old defects ever fired is not
recoverable from state. Recording that as unknowable rather than unknown.

## Not answerable from the July dump

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
