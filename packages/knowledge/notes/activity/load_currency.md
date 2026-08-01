---
id: load_currency
name: "Load Currency — TRIMP vs TSS (why Healthee reasons over one unit)"
topic: "Load-currency reconciliation — Healthee's internal HR-based Banister TRIMP (cardio_load) vs external power/pace-based TSS; they are different constructs and are not interchangeable"
category: activity
grade: Probable
summary: "Healthee's load currency is Banister TRIMP (HR-based, `cardio_load`); TSS is power/pace-based. They measure different things (internal vs external load), do not convert one-to-one, and must not be mixed — ACWR and readiness reason over TRIMP only."
aliases: ["load-currency", "trimp vs tss", "internal load", "external load", "load unit", "cardio_load currency", "trimp tss conversion", "session load unit"]
tags: [methodology, training-load, trimp, tss, cardio-load, heart-rate]
applies_to_metrics: ["cardio_load"]
applies_to_interventions: [exercise]
population: general
last_reviewed: 2026-07-15
---

# Load Currency — TRIMP vs TSS

## Summary
Two different "training load" numbers appear across the corpus, and they are **not the
same unit**. Healthee's internal load — the one it actually derives and reasons over —
is **Banister TRIMP**, an **internal, heart-rate-based** measure surfaced as
`cardio_load`. The sports-science docs also reference **TSS** (Training Stress Score),
an **external, power/pace-based** measure. TRIMP asks *how hard did the cardiovascular
system work?* (measured from HR); TSS asks *how much external work was done relative to
threshold?* (measured from power or grade-adjusted pace). They correlate at the group
level but are **different constructs with no universal conversion factor**. The single
coaching takeaway: **Healthee reasons over exactly one load currency — TRIMP
(`cardio_load`) — for ACWR, baselines and readiness**, because it has heart rate but no
power meter and no FTP. TSS is documented for cross-reference and shared vocabulary
only; never mix the two units in one trend or convert between them with a fixed factor.

## What it is
A "load currency" is the unit a session's overall stress is expressed in before it is
summed into daily load, baselines, and acute:chronic trends. Two families exist:

- **Internal load** — quantifies the *body's response* to the effort. Heart-rate-based
  **TRIMP** (Training Impulse) is the canonical example: it reads physiological strain
  off HR. Session-RPE (RPE × minutes) is another internal measure.
- **External load** — quantifies the *mechanical work produced*, independent of how the
  body coped. **TSS** (and its running variant rTSS) is the canonical example: it scores
  normalized power (or grade-adjusted pace) relative to a threshold.

The same session yields a TRIMP number and a TSS number that are **not equal and not
proportional across people or session types** — a hot, under-slept day inflates HR (and
thus TRIMP) at unchanged external work (unchanged TSS), which is exactly the internal-vs-
external distinction.

## Physiology / mechanism
HR-based internal load and power-based external load diverge because HR is a *response*
variable and power/pace is an *input* variable. For a fixed external workload, HR (and
therefore TRIMP) rises with heat, dehydration, fatigue, caffeine, altitude and
cardiovascular drift, while external work (and therefore TSS) does not. Conversely, for
very short maximal or eccentric efforts, HR lags the true mechanical stress, so TRIMP
*under*-reads work that TSS captures. Because the two respond to different perturbations,
there is no physiological constant that maps one onto the other for an individual.

## The evidence
- **[Established]** **TRIMP and TSS are defined differently.** TRIMP = duration ×
  HR-reserve fraction × a lactate-derived weighting [Banister 1991]; TSS = duration ×
  intensity-factor² × 100 with intensity from power/pace [Coggan & Allen 2010]. These are
  the authors' own definitions, not in dispute (see *How we compute it* for the verified
  formulae).
- **[Probable]** **They correlate but are not interchangeable.** In well-trained cyclists,
  TSS correlated strongly with an individualised bioenergetic TRIMP (r ≈ 0.88) and TRIMP
  with sRPE (r ≈ 0.90) [Moya-Ramón et al. 2018]; HR-TRIMP variants agree with each other
  and with sRPE across sports (r ≈ 0.7–0.95) [Haddad et al. 2017; Edwards 1993]. A strong
  *group-level* correlation is not a *per-person conversion*: agreement varies between
  individuals, intensities and session types — sRPE–TRIMP agreement is weaker for
  high-intensity than low-intensity work [Haddad et al. 2017].
