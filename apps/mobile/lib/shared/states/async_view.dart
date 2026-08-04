/// [AsyncView] — the other half of the three-states rule, for Riverpod's `AsyncValue`.
///
/// [ReadingView] covers "what did the server say"; this covers "did we hear back".
/// The two nest, and their layering is the design:
///
/// ```dart
/// AsyncView<TodaySnapshot>(
///   value: ref.watch(todaySnapshotProvider),
///   onRetry: () => ref.invalidate(todaySnapshotProvider),
///   builder: (context, today) => ReadingView<Vo2max>(
///     reading: today.vo2max,
///     label: 'VO₂max',
///     builder: (context, vo2max) => Vo2maxHero(vo2max),
///   ),
/// )
/// ```
///
/// Keeping them separate is deliberate. A timeout and a withhold are opposite
/// messages — one is our fault and worth retrying, the other is the answer — and
/// a single widget rendering both would have to pick one voice for them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Renders an `AsyncValue`, covering loading and error so a screen cannot skip them.
class AsyncView<T> extends StatelessWidget {
  /// Renders [value]; [builder] draws the data once it arrives.
  const AsyncView({
    required this.value,
    required this.onRetry,
    required this.builder,
    this.loadingLabel,
    this.errorMessage,
    super.key,
  });

  /// The async state being rendered.
  final AsyncValue<T> value;

  /// Re-runs the request. Required — an error the owner cannot retry is a dead end.
  final VoidCallback onRetry;

  /// Draws the loaded data.
  final Widget Function(BuildContext context, T data) builder;

  /// What is loading, e.g. "Loading today".
  final String? loadingLabel;

  /// Overrides the failure sentence. The default names no exception class: a
  /// stack trace is for the log, not for somebody looking at their sleep.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      data: (data) => builder(context, data),
      loading: () => LoadingState(label: loadingLabel),
      error: (error, stackTrace) => ErrorState(
        message: errorMessage ?? "Couldn't reach the server",
        detail: 'Your data is safe. This is a connection problem, not a gap in it.',
        onRetry: onRetry,
      ),
    );
  }
}
