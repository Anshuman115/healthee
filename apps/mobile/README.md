# Healthee — mobile

The Flutter app. Five tabs — Today · Sleep · Activity · Insights · Actions —
over the layer everything is built on: the theme, the API client, the local
store, and the type that carries the product's honesty contract. **Coach is not
a tab**: it is a button on Today and a chat sheet behind it, which is legacy's
shape (`app/lib/main.dart:399`). Pairing, server sign-in, settings and
diagnostics sit outside the tabs.

Read `docs/ENGINEERING_STANDARDS.md` §3 and `docs/APP_DESIGN_BRIEF.md` before
writing UI. (`docs/APP_DESIGN.md` is the older planning doc; where they differ,
the brief wins.)

## Run it

```bash
cd apps/mobile
flutter pub get
dart run build_runner build          # only after editing an annotated file
flutter run --dart-define=HELIO_API=https://healtheeapi.afk.codes
```

## Gates (what CI runs)

```bash
flutter analyze --fatal-warnings --fatal-infos   # zero warnings AND zero infos
flutter test
python3 ../../scripts/check_file_length.py       # 400-line gate, repo-wide
```

`--fatal-infos` is not incidental: every lint in `analysis_options.yaml` is a
build gate, because a warning nobody has to fix is a warning nobody fixes.

## Where things live

```
lib/
  core/       env.dart (the ONLY dart-define site) · logging · provider_logger
              · router · theme/ (palette · tokens · instrument_hues
                · metric_hue · instrument_type · shapes · motion · dimensions
                · typography · app_theme)
  ble/        strap_scanner (the presence check) — the PROTOCOL is still to come
              (see its README)
  data/       honesty/ (the Reading union) · api/ (one dio client + credentials
              + secret_store + the server session: url · probe · failures)
              · pairing/ (the Zepp account route) · models/ (typed wire models)
              · store/ (drift, 60-day tier) · today_repository.dart
  analytics/  on-device engine — empty (see its README)
  features/   today/ sleep/ activity/ insights/ actions/ coach/ settings/
              diagnostics/ pairing/ signin/
  shared/     instrument_screen (the shell every tab uses) · app_tab_bar
              · connection/ (the dot and the strip)
              · page_head · page_section · section_heading · instrument_module
              · instrument/ (the ported HTap · badges · progress bar)
              · charts/ · skeletons/ · states/ (loading · error · empty
                · withheld · value_hole) · foundation_screen
test/         golden contract parse · envelope unit · store · theme tokens
              · typography (the face swap, measured) · widget smoke
              · pairing (crypto goldens · client fixtures · failure taxonomy ·
                the secrecy proof)
              · signin (address rules · what is stored · the secrecy proof)
              · render/ (a look-at-it harness, NOT a test — see below)
```

## The screens, and why Today is short

**Today is an index.** It carries the greeting, the data-health strip, the
illness flag, the readiness instrument, a six-module grid, the 24-hour heart
rate, stress, and one suggested action — the shape of
`design_reference/project/hh/screen_today.jsx`, which is 140 lines. **Every grid
module is a door**, exactly as legacy's are, and the detail lives behind it:

| tab | what it holds |
|---|---|
| **Sleep** | last night · sleep health · debt · the week · blood oxygen · the recovery ladder |
| **Activity** | steps · cardio load · active minutes · workouts · VO₂max · biological age |
| **Insights** | trends over the owner's own history, and the correlations found in it |
| **Actions** | every cited action the server raised for today, in full |

`/settings` and `/diagnostics` are **off the tab bar**. The Today avatar opens
settings, and settings is the only door to diagnostics: "is the instrument
working" is a question asked when something looks wrong, and never at 7am.

### Colour on Insights, and the split that governs it

A **trend** may be coloured `fav`/`unf`, because
`shared/format/metric_polarity.dart` holds the one table saying which direction
is better for each metric — and a metric moving against the owner's own past is
precisely the claim those two colours are licensed for.

