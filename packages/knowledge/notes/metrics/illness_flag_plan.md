---
id: illness_flag_plan
name: "Illness / recovery early-warning flag"
topic: Implementation plan — nightly illness/recovery early-warning flag from skin temp + RR baselines
category: metrics
grade: Probable
evidence_grade: 2
summary: "A nightly flag that compares the night's skin temperature and respiratory rate against the 14-night personal baseline and raises a moderate/high illness-recovery signal — the RR limb (≥ +2 br/min sustained over 2 nights) is validated (Smarr 2020, Quer 2021); the skin-temp limb's + 0.5 °C trigger is OUR heuristic, not a sourced threshold — framed as 'possible early signal, consider light recovery,' never a diagnosis (combined evidence ★★, skin temp the weaker limb)."
aliases: ["illness_flag", "illness flag", "early-warning", "recovery flag", "sick day", "implementation", "illness", "recovery", "dashboard"]
applies_to_metrics: ["skin_temp_c", "respiratory_rate_sleep", "hrv_sleep_avg", "rhr_daily"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
---

# Illness / recovery early-warning flag

## Summary
A nightly check compares the just-completed night's `skin_temp_c` and `respiratory_rate_sleep` against the user's 14-night personal baseline and raises an **illness/recovery flag** when both exceed the trigger values below: the respiratory-rate trigger follows the **Smarr 2020 / Quer 2021** sustained-elevation convention; the **+0.5 °C skin-temperature trigger is our own operating heuristic, not a sourced threshold** (see *Provenance of the +0.5 °C trigger*). It is surfaced as a small pill on the Today header the morning after, with explicit "possible early signal — consider light recovery" framing, **not a diagnosis**. Respiratory rate is the stronger, better-evidenced limb (★★★); skin temperature is the weaker limb (★★); combined evidence is **★★ moderate**. HRV drop, RHR rise, and logged symptoms boost confidence but are not part of the threshold.

## What it is
The flag is a **deterministic, non-LLM early-warning signal** derived from two overnight vitals whose personal stability makes a sustained over-baseline rise meaningful: respiratory rate (see `respiratory_rate_normal`) and skin temperature (see `skin_temp_signals`). It is information, not prescription — it says "consider lighter activity," never "you're sick" or "rest today."

## Physiology / mechanism
Infection and inflammatory activation raise overnight respiratory rate (chemoreceptor/sympathetic drive) and skin temperature (fever/vasodilation), and suppress HRV / raise RHR — all before a person consciously notices symptoms. Because these signals are personally stable night-to-night, a sustained multi-night deviation above the individual's own baseline is a genuine pre-symptomatic signal. The flag operationalises that convergence while respecting each signal's noise (MAD-robust thresholds, sustained-over-two-nights confirmation).

## The evidence
- **[Established] Respiratory rate ≥ +2 br/min sustained over 2 nights is a validated pre-symptom illness signal** [Smarr 2020 (n≈271k); Quer 2021]. This is the strong limb (★★★).
- **[Probable] Overnight wrist temperature adds illness-detection signal**, best in combination with other markers — wrist temperature plus HRV detects illness better than either alone [Mason 2022 (TemPredict)]. This is the weaker limb (★★).
- **[Our heuristic — unsourced] The specific ≥ +0.5 °C-above-14-night-median trigger.** No citation in this corpus establishes that number; see *Provenance of the +0.5 °C trigger* below. It is consistent with the ~0.3–0.5 °C personal-baseline deviation band `skin_temp_signals` describes, and it is set at the top of that band deliberately (the weaker, more confounded limb should fire less often), but that is a design argument, not evidence.
- **Combined evidence grade: ★★ moderate** (skin temp is the weaker limb, and its trigger value is unsourced).

### Provenance of the +0.5 °C trigger

This threshold was attributed to **"Lim 2024"** — a citation that **cannot be resolved and is being retired**, not repaired:

- The legacy note (`~/projects/healthee-legacy/research/metrics/illness_flag_plan.md`) that this note was reconciled from names "Lim 2024" twice and **has no References section at all** — so the citation never had a source in this project's history. The References entry that appeared here during reconciliation ("Lim et al. (2024). Skin-temperature illness-signal threshold") carried no journal, volume or DOI because there was nothing to carry; it was written to satisfy the shape of a References list.
- It was said to defer to `skin_temp_signals`, which **does not cite Lim anywhere** — the pointer led nowhere.
- A literature search for a 2024 first-author-Lim paper on wearable skin temperature and illness detection found nothing matching. (The one 2024 wearable-skin-temperature paper that recurs in results — Gombert-Labedens et al., *J Biol Rhythms* 39(4):331–350 — is menstrual-cycle cosinor modelling, has no Lim author, and reports no deviation threshold.) Secondary sources quoting a "0.5 °C above baseline" rule of thumb exist but trace back to vendor blogs, not to a primary study.

Per the citations-real-or-absent rule the citation is **removed rather than replaced with a plausible-looking one**. **The 0.5 value itself is unchanged** — it is a shipped threshold, and changing it is a science-code behaviour change that belongs in its own PR with known-value tests. What changes is that it is now labelled as ours.

## Recommendation

Build a nightly check that compares the just-completed night's
`skin_temp_c` and `respiratory_rate_sleep` against the user's 14-night
personal baseline; raise an **illness/recovery flag** when both exceed
the triggers below. Surface as a small alert pill on the Today header
morning-after, with explicit framing ("possible early signal — consider
light recovery"), not a diagnosis.

Evidence base:
- [[respiratory_rate_normal]] — ★★★ — RR ≥ +2 bpm sustained 2 nights
  is the validated illness pre-symptom signal (Smarr 2020, Quer 2021).
- [[skin_temp_signals]] — ★★ — overnight wrist temperature is a
  supporting illness/cycle signal as a personal-baseline delta
  (Mason 2022). **The + 0.5 °C trigger value is ours, unsourced** —
  see *Provenance of the +0.5 °C trigger*.

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

## How the coach uses it
- **Stage 1 (no 14-day baseline):** no flag is possible; stay silent (no "insufficient data" noise) and rely on the user's own reporting.
- **Stage 2 (moderate flag):** surface the muted pill with the underlying numbers and citation chips; suggest lighter activity today, framed as a possibility.
- **Stage 3 (high flag / sustained):** stronger (still non-alarming) framing; if logged symptoms include fever/chest pain/fainting, append the static "consider seeing a clinician" line without replacing the signal description.
- **Always:** the flag is a *prompt to consider recovery*, never a diagnosis, a medication cue, or a "rest today" order.

## Safety bounds
- **Never suggest medication, supplements, or a specific diagnosis** — mirrors the LLM health-advice guardrails even though no LLM is involved.
- Severity-flagged logged symptoms (fever, chest pain, fainting) in the last 48 h **append** a static "consider seeing a clinician" line; they never replace the neutral signal description.
- The flag never says "rest today" — only "consider light recovery."

## Honesty & uncertainty
- **Combined evidence is ★★ moderate**, gated by the skin-temperature limb.
- **The skin-temp trigger value is our heuristic, not a finding.** The ≥ +0.5 °C cut has no primary source (see *Provenance of the +0.5 °C trigger*); never present it, in UI or LLM output, as "studies show 0.5 °C." The sustained-two-night RR pattern is the part that carries a citation.
- **Cycle confound:** luteal-phase skin-temp rise (0.3–0.5°C) makes skin temp a weak mid-cycle illness signal; RR is the stronger lever, and this isn't solvable without cycle tracking.
- **Ambient temperature** can cause skin-temp false positives; the MAD threshold mitigates but does not eliminate them.
- **No data → no flag** (silent skip), so absence of a flag never means "healthy."
- The flag is **sensitive, non-specific, and pre-symptomatic** — it cannot name the cause.

## Bottom line
**Act on confidently:** a **sustained RR ≥ +2 br/min over 2 nights** as an early illness signal; the deterministic, non-alarming, "consider light recovery" framing; boosting confidence with HRV/RHR/logged symptoms.

**Hold loosely:** the skin-temperature limb (weaker, cycle- and ambient-confounded); any single-night or single-signal "mild" pattern (deliberately not surfaced); anything approaching illness classification.

## Coach Directives
1. Raise the flag only from a **14-day personal baseline (≥10 nights)**; if it can't be computed, skip silently — no "insufficient data" badge. *(confidence: moderate)*
2. **High** = `rr_delta ≥ 2.0` AND `temp_delta ≥ 0.5` AND prior night `rr_delta ≥ 1.5` (sustained); **Moderate** = one robust strong signal; **Mild** is never surfaced. *(moderate)*
3. Frame every flag as "possible early signal — consider light recovery," never a diagnosis, medication cue, or "rest today." *(high)*
4. **SAFETY:** never suggest medication/supplements/diagnosis; append "consider seeing a clinician" (without replacing the description) when severity-flagged symptoms are logged in 48 h. *(high)*
5. Surface citation chips (`respiratory_rate_normal`, `skin_temp_signals`) and the underlying deltas for transparency; auto-clear when deltas fall below the moderate thresholds. *(moderate)*

## References
- Smarr BL, Aschbacher K, Fisher SM, et al. (2020). *Feasibility of continuous fever monitoring using wearable devices.* Scientific Reports 10:21640 (n ≈ 271k; sustained-elevation illness convention). https://doi.org/10.1038/s41598-020-78355-6
- Quer G, Radin JM, Gadaleta M, et al. (2021). *Wearable sensor data and self-reported symptoms for COVID-19 detection.* Nature Medicine 27:73–77. https://doi.org/10.1038/s41591-020-1123-x
- Mason AE, Hecht FM, Davis SK, et al. (2022). *Detection of COVID-19 using multimodal data from a wearable device: results from the first TemPredict study.* Scientific Reports 12:3463. https://doi.org/10.1038/s41598-022-07314-0
- *(No reference backs the ≥ +0.5 °C skin-temperature trigger.* The former "Lim et al. (2024)" entry was unresolvable and has been removed rather than replaced — see *Provenance of the +0.5 °C trigger*. Citations here are real or absent.*)*

## Healthee implementation & honesty policy
- **Status: SHIPPED (this plan is implemented).** The `illness_flag` table exists and the latest active flag is read by `read/health_metrics.py::illness_flag_payload` (returns the flag within 2 days; auto-clears when deltas fall below threshold — no row means no flag). The user-facing string is produced by `_illness_framing` — **deterministic metric text, not an LLM** — e.g. "Possible early signal — consider lighter activity today. Breathing rate +X bpm vs your 14-day baseline; skin temperature +Y°C … Not a diagnosis," with the sustained-two-night ("Smarr 2020 / Quer 2021 pattern") suffix when applicable.
- **Inputs (v2 field names):** `respiratory_rate_sleep` (strong limb) and `skin_temp_c` (weak limb) as personal-baseline deltas; `hrv_sleep_avg` (v1 note wrote `hrv_sleep_avg_ms`) and `rhr_daily` as confidence-boosting cross-checks. `research_note_ids` on each flag cite `respiratory_rate_normal` + `skin_temp_signals`.
- **Honesty rules (carry into UI + LLM):** framing is fixed to "possible early signal / consider light recovery," never a diagnosis, illness name, medication, or "rest today"; no flag ever means "healthy" (data may be missing); severity-flagged symptoms only *append* a clinician line.
