# Healthee Engineering Standards

These standards are binding for all code written in this repo — human or agent.
They exist so the codebase stays clean, maintainable, extendable, and above all
**easy to read and follow**. A reviewer enforces them on every diff; a diff that
violates a MUST is rejected regardless of whether it works.

The product context: Healthee is an honest health companion. Code quality is a
health-data integrity issue here, not aesthetics — unreadable code is where
silent wrongness hides, and this product's one promise is that it never lies.

The legacy repo (`~/projects/healthee-legacy`) is the cautionary tale these
rules exist to prevent: a 4,463-line API file, a 1,571-line screen, one helper
copied into 11 files, and five features silently dead behind swallowed errors.

---

## 1. Universal rules (server + mobile)

### Size limits (hard gates)
- **File: 400 lines maximum.** Target ≤ 250. A file at 300+ needs a comment in
  the PR explaining why it can't be split. There is no file for which 1,000+
  lines is acceptable — split by responsibility before you get there.
- **Function/method: 40 lines maximum** (excluding docstring). If it doesn't fit,
  it's doing more than one thing.
- **Class/widget: ~200 lines.** A screen is composition of small widgets, not one
  God-widget.
- **One public class/widget per file.** Small private helpers used only by that
  class may live alongside it.

### One responsibility
- A file has one reason to change. Name it after that reason
  (`recovery_score.dart`, not `utils2.dart`).
- Modules depend **downward only**: UI → domain → data → core. Never upward,
  never sideways between features. A feature that needs another feature's logic
  means that logic belongs in a shared/domain layer.

### Duplication
- **Second occurrence = extract.** Before writing a helper, search for it.
  Before copying anything, extract it.

### Errors are never swallowed
- **Banned:** bare `except:`/`except Exception: pass` (Python), `catch (_) {}`
  (Dart), returning empty-string/empty-map to mean "something failed".
- Every failure is (a) logged with context through the one logging path, and
  (b) either handled meaningfully or propagated. "No data" and "operation
  failed" are different states and must be distinguishable by the caller.
- Background/silent contexts (sync, jobs, schedulers) must report failures to
  their health surface (mobile: sync health; server: job status + Telegram).

### Naming & readability
- Full words over abbreviations, except domain-standard terms (hr, hrv, spo2,
  rhr, sri, tee, met).
- **Units live in names**: `durationS`, `distanceM`, `tstMin`, `skinTempC`.
- Every magic number is a named constant. Every constant derived from research
  cites its note: `// Tanaka HRmax [vo2max_submaximal]`.
- Comments explain *constraints and why*, never *what the next line does*.
  Byte-format and protocol code MUST carry layout comments (offset tables).

### Science code is sacred
- Any function implementing a published method (SRI, TRIMP, Gompertz, Minetti,
  Tanaka…) must: cite its knowledge note in the docstring, have a known-value
  test, and never be "simplified" during refactors or ports. Port verbatim from
  legacy, then verify against golden fixtures — behavior change in science code
  is its own PR.

### Tests are part of the definition of done
- New module → tests in the same PR. No exceptions for "it's simple".
- **Parsers** (BLE byte formats, protobuf, blobs) → golden-fixture tests from
  real captured data.
- **Science/derive functions** → known-value tests (hand-computed or
  literature-published expected outputs).
- **API endpoints** → contract test (seeded DB → asserted JSON shape), snapshots
  stored in `packages/contracts`.
- **Device analytics** → parity tests against server-exported golden fixtures.

### How we verify — the practices, and how each has failed

`HOW_WE_VERIFY.md` is the companion to this file: this one says what the code
must be, that one says how we find out whether it is. Mutation testing and its
four ways of lying, the honesty layer's structural enforcement, the two
symmetric lies (stale-as-current and future leak), verifying against the design,
and the contract-snapshot trap.

### Dead code
- Delete, don't comment out. Delete, don't keep "just in case" — git has it.
  Unused dependencies are removed in the same PR that orphans them.