A **finding** may not turn its sign into a verdict, in any state. The sign of a
rank correlation says *moved together* or *moved opposite*; that is a direction,
not a verdict, and a q-corrected correlation over 105 days of one person's
history cannot support "this is good for you". Legacy kept the same restraint
(`insights_screen.dart:274`).

The test for that used to be "a finding spends no `fav` and no `unf`". It cannot
be, since the port: legacy's `cHrv` **is** its green, so a finding about HRV
legitimately paints its own hue in the colour that also means improving. What is
asserted instead is stronger — **flip the sign of the coefficient and nothing may
change colour** — and it is mutation-proof in a way the old assertion was not,
because the old one also passed for a row that was simply grey.

A metric the table calls **neutral** (calories) and a metric it has **never heard
of** both render with no verdict colour. That is the load-bearing case rather
than the leftover one: a screen that tinted everything would teach the owner that
colour here is decoration, after which the rows where it is a claim say nothing.
`test/mutations.sh` breaks it on purpose.

The **recovery signal ladder stays on Sleep** and keeps using the server's own
`direction` field. CLAUDE.md allows one definition per metric, and computing a
second opinion in the client would be a second definition free to disagree.

There is **no anomalies section**, because `/api/today` cannot feed one:
`read/today.py:83` sets `payload["anomalies"] = []` unconditionally and points at
`/api/notable` — a separate, premium-gated, LLM-backed endpoint this app does not
call. A heading that can never have anything under it is dead code.

## The coach is a sheet, and it is wired

`features/coach/` is a FAB on Today (`shared/app_shell.dart` draws it for the
home branch alone) opening a chat sheet. `POST /api/coach` is real and metered at
**20 questions per rolling 30 days**, so three things are structural:

1. **The input cannot exist without the meter.** The sheet reads
   `/api/entitlement` first and only builds a composer when it holds a balance
   that permits a question. Checking, failed, locked and spent each render their
   own sentence and no box to type in.
2. **The cost is on the button before the tap** — `Ask — uses 1 of your 17`.
3. **The meter is re-read, never decremented.** `routers/coach.py` refunds the
   question on a refusal, on an unvalidated answer and on a transport failure, so
   a local subtraction would be wrong in three of five outcomes — and wrong in
   the flattering direction.

Every failure lands **in the thread**, saying whether anything was charged. A
question that vanished, or that left the thread looking unanswered, is how "did
that use one of my twenty?" becomes unanswerable.

## The connection surface: a dot, until it isn't

A full-width `Connected · Sync now` bar used to sit at the top of Today forever.
It is now a 7 px dot beside the date when nothing is wrong
(`shared/connection/connection_dot.dart`), and a full-width strip when something
is (`connection_strip.dart`).

**A quiet healthy state is honest only if every unhealthy state is loud.** So
`data/sync/connection_health.dart` is the ONE place the quiet answer is computed;
its link half is a `switch` over the sealed union with no default; and its data
half **iterates** `dataHealthLines` rather than naming the faults it knows about,
because the failure mode of a hand-written list is silence.

`HealthLine` has two constructors and `HealthLine.alarm` **requires** a short
headline and an id, so a loud line the strip could not draw does not compile.
The strip shows the headline and the data-health card shows the paragraph: a
title and its body from one function, not two voices.

**Pull-to-refresh is the manual sync** — `SyncController.syncNow`, the
un-debounced path — which is what let the permanent button go. The button
survives only on the strip that appears when something is wrong.

### Two resting heart rates, and the rule

Resting heart rate and HRV each have **two instruments** in this product, and
they disagree by construction. The full trace is in
`features/diagnostics/diagnostics_screen.dart`; the rule is:

1. **The canonical daily read is the server's** — `rhr_daily` (the lowest
   5-minute mean heart rate inside the sleep window) and `hrv_sleep_avg` (the
   bounded mean of overnight RMSSD).
