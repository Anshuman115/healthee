---
id: illness_flag_plan
topic: Implementation plan — nightly illness/recovery early-warning flag from skin temp + RR baselines
evidence_grade: 2
applies_to_metrics: [skin_temp_c, respiratory_rate_sleep, hrv_rmssd_ms, rhr_daily]
applies_to_interventions: []
tags: [implementation, illness, recovery, early-warning, dashboard]
last_reviewed: 2026-05-15
---

## Recommendation

Build a nightly check that compares the just-completed night's
`skin_temp_c` and `respiratory_rate_sleep` against the user's 14-day
personal baseline; raise an **illness/recovery flag** when both
exceed the Smarr 2020 / Lim 2024 thresholds. Surface as a small
alert pill on the Today header morning-after, with explicit framing
("possible early signal — consider light recovery"), not a diagnosis.

Evidence base:
- [[respiratory_rate_normal]] — ★★★ — RR ≥ +2 bpm sustained 2 nights
  is the validated illness pre-symptom signal (Smarr 2020, Quer 2021).
- [[skin_temp_signals]] — ★★ — skin temp ≥ +0.5°C above 14-day median
  is the cycle-tracking / illness signal (Mason 2022, Lim 2024).

Combined evidence grade: **★★ moderate** (skin temp is the weaker
limb).

## Trigger logic

For each `night N` (the just-completed sleep session):

1. Compute personal baselines over nights `[N-14, N-1]`:
   - `rr_med` = median of `respiratory_rate_sleep`
   - `rr_mad` = MAD of `respiratory_rate_sleep`
   - `temp_med` = median of `skin_temp_c`
   - `temp_mad` = MAD of `skin_temp_c`
   - Need ≥10 nights of data; else skip.
2. Compute night-N deltas:
   - `rr_delta = rr_N − rr_med`
   - `temp_delta = temp_N − temp_med`
3. **Flag tiers** (most → least severe):
   - **High** (both signals + sustained):
     - `rr_delta ≥ 2.0` AND `temp_delta ≥ 0.5`
     - AND night `N-1` also had `rr_delta ≥ 1.5` (sustained, the
       Smarr-2020 / Quer-2021 convention).
   - **Moderate** (single strong signal):
     - `rr_delta ≥ 2.0 AND rr_delta ≥ 1.5 × rr_mad` (robust)
     - OR `temp_delta ≥ 0.5 AND temp_delta ≥ 2.0 × temp_mad`
   - **Mild** (suggestive but inconclusive — don't surface):
     - any single-night `rr_delta ≥ 1.5` OR `temp_delta ≥ 0.3`
4. Pair with cross-checks (boosts confidence, not threshold):
   - HRV `hrv_sleep_avg_ms` drop > 1 SD from 14-day baseline
   - RHR rise > 1 SD from baseline
   - Manual `symptom` entries logged in last 48 h

## Persistence

New table:

```sql
CREATE TABLE IF NOT EXISTS illness_flag (
    date           DATE PRIMARY KEY,             -- wake date
    severity       TEXT NOT NULL CHECK (severity IN ('moderate', 'high')),
    rr_delta_bpm   REAL,
    temp_delta_c   REAL,
    hrv_delta_z    REAL,
    rhr_delta_z    REAL,
    sustained      BOOLEAN NOT NULL DEFAULT FALSE,
    research_note_ids TEXT[] NOT NULL,           -- e.g. {respiratory_rate_normal, skin_temp_signals}
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

(Or fold into the existing `finding` table with `kind='illness_flag'`
— decide at implementation; standalone table is cleaner for the UI
because we don't want this in the correlations stream.)

## Backend

- New function `_derive_illness_flag(day, conn)` in `derived.py`.
- Wired into nightly `derive` job (runs after sleep-session derive,
  before SRI / 4-dim).
- New endpoint `GET /api/illness` returns the latest flag (if any)
  + last-14-day baseline values for transparency.
- Or embed into `/api/today` as:
  ```json
  "illness_flag": {
    "severity": "moderate",
    "rr_delta_bpm": 2.4,
    "temp_delta_c": 0.6,
    "sustained": false,
    "research_note_ids": ["respiratory_rate_normal", "skin_temp_signals"],
    "framing": "Possible early signal — consider light recovery today.",
    "date": "2026-05-15"
  } | null
  ```

## Frontend

- Small pill on the Today header (just below the date) when set:
  - `severity='moderate'`: muted amber pill, single sentence.
  - `severity='high'`: coral pill, slightly stronger sentence.
- Tap → expands inline with the underlying numbers and the citation
  chips for `respiratory_rate_normal` + `skin_temp_signals`.
- **No alert/red-cross icon, no "warning" language** — frame as
  "early signal, consider recovery", not "you're sick".
- Auto-clears the morning the deltas drop below the moderate
  thresholds.

## Honest framing

UI copy must say what this is and isn't:

> "Your respiratory rate is 2.4 bpm above your 14-day baseline and
> skin temperature is 0.6°C higher. Studies (Smarr 2020, n=271k;
> Mason 2022) found these signals together can precede symptoms
> by 1–2 days. This is not a diagnosis."

## Guard rails

- **Never** suggest medication, supplements, or specific diagnoses.
  This aligns with [[llm_health_advice_safety]] — the same rules apply
  even though no LLM is involved here.
- If the user has logged `symptom` entries with severity-flagged
  content (fever, chest pain, fainting) in the last 48 h, **append**
  a static "consider seeing a clinician" line — do NOT replace the
  signal description.
- The flag is information, not prescription. UI never says
  "rest today" — it says "consider light recovery".

## Caveats baked into the flag

- **Cycle-tracking confound** (Mason 2022): in menstruating users,
  skin temp rises 0.3–0.5°C in the luteal phase. Skin-temp alone
  is therefore not a strong illness signal mid-cycle — RR is the
  stronger lever. This isn't currently solvable without cycle
  tracking; document the limitation in the UI footer.
- **Ambient temperature** affects skin temp; a hot night may
  trigger false positives. The MAD-based threshold mitigates but
  doesn't eliminate.
- **No data, no flag** — if 14-day baseline can't be computed,
  silently skip; don't show "insufficient data" badge (noise).

## Out-of-scope

- Specific illness classification (cold vs flu vs COVID etc).
- Push notifications. Surface in the Today page only.
- Wearing the strap during waking hours adds confidence to the
  signal but isn't required.