### Dependencies are current at write time
- When adding any dependency, GitHub Action, base image, or tool pin: **look up
  the current version at write time** (`uv add` resolution, `pip index
  versions`, `gh api …/releases/latest`, registry tags) — never write a version
  from memory. A dep that's stale on day one is instant dependabot noise.
- Dependabot (monthly) is the backstop, not the mechanism. Take its bumps
  promptly; CI validates them.
- Major-version bumps of runtime deps get a changelog skim in the PR
  description — one line on what changed.

### Performance is a requirement, not an aspiration
Fast is a top product priority. A change that blows a budget is rejected in
review exactly like a failing test.

**Budgets (measured on typical real data, not empty DBs):**

| Surface | Budget |
|---|---|
| Server read endpoints (non-LLM) | p95 < 100 ms |
| Ingest push (one normal day of new data) | < 5 s end-to-end |
| LLM endpoints | pre-warmed/cached per day; generation never blocks a sync or a read path |
| App cold start → first meaningful paint | < 2 s (cache-first render) |
| Tab switch / scroll | 60 fps — no dropped-frame jank; charts never rebuild on scroll |
| Full incremental BLE sync (typical day) | < 30 s |

**Rules that keep the budgets:**
- **Measure, don't guess.** Any PR claiming or affecting performance carries
  numbers (before/after). Suspicion of jank → profile (DevTools / py-spy),
  don't speculate.
- **Bound the round-trips.** No N+1 queries; bulk writes use
  `executemany`/pipelining (the legacy push once did one round-trip per sample
  and hit 180 s timeouts); no per-item connections — the pool is the only way
  in.
- **Hot loops vectorize.** Per-minute day-windows (1440 iterations) in
  Python use numpy/polars when they're on a request or sync path.
- **Caching is a design element, not a patch**: stale-while-revalidate on
  device, per-day kv cache for generated text, mtime-cached corpus manifest,
  pre-warmed daily insights in the scheduler.
- **Unbounded data is windowed** — every list endpoint paginates; every chart
  query has a range.
- **Flutter:** `const` constructors wherever possible, `ListView.builder` for
  any list, granular provider `select` to minimize rebuilds, `RepaintBoundary`
  around chart painters, no synchronous I/O on the UI isolate, heavy parsing
  in `compute()` isolates.
- **Never trade correctness for speed silently** — if an optimization changes
  results (sampling, approximation), the honesty contract applies: it's
  documented and surfaced.

---

## 2. Server standards (`apps/server`, Python 3.13)

### Layout
```
apps/server/src/healthee/
  core/        config (pydantic-settings ONLY), db (the one pool + tenant_transaction),
               request_auth (transitional dual auth), supabase_auth (JWT verify +
               device tokens), tenancy (active_users, the sentinel), knowledge
               (corpus loader, cached, + manifest), notify, logging
  ingest/      payload validation + upserts
  derive/      science layer — pure functions over the sample window
  analytics/   baselines, correlations, anomalies, cutoffs, bio-age
  read/        per-endpoint read services (canonical-table reads)
  insights/    llm client, pipeline (THE choke point: its stages + the gate
               registries) + gate_types (the vocabulary those gates speak),
               grounded_ask + coach (its two entry points), validator,
               output_guard (hard guardrails), action_claims (anti-hallucination),
               personal_claims (no value asserted for data we lack), refusals,
               retrieval, context, coach tools
  api/         app.py (wiring only) + routers/ (thin HTTP layer)
  jobs/        scheduler (per-owner tick) + supervised chain + correlate/recs/briefing
  db/          schema + numbered migrations + runner + one-off ops modules
tests/         unit + seeded-DB integration + contract tests + db/ (tenancy guards)
```

### Rules
- **Routers are thin**: auth dep → validate input → call one domain function →
  shape response. Zero business logic, zero SQL in routers.
- **DB access only via `core/db`** (one psycopg_pool, one transaction
  convention: context-managed, commit-on-exit). No module-local `_connect()`.