2. **The strap's own estimates are still shown, and every one names its
   instrument** — as VO₂max names `gps_graded` against `jurca_non_exercise`.
3. **A label may never carry two definitions.** Where a grid cell falls back to
   a strap value it becomes `Resting HR · strap`.

## Looking at it

`test/render/render_screens.dart` renders every screen to PNG in both themes,
with the app's real fonts loaded, at a phone's width and a viewport tall enough
that the whole scroll lays out in one pass. It is **not a test** — it asserts
nothing, and its filename keeps it out of `flutter test`.

```bash
flutter test test/render/render_screens.dart && ls build/renders/
```

Run it before and after any layout or colour change and *look at the output*.
Grep is not a design, and a report of visual work is not the work.

## The tab bar is the shell's, and the tabs are branches

`core/router.dart` mounts the five tabs as the branches of a
`StatefulShellRoute.indexedStack`; `shared/app_shell.dart` is the only `Scaffold`
in the app with a `bottomNavigationBar`, and `core/tabs.dart` is the one list the
bar and the branches are both built from — they are joined by **index**, so two
lists would be a defect that compiles.

**A screen never draws the bar and never takes a tab index.** They used to: five
copies over four sibling `GoRoute`s, which meant a tab switch built a new page
and threw away the scroll offset, the reveal registry and the provider reads with
it. `RevealOnce` holds "have I been seen" in the screen's `State`, so the replay
rule CLAUDE.md sets was being kept inside a screen and defeated between them.
`test/features/tab_shell_test.dart` measures both.

Pairing, sign-in, `/settings` and `/diagnostics` sit **outside** the shell, with
no bar: two are setup flows the router redirects into, and the other two are
about the app rather than about a day.

Actions used to be drawn dimmed and inert, which is the right shape for a missing
*number* — the card is the shape and the sentence under it is the answer — and
the wrong shape for a navigation control, which is a promise of a destination
with no room to qualify itself. It came back with its screen, as that argument
said it would.

### Android back

`shared/app_shell.dart` answers it in three steps: pop the current branch's own
`Navigator`; failing that, and not on Today, go to Today; on Today with an empty
stack, leave the app. Step 1 reads `StatefulShellBranch.navigatorKey` rather than
a history list — the branch navigator already holds what a tab has pushed, and a
parallel list would be a second copy of the navigation state.

Leaving on the third step is deliberate: it is the platform contract, nothing is
unsaved (the store is on disk and the sync controller is `keepAlive`), and
"press back again to exit" trains people to press back twice forever to prevent
an accident that costs nothing.

**`go` replaces; every out-of-shell destination is `push`ed.** That rule was
missing and the app shipped a defect the shell rule then executed perfectly: a
`go` into Settings left nothing beneath it, so back found an empty branch stack,
concluded "not on Today", and dropped the owner onto the Android home screen.
Settings → Diagnostics → back did it too. The verbs now go:

| navigation | verb |
|---|---|
| tab → tab (`app_tab_bar.dart`) | `go` — a bar switches between siblings |
| Today → settings · sign-in | `push` |
| settings → diagnostics · sign-in · pairing | `push` |
| the router's unpaired redirect | replace — there is nothing to return to |

`push` is also what draws the back arrow: a `go`-ed screen with an `AppBar` has
no leading control, so those screens offered no way back **at all**. The gesture
and the affordance went missing together, which is why nothing looked broken.

`router.dart::leaveSetup` is the one place the two columns meet — pairing and
sign-in are *pushed* from Settings and *redirected into* when unpaired, so "Done"
asks `canPop()` rather than being told which it was. Back out of a **redirected**
setup flow still leaves the app, deliberately: there is nothing underneath and
the redirect would bounce the owner straight back onto it.

## Settings

