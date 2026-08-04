# Healthee — mobile

The Flutter app. **Foundation only** — there are no feature screens yet. What
exists is the layer everything else gets built on: the theme, the API client, the
local store, and the type that carries the product's honesty contract.

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
              · router · theme/ (palette · tokens · dimensions · typography
                · app_theme)
  ble/        strap_scanner (the presence check) — the PROTOCOL is still to come
              (see its README)
  data/       honesty/ (the Reading union) · api/ (one dio client + credentials
              + secret_store + the server session: url · probe · failures)
              · pairing/ (the Zepp account route) · models/ (typed wire models)
              · store/ (drift, 60-day tier) · today_repository.dart
  analytics/  on-device engine — empty (see its README)
  features/   pairing/, signin/ and today/ are built; the other tabs are not
  shared/     states/ (loading · error · empty · withheld · value_hole)
              · foundation_screen
test/         golden contract parse · envelope unit · store · theme tokens
              · widget smoke · pairing (crypto goldens · client fixtures ·
                failure taxonomy · the secrecy proof)
              · signin (address rules · what is stored · the secrecy proof)
```

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

The theme is the **approved app design** (`Healthee.html`), transcribed verbatim
from `docs/APP_DESIGN_BRIEF.md` §2 — indigo accent, near-white light and
near-black dark, Instrument Sans. Owner decision 2026-08-04: *"the colors and
fonts all we will keep from new."* Direction is **modern instrument**, explicitly
not editorial: no serif, no paper texture, no beige.

**The app and the landing page deliberately diverge.** `apps/landing` is v5 "The
Ledger" — warm paper, clay accent. The app is not, and that is a choice, not
drift. It also settles `docs/APP_DESIGN.md` §7.1's open "green vs indigo"
question: neither option that question offered survived.

Rules that are structural here, not conventions:

- **Colour is a claim.** Only `fav`/`unf` say something about a reading (better
  or worse than the owner's *own* normal), and `alert` is the illness flag alone.
  Everything else is greyscale + accent. Never colour a card to decorate it.
- **A refusal spends no colour.** A withheld value renders a `ValueHole` — a
  dashed, `hole`-filled box exactly where the number would have been — with the
  reason in ordinary ink. Tinting it would make "we are declining to tell you"
  look like a verdict about the owner's body.
- **`unf` is not a warning colour and must never be used as one.** "This reading
  is below your normal" and "we won't guess" are different claims. The recovery
  signal ladder (brief §5.1) needs the `fav`/`unf` pair and cannot be drawn
  without it.
- **There is one red.** `alert`, for illness. `ErrorState` is greyscale with an
  outlined retry; a dead request is not a fact about the owner's health.
  `ColorScheme.error` is wired to `alert` only so Material's own widgets do not
  introduce a second red nobody chose.
- **The accent is a light/dark PAIR**, not one hex reused. `test/core/theme_test.dart`
  fails if a theme-invariant brand colour is reinstated.

**One deliberate departure from `Healthee.html`:** it hardcodes `#fff` on the
accent, which measures 2.97:1 against the dark accent — below WCAG AA and below
even the 3:1 large-text floor. `onAccent` is therefore per-theme (white on light,
page-background on dark, 6.30:1 and 6.66:1). No new colour; both values were
already approved. Flagged for the owner.

Instrument Sans is vendored in `assets/fonts/` (SIL OFL, licence beside it,
~195 KB) rather than fetched — no CDN at paint time, and the face is confirmed by
the approved design. Tabular figures are on for the whole text theme, so a value
that changes does not shift the glyphs beside it (brief §7 makes this a hard
constraint).

**No colour literal exists outside `core/theme/palette.dart`**, and
`test/core/theme_test.dart` locks every token to the brief's table — `flutter
analyze` cannot see a wrong-but-valid colour, so a test has to.
