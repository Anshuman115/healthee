/// Every provider failure reaches the log, without anyone remembering to log it.
///
/// Standards §1: "Every failure is (a) logged with context through the one
/// logging path, and (b) either handled meaningfully or propagated."
///
/// The obvious way to satisfy (a) is a `try`/`catch` in each repository that logs
/// and rethrows. That has two problems. It is a MUST that depends on someone
/// remembering — the weakest kind, as the server's own standards note says about
/// the coach pipeline. And to catch a parse failure at all it must catch a
/// `TypeError`, which `avoid_catching_errors` rightly bans: a cast blowing up is a
/// bug, and code that catches bugs starts hiding them.
///
/// A [ProviderObserver] closes both. Riverpod already routes every asynchronous
/// failure through `providerDidFail`, so the coverage is total by construction —
/// a repository added next month is logged without its author doing anything —
/// and the error is *observed* rather than caught, so it still propagates to the
/// UI as an `AsyncError` for [AsyncView] to render with a retry.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/logging.dart';

/// Logs every provider failure through [AppLog].
final class ProviderLogger extends ProviderObserver {
  /// Builds the observer. Attach it to the root `ProviderScope`.
  const ProviderLogger();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLog.failure(
      'provider',
      '${context.provider.name ?? context.provider.runtimeType} failed',
      error,
      stackTrace,
    );
  }
}
