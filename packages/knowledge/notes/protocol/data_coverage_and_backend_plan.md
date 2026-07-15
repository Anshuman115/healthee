---
title: Data coverage audit + historical-data + backend-alignment plan
date: 2026-06-04
status: plan (researched against GB source + healthee backend)
---

# Part 1 — What the strap actually gives (and what it doesn't)

The Helio Strap exposes data over BLE in two ways: the **historical fetch**
(type codes on char 0004/0005) and **live services** (realtime). Researched
against Gadgetbridge's per-type parsers.

## Strap-native, available via historical fetch
| Data | Fetch code | We fetch? | Notes |
|---|---|---|---|
| Heart rate (per-min) | 0x01 | ✅ | record = kind,intensity,steps,HR |
| Steps (per-min) | 0x01 | ✅ | byte 2 of the activity record |
| HRV | 0x49 | ✅ | |
| SpO₂ spot | 0x25 | ✅ | |
| SpO₂ sleep + OSA/ODI | 0x26 | ✅ (basic) | 30-byte recs; OSA fields undecoded |
| Skin temperature | 0x2E | ✅ | |
| Stress (auto) | 0x13 | ✅ | |
| Stress (manual) | 0x12 | ✅ | usually empty |
| Resting / Max HR | 0x3A / 0x3D | ✅ | daily |
| Sleep sessions + stages | 0x48 | ✅ | 594B blob decoded |
| Sleep respiratory rate | 0x38 | ✅ | |
| **Workouts (summary)** | **0x05** | ❌ | per-workout: calories, distance, avg/max HR, duration, sport type (GB `ActivitySummaryParser`) |
| **Workouts (detail track)** | **0x06** | ❌ | per-second GPS/HR track |
| PAI | 0x0d | ❌ (skip) | proprietary composite — excluded per project rule |
| Statistics | 0x2c | ❌ | GB doesn't decode it; unknown format |
| AFib / PPG-RR / body-temp (Tier-2) | 0x27/0x3b/0x4a/0x4e | ❌ | discovered, formats partly reversed |

## NOT on the strap (important)
**Daily calories, daily distance, floors climbed are NOT in the historical
fetch.** The per-minute activity record has no calorie/distance fields, and GB
ignores the statistics payload. On the strap these are either live-only or not
present (the Helio Strap has no barometer → no floors).

→ The healthee **backend gets calories/distance/floors from Health Connect**
(Tasker, phone-deduped daily aggregates: `_HC_DAILY_METRICS` =
steps_total, distance_m_daily, floors_climbed_daily, active_calories,
total_calories, basal_calories…). So our BLE fetch is **complementary to HC,
not a replacement for it.**

**Where calories/distance CAN come from for us:**
1. **Per-workout** — from the workout summary (0x05). ✅ real strap data.
2. **Daily totals** — DERIVE them (backend already derives calories from HR +
   profile; distance from steps + stride), OR keep getting them from HC.
   Floors: only via HC (no strap sensor).

**Answer to "does it get calories and all other data?":** It gets all the
*biometric* data natively (HR/HRV/SpO₂/temp/stress/sleep/steps). It does NOT
get daily calories/distance/floors from the strap — those need HC or
derivation. Workouts (with calories/distance) are available but not yet fetched.

# Part 2 — Showing historical / old data

The device **retains history** because we ack with 0x09 (keep-on-device,
non-destructive). So we can fetch back as far as the strap stores (the record
counts showed hundreds of pending records ≈ weeks). Today we only fetch 2 days.

## Plan
1. **Backfill**: one-time deep fetch (`since` = e.g. 90 days ago) per type,
   paged. Bounded + resumable.
2. **Local persistence** — the app currently holds data in memory and clears on
   each sync. Add a local store (SQLite via `drift` or `sqflite`) keyed by
   (metric, ts). Idempotent upsert. Track **last-synced timestamp per type** so
   each sync is incremental (only fetch new since last).
3. **Historical UI** — per-metric pages with the web's time-range selector
   (1D/7D/30D/90D/1Y/All), calendar heatmaps, trend charts. Aggregate
   server-side or in-app (hourly/daily rollups) for long ranges.
4. **Source-of-truth decision** (see Part 3): local DB for offline/instant, but
   the **backend should remain the canonical historical store + analysis**, and
   the app reads `/api/*` for derived/analysis views.

# Part 3 — Backend alignment

## Current pipeline (the brain stays Python/FastAPI)
`metric_sample` canonical store fed by: GB DB upload (`/ingest/gadgetbridge`,
strap raw), HC via Tasker (`/ingest/health_connect/*`, calories/distance/floors/
workouts/sleep), Zepp Cloud (stress/walk/brisk). Source preference for dedup:
`derived > tasker_hc > gadgetbridge > zepp_cloud`.

## The new source: the app's direct BLE fetch
The app reads the **same strap-native metrics GB does** → it can **replace GB**
as the ingestion path for strap-native data (HR/HRV/SpO₂/temp/stress/sleep/
steps/resting-HR), and add workouts + the Tier-2 types GB can't.

