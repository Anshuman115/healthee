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

import 'package:meta/meta.dart';

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
  /// A test's window onto everything this logger emits. **Null in production.**
  ///
  /// `dart:developer`'s `log` writes to the platform log and returns nothing
  /// catchable, so from inside `flutter test` there is no way to see what the app
  /// logged — which makes "no secret ever reaches the log" an unfalsifiable claim,
  /// and this codebase does not ship those. With this seam it is a test:
  /// `test/pairing/pairing_secrecy_test.dart` runs the whole pairing flow with
  /// sentinel passwords, tokens and auth keys, and fails if any of them appears
  /// in a captured line.
  ///
  /// It is a hook, not a second logging path — every line still goes to
  /// [_emit] and out through `developer.log` exactly as before. Nothing in `lib/`
  /// assigns it, and `logging_test.dart` asserts it starts null.
  @visibleForTesting
  static void Function(String line)? sink;

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
    // Everything `developer.log` was just given, flattened — including the error
    // object, because an exception's `toString` is a place secrets leak and the
    // secrecy test has to be able to see it.
    sink?.call('healthee.$source ${level.name} $message ${error ?? ''}');
  }
}
