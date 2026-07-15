---
id: sleep_timing_chronotype
name: "Sleep timing, chronotype & the CVD-lowering bedtime"
topic: Sleep timing (when to sleep/wake), chronotype, and the bedtime that lowers CVD risk
category: sleep
grade: Probable
evidence_grade: 2
summary: "Sleep onset ~10–11 PM with 7–8 h and a ~6:30–7 AM wake sits at the lowest-CVD-risk window (U-shaped; Nikbakhtian 2021), but consistency of timing matters more than the exact clock time, and for night owls a consistent wake time plus gradual morning-light shift beats a forced early bedtime."
aliases: ["sleep timing", "when to go to bed", "best bedtime", "bedtime", "chronotype", "night owl", "early bird", "10pm bedtime", "sleep onset time", "wake time", "social jetlag"]
applies_to_metrics: ["sleep_health_score_4dim", "sleep_regularity_index"]
applies_to_interventions: ["sleep_timing", "bedtime_consistency", "morning_light", "wind_down"]
population: general
last_reviewed: 2026-07-15
related: ["sleep_regularity_index", "sleep_consistency", "morning_light_circadian", "sleep_duration_mortality", "no_validated_sleep_score"]
tags: [sleep, circadian, bedtime, chronotype, cardiovascular]
---

# Sleep timing, chronotype & the CVD-lowering bedtime

## Summary

There is no single magic clock time, but the evidence converges on a window:
**sleep onset ~10:00–11:00 PM, 7–8 h of sleep, waking ~6:30–7:00 AM** — with the
strong caveat that *consistency* of that timing matters more than the exact time
(see `sleep_regularity_index`). Going to bed both too late and too early associates
with higher cardiovascular risk (a U-shape). The mechanism is circadian: a late
onset reduces morning bright-light exposure, which is what resets the body clock.

## What it is

Sleep timing is *when* the sleep episode falls on the clock (onset, midpoint,
wake), as distinct from its duration or regularity. **Chronotype** is a person's
biological disposition toward earlier ("lark") or later ("owl") timing. This note
covers the CVD-risk evidence for *when* to sleep, and how to reconcile the
population "sweet spot" with an individual's chronotype. The regularity of the
schedule (`sleep_regularity_index`) is a higher-value lever than the exact time.

## Physiology / mechanism

The mechanism behind the timing effect is **circadian**: a late sleep onset pushes
wake later and cuts morning bright-light exposure, which is the dominant zeitgeber
that resets (phase-advances) the central clock (`morning_light_circadian`). Chronic
late timing therefore drifts and destabilises the clock, misaligning it from
metabolic and cardiovascular rhythms. Much of the *night-owl* health risk is not
the late clock per se but **social jetlag** — being forced awake early against a
late body clock, creating chronic sleep loss.

## The evidence

### The bedtime sweet spot (~10–11 PM) [Probable]

- **Nikbakhtian et al. 2021** (Eur Heart J Digital Health 2(4):658–666; UK Biobank,
  n = 88,026, accelerometer-derived onset, mean age 61, 58% female, 5.7 y
  follow-up, 3,172 CVD events). Incidence per 100 person-years was U-shaped:
  **2.78 for 10:00–10:59 PM (lowest)**, 3.32 for 11:00–11:59 PM, 4.29 after
  midnight, 3.82 before 10 PM. Fully-adjusted HRs vs the 10–11 PM reference:
  **1.25 [1.02–1.52] after midnight, 1.12 [1.01–1.25] for 11–11:59 PM, 1.24
  [1.10–1.39] before 10 PM**. Adjusting for sleep duration *and* irregularity did
  **not** attenuate it → timing acts independently.
  *[figures primary-source verified 2026-06-09 vs the published article]*
- **Sex difference (large):** in women, after-midnight HR 1.63 and before-10 PM HR
  1.34; in men only before-10 PM was significant (HR 1.17).
- **AHA 2025 scientific statement** notes a 10–11 PM bedtime window discriminates
  cardiovascular risk factors among adults.

Honesty check: all observational (association, not causation). The "before 10 PM is
also bad" arm is the weakest — that group was small and very early bedtimes can be
a marker of underlying illness (they re-ran models excluding the first 12–18 months
to address reverse causation; it held). Cohort is mostly white-British and
"healthier/wealthier." **COI:** all authors were employees of Huma Therapeutics (a
digital-health company promoting wearables as CVD tools).

### Duration: 7–8 h [Established]

AASM recommends adults sleep **≥ 7 h**; < 7 h is consistently detrimental to
cardiovascular health and ≥ 9 h also associates with worse outcomes. A ~10:30 PM
onset with a ~6:30 AM wake hits this window naturally.

### Regularity beats timing [Established]

The higher-value lever is keeping timing **consistent** — see
`sleep_regularity_index`. Windred 2024 found regularity a stronger mortality
predictor than duration; the concrete target is sleep/wake within a **~1-hour band**
day to day, weekends included.

### Chronotype (night owls) [Probable]

- Chronotype is **partly genetic** (300+ identified markers) but **modifiable** via
  light exposure, meal times, caffeine, and exercise. Much of the night-owl health
  risk (mood/anxiety disorders, T2D, hypertension) comes from **social jetlag** —
  being forced awake early against a late body clock, creating chronic sleep loss —
  rather than the late clock per se.
