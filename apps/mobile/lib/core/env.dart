/// The ONLY place in this app that reads a `--dart-define`.
///
/// Engineering Standards §3 is explicit: "All dart-defines live in
/// `core/env.dart`". Not "mostly"; the rule is worth the file because
/// `String.fromEnvironment` is a **compile-time** read — it silently returns the
/// default when the define is missing, so a second call site with a mistyped key
/// does not fail, it just quietly gets the empty string. One file means one place
/// to read to know what this build was configured with, and one place to grep
/// before a release.
///
/// If you are adding a build-time knob, it goes here. If you are reaching for
/// `String.fromEnvironment` anywhere else, the answer is no.
///
/// ## What is deliberately NOT here: `MAC` and `AUTHKEY`
///
/// The legacy app took the strap's Bluetooth MAC address and its pairing
/// AUTHKEY as dart-defines, baked at build time. That single decision is what
/// made it a single-owner app: the binary *was* the pairing. A second person
/// could not use a build without recompiling it, and the owner's own key shipped
/// inside every APK.
///
/// Both values come from the Zepp account at pairing time and are per-owner
/// secrets. They live in the platform keystore via `flutter_secure_storage`
/// (`data/api/credentials.dart`), written once when the strap is paired and read
/// by the BLE layer. The same goes for the API bearer token: `HELIO_TOKEN` is
/// *not* a define here either, because a token compiled into a build is a token
/// that cannot be rotated without a release.
///
/// The rule that follows: **a dart-define may describe the build; it may never
/// identify the owner.** Anything owner-specific is runtime state in secure
/// storage. That is the whole difference between the legacy app and this one.
library;

/// Build-time configuration. All fields are compile-time constants.
///
/// Not injectable and not a provider on purpose — these values cannot change
/// while the app runs, and wrapping a `const` in a provider would suggest they
/// can. Runtime configuration (the paired strap, the signed-in owner, the
/// selected theme) is Riverpod state; this is not that.
abstract final class Env {
  /// Base URL of the Healthee API, e.g. `https://healtheeapi.afk.codes`.
  ///
  /// Defaults to the loopback address a debug build talks to when the server is
  /// running from `infra/docker-compose.yml` on the same machine. It is a
  /// LOCAL-ONLY default on purpose: a release build that forgets `--dart-define`
  /// should fail to reach anything, loudly, rather than quietly aim at prod.
  static const String apiBaseUrl = String.fromEnvironment(
    'HELIO_API',
    defaultValue: 'http://127.0.0.1:8765',
  );

  /// How long a single API call may take before it is an error.
  ///
  /// Standards §1 budgets server read endpoints at p95 < 100 ms, so ten seconds
  /// is not a latency target — it is the point past which the network is not
  /// coming back and the UI should say so instead of spinning forever.
  static const Duration requestTimeout = Duration(
    seconds: int.fromEnvironment('HELIO_TIMEOUT_S', defaultValue: 10),
  );

  /// How long one `POST /ingest/helio` may take.
  ///
  /// Deliberately far longer than [requestTimeout], and the legacy client's
  /// comment says why in the voice of the person it happened to: a multi-day
  /// backlog is a big body **and** a server-side multi-day re-derive, "30 s was
  /// too short, so the sync kept timing out and the backlog never cleared". A
  /// backlog that can never clear is a permanent hole in the owner's history,
  /// which is a worse failure than a slow request.
  ///
  /// The push is paged, so this bounds a page rather than a whole catch-up.
  static const Duration pushTimeout = Duration(
    seconds: int.fromEnvironment('HELIO_PUSH_TIMEOUT_S', defaultValue: 180),
  );

  /// Whether to log every HTTP request/response body.
  ///
  /// Off unless asked for, in every build type. Response bodies here are somebody's
  /// health data, and `--dart-define=HELIO_LOG_HTTP=true` is a deliberate act.
  static const bool logHttpBodies = bool.fromEnvironment('HELIO_LOG_HTTP');

  /// True when the app was built without being told where the server is.
  ///
  /// Surfaced on the sync-health screen rather than thrown: a build misconfigured
  /// this way still runs against the local cache, and telling the owner why the
  /// network is silent beats a crash on launch.
  static bool get isUsingFallbackApi => apiBaseUrl == 'http://127.0.0.1:8765';
}
