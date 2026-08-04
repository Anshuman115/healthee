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

String _$todayRepositoryHash() => r'da0fb7f39639a4a2aa7d9cea3774336603004615';

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
