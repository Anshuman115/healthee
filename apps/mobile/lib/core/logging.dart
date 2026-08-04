/// The one logging path.
///
/// Engineering Standards §1: every failure is "logged with context through the one
/// logging path", and §3 adds that a `catch` "routes through the app logger; sync
/// and push failures surface in sync health, never debugPrint-only".
///
/// `debugPrint` is compiled out of release builds, so anything logged only that way
/// is invisible exactly where it matters. `dart:developer`'s `log` reaches the
/// platform log in every build type and carries a name, an error and a stack —
/// which is the difference between a breadcrumb and something you can act on.
///
/// ## This is not the whole story, deliberately
///
/// Logging a failure is necessary and not sufficient. A background sync that fails
/// silently but neatly is still a feature that stopped working — the legacy repo
/// had five of those. The rule that closes it is that background failures ALSO
/// reach sync health, which lands with the sync engine. [AppLog.failure] takes a
/// `context` argument so those reports have something to quote.
library;

import 'dart:developer' as developer;

/// How loud a message is.
enum LogLevel {
  /// Routine progress — a sync started, a cache hit.
  info(800),

  /// Something is off but the operation continued.
  warning(900),

  /// The operation did not complete.
  error(1000);

  const LogLevel(this.value);

  /// `dart:developer`'s numeric level.
  final int value;
}

/// The app logger. Call it; do not wrap it.
abstract final class AppLog {
  /// Routine progress.
  static void info(String source, String message) =>
      _emit(LogLevel.info, source, message, null, null);

  /// Something recoverable that a reader should know happened.
  static void warning(String source, String message) =>
      _emit(LogLevel.warning, source, message, null, null);

  /// A failure, with the object and stack that produced it.
  ///
  /// [context] says what was being attempted in the caller's own words — "loading
  /// today's snapshot", "writing the 60-day cache". A stack trace tells you where;
  /// only the caller can say what for.
  static void failure(
    String source,
    String context,
    Object error, [
    StackTrace? stackTrace,
  ]) => _emit(LogLevel.error, source, context, error, stackTrace);

  static void _emit(
    LogLevel level,
    String source,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    developer.log(
      message,
      name: 'healthee.$source',
      level: level.value,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
