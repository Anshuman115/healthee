// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [SleepRepository].

@ProviderFor(sleepRepository)
final sleepRepositoryProvider = SleepRepositoryProvider._();

/// The app's [SleepRepository].

final class SleepRepositoryProvider
    extends
        $FunctionalProvider<SleepRepository, SleepRepository, SleepRepository>
    with $Provider<SleepRepository> {
  /// The app's [SleepRepository].
  SleepRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepRepositoryHash();

  @$internal
  @override
  $ProviderElement<SleepRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SleepRepository create(Ref ref) {
    return sleepRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SleepRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SleepRepository>(value),
    );
  }
}

String _$sleepRepositoryHash() => r'3f09250e79cffc342291e46e881b8e350a218b4e';

/// The nights and naps. Watch this from the Sleep screen.

@ProviderFor(sleepPage)
final sleepPageProvider = SleepPageProvider._();

/// The nights and naps. Watch this from the Sleep screen.

final class SleepPageProvider
    extends
        $FunctionalProvider<
          AsyncValue<SleepPage>,
          SleepPage,
          FutureOr<SleepPage>
        >
    with $FutureModifier<SleepPage>, $FutureProvider<SleepPage> {
  /// The nights and naps. Watch this from the Sleep screen.
  SleepPageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepPageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepPageHash();

  @$internal
  @override
  $FutureProviderElement<SleepPage> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<SleepPage> create(Ref ref) {
    return sleepPage(ref);
  }
}

String _$sleepPageHash() => r'c0434f5a85c9f0ae997c119a94c1881713df162d';

/// Bedtime/wake regularity, the odd nights, and tonight's lever.

@ProviderFor(sleepConsistency)
final sleepConsistencyProvider = SleepConsistencyProvider._();

/// Bedtime/wake regularity, the odd nights, and tonight's lever.

final class SleepConsistencyProvider
    extends
        $FunctionalProvider<
          AsyncValue<SleepConsistency>,
          SleepConsistency,
          FutureOr<SleepConsistency>
        >
    with $FutureModifier<SleepConsistency>, $FutureProvider<SleepConsistency> {
  /// Bedtime/wake regularity, the odd nights, and tonight's lever.
  SleepConsistencyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepConsistencyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepConsistencyHash();

  @$internal
  @override
  $FutureProviderElement<SleepConsistency> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SleepConsistency> create(Ref ref) {
    return sleepConsistency(ref);
  }
}

String _$sleepConsistencyHash() => r'2d3d6874c237e8872db430cfa5369e052ad6f256';

/// The grounded AI analysis of recent sleep.

@ProviderFor(sleepInsight)
final sleepInsightProvider = SleepInsightProvider._();

/// The grounded AI analysis of recent sleep.

final class SleepInsightProvider
    extends
        $FunctionalProvider<
          AsyncValue<SleepInsight>,
          SleepInsight,
          FutureOr<SleepInsight>
        >
    with $FutureModifier<SleepInsight>, $FutureProvider<SleepInsight> {
  /// The grounded AI analysis of recent sleep.
  SleepInsightProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepInsightProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepInsightHash();

  @$internal
  @override
  $FutureProviderElement<SleepInsight> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SleepInsight> create(Ref ref) {
    return sleepInsight(ref);
  }
}

String _$sleepInsightHash() => r'bdbe1d4573d421c295b31dbd23d2b9090e30c0c5';