`/settings`, off the tab bar, opened by the Today avatar — the entry point that
already existed, extended rather than duplicated. Five rows and every one does
something real today: **appearance** (over the SAME `themeControllerProvider` the
header toggle writes, so the two agree by construction), **your server**, **your
strap** (pairing, `lastCompleteSync` — never `lastAttempt` — and the battery at
that sync), **diagnostics**, and **about**.

Sign-out and unpair are *routed to*, not re-implemented: `features/signin/` and
`features/pairing/` own them, §3 forbids a feature reaching into another's code,
and two sign-outs would be two places the keystore write can diverge.

**The licence notice is a licence term, not a nicety.** `assets/fonts/OFL.txt`
was never declared as an asset, so the SIL OFL shipped to git and not to a phone.
It is bundled now, registered with `LicenseRegistry` in `core/licences.dart`, and
reachable through the About row's `showLicensePage`.

## Generated prose renders through `GroundedProse`, always

`/api/today` carries four fields a model wrote: `action`, and each
recommendation's `action`, `expected_effect` and `rationale`. They arrive with
inline `[note_id]` citation markers, which is correct — the server's blocking
validator reads them — and the card used to print the string, markers and all.

`shared/states/grounded_text.dart` is the only thing feature code may use for
those fields. It takes the **raw** string and renders the sentence and its
sources together; there is no parameter that turns the second half off, and the
parse is deliberately not exposed, because a `stripCitations()` helper would make
dropping the grounding one character cheaper than keeping it.

A bracket that resolves to no citation is **left in the sentence** and announced
underneath. It might be the model's own prose or a truncation, and deleting it
would be the app editing a claim it cannot read.

Chips show the corpus's own **name**, never the id — `shared/format/note_names.dart`
is generated from `packages/knowledge/manifest.json` by `tool/gen_note_names.py`,
aliases included, because the server cites some of those directly.

## The one thing to understand before writing a screen

`data/honesty/reading.dart` defines `Reading<T>` — a **sealed union** with four
cases that mirror the server's own vocabulary:

| case | meaning |
|---|---|
| `Present` | a value, with nothing attached |
| `Caveated` | a value, **and** which way it leans |
| `Withheld` | no value, **and** the action that would bring one back |
| `Excluded` | no value, and nothing anyone could do — the evidence doesn't support it |

The server already keeps its half structurally: when a gate refuses, it nulls the
value *and* attaches a `withheld` block. `read/vo2max.py` says why in as many
words — "a dated field the UI may not render does not undo a confident
current-looking number". That sentence is about the app. If a value were modelled
as `double?`, forgetting the withheld case would be a blank card rather than a
compile error, and the gate would be defeated on the last hop.

So it is one type, and **Dart's exhaustiveness checking makes forgetting a case a
compile-time error**. Render through `ReadingView`, which supplies the three
honest states for free and prints a `Caveated` value's disclosures *without being
asked* — dropping them takes a deliberate override rather than an oversight.

`AsyncView` is its sibling for `AsyncValue` (loading / error-with-retry). They are
separate on purpose: a timeout and a withhold are opposite messages — one is our
fault and worth retrying, the other is the answer.

## Pairing — what is stored, and what the owner chose

`lib/data/pairing/` reads the strap's MAC and pairing key out of the owner's
**Zepp account**, which is where pairing the strap in Zepp's own app already put
them. Three calls (`zepp_endpoints.dart`), the middle one encrypted with a fixed
key Zepp's Android client publishes to the world. Then a BLE scan confirms the
strap is actually advertising, because credentials for a strap in a drawer look
identical to credentials for the one on your wrist.

**Kept, always:** the MAC and the auth key, in the platform keystore. Both are
device secrets and the auth key is treated exactly like a password — it is never
rendered on screen, never logged, and **never sent to the Healthee API**. There
is no endpoint that takes it and this work package added none.

**Kept only if the owner ticks the box** (default off, and turning it back off
deletes what an earlier pairing stored): the Zepp email and password, so
re-pairing does not mean typing them again.