- **Tenant data only via `tenant_transaction(user_id)`** (or its connection-scoped
  form) — it is the ONE way tenant rows become visible to the app role, because it
  sets the `healthee.user_id` GUC that RLS keys on. A tenant read on plain
  `transaction()` returns **zero rows and raises nothing**: failing closed is right,
  but it means a missed call site shows a user "no data" rather than erroring. The
  suite runs as the least-privilege role so that mistake fails a test.
  `migrate`/`provision_app_role`/`claim_sentinel`/`seed.reset` use
  `admin_connection()` deliberately.
- **Every tenant query carries `AND user_id = %s` anyway.** RLS is the backstop,
  not the filter — the explicit predicate is clarity + index use, and
  `tests/db/test_tenant_read_scoping.py` (an AST guard) fails the build without it.
- **SQL is always parameterized** (`%s`). F-string interpolation into SQL only
  from hardcoded constant dicts, and each such site carries a comment saying so.
- **LLM access only via the grounded-ask choke point** in `insights/` —
  citation validation, refusal domains, hard output guardrails, anti-hallucination
  and confidence tagging happen there, not per-endpoint. The choke point is
  **`insights/pipeline.py`**; the only two entry points are `grounded_ask`
  (non-conversational surfaces) and `run_coach` (the coach, which needs a bounded
  tool loop and expresses it as a `pipeline.Loop`). No other module may talk to the
  LLM, and **no module except `pipeline.py` may reach a choke-point primitive**
  (`classify_refusal`, `check_output`, `validate`, `validate_json`,
  `evidence_section`, `build_context`) — an AST guard in
  `tests/insights/test_pipeline_shared.py` fails the build otherwise.
  **A new choke-point stage is added to `pipeline.answer_gates()` or
  `pipeline.question_gates()`**, never to a surface; the same test proves an injected
  stage reaches both surfaces.
  > `coach.py` used to be a standing exception here: it re-implemented the sequence
  > from the primitives (*enforced-equivalent, not routed-through*), and this rule
  > read "a new stage MUST be mirrored into the coach in the same PR". It had already
  > been missed once — the output guardrail was written in two places. #46 collapsed
  > the coach onto the shared pipeline, so the exception is gone and the mirroring
  > rule with it. A MUST that depends on someone remembering is the weakest kind.
- **Type hints on all public functions.**
- **Request bodies are ALWAYS pydantic models** — never a raw dict. Validation at
  the boundary is what keeps a bad value out of the science layer.
- **Responses are pydantic models for small, stable payloads** (`/api/challenges`,
  `/api/profile`, `/api/me`, …) — the model is cheap there and gives FastAPI a real
  OpenAPI schema plus a pyright-checked boundary.
  **Large aggregates are the documented exception** (`/api/today` is ~20 KB of deeply
  nested, largely-optional structure; `/api/sleep` similar): a model would duplicate
  that shape in a second place and rot, so **the contract snapshot in
  `packages/contracts` is the pin** and the handler returns `dict`. A new aggregate
  taking this exception says so in its router docstring.
  > This rule was rewritten 2026-07-31 to state what we actually do and intend. It
  > previously read "API request/response bodies are pydantic models, not raw dicts"
  > — an absolute that 24 of 28 routers ignored, i.e. a MUST that taught readers the
  > doc was decorative. Snapshots and models are not alternatives: the snapshot is
  > the *test* mechanism, the model is the *type* mechanism.
- **No import-time side effects**, no `__import__` reflection, no
  `subprocess`/`Popen` for in-process work — jobs run as supervised functions.
- Local (inside-function) imports are banned except to break a documented cycle
  — the legacy app.py's per-function imports caused repeated 500s.

### Tooling (enforced in CI)
- `ruff check` with: `E, W, F, I, N, UP, B, SIM, ARG, C90` (mccabe
  max-complexity 10), line length 100, target py313. `ruff format`.
- `pytest` — unit + the seeded-DB integration test must pass.
- A file-length gate script fails CI on any `*.py` over 400 lines.

---

## 3. Mobile standards (`apps/mobile`, Flutter / Dart)