### Alignment work
1. **New ingest endpoint(s)** for the app, OR reuse existing. Cleanest: a new
   `POST /ingest/helio` (batch of typed samples) + keep `/ingest/realtime`.
   New `source` tag e.g. `helio_app`; insert into the source-preference order
   (probably above gadgetbridge, below derived/tasker_hc — or topmost for the
   metrics only the app has).
2. **Metric-name mapping** (app → backend canonical). The app must emit the
   backend's canonical names/units/timestamps, e.g.:
   - app `hr` → `hr` (per-minute) ✓
   - app `resting_hr` → `rhr_daily`
   - app `hrv` (sleep-avg) → `hrv_sleep_avg`
   - app `temperature_c` → `skin_temp_c`
   - app `respiratory_rate` → `respiratory_rate_sleep`
   - app `steps`/min → `steps_per_minute`
   - app sleep session → `session(kind='sleep')` + per-minute `sleep_stage`
   - workouts → `session(kind='workout', source='helio_app')`
   Define this mapping ONCE (mirrors the app-side `Vitals` canonical rule).
3. **What HC still provides**: calories/distance/floors (strap can't). Decide:
   (a) keep the HC/Tasker daily push for those, or (b) derive them server-side
   from the app's HR+steps+profile (backend already has calorie logic). Floors
   stay HC-only regardless.
4. **Backfill ingest**: the app's 90-day backfill pushes historical samples to
   the backend (idempotent ON CONFLICT) → backend gains real strap history
   beyond what GB happened to upload.
5. **Retire decision**: once the app ingest is proven, GB DB upload + the GB
   app can be retired (the app does it natively). HC/Tasker stays for
   calories/distance/floors unless we derive. Zepp Cloud already lean.

## Why this is the right shape
- Backend stays the single canonical store + analysis brain (the project's
  "100% correct legible data" principle; same reason the app uses one `Vitals`
  source). The app does NOT re-implement analysis — it ingests raw + renders
  `/api/*`.
- Eliminates the GB+Tasker+export plumbing for strap data → the "self-contained
  app" goal, while keeping HC only for what the strap genuinely lacks.

# Part 4 — Phased plan

- **P1 · Complete coverage**: fetch workouts (0x05/0x06 → calories/distance/HR
  per workout), confirm daily-step rollup, finish Tier-2 decode (AFib/OSA/
  PPG-RR/body-temp). Decide calories/distance derivation vs HC.
- **P2 · Local persistence + history**: SQLite store, incremental sync
  (last-synced per type), 90-day backfill, time-range historical UI.
- **P3 · Backend ingest path**: define the app→backend metric mapping; add
  `/ingest/helio` + `source='helio_app'` + source-preference; push live + backfill.
- **P4 · Reconcile + retire**: dedup vs existing sources; retire GB upload;
  keep HC for calories/distance/floors (or derive); verify analysis unchanged.
- **P5 · App = full client**: app reads `/api/*` for derived/analysis +
  historical (backend canonical), local DB for offline/instant. Backend
  recommendations/sleep-score/etc. render natively.

# Decisions (LOCKED 2026-06-04)

1. **Calories/distance: derive scientifically in the backend.** Evidence notes:
   `research/activity/energy_expenditure_derivation.md` (Mifflin BMR + Keytel
   HR-active) and `research/activity/distance_from_steps.md` (stride × steps).
2. **Historical store: backend canonical + app cache.**
3. **Retire Gadgetbridge.** The app is the sole strap collector.
4. **Tier-2 (AFib/OSA/PPG-RR): DEFERRED** — core data + calories/distance +
   workouts + backend alignment first.
5. **Workouts (0x05/0x06): fetch + parse** — real per-workout calories/distance/
   HR/pace/sport. Format = `HuamiActivitySummaryParser` (fixed layout, version-
   aware ~150 lines).
6. **RETIRE Health Connect entirely.** Profile (height/sex/dob/weight) is
   entered IN THE APP and pushed to the backend; calories/distance fully
   derived. **Floors is dropped** (strap has no barometer; was HC-only).

## Resulting unified architecture
- **App** = sole data collector: strap BLE fetch (all biometrics + steps +
  workouts) + profile entry. Pushes raw + profile to backend. Renders /api/*.
- **Backend** = canonical store + ALL derivation/analysis (calories, distance,
  sleep score, vo2max, recs…) + /api/*. No HC, no GB.
- **Retired**: Health Connect (Tasker) + Gadgetbridge. Zepp Cloud already lean
  (revisit). **Lost**: floors climbed (acceptable).

## Execution order (revised)
- P1 · App: workouts fetch+parse (0x05) + display; daily-step rollup.
- P2 · App: profile/settings screen (height/sex/dob/weight) + local SQLite
  cache + incremental sync + 90-day backfill + historical UI.
- P3 · Ingest path: app → `POST /ingest/helio` (`source='helio_app'`) + push
  profile; metric-name mapping (one definition).
- P4 · Backend: implement derived calories (Keytel+Mifflin) + distance (stride);
  retire HC ingest + GB upload; reconcile source preference.
- P5 · App reads /api/* for analysis + history (backend canonical); native
  recs/sleep-score/etc.