**Never kept:** the Zepp app token. It has a ~30-day life, which is exactly the
argument for caching it — and nothing after pairing reads it, because the strap
is reached over BLE directly. A stored credential with no consumer is a blast
radius; a stored credential that silently expires is a bug this repo has already
paid for once.

**The password's whole life:** typed into the form, held in a private field on
`PairingController`, sent once to `api-user-us2.zepp.com`, dropped. It is not in
`PairingState` — an observer that logged state transitions would otherwise print
it the day someone adds one.

`test/pairing/pairing_secrecy_test.dart` is the proof rather than the promise:
it drives the whole flow with sentinel secrets, captures everything `AppLog`
emits, and fails if any of them appears. It covers the failure paths hardest,
because an exception object is the thing that has the response body in hand.

## What the phone keeps — and the one thing that can end a measurement

The 60-day local tier is a **read** horizon, not a delete-by date. `localHorizonDays`
bounds how much history the app will show you; it does not decide when your data
stops existing. `lib/data/store/horizon_prune.dart` is the whole policy and it is
three tiers, because the five day-keyed tables do not hold the same kind of thing:

| table | what it is | when a row goes |
|---|---|---|
| `cached_payloads` | a copy of what the server sent | 60 days, always — the server will send it again |
| `sleep_sessions` · `stored_workouts` · `device_totals` | measurements, a few rows a day | 60 days **if pushed**; an unsent row is kept with no second bound |
| `strap_samples` | measurements, 11,520 rows a worn day | 60 days **if pushed**; an unsent row is kept for a year |

The guard is `pushed_at_ms`, which the push already writes and only writes after a
2xx. A row the server has acknowledged is safe to drop — the server is its durable
home. A row the server has never seen is not, because the strap's ring buffer
overwrites in about a week or two and there is nowhere else to read it from.

**Why the event tables get no bound and the samples get one year.** Measured on a
real drift/SQLite file: a sample row costs ~60 bytes, a staged night ~1.4 kB. Four
nights, a handful of workouts and one counter a day is ~2 MB a *year* — a table that
grows by events cannot make a phone grow without limit, so there is no honest bound
to set. Per-minute samples are ~0.66 MB a worn day, so they are the only real storage
question: one year caps them at ~240 MB. A year is chosen because no transient cause
of a stuck queue — signed out, rotated token, server down, a fortnight with no signal
— lasts one, and because the loud "N measurements are waiting here" line will have
been on the Today screen roughly 365 times by then.

**If that bound is ever reached, the app says so and does not stop saying so.** The
count, the date it covers and what the owner could have done are written into
`SyncMeta`, surfaced on `PushStamp.loss`, and stated in full ink on the data-health
card — permanently, because nothing undoes it. It is never phrased as maintenance.

`test/mutations.sh` breaks each of these guards on purpose and fails if a test does
not notice. A guard that fires 60 days after a row is written is a guard nobody
exercises by using the app.

## Where tokens live

`core/env.dart` is the **only** place a `--dart-define` is read. `HELIO_API`,
`HELIO_TIMEOUT_S` and `HELIO_LOG_HTTP` are the whole list.

**`MAC`, `AUTHKEY` and `HELIO_TOKEN` are deliberately not dart-defines.** They are
per-owner secrets, they live in the platform keystore via
`data/api/credentials.dart`, and they are written at runtime — the first two by
pairing, the third by the sign-in screen. The legacy app compiled the first two
in, and that single decision is what made it single-owner: the binary *was* the
pairing, a second person could not use a build without recompiling it, and the
owner's key shipped inside every APK.

The rule that follows: **a dart-define may describe the build; it may never
identify the owner.**

## Signing in to the server

`features/signin/` takes a server address and one opaque token, and
`data/api/server_session.dart` stores them **only after the server has said yes**.
The order is the whole feature:

```text
  parse the address   ──▶  cleartext and malformed die here, unsent
  trim the token      ──▶  a pasted newline never becomes a 401
  ask the server      ──▶  200 · 401 · unreachable, told apart
  THEN store          ──▶  only a token the server itself accepted
```

**The check is `GET /api/entitlement`.** It is the lightest authenticated read on
the API (one `subscription` row, no samples), it is *deliberately ungated* on the
server so a free or lapsed owner still gets 200, and it is uncached. `/api/me`
looks like the obvious probe and is wrong: `routers/auth.py` binds it to Supabase
JWT only, so it answers 401 to the shared token that is the only thing that works
today — probing with it would report every correct token as refused.

**The three outcomes are different code paths, not three branches of one catch.**
The probe's dio sets `validateStatus: (_) => true`, so a 401 is a status on a
`Response` and only a dead network throws. That is what makes "couldn't reach the
server" structurally unable to appear for a token the server read and rejected —
the failure that is expensive precisely because it sends somebody to their router
for an evening. `data/api/signin_failure.dart` is the named taxonomy; a
`DioException` type is never shown to anyone.

**Plain `http://` is refused unless the host is loopback**, before the request is
built. A bearer token on an unencrypted connection to a remote host has leaked by
the time anything answers, so there is no override to tick.

**Nothing redirects to the sign-in screen.** Strap-only is a supported mode: the
measured half of Today comes off this phone with no network at all. The way in is
the Today data-health strip, which says plainly when there is no session and is
silent when there is, and a "Your server" row on the pairing screen — which is
also where sign-out lives.

`test/signin/signin_secrecy_test.dart` is the proof that the token is never
logged: it drives the sign-in check *and* the app's real dio (both interceptors,
including with body logging switched on) with a sentinel that exists in no other
file, captures everything `AppLog` emits, and fails if it appears. It was
mutation-checked three ways — logging request headers, handing the
`DioException` to the logger, and printing the token on success — and each one
failed it.

## Generated code IS committed

`*.g.dart` and `*.drift.dart` are in git. CI runs `flutter pub get`, `analyze` and
`test` — it does **not** run `build_runner`, so uncommitted generated files would
be missing `part` files and analysis would fail on the first push. Committing them
also means a reviewer sees what the annotations actually produced.

They are excluded from `flutter analyze` (their generator owns their style) and
from the 400-line gate (`scripts/check_file_length.py` already skips them).

**Re-run `dart run build_runner build` and commit the output** after editing
anything annotated `@riverpod`, `@DriftDatabase`, or `@JsonSerializable`.

## Dependency conflicts, and what was chosen

Three of the versions in the brief could not be used. None was silently
downgraded; each is recorded here and in a comment at its line in `pubspec.yaml`.

**The root cause is one constraint.** Flutter 3.44.7's bundled `flutter_test` pins
`meta 1.18.0` and `test_api 0.7.11`, which puts a hard ceiling of **analyzer 12.x**
on this package. The whole code-generation stack hangs off the analyzer version,
so several packages' newest releases are not merely unpreferred here — they are
unreachable. Raising the Flutter SDK lifts all of them, and the caret ranges mean
that happens without editing `pubspec.yaml`.

| wanted | taken | why |
|---|---|---|
| `build_runner 2.16.0` | `^2.14.0` → 2.15.1 | ≥2.15.2 needs analyzer ≥13.3, which needs meta ^1.18.3 |
| `riverpod_generator 4.0.8` · `flutter_riverpod 3.4.2` · `riverpod_annotation 4.0.6` | 4.0.4 / 3.3.2 / 4.0.3 | generator ≥4.0.6 needs analyzer ^13; the riverpod family is version-locked to its own generator, so the runtime moved with it |
| `drift_dev 2.34.5` | `^2.34.0` | ≥2.34.1+1 needs analyzer ^13. Still the same minor as the `drift` runtime, which is what generated code targets |