- **[Probable]** **Internal and external load can rank sessions and athletes differently.**
  A criterion-validity study against measured O₂ cost found external work the most
  valid/reliable quantifier while HR-TRIMP and sRPE showed poorer reliability [Wallace et
  al. 2014]; other work found individualised *internal* metrics competitive with or better
  than external TSS for tracking fitness change [Sanders et al. 2017]. Whichever is
  "better" is unsettled — but the fact that they disagree is the point: there is **no
  settled winner and no universal factor to translate one into the other.**
- **[Myth]** "A TRIMP can be converted to a TSS (or vice versa) with a fixed multiplier."
  No such constant exists. Any conversion would have to be re-derived per person, per
  intensity, and per environmental condition — which defeats the purpose of a single
  currency [Moya-Ramón et al. 2018; Wallace et al. 2014].

## How we compute it
Healthee computes **only TRIMP**; TSS is shown here for definition/cross-reference.

**Banister TRIMP — Healthee's `cardio_load` (VERIFIED against Banister 1991):**
```
ΔHR   = (HR_ex − HR_rest) / (HR_max − HR_rest)     # Karvonen HR-reserve fraction, 0–1
y     = 0.64 · e^(1.92 · ΔHR)   (men)              # lactate-derived weighting
        0.86 · e^(1.67 · ΔHR)   (women)
TRIMP = Σ_minutes ( 1 min · ΔHR · y )
```
Inputs: per-minute `hr`, measured `rhr_daily`, Tanaka HR_max (`208 − 0.7 × age`). Full
derivation, Edwards zone breakdown, and the Strain 0–21 rescale live in
`training-stress-score`.

**TSS — for cross-reference only (VERIFIED against Coggan/TrainingPeaks):**
```
IF  = normalized_intensity / threshold_intensity   # NP/FTP (power) or NGP/FTPace (run)
TSS = duration_hours × IF² × 100                    # 1 h at threshold = 100 by definition
```
Equivalently `TSS = (duration_sec × NP × IF) / (FTP × 3600) × 100`. Healthee cannot
compute this: it has **no power meter, no FTP, and no reliable per-second pace** — only
HR — so IF is unobtainable.

## How the coach uses it
- **One currency, always.** Every load surface — daily `cardio_load`, personal 7-/30-day
  baselines, and the acute:chronic ratio in `training-load-acwr` — is denominated in
  **TRIMP**. The coach never sums, averages, or ratios TRIMP against a TSS figure.
- **If a user quotes a TSS** (from Strava/TrainingPeaks/Garmin), treat it as a *separate,
  external* number: acknowledge it, but do not convert it into `cardio_load` or splice it
  into Healthee's trend. Explain that it measures external work, whereas Healthee's load
  measures the cardiovascular response.
- **Readiness reasons over TRIMP too.** Acute load, load-vs-baseline, and any "you're
  carrying fatigue" cue derive from `cardio_load`, keeping the readiness picture internally
  consistent.

## Safety bounds
- Load-management guardrails (progression limits, the long-run-spike check in
  `training-load-acwr`) operate on the **TRIMP** currency only; do not gate on a
  user-supplied TSS.
- Never silently substitute a TSS for a missing TRIMP, or vice versa — a fabricated
  conversion would corrupt the load history and the honesty contract. "No TRIMP available"
  is a distinct state from "low load" and must stay distinguishable.

## Honesty & uncertainty
- **No conversion is offered because none is valid.** Healthee will not print a
  "TRIMP ≈ TSS" equivalence; the two are different constructs and any factor would be
  wrong for some person, intensity, or day.
- **TRIMP is internal, so it moves with confounders** (heat, sleep, caffeine, HR_max
  estimation error) that external TSS is blind to — which is a feature for a *cardiovascular
  response* signal but means absolute TRIMP is a personal-trend number, not a cross-person
  absolute.
- **The "which is better" debate is genuinely open** [Sanders 2017; Wallace 2014]; Healthee
  does not claim TRIMP is superior to TSS, only that TRIMP is the currency it can *measure*
  from a wrist HR strap, and consistency (one currency) beats mixing units.

