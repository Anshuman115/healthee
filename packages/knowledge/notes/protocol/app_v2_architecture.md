---
title: healthee app v2 — premium client architecture
date: 2026-06-04
status: building (phase 2)
---

# Goal
A premium (NOT Material-looking), performant, scalable, maintainable health app
that COLLECTS strap data over BLE, PUSHES to /ingest/helio, PULLS /api/* and
renders the full analysis, with beautiful animations + clean interactive charts.
Does everything: scores, trends, recommendations, AI chat, logs.

# Stack
- **go_router** — declarative routing, shell route for the 4-tab nav + deep
  drill-downs.
- **flutter_riverpod** — state mgmt. Providers wrap the repository; UI watches.
- **fl_chart** — clean line/bar charts with custom interactive tooltips
  (custom-paint kept only for the HR capsule chart).
- **flutter_animate** — declarative motion everywhere (staggered card entrances,
  score count-ups, page transitions, shimmer loading).
- **solar_icons** — modern icon set.
- Custom design tokens (`core/theme`) — OKLCH-derived palette, Manrope +
  JetBrains Mono. Premium, dark-first.

# Folder structure (feature-first)
```
lib/
  main.dart                 ProviderScope + MaterialApp.router(go_router)
  core/
    theme/       tokens (HColors, type, spacing, radius, motion)
    api/         HelioApi (http), models
    ble/         StrapClient, Store, parsers (existing — the collector)
    router.dart  go_router config (shell + 4 tabs + detail routes)
  data/
    health_repository.dart   API + SQLite cache; the single data source the UI reads
    providers.dart           Riverpod providers (todayProvider, historyProvider, recsProvider, syncProvider)
  features/
    today/       scores-hero + cards            (tab 1)
    trends/      sleep / activity / heart detail (tab 2)
    coach/       recommendations + insights + chat (tab 3)
    you/         profile + logs + settings       (tab 4)
  widgets/       shared premium components (HCard, HScoreRing, HChart, HTile…)
```

# Data flow (performant, offline-first)
UI → Riverpod provider → HealthRepository → (1) return SQLite cache instantly,
(2) fetch /api/* in background, update cache + notify. Repository also owns the
push (strap → /ingest/helio). The **foreground service** (phase 4,
flutter_foreground_task) runs the repository's sync (BLE fetch → push → pull)
periodically in the background → data always fresh (also fixes the watch's
~4-day retention).

# Scores hero (no proprietary composite — [[no-composite-score]])
Bold layout, legitimate numbers only: sleep score (device 0–100 + 4-dim health),
RHR & HRV vs 14-day baseline, MVPA vs 150-min guideline, VO₂max, today's
calories/steps. NOT an invented readiness score.

# Build phases
1. API endpoints (recs + enriched today ✅; sleep/insights/logs/ask next)
2. Foundation: theme + repository + providers + go_router shell + Today hero ← now
3. Trends · Coach · You screens
4. Foreground service (background push/pull)
5. AI chat + logs