**`freezed` was dropped entirely.** No *stable* freezed supports analyzer 12 —
3.2.5 caps at 10, and only the 3.2.6-dev pre-release reaches 12. Keeping it would
have meant either downgrading four packages to keep one, or putting a pre-release
code generator underneath every model in the app. What freezed would have
contributed here is `copyWith`/`==`/`toString` boilerplate; it is **not** what
makes the honesty union exhaustive. Dart 3's own `sealed class` is, and that is a
language feature no package can hold back a version.

**`sqflite` was dropped** as superseded, not blocked: the architectural decision
picked `drift` over it, and keeping both would be a second way into the same
database.

**`custom_lint` + `riverpod_lint` cannot both be installed**, and riverpod's lints
are **not running**. riverpod_lint 3.1.4 moved off custom_lint onto the analyzer's
own plugin protocol, so 3.1.8 needs `analyzer_plugin ^0.14.0` while custom_lint
0.8.1 needs `^0.13.0`. The successor path — a `plugins:` block in
`analysis_options.yaml` — was tried and **measured**: `flutter analyze` accepts the
key and reports nothing from it (verified by deleting the root `ProviderScope`, a
textbook `missing_provider_scope` violation, which analyze did not flag), and
`dart analyze` hung for 7+ minutes until the block was removed. Declaring a lint
nobody runs is worse than declaring none, so the block is gone and
`analysis_options.yaml` records the experiment and how to re-check it after an SDK
bump.

## Design system

**The legacy app is the specification.** Owner decision 2026-08-05: *"not a
single change in design, every section remains as is, every tab, everything —
only honesty wording as mentioned."* Everything visual is ported from
`~/projects/healthee-legacy/app/lib/ui/`. Exactly three things may differ:

1. **The typeface** — Manrope replaces Newsreader / Hanken Grotesk / Space Mono.
2. **The light/dark scaffolding** — page, surface, ink and hairline keep the
   rebuild's near-white and near-black values. Every *other* colour is legacy's,
   to the hex.
3. **Honesty wording** — `Reading<T>` still governs every field, a withheld value
   still renders withheld, citations still resolve to readable source names.

### Where the design lives

```
core/theme/palette.dart          the ONLY colour literals: scaffolding + legacy
core/theme/tokens.dart           semantic roles → context.colors
core/theme/instrument_hues.dart  legacy's ten per-metric hues + sleepStage()
core/theme/metric_hue.dart       which metric wears which, from legacy's call sites
core/theme/instrument_type.dart  legacy's HType roles, wearing Manrope
core/theme/shapes.dart           hSquircle — the continuous corner every card has
core/theme/motion.dart           legacy's four durations and its signature ease
shared/instrument/               HTap · HDeltaBadge · HProgressBar · HIconBadge
shared/instrument_module.dart    HModule and its eyebrow, value and foot
shared/charts/                   the ported painters
shared/skeletons/                the content-shaped loading states
```

### Rules that are structural here, not conventions

- **Identity and judgement SHARE hues, by decision.** Legacy's `cHrv` and
  `cReady` *are* its green, which is also "improving"; its `cHeart` is also
  "degrading" and the illness flag (`insights_screen.dart:171` —
  `improving ? c.green : c.cHeart`). The five-hue identity-tag system existed to
  make exactly that impossible, and is **deleted** — `metric_hues.dart` and its
  test are gone. Do not reintroduce a separate verdict palette; `palette.dart`
  carries the whole argument, and `test/theme/legacy_hues_test.dart` asserts the
  collisions rather than avoiding them, so a "fix" fails and has to be argued.
- **A hue is a function of the metric's identity and never of its value.**
  `core/theme/metric_hue.dart` holds the one table, transcribed from legacy's own
  call sites with the line numbers cited; `hueFor` takes an id and nothing else.
