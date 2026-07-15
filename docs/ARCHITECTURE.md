# Healthee — Target Architecture

Full blueprint with diagrams, the honesty contract, and the complete audit
findings: `docs/blueprint.html` (published copy:
https://claude.ai/code/artifact/c854d435-402b-471d-b308-d853f61b7a36).
This file is the working summary.

## One system, three tiers

```
Helio Strap ──BLE (RE'd Huami/ZeppOS)──▶ Mobile app ──POST /ingest/helio──▶ Server (FastAPI)
  sensors + firmware buffers              │ ble kit (auth·pager·parsers)      │ ingest → TimescaleDB
                                          │ local store (60d samples,         │ derive (science layer)
                                          │   400d sessions + dailies)        │ analytics (baselines·corr·
                                          │ device analytics (provisional)    │   anomalies·cutoffs·bio-age)
                                          │ sync engine ◀─GET /api/sync/down──│ insights (grounded LLM)
                                          └ offline-first UI                  │ jobs (supervised) · backup
                                                                              └ Telegram · OpenRouter
                        packages/knowledge (graded corpus) grounds BOTH tiers
```

- **Strap** is the sensor. Keep-on-device ACKs + per-metric watermarks make
  partial syncs safe and resumable (proven in legacy — port this design).
- **Mobile** is collector *and* analytical node: renders everything from local
  data instantly (provisional recovery score at wake-up), reconciles with the
  server after push. Offline = degraded (no LLM, no full history), never dead.
- **Server** is the canonical brain: full history, the science layer, the
  grounded intelligence. Server values win on reconcile; drift beyond tolerance
  is logged, never hidden.

## The honesty contract (product law)

1. Never lies, never flatters — every interpretive sentence cites the corpus or
   doesn't ship (validated at the grounded-ask choke point).
2. Confidence is part of the answer — every number carries coverage, freshness,
   origin (measured/derived/provisional), and evidence grade.
3. Nudge, don't please — measured outcomes (frozen ledgers), not streak theater.
4. Science is a pipeline — graded notes, calibrated language, safety directives
   as hard guardrails.
5. The user owns the data — self-hosted, on-device history, backups, export.

## Phase plan

| Phase | Scope | Done when |
|---|---|---|
| 0 | Foundations: repo scaffold, CI skeleton, contracts package, backup script in infra/ | CI runs the gates on every push |
| 1 | Server core: core/ingest/derive ported verbatim + routers rebuilt clean; the 5 legacy view-seam bugs fixed by design (v2-native reads); seeded-DB + contract tests | All legacy /api/* endpoints reproduced, contract-tested; deployable |
| 2 | Mobile core: ble/ ported (version-guarded, sentinel-filtered), core/data layers, features rebuilt clean screen-by-screen | APK on device, all tabs live against the new server |
| 3 | On-device 60-day tier: local daily_metric mirror, /api/sync/down, retention pruning, offline-first rendering | Airplane mode = fully functional app; reinstall repopulates in one sync |
| 4 | Device analytics: baselines/trends/anomalies/provisional recovery/confidence in Dart, parity-tested vs server goldens | Parity suite green in CI; instant wake-up score |
| 5 | Companion intelligence: per-card confidence, weekly review digest, coach memory, knowledge-corpus upgrade (daud conventions + directives manifest), export | First honest weekly review delivered and fact-checked |
| 6 | Cutover + multi-user readiness: VPS re-pointed to this repo, legacy archived; auth/tenancy seams | Prod runs from this repo; legacy repo frozen |

Legacy audit findings (what these phases must not recreate): five silent
view-seam bugs, no backups, no tests, swallowed errors everywhere, a 4,463-line
API file, an 1,571-line screen. Full catalogue in the blueprint appendix.
