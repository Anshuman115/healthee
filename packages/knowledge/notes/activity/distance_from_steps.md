---
id: distance_from_steps
name: "Deriving distance from step count"
topic: Deriving walking/running distance from step count + profile
category: activity
grade: Probable
summary: "The strap reports no distance over BLE, so distance is derived from steps × a height-based step length (walking k ≈ 0.414), refined by cadence when moving fast; a rough ±10–20% daily-total proxy (not route distance), always labelled an estimate, and superseded by the device's own GPS distance during workouts."
aliases: ["distance from steps", "step length", "stride length distance", "walking distance derivation", "distance_from_steps"]
tags: ["distance from steps", "step length", "stride length distance", "walking distance derivation", "distance_from_steps"]
applies_to_metrics: ["distance_m_daily"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
related: ["cadence_intensity", "energy_expenditure_derivation", "steps_mortality"]
---

# Deriving distance from step count

## Summary

The strap does not report distance over BLE. Derive it from step count + height, in two
tiers by available data. It is a **rough daily-total proxy** (±10–20% vs GPS), always
labelled an estimate; during workouts the device's own GPS-backed distance is used instead.

## What it is

`distance_m_daily` — an estimated daily walking/running distance computed from the step
count and the user's height (with a cadence refinement when available), plus the
per-workout measured distance when a GPS-backed workout exists. It is a derived metric, not
a sensor reading.

## Physiology / mechanism

Distance = steps × step length, and step length scales roughly with stature (leg length)
and grows with walking speed/cadence. A fixed height-ratio stride is therefore a reasonable
central estimate that under-counts fast running (longer strides) and over-counts shuffling
(shorter strides) — which is why the cadence-adjusted tier exists.

## The evidence

- **[Probable]** **Step length ≈ 0.41–0.43 × height** across studies; Hatano's pedometry
  default walking factor is **k ≈ 0.414** [Hatano 1993; Bohannon & Williams Andrews 2011].
- **[Probable]** **Step length grows with cadence/speed**, so a fixed k under-counts running
  and over-counts shuffling — the ACSM cadence→speed relationships let it scale
  ([ACSM metabolic equations]; see [[cadence_intensity]]).
- **[Established] (device)** During GPS-backed workouts the device's own per-workout
  `distanceMeters` (fetch 0x05) is a **measured**, not derived, value and is preferred.

## How we compute it

### Tier 1 — step length × steps (baseline, always available)

```
step_length_m ≈ k · height_cm / 100
  walking k ≈ 0.414   (≈0.41–0.43 across studies; Hatano's pedometry default)
distance_m = steps · step_length_m
```

Compute per minute (so it tracks intra-day) and sum to daily. Sex tweak is negligible vs
the height term; keep one k for simplicity unless validated.

### Tier 2 — cadence-adjusted (more accurate when moving fast)

Step length grows with cadence/speed, so a fixed k under-counts running and over-counts
shuffling. When per-minute cadence (steps/min) is available — we have it from the activity
stream and already compute it for MVPA ([[cadence_intensity]]) — scale step length with
cadence, or estimate speed from cadence via the ACSM walking/running relationships and
integrate speed × time.

During **workouts**, prefer the device's own per-workout `distanceMeters` (fetch 0x05,
often GPS-backed) — real, not derived.

## How the coach uses it

- Present daily distance as an **estimate**, not a precise route distance; use it for
  trend/context alongside steps ([[steps_mortality]]).
- For any workout with GPS, show the **device's measured distance**, not the derived one.

## Safety bounds

- Purely informational; no safety-critical use. Never present derived distance with false
  precision.

## Honesty & uncertainty

- A fixed height-ratio stride is a **rough** estimate: real stride varies with speed,
  terrain, fatigue, and individual gait. Expect **±10–20%** error vs GPS.
- It is a reasonable daily-total proxy, **NOT a precise route distance**. Label it
  "estimate". Do not present it with false precision.
- For any workout with GPS, use the device's measured distance, not this.

## Bottom line

**Act on confidently:** steps × height-based step length gives a usable daily-distance
estimate; the device's GPS distance is the truth for workouts.

**Hold loosely:** the exact daily figure (±10–20%), and any per-route precision from the
derived value.

## Coach Directives

1. Derive daily distance as steps × height-based step length (walking k ≈ 0.414),
   cadence-adjusted when moving fast; **label it an estimate**. *(confidence: high)*
2. Prefer the **device's GPS `distanceMeters`** for any workout that has it. *(high)*
3. Never present derived distance with false precision. *(high)*

## References

- Bohannon RW, Williams Andrews A. *Normal walking speed: a descriptive meta-analysis.*
  Physiotherapy 2011;97(3):182–189.
- Hatano Y. *Use of the pedometer for promoting daily walking exercise.* ICHPER 1993.
  (Pedometry step-length factor k ≈ 0.414.)
- *ACSM's Guidelines for Exercise Testing and Prescription* (metabolic equations: speed
  from cadence).

## Healthee implementation & honesty policy

- **Metric: `distance_m_daily`** — a **TIERED** metric, and the tier decides how it may be
  described (corrected 2026-09-08; this bullet used to call the stride estimate "the sole
  distance source", which stopped being true when #121 gave the strap's own counter a
  durable home). `derive/device_totals.py::select_distance` returns:
  1. **the strap's own measured daily distance** (`device_daily_total.distance_m`)
     whenever it reported one — a measurement, `flags.method = "device"`, and it needs no
     profile height at all; then
  2. **steps × stride** as the fallback, `flags.method = "stride"`, which is the estimate
     this note derives; then
  3. **nothing**, when there is no device figure and no height.
  GPS-backed workouts carry the device's measured per-workout distance separately.
- **Honesty rules, PER TIER** — the wire says which one produced the row, so the prose
  must follow it rather than describing every row as an estimate:
  - `method = "stride"`: always "estimate"; ±10–20% vs GPS; a daily-total proxy, not a
    route distance; **needs profile height** and is withheld without it.
  - `method = "device"`: it is the strap's own measurement, not a stride estimate. The
    ±10–20% band above is the error of *this note's* derivation and does not apply to it,
    and neither does the height precondition. Wrist step-and-distance counting has its own
    error, which we have no published figure for — say that, rather than borrowing a
    number from the wrong tier.
  - Never fabricate a distance for a day neither tier can price.
  Related derivations: [[cadence_intensity]], [[energy_expenditure_derivation]].
