// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [TodayRepository].

@ProviderFor(todayRepository)
final todayRepositoryProvider = TodayRepositoryProvider._();

/// The app's [TodayRepository].

final class TodayRepositoryProvider
    extends
        $FunctionalProvider<TodayRepository, TodayRepository, TodayRepository>
    with $Provider<TodayRepository> {
  /// The app's [TodayRepository].
  TodayRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayRepositoryHash();

  @$internal
  @override
  $ProviderElement<TodayRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TodayRepository create(Ref ref) {
    return todayRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TodayRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TodayRepository>(value),
    );
  }
}

String _$todayRepositoryHash() => r'9b715fc2421c68f4b3cae20c77255b1491fcc32a';

/// Today's snapshot, with its provenance. Watch this from the Today screen.
///
/// [ProviderLogger] logs every provider failure through the one logging path, so
/// there is deliberately no `try`/`catch` here: catching would only let us
/// re-throw after a log entry that already happens.

@ProviderFor(todaySnapshot)
final todaySnapshotProvider = TodaySnapshotProvider._();

/// Today's snapshot, with its provenance. Watch this from the Today screen.
///
/// [ProviderLogger] logs every provider failure through the one logging path, so
/// there is deliberately no `try`/`catch` here: catching would only let us
/// re-throw after a log entry that already happens.

final class TodaySnapshotProvider
    extends
        $FunctionalProvider<
          AsyncValue<TodayView>,
          TodayView,
          FutureOr<TodayView>
        >
    with $FutureModifier<TodayView>, $FutureProvider<TodayView> {
  /// Today's snapshot, with its provenance. Watch this from the Today screen.
  ///
  /// [ProviderLogger] logs every provider failure through the one logging path, so
  /// there is deliberately no `try`/`catch` here: catching would only let us
  /// re-throw after a log entry that already happens.
  TodaySnapshotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todaySnapshotProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todaySnapshotHash();

  @$internal
  @override
  $FutureProviderElement<TodayView> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TodayView> create(Ref ref) {
    return todaySnapshot(ref);
  }
}

String _$todaySnapshotHash() => r'b6d1708dcd7748d1ae9b0f832a227adcf390826d';

/// The last biological age this phone holds, and the day it belonged to.
///
/// Deliberately **lazy**: only the withheld hero watches it, so a payload that
/// carried a number never touches the local tier at all. A field on [TodayView]
/// would scan the cache on every load to answer a question almost every load
/// does not ask.

@ProviderFor(lastKnownBiologicalAge)
final lastKnownBiologicalAgeProvider = LastKnownBiologicalAgeProvider._();

/// The last biological age this phone holds, and the day it belonged to.
///
/// Deliberately **lazy**: only the withheld hero watches it, so a payload that
/// carried a number never touches the local tier at all. A field on [TodayView]
/// would scan the cache on every load to answer a question almost every load
/// does not ask.

final class LastKnownBiologicalAgeProvider
    extends
        $FunctionalProvider<
          AsyncValue<LastKnown<double>?>,
          LastKnown<double>?,
          FutureOr<LastKnown<double>?>
        >
    with
        $FutureModifier<LastKnown<double>?>,
        $FutureProvider<LastKnown<double>?> {
  /// The last biological age this phone holds, and the day it belonged to.
  ///
  /// Deliberately **lazy**: only the withheld hero watches it, so a payload that
  /// carried a number never touches the local tier at all. A field on [TodayView]
  /// would scan the cache on every load to answer a question almost every load
  /// does not ask.
  LastKnownBiologicalAgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastKnownBiologicalAgeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastKnownBiologicalAgeHash();

  @$internal
  @override
  $FutureProviderElement<LastKnown<double>?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LastKnown<double>?> create(Ref ref) {
    return lastKnownBiologicalAge(ref);
  }
}

String _$lastKnownBiologicalAgeHash() =>
    r'1363b5c2f872c50af294e0a2701d221466cebd12';
