// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every conversation this sign-in has had on this device, most recent first.
///
/// Scoped through `CacheSession` like every other local read: a provider that
/// forgot to would hand a second owner on one handset the first owner's threads.

@ProviderFor(coachThreads)
final coachThreadsProvider = CoachThreadsProvider._();

/// Every conversation this sign-in has had on this device, most recent first.
///
/// Scoped through `CacheSession` like every other local read: a provider that
/// forgot to would hand a second owner on one handset the first owner's threads.

final class CoachThreadsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CoachThreadSummary>>,
          List<CoachThreadSummary>,
          FutureOr<List<CoachThreadSummary>>
        >
    with
        $FutureModifier<List<CoachThreadSummary>>,
        $FutureProvider<List<CoachThreadSummary>> {
  /// Every conversation this sign-in has had on this device, most recent first.
  ///
  /// Scoped through `CacheSession` like every other local read: a provider that
  /// forgot to would hand a second owner on one handset the first owner's threads.
  CoachThreadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachThreadsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachThreadsHash();

  @$internal
  @override
  $FutureProviderElement<List<CoachThreadSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CoachThreadSummary>> create(Ref ref) {
    return coachThreads(ref);
  }
}

String _$coachThreadsHash() => r'25b6d00e9798af535bd5c020ee1bf81475cee164';