- **One sleep-stage mapping.** `InstrumentHues.sleepStage` — deep amber, light
  blue, REM purple, awake red — and nothing else decides a stage's colour.
- **A refusal spends no colour.** A withheld value renders a `ValueHole` — a
  dashed, `hole`-filled box exactly where the number would have been — with the
  reason in ordinary ink. This is honesty wording, so it survives the port.
- **Charts animate once.** `progress` is a parameter supplied by `RevealOnce`; no
  chart owns a ticker, or it replays on every scroll-back.
- **No colour literal exists outside `core/theme/palette.dart`.**
  `test/core/theme_test.dart` and `test/theme/legacy_hues_test.dart` restate both
  source tables independently — `flutter analyze` cannot see a wrong-but-valid
  colour, so a test has to.

### Three legacy imperfections that ship as-is, and are flagged

The brief is explicit that a faithful port of something imperfect beats an
unrequested fix, so each of these is recorded rather than repaired.

- **`onGreen` fails contrast on the dark accent.** Legacy puts one off-white
  (`#FBF7EF`) on both greens: 5.68:1 on light, **2.14:1** on dark — below WCAG AA
  and below the 3:1 large-text floor. The measurement is pinned in
  `test/core/theme_test.dart` so it cannot drift further or be forgotten.
- **An unrecognised sleep stage is drawn as light sleep** (`theme.dart:36`), so a
  code nothing measured is not visibly distinct from one that was.
- **Legacy disagrees with itself twice**: cardio load is `cHeart` on Today and
  `cReady` on Activity; blood oxygen is `cResp` on Today and `cSpo2` on Sleep.
  Today's wins in `metric_hue.dart`, and both conflicts are documented there.

### The hue set, both themes

| legacy | light | dark | what wears it |
|---|---|---|---|
| `cSleep` | `#5B5483` | `#968EC9` | sleep, sleep debt, REM |
| `cHeart` | `#BF472E` | `#E07A5F` | heart rate, cardio load, awake, **`alert`** |
| `cHrv` | `#1F6F54` | `#4BBF93` | HRV, MVPA — **the accent and `fav`** |
| `cSteps` | `#B27F2C` | `#D9A84E` | steps, distance, deep sleep |
| `cCal` | `#CE6131` | `#E8835A` | calories, and legacy's stress card |
| `cResp` | `#3C7A84` | `#5FA9B4` | breathing, overnight blood oxygen |
| `cSpo2` | `#587A97` | `#7DA3C4` | light/core sleep, SpO₂ vitals, zone 1 |
| `cStress` | `#A55F6D` | `#C98A96` | skin temperature |
| `cReady` | `#1F6F54` | `#4BBF93` | VO₂max, biological age, SRI, load |
| `cRem` | `#8A7FB8` | `#B3A9E0` | nothing — defined by legacy, drawn by none |

Two more legacy values are **one colour in both themes**, because legacy wrote
one: the warn amber `#E0A33E` (`unf`) and `onGreen` `#FBF7EF` (`onAccent`).

**Manrope** is vendored in `assets/fonts/` (SIL OFL, no Reserved Font Name,
licence beside it, ~290 KB) rather than fetched — no CDN at paint time. Three
weights, 400/500/600, instanced from upstream's variable font. Two consequences
of that for the port, both named in `instrument_type.dart` rather than hidden:
`HType.number` asks for **700 and gets 600**, and `HType.serif(italic: true)`
renders **upright**, because neither face is vendored.

Tabular figures are on for the whole text theme and for every `HType` role, so a
value that changes does not shift the glyphs beside it.
`test/core/typography_test.dart` measures that rather than trusting it, checks
the display strings against the narrowest phone (Manrope runs wider), and reads
the font's own `cmap` to prove the glyphs are there — **Instrument Sans had no
U+2082**, so `SpO₂` drew a tofu box on the live screen, and no `σ` for the
recovery ladder's caption either.