## Bottom line
**Act on confidently:**
- TRIMP (internal, HR) and TSS (external, power/pace) are **different constructs**; use one
  currency and do not convert between them [Banister 1991; Coggan & Allen 2010].
- Healthee's single load currency is **Banister TRIMP = `cardio_load`**, because it has HR
  but no power/FTP; ACWR and readiness reason over it.

**Hold loosely:**
- Whether internal or external load better predicts adaptation/injury — unsettled, small
  and mixed samples [Sanders 2017; Wallace 2014; Moya-Ramón 2018].

## Coach Directives
1. Denominate **all** Healthee load surfaces (daily load, baselines, ACWR, readiness) in
   **TRIMP (`cardio_load`)**; never mix in a TSS figure. — confidence: high
2. **Never convert** TRIMP↔TSS with a fixed factor, or present the two as equivalent — no
   universal conversion exists. — confidence: high *(SAFETY-CRITICAL: a fabricated
   conversion corrupts the load history)*
3. Treat a user-supplied TSS as a **separate external metric** — acknowledge it, explain
   the internal-vs-external difference, but keep it out of Healthee's trend. — confidence: high
4. If TRIMP is unavailable for a session, report **"no load computed"**, never a
   substituted/estimated TSS. — confidence: high

## References
- Banister, E. W. (1991). *Modeling elite athletic performance.* In MacDougall, J. D.,
  Wenger, H. A., & Green, H. J. (Eds.), *Physiological Testing of the High-Performance
  Athlete* (2nd ed., pp. 403–424). Human Kinetics. (Origin of TRIMP: duration × HR-reserve
  × lactate weighting.)
- Coggan, A. R., & Allen, H. (2010). *Training and Racing with a Power Meter* (2nd ed.).
  VeloPress. (Defines TSS = duration × IF² × 100, IF = NP/FTP, 1 h at FTP = 100 TSS.)
- Moya-Ramón, M., Javaloyes, A., & Sarabia, J. M. (2018). *TRIMP concurrent validity for
  cycling.* Journal of Science and Cycling, 7(1), 17–23. (TSS–TRIMP r ≈ 0.88; TRIMP–sRPE
  r ≈ 0.90 — group-level agreement, not per-person conversion.)
- Haddad, M., Stylianides, G., Djaoui, L., Dellal, A., & Chamari, K. (2017). *Session-RPE
  method for training load monitoring.* Frontiers in Neuroscience, 11, 612.
  https://doi.org/10.3389/fnins.2017.00612
- Wallace, L. K., Slattery, K. M., Impellizzeri, F. M., & Coutts, A. J. (2014).
  *Establishing the criterion validity and reliability of common methods for quantifying
  training load.* Journal of Strength and Conditioning Research, 28(8), 2330–2337.
  https://doi.org/10.1519/JSC.0000000000000416
- Sanders, D., Abt, G., Hesselink, M. K. C., Myers, T., & Akubat, I. (2017). *Methods of
  monitoring training load and their relationships to changes in fitness and performance in
  competitive road cyclists.* International Journal of Sports Physiology and Performance,
  12(5), 668–675. https://doi.org/10.1123/ijspp.2016-0454
- Edwards, S. (1993). *The Heart Rate Monitor Book.* (Summated-HR-zone TRIMP variant.)

## Healthee implementation & honesty policy
- **Field name:** `cardio_load` in `derived_daily` (Banister TRIMP), summed over all
  non-sleep per-minute HR. `derive/` computes it verbatim from the Banister formula above
  (science code is sacred — cited, known-value tested, never simplified).
- **One canonical currency:** ACWR (`training-load-acwr`), the personal 7-/30-day
  baselines, and readiness all read `cardio_load`. There is intentionally **no** TSS field
  in the schema — Healthee lacks the power/pace/FTP inputs to compute one.
- **Honesty rule (the reason this note exists):** the corpus references both TRIMP and TSS,
  so the coach must not conflate them. Do **not** convert between the units, do **not**
  present a TSS as if it were `cardio_load`, and do **not** claim one is universally better.
  A user's external TSS and Healthee's internal TRIMP are two honest but different answers
  to two different questions; keeping them separate is what keeps the load history truthful.