### Layout
```
apps/mobile/lib/
  core/        env.dart (ALL dart-defines — the only place), logging, utils, theme controller
  ble/         protocol layer (auth, transport, fetcher, parsers) — version-guarded
  data/        store (local 60-day tier), api client (ONE instance via provider),
               sync engine, typed models
  analytics/   on-device engine — pure functions, parity-tested
  features/    today/ sleep/ activity/ insights/ actions/ coach/ profile/ workouts/
               (each: screen + widgets/ + providers; nothing reaches into another feature)
  shared/      charts, banners, error/empty/loading states, refresh scaffold, sheets
test/          parser goldens + analytics parity + widget smoke tests
```

### Rules
- **State via Riverpod only.** No global singletons, no `ValueNotifier`
  globals, no service instantiation inside widgets — everything injectable via
  providers (testability is the point).
- **Typed models at the data boundary.** The data layer parses JSON into typed
  models; feature code never reads raw `Map<String, dynamic>`.
- **Screens are composition.** A screen file lays out modules; each module
  widget lives in its own file under the feature's `widgets/`.
- **Every async consumer renders all three states** — loading, error (with
  retry), and empty/no-data — using the shared-state widgets. An error state
  that renders as a blank card is a bug.
- **`catch` requires an `on` clause** and routes through the app logger; sync
  and push failures surface in sync health, never debugPrint-only.
- **Design tokens only**: colors/typography/spacing from the theme system —
  no inline `Color(0xFF…)` in feature code.
- **Timezone/user constants come from profile/config**, never string literals.
- BLE parsers: layout-versioned, sentinel-filtered (`0xFF`), golden-fixture
  tested; byte offsets documented in an offset-table comment.

### Tooling (enforced in CI)
- `flutter analyze` — zero warnings. `analysis_options.yaml` extends
  `flutter_lints` plus at minimum: `always_declare_return_types`,
  `prefer_final_locals`, `avoid_catches_without_on_clauses`,
  `unawaited_futures`, `directives_ordering`, `require_trailing_commas`.
- `flutter test` — goldens + parity + smoke tests.
- The same 400-line file gate for `*.dart`.

---

## 4. Knowledge & grounding standards (`packages/knowledge`)

