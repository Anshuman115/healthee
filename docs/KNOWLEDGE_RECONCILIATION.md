# Knowledge Reconciliation — plan of record

Goal, non-negotiable: **unify the two knowledge collections without losing a
single claim, citation, formula, or directive.** The corpus is the product's
spine ("never lies"); a reconciliation that drops content is a regression, not
a refactor. This doc is the auditable plan and the anti-degradation method.

Source audit: 2026-07-15 read-only comparison of `packages/knowledge/notes/`
(55 legacy consumer-health notes) vs `packages/knowledge/sports-science/`
(29 imported running-coach docs). Key finding: **most overlaps are
complementary, not duplicate** — same metric, opposite angle (health-marker vs
training-signal). The default action is merge/graft, not pick-one-delete-other.

## The anti-degradation method (how "no loss" is enforced, not trusted)

Every reconciled note ships with a **coverage checklist** in its PR:
1. Enumerate every atomic unit in BOTH source docs — each claim, each citation
   (author/year), each formula, each directive, each Healthee-impl detail.
2. For each unit, mark where it lands in the canonical note, OR mark it
   **deliberately superseded** with a one-line reason (e.g. "legacy's 220−age
   dropped: SS uses Tanaka, better-evidenced").
3. A unit that is neither carried nor consciously superseded = a blocked PR.
4. The reviewing lead diffs the canonical note against both sources and checks
   the checklist before merge. Nothing merges on trust.
5. Citations are verified against primary sources before they ship
   (feedback_verify_primary_sources) — a merge may not launder an unverified
   figure from either source.

Net rule: a reconciled note is a **superset** of both sources' substance, in
the richer template. If anything must be cut, it's named and justified.

## Unified template

Base = the sports-science `TEMPLATE.md` (11 sections: Summary · What it is ·
Physiology/mechanism · The evidence [per-claim grades] · How we compute it ·
How the coach uses it [staged] · Safety bounds · Honesty & uncertainty ·
Bottom line [Act-confidently vs Hold-loosely] · Coach Directives · References).

Plus, carried from legacy so nothing product-specific is lost:
- **Frontmatter**: `applies_to_metrics`, `applies_to_interventions`, numeric
  `evidence_grade` + ship-tier policy, alongside SS's `id`/`aliases`/`category`/
  `related`/`last_reviewed`. (Same schema WP4 establishes.)
- **New mandatory section — "Healthee implementation & honesty policy"**: the
  metric's real field name, `derive.py`/`app.py` provenance, any composite-score
  exception + its required per-factor breakdown, device-ingestion specifics, and
  product honesty rules ("never show a death-risk number", "score vs absolute
  need not personal baseline"). This section is the specific safeguard: without
  it, migrating legacy notes to the SS template would strip their most valuable
  content.

Result: legacy notes GAIN mechanism, staged coaching, per-claim grades,
directives, safety bounds, calibration; they LOSE nothing.

The canonical template file lands at `packages/knowledge/TEMPLATE.md` when
reconciliation starts (supersedes the SS-only one).

## Per-topic canonical calls

Complementary → keep two cross-linked docs; near-duplicate → one merged note.

| Topic | Decision | Canonical base | Graft in |
|---|---|---|---|
| HRV | merge | SS heart-rate-variability | legacy ranked baseline-raising levers + alcohol dose table + our field names |
| Resting HR | merge | SS resting-heart-rate | legacy mortality/CV angle (Aune) + `rhr_daily` derivation — do not lose the consumer use-case |
| VO₂max | two layers | SS vo2max (physiology) + legacy submax/non-exercise (our estimator) | fold vo2max_fitness_mortality into SS; keep estimator maths intact |
| Sleep + recovery + readiness | merge, legacy-led | legacy (composite-validity science + shipped recovery/readiness formulas) | SS triangulation rule + subjective-wellness input |
| Cardio load / zones / ACWR | merge | SS TSS + heart-rate-zones + training-load-acwr | legacy Strain 0–21 derivation + no-composite framing + `hr_zone_minutes` |
| Max HR | adopt | SS maximum-heart-rate | our field provenance only |
| Cadence | keep both | — | cadence_intensity (MVPA) and cadence (running form) stay separate, cross-linked |
| Strength | keep both | — | mortality-dose (legacy) vs economy-dose (SS) differ; merging blurs advice |
| Sauna / heat | keep both | — | sauna→mortality (legacy) vs heat-acclimatization (SS), cross-linked |

Legacy-only unique coverage that MUST survive untouched: respiratory rate,
SpO2, skin temp, illness flag, biological age, distance, energy/TEE, SRI /
sleep-regularity, chronotype, sleep-composite-validity. These have no SS
counterpart — they are migrated to the unified template, not merged.

Exception (owner decision, 2026-07-16): the **PAI** note (`pai_activity_score`)
was **removed** — PAI is not computed anywhere in v2 (the derive layer emits no
`pai_*` row; the Today `pai` card is always null), so its note documented a
metric the app does not have. Deleted at the owner's direction; recoverable from
git history if PAI is ever reinstated as a tracked metric.

## Gap backlog (new docs — primary-source-verified)

Extend-existing (material already present):
- Strain 0–21 → extend the cardio-load note (INTELLIGENCE §7.2 A3).
- Intraday readiness-decay → build around honestly labeling the existing
  `recovery_readiness` heuristic (A5).
- Hydration (general) → re-scope from SS fueling-and-hydration (B7).

Net-new:
- Wearable stress-score validity (A1) · weight/BMI/body-composition (A2) ·
  napping (A4) · fasting / time-restricted eating (B6) · nutrition-protein
  basics OR a documented out-of-scope policy (B8).

New gaps the audit surfaced:
- **Load-currency reconciliation** — legacy Banister TRIMP vs SS TSS; ACWR and
  readiness must reason over one currency. High priority (blocks coherent
  load/ACWR grounding).
- Ground the SS illness-override directive by wiring in legacy respiratory-rate/
  temp illness notes (currently ungrounded).
- General alcohol/caffeine health docs (beyond the sleep-specific ones).
- Biological-age is thin (single-doc, no external cross-check) — flag.

## Sequencing

1. WP4 (frontmatter + manifest) merges first — it sets the unified frontmatter
   schema, snake_case ids, and the generator these notes depend on.
2. Reconciliation runs as its own track, **one topic at a time**, each merged
   note gated on: coverage checklist complete + lead diff-review against both
   sources + primary-source citation check + manifest regenerated + CI green.
3. Order: near-duplicates first (HRV, cardio-load, readiness) to prove the
   template and method, then complementary migrations, then the gap backlog.
4. No note body is rewritten before its coverage checklist and review — the
   method above is the gate on every single note.
