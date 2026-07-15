---
id: sleep_need_debt
topic: Personal sleep need (age-based) and rolling cumulative sleep debt — the evidence-based version of Whoop/Oura "sleep need / debt"
evidence_grade: 2
applies_to_metrics: [asleep, sleep_need_min, sleep_debt_min, tst_min]
applies_to_interventions: []
tags: [sleep, circadian, recovery]
last_reviewed: 2026-06-05
---

## Finding

Two related, evidence-grounded quantities:

1. **Sleep need** — the nightly total-sleep target for the user. The National
   Sleep Foundation's 2015 consensus (panel of 18 experts, 300+ studies
   reviewed) gives age bands: **adults 18–64 → 7–9 h**, **older adults 65+ →
   7–8 h** (younger ages need more). We anchor each person's need at the band
   **midpoint** (8.0 h for 18–64, 7.5 h for 65+) as a defensible default, since
   no validated per-person "need" estimator exists from wearable data alone.

2. **Sleep debt** — the running shortfall of actual sleep vs need. Chronic
   partial sleep restriction accumulates a *cumulative* deficit whose cognitive
   cost grows night over night (Van Dongen 2003). We track a **rolling 14-night
   cumulative debt**:

   ```
   need_min        = age_band_midpoint (e.g. 480 min for 18–64)
   nightly_deficit = max(0, need_min − tst_min)        # only shortfalls add debt
   sleep_debt_min  = Σ over last 14 nights ( nightly_deficit )
                     − recovery_credit                 # see below
   ```

   Nights **above** need pay debt back (recovery sleep), but physiology only
   recovers a fraction of lost sleep per night — we credit surplus at **0.5×**
   (you don't fully "bank" extra sleep) and cap total debt at a sane ceiling
   (~ 2 nights' need) so a long gap doesn't read as an implausible deficit.

This is explicitly **not** a proprietary composite — it's arithmetic over one
measured quantity (total sleep time) against a cited target
([[feedback-no-composite-score]], [[sleep-duration-mortality]]).

## Effect size / what it quantifies

- NSF need is a *recommendation band*, not an effect size. The health backing for
  the 7–9 h target itself is the U-shaped duration↔mortality relationship
  (Cappuccio 2010; both < 6 h and > 9 h carry elevated risk) — see
  [[sleep-duration-mortality]].
- Van Dongen 2003: restricting sleep to 6 h/night for 14 nights degraded
  cognitive performance to a level equivalent to **2 nights of total sleep
  deprivation**, and the deficit **kept accumulating** without plateau — the
  empirical basis for treating debt as cumulative, not just "last night."

## Evidence strength

- **Hirshkowitz et al. (2015)** *Sleep Health* 1(1):40-43 — "National Sleep
  Foundation's sleep time duration recommendations: methodology and results
  summary." Structured expert consensus over 300+ studies. **★★★** for the
  age-band targets.
- **Van Dongen, Maislin, Mullington & Dinges (2003)** *Sleep* 26(2):117-126 —
  "The cumulative cost of additional wakefulness: dose-response effects on
  neurobehavioral functions…" Landmark controlled lab study; replicated by Belenky
  2003. **★★** for the cumulative-debt model (lab cognition endpoints, n small).
- **Cappuccio et al. (2010)** *Sleep* 33(5):585-592 — U-shaped duration↔all-cause
  mortality meta-analysis (n ≈ 1.4 M). Backs the *target* the need is set to.
  **★★★** (already in [[sleep-duration-mortality]]).

## Caveats

- Individual sleep need genuinely varies (a minority are short/long sleepers);
  the age-band midpoint is a population default, not a measured personal need.
  Surface it as "recommended", and let the user override their target.
- The 0.5× recovery credit and 14-night window are **modeling choices**, not
  validated constants — the literature establishes that debt accumulates and that
  recovery is partial, but not an exact payback coefficient. Keep them in flags
  and label the debt as an estimate.
- "Sleep debt" evidence is for **cognitive/alertness** outcomes, not a direct
  morbidity endpoint — don't imply medical risk from a few hours of debt.
- Total sleep time itself depends on wearable sleep-staging accuracy
  ([[wearable-sleep-stage-validity]]); TST is more reliable than per-stage splits.

## Operational use

- Compute `sleep_need_min` (age-band midpoint) and `sleep_debt_min` (rolling
  14-night, partial-recovery) as daily derived metrics.
- Surface as: **"Sleep need 8 h · you're 3.2 h in debt over 2 weeks"** with the
  trend, framed descriptively. Recommend (not prescribe) catch-up.
- Evidence label: **★★ moderate** for the debt model; the 7–9 h need band is
  ★★★. Always show "recommended need — adjust to yours."