- **Per-claim evidence grades** with calibrated language: Established (state
  plainly) · Probable (light hedge) · Emerging (flag uncertainty) · Contested
  (present as debated) · Myth/Refuted (correct gently).
  **All five are now enforced, not just documented (#91).** `validator._grade_issue`
  implemented only three: `Myth` and `Refuted` both rank 0 in `GRADE_RANK`, so they
  fell through the branch they share with `Emerging` and were satisfied by "limited
  evidence" or a plain hedge. Hedging a debunked claim is the wrong framing twice
  over — it softens a correction the evidence supports flatly, and it lends a refuted
  claim the shape of thin-but-real evidence. Refuted grades now own the sentence and
  demand correction framing. The gap survived because **no note was graded `Myth`, so
  the branch was unreachable and no test could fail on it** — the same
  authored-intent-vs-enforced-value split as #83, one layer down and in the code
  rather than the corpus. What is enforced is that the sentence *marks the claim as
  unsupported*; "gently" is tone and stays with the banned-tone rule and the prompt.
- **A claim whose required framing differs from its note's headline grade gets its
  own note.** A note carries one `grade`, and that grade decides the framing the
  validator demands for every sentence citing it — so a `Myth` claim inside a
  `Probable` note ships under a hedge. The fix is to split the claim out when it is a
  separately *citable topic* (`hydration_8x8_rule` — "is the 8-glasses rule real?" —
  split from `hydration_everyday`, #91), keeping the parent note's id, aliases and
  `safety_critical` markers intact so no compiled guardrail moves.
  > Two other designs were considered and **rejected on measurement, not taste**:
  > *(a) redefine the note grade as "the weakest claim herein"* — 48 of ~50 graded
  > notes carry an inline claim weaker than their frontmatter grade, so this would
  > regrade nearly the whole corpus to Contested/Myth and force the coach to hedge
  > everything, including claims that are genuinely Established.
  > *(b) per-claim grades the validator resolves from a scoped citation* — this
  > assumes the inline `[Established]`/`[Myth]` markers and the note `grade` are the
  > same scale. They are not: an inline `[Myth]` marker almost always marks a claim
  > the note **refutes** (8×8; 220−age; the 10% rule), not a weak claim it asserts.
  > Making one mirror the other would rebuild #83's `evidence_grade` in a new shape —
  > a second grade that can disagree with the first. An unscoped citation would also
  > fall back to the note grade, i.e. to the bug.
- **A note has exactly ONE grade field, `grade`** — in both collections. The numeric
  `evidence_grade` mirror was removed (#83): the two could disagree, the winner
  depended on the note's *directory*, and the numeric could not express Contested or
  Myth at all, so a note authored `Myth` could ship as `Established` — the corpus
  instructing the product to state a debunked claim as fact. `make knowledge` rejects
  a note that reintroduces the field. Where code needs a numeric rank it derives one
  from the string in `insights/manifest.py::GRADE_RANK` — one definition, and the only
  one that can rank Contested (1) and Myth (0). *(As of #88 that name is a re-export:
  the map itself lives in `core/knowledge.py`, because `analytics/notes.py` needs it
  too and `analytics/` may not import `insights/`. It had quietly grown a second,
  identical copy there — identical being exactly the state the two grade FIELDS were
  in before they started publishing `Myth` as `Established`. Import it from either
  name; there is one dict.)*
- **Citations are real or absent** — a claim that can't be sourced is labelled
  practitioner consensus or omitted. Verify primary sources BEFORE writing.
- **Honesty section is mandatory** in every note: confounders, individual
  variation, limits of the metric.
- **Directives blocks**: each note ends with machine-applicable rules. A note may
  declare that one of them is a hard guardrail by naming it in frontmatter
  (`safety_critical: [5, 6]`), and **that declaration is now checked, not trusted**
  (#87). `gen_manifest.py` rejects a marker pointing at a directive that does not
  exist or does not say `SAFETY-CRITICAL` in its own text;
  `insights/guard_directives.py` compiles one blocking `OutputRule` per marker; and
  `tests/insights/test_guard_directives.py` asserts a **bijection** between the two,
  so a note claiming a guardrail nobody wrote fails the build and a rule whose origin
  directive was edited away fails it too. The corpus owns the claim, the code owns the
  pattern, the test owns the correspondence.
  > This rule was rewritten 2026-08-01. It previously described the compilation half
  > as not built — accurate then, but ~24 notes were meanwhile *asserting in prose*
  > that their directives were "mirrored as a hard guardrail in `@daud/core`, the AI
  > may not override". `@daud/core` exists in no repo. A false safety claim inside the
  > safety system is the worst kind: an auditor reads it and stops looking. **A note
  > may no longer make that claim in prose at all** — it declares the marker or it says
  > plainly that the rule is not enforced in code.
- Two rule tables are in force and they have different admission criteria, which is
  why they stay separate: `output_guard._DOCUMENTED_RULES` (hand-compiled, each citing
  the **doc line** that forbids it) and `guard_directives` (compiled from **marked note
  directives**). `output_guard.output_rules()` is the one seam both reach the pipeline
  through. **A new guardrail MUST have a documented origin** — that has always been
  binding and still is.
- A generated typed manifest makes the corpus retrievable (id, name, aliases,
  category, grade) — the index is generated, never hand-edited.

---

## 5. Process

- **Working model:** the lead agent writes briefs and reviews; implementation
  agents write code. Every diff is reviewed against this document before commit.
- **Small PRs/commits**: one reviewable concern per commit; commit in batches
  by theme. Never add a Co-Authored-By: Claude trailer.
- **Definition of done**: code + tests + this doc's gates green + verified
  end-to-end (run the affected flow, not just the tests) + docs updated.
- **Porting rule**: legacy code is reference, not substrate. Proven protocol
  and science code ports verbatim (then golden-verified); everything else is
  written fresh to these standards. Nothing is copied wholesale.