- For a strong night owl: **prioritize a consistent wake time first**, then nudge
  the schedule gradually earlier with **morning bright light** and earlier meals,
  rather than forcing a drastic jump.

## How we compute it

Timing feeds the **Timing** dimension of `sleep_health_score_4dim` (sleep midpoint
in [02:00, 04:00) local → 1 point; `derive/sleep_score.py`), and the schedule's
stability is captured by `sleep_regularity_index`. There is no standalone
"chronotype" derived metric; chronotype is a user attribute the coach reasons over.

## How the coach uses it (and for THIS user)

This user is a **chronic short sleeper (~3.7 h)** — see `user_chronic_short_sleep`.
The realistic order of operations:

1. **Anchor a consistent bedtime first** (regularity > exact time). A nightly
   **bedtime reminder** (wind-down nudge ~45 min before, then at target) is the
   intervention this note backs — keep onset inside a ~1-hour band.
2. **Aim the target at ~10:30–11:00 PM** if feasible; the win for a short sleeper is
   as much *extending* total sleep as shifting it.
3. **Bright light shortly after waking** to anchor the clock (it's the mechanism
   doing much of the work behind the timing effect).
4. Surface this in the coach as concrete behaviour, not the abstract score: "Bed by
   10:45, same time tomorrow — consistency is the biggest lever you have."

## Safety bounds

No physiological guardrail. Do not present timing associations as causal health
threats (see below). Very early bedtimes can be a marker of underlying illness —
don't reassure or alarm on the timing number alone.

## Honesty & uncertainty

- **What NOT to do:**
  - Do NOT present the U-shape as causal ("sleeping before 10 PM will kill you"). It
    is observational, the early arm is weak, and the dataset has a commercial COI.
  - Do NOT prescribe a one-size bedtime ignoring chronotype — for a night owl, a
    consistent wake time + gradual shift beats a forced early bedtime.
- All timing evidence is observational; the Nikbakhtian cohort is mostly
  white-British, healthier/wealthier, with an all-author commercial COI (Huma).
- The "before 10 PM is also bad" arm is the weakest (small group; possible
  reverse causation, addressed but not eliminated).
- Regularity is a stronger, better-established lever than exact timing.

## Bottom line

**Act on confidently:** consistency of sleep timing is the primary lever
(`sleep_regularity_index`); 7–8 h in roughly a 10–11 PM to ~6:30–7 AM window is a
sensible, well-tolerated target; for night owls anchor a consistent wake time and
shift gradually with morning light.

**Hold loosely:** the exact CVD hazard ratios and the "too early is also risky"
arm (observational, COI); any causal claim about a specific clock time.

## Coach Directives

1. Prioritise **timing consistency** over the exact clock time; give the ~1-hour-
   band target. *(confidence: high)*
2. Suggest a ~10:30–11:00 PM onset / ~6:30–7 AM wake as a default target where
   feasible, framed as association not causation. *(confidence: moderate)*
3. For a night owl, anchor a **consistent wake time first**, then shift gradually
   with morning light and earlier meals — never force a drastic early bedtime.
   *(confidence: moderate)*
4. Never present the bedtime U-shape as causal or alarming (observational, weak
   early arm, commercial COI). *(confidence: high)*
5. For this chronic short sleeper, weight *extending* total sleep as much as
   shifting timing; back it with a wind-down bedtime reminder. *(confidence: moderate)*

## References

- Nikbakhtian S, Reed AB, Obika BD, et al. *Accelerometer-derived sleep onset
  timing and cardiovascular disease incidence: a UK Biobank cohort study.* Eur
  Heart J Digital Health 2(4), 658–666 (2021).
  https://academic.oup.com/ehjdh/article/2/4/658/6423198
- American Heart Association. *Sleep and Cardiovascular Health* scientific statement
  (2025).
- Windred DP, Burns AC, Lane JM, et al. *Sleep regularity is a stronger predictor
  of mortality risk than sleep duration.* Sleep 47(1), zsad253 (2024).
  https://academic.oup.com/sleep/article/47/1/zsad253/7280269
- Watson NF, Badr MS, Belenky G, et al. *Recommended Amount of Sleep for a Healthy
  Adult* (AASM/SRS consensus). Sleep 38(6), 843–844 (2015).

## Healthee implementation & honesty policy

- No standalone timing/chronotype derived metric. Timing feeds the **Timing**
  dimension of `sleep_health_score_4dim` (midpoint in [02:00, 04:00) local →
  1 point, `derive/sleep_score.py`); schedule stability is `sleep_regularity_index`.
  Chronotype is a user attribute the coach reasons over, not a computed number.
- The Timing cutoff is chronotype-blind (see `sleep_score_implementation_plan`); the
  coach must not penalise a consistently-timed night owl and should offer a neutral
  rendering / per-user override.
- **Honesty policy:** frame timing as association, never causation; never alarm on
  the bedtime number; lead with consistency; for this chronic short sleeper (~3.7 h)
  prioritise extending sleep and anchoring a regular schedule.
