---
id: distance_from_steps
title: Deriving walking/running distance from step count + profile
evidence_grade: 2
applies_to_metrics: [distance_m_daily, distance_m]
citations:
  - "Bohannon RW, Williams Andrews A. Normal walking speed: a descriptive meta-analysis. Physiotherapy. 2011;97(3):182-189."
  - "Hatano Y. Use of the pedometer for promoting daily walking exercise. ICHPER. 1993."
  - "ACSM's Guidelines for Exercise Testing and Prescription (metabolic equations: speed from cadence)."
---

# Goal

The strap does not report distance over BLE. Derive it from step count +
height. Two tiers, by available data.

## Tier 1 — step length × steps (baseline, always available)

```
step_length_m ≈ k · height_cm / 100
  walking k ≈ 0.414   (≈0.41–0.43 across studies; Hatano's pedometry default)
distance_m = steps · step_length_m
```

Compute per minute (so it tracks intra-day) and sum to daily. Sex tweak is
negligible vs the height term; keep one k for simplicity unless validated.

## Tier 2 — cadence-adjusted (more accurate when moving fast)

Step length grows with cadence/speed, so a fixed k under-counts running and
over-counts shuffling. When per-minute cadence (steps/min) is available — we
have it from the activity stream and already compute it for MVPA
(cadence_intensity.md) — scale step length with cadence, or estimate speed from
cadence via the ACSM walking/running relationships and integrate speed×time.

During **workouts**, prefer the device's own per-workout `distanceMeters`
(fetch 0x05, often GPS-backed) — real, not derived.

# Accuracy & honest caveats (evidence-first)

- A fixed height-ratio stride is a **rough** estimate: real stride varies with
  speed, terrain, fatigue, and individual gait. Expect **±10–20%** error vs GPS.
- It is a reasonable daily-total proxy, NOT a precise route distance. Label it
  "estimate". Do not present it with false precision.
- For any workout with GPS, use the device's measured distance, not this.

# Where it runs

Backend derived metric, same as energy (it has the profile height + raw steps/
cadence). The app renders it. With HC retired, this is the sole distance source.

Related: cadence_intensity.md, energy_expenditure_derivation.md,
research/protocol/data_coverage_and_backend_plan.md.
