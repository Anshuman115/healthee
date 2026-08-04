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

String _$todayRepositoryHash() => r'9eacfb28076dd14be98978a2f3c518e8ca4163e1';

/// Today's snapshot. Watch this from the Today screen.

@ProviderFor(todaySnapshot)
final todaySnapshotProvider = TodaySnapshotProvider._();

/// Today's snapshot. Watch this from the Today screen.

final class TodaySnapshotProvider
    extends
        $FunctionalProvider<
          AsyncValue<TodaySnapshot>,
          TodaySnapshot,
          FutureOr<TodaySnapshot>
        >
    with $FutureModifier<TodaySnapshot>, $FutureProvider<TodaySnapshot> {
  /// Today's snapshot. Watch this from the Today screen.
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
  $FutureProviderElement<TodaySnapshot> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TodaySnapshot> create(Ref ref) {
    return todaySnapshot(ref);
  }
}

String _$todaySnapshotHash() => r'aedd60c6791785f6370be6e736f692e48b1b057e';
