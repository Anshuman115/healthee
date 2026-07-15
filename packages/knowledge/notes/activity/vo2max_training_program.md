---
id: vo2max_training_program
title: Raising VO₂max — protocol + trainability trajectory
evidence_grade: 3
applies_to_metrics: [vo2max_estimate, mvpa_min, cardio_load]
applies_to_interventions: [exercise]
last_verified: 2026-06-20
---

# Raising VO₂max — protocol + how fast it moves

**For a low-fit adult, VO₂max is the most trainable longevity lever**, and the gain
is largest when fitness is low (more headroom). This grounds a *visible plan* + an
honest *projected trajectory* — framed as an estimate of typical response, never a
promise.

## The protocol (polarized: easy base + a hard stimulus)
- **Zone 2 base** — ~3 sessions/week, 30–45 min easy aerobic (conversational pace,
  ~60–70% HRmax). Builds mitochondrial/aerobic base; the bulk of the volume.
- **One weekly high-intensity stimulus** — intervals (e.g. 4–5 × 1–4 min hard) OR
  **VILPA** (vigorous intermittent lifestyle activity: short all-out bursts —
  stairs, hill, fast walk-to-jog). This is the part that drives VO₂max up.
- Polarized (mostly easy + a little very hard) outperforms all-moderate for VO₂max.

## How much / how fast (the trajectory evidence)
- **Bacon 2013** (PLOS One meta, 37 studies, n=334, 6–13 wk) — interval / combined
  training raised VO₂max **+0.51 L·min⁻¹** (95% CI 0.43–0.60); longer 3–5 min
  intervals **~0.8–0.9 L·min⁻¹**; continuous-only ~0.2–0.4. ★★★ [primary-source
  verified 2026-06-20]
  - For an ~80 kg person, 0.51 L·min⁻¹ ≈ **+6.4 ml/kg/min** in young untrained over
    ~10 wk. We deliberately project **more conservatively** (~half) for real-world
    adherence + a short-sleeper's limited recovery.
- **Milanović 2015** (Sports Med meta) — HIIT and MICT both raise VO₂max; HIIT a bit
  more (~+1.2 ml/kg/min difference). ★★★
- **VILPA / vigorous bursts** — Stamatakis 2022/2023 (see [[mvpa_minutes_mortality]])
  — brief daily vigorous bursts improve fitness + sharply cut mortality. ★★★

## The projection model used (honest + conservative)
12-week projected gain scales with the **gap to the age-median** (low fitness = more
trainable), bounded **+2 to +5 ml/kg/min**: `gain = clamp(0.4 × gap, 2, 5)`. This is
~40% of the gap closed in a 12-week block — squarely inside the conservative end of
the trainability literature, and physiologically right (bigger headroom → bigger
response). Shown as "≈{current}→{projected} in 12 wk **if you follow the plan**" with
the citation — an estimate of typical response, not a guarantee. Re-anchors to the
user's measured VO₂max each week, so it stays honest as real data comes in.

## Honesty constraints
- "Estimate / typical response", never a promise; depends on adherence + recovery.
- Re-base on the user's *measured* VO₂max trend; don't let the projection drift from reality.
- Scale intensity to recovery (tie to [[recovery_readiness]] — no hard session on a
  low-recovery day) and to the chronic short sleep (recovery is the limiter).

## Primary sources
- Bacon AP 2013, PLOS One — VO₂max trainability & HIIT meta-analysis.
- Milanović Z 2015, Sports Medicine — HIIT vs MICT VO₂max meta-analysis.
- Stamatakis E 2022, Nature Medicine — VILPA & mortality (via mvpa_minutes_mortality).
