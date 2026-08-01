---
title: v2 backend — clean single-source rebuild (fast, accurate, from scratch)
date: 2026-06-04
status: SUPERSEDED — historical design record, not a plan to implement
superseded_by: docs/ARCHITECTURE.md (target architecture) + apps/server/src/healthee (what shipped)
superseded_on: 2026-08-01
---

> ⛔ **SUPERSEDED — read this as history, not as instructions.**
> This is the 2026-06-04 design record for the v2 backend. The clean-rebuild
> monorepo has since been built and shipped; the plan of record is
> **`docs/ARCHITECTURE.md`**, and the truth about any derivation is the code in
> `apps/server/src/healthee/derive/` plus the note that backs it.
> It is kept for provenance (why v2 dropped multi-source, what "discard the old
> DB" meant), and it is **not** a citable evidence note — the manifest generator
> deliberately skips `notes/protocol/`.
> **One claim below was wrong when it was written and must not be carried
> forward: the calorie line.** See the correction at that line.

# Decision

The v1 backend (multi-source: gadgetbridge + tasker_hc + zepp_cloud) is slow and
unoptimized — its complexity is the source-dedup/preference machinery. v2 is a
clean rebuild for a SINGLE source (the strap, via the app). We **discard the old
DB data** and the multi-source code. Goal: faster, more performant, and more
ACCURATE in every aspect.

Keep the proven stack (FastAPI + Postgres) — it's plenty fast when the schema is
right; the slowness was design, not the engine. PORT the *accurate science*
(evidence-based derivations), not the cruft.

# What dies
- Multi-source: `source IN (...)`, `_CALORIE_SOURCE_RANK`, `_NAP_SOURCE_RANK`,
  source-preference dedup — all gone. One source ⇒ one value per (metric, ts).
- `/ingest/gadgetbridge`, `/ingest/health_connect/*` endpoints.
- Health Connect (Tasker) + Gadgetbridge pipelines.
- Floors (no strap sensor) — dropped.

# v2 schema (clean, indexed, single-source)
```sql
sample(metric TEXT, ts TIMESTAMPTZ, value REAL, PRIMARY KEY(metric, ts));
  -- + INDEX (metric, ts DESC).  No source column.
sleep_session(start_ts TIMESTAMPTZ PK, end_ts, score, avg_hr,
              rem_min, light_min, deep_min, wake_min, stages JSONB);
workout(start_ts TIMESTAMPTZ PK, sport INT, duration_s, calories,
        distance_m REAL, avg_hr, max_hr, min_hr);
derived_daily(day DATE, metric TEXT, value REAL, flags JSONB,
              PRIMARY KEY(day, metric));   -- materialized for fast reads
profile(id INT PK DEFAULT 1, height_cm, sex, dob DATE);
weight_log(ts TIMESTAMPTZ PK, kg REAL);
```

# Ingestion (lean)
- `POST /ingest/helio` — batch of {metric, ts, value} + sleep sessions +
  workouts + profile. Upsert (ON CONFLICT). After a batch, **incrementally**
  re-derive only the affected days (not a full recompute) → fast.

# Derivations (accurate, evidence-graded, single-source)
Port the GOOD v1 science, drop the source filters:
- `rhr_daily` — min 5-min rolling-avg HR in sleep window (Aune 2017 marker).
- `hrv_sleep_avg` — mean HRV over sleep window.
- `spo2_overnight` (avg + min).
- Sleep: score, stage minutes, `sleep_regularity_index`,
  `sleep_health_score_4dim`.
- `total_calories` / `active_calories` — ~~Mifflin BMR + Keytel HR-active~~
  (energy_expenditure_derivation.md); workout minutes use the device's measured
  calories.
  > ⛔ **CORRECTION (2026-08-01) — this line miscited its own evidence note.**
  > `energy_expenditure_derivation` grades raw Keytel HR→EE
  > **[Contested → rejected]** (it overcounts free-living 2–3×) and its
  > **Directive 1 is "never raw Keytel/HR→EE for free-living minutes."**
  > `CLAUDE.md`'s hard rules say the same. Citing that note as support for
  > Keytel inverted it.
  > **What actually shipped** (`derive/energy.py`, ported verbatim from legacy
  > v2): **Mifflin–St Jeor BMR + a MET-by-state model** — a MET per minute by
  > state (walking from steps via ACSM · asleep 0.95 · awake-NEAT 1.3/1.55),
  > anchored so 1 MET == BMR/min. Heart rate is deliberately **not** an input to
  > free-living EE. Workout minutes are excluded and counted from the device's
  > measured calories, which is the one part of this line that held.
- `distance_m_daily` — stride×steps (distance_from_steps.md); GPS workout
  distance preferred when present.
- `vo2max_estimate` — Jurca (non_exercise_vo2max.md).
- `mvpa_min` — cadence-based (cadence_intensity.md).
- `steps_total` — daily sum.

# API (lean, pre-derived → fast reads)
- `GET /api/today` — latest vitals + today's derived + last night's sleep.
- `GET /api/history?metric=&from=&to=` — daily series from derived_daily.
- `GET /api/sleep`, `GET /api/workouts`.
All read pre-materialized rows; no heavy on-request computation.

# Performance principles
- Index every (metric, ts) access path; derived_daily for O(1) dashboard reads.
- Incremental derivation on ingest (touch only changed days).
- One source ⇒ no dedup joins.
- App keeps its SQLite cache for instant/offline; backend is canonical.

# Crons / analytics port — via a compat VIEW (no rewrites)

The analytics (correlate, anomalies, baselines, cutoff_finder, recs) are
READ-ONLY on `metric_sample` and WRITE only to `finding`/`recommendation`/
`illness_flag` (all kept in v2). So instead of rewriting ~1800 lines, v2 ships a
`metric_sample` **compat view** over `sample` + `derived_daily` (raw →
source='gadgetbridge', derived → 'derived'). The existing source-preference
(`derived` first) makes derived calories/distance win automatically. The
analytics run UNCHANGED. View lives in schema_v2.sql, guarded so it only
creates on a fresh v2 DB. VALIDATED: raw + derived metrics read correctly
through the view. Remaining: trim the scheduler (drop the Zepp pulls in
daily-sync/weekly — the app pushes now; keep correlate/recs/daily-insight).

# Build order
1. v2 schema + migrations (fresh DB).
2. `/ingest/helio` (samples + sessions + workouts + profile) + incremental derive.
3. Port derivations (single-source) — vitals → sleep → calories/distance → vo2max.
4. `/api/*` lean read endpoints.
5. App: ingest client (push) + read client (render /api/*); drop local health math.
6. Decommission GB/HC pipelines + endpoints.
