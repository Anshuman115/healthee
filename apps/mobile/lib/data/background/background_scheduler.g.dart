// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_scheduler.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(backgroundScheduler)
final backgroundSchedulerProvider = BackgroundSchedulerProvider._();

final class BackgroundSchedulerProvider
    extends
        $FunctionalProvider<
          BackgroundScheduler,
          BackgroundScheduler,
          BackgroundScheduler
        >
    with $Provider<BackgroundScheduler> {
  BackgroundSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundSchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundSchedulerHash();

  @$internal
  @override
  $ProviderElement<BackgroundScheduler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackgroundScheduler create(Ref ref) {
    return backgroundScheduler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundScheduler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackgroundScheduler>(value),
    );
  }
}

String _$backgroundSchedulerHash() =>
    r'8e056aa8a95e603e19f6268e9e956087ab4ee183';

@ProviderFor(backgroundPreferences)
final backgroundPreferencesProvider = BackgroundPreferencesProvider._();

final class BackgroundPreferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<BackgroundPreferences>,
          BackgroundPreferences,
          FutureOr<BackgroundPreferences>
        >
    with
        $FutureModifier<BackgroundPreferences>,
        $FutureProvider<BackgroundPreferences> {
  BackgroundPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundPreferencesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundPreferencesHash();

  @$internal
  @override
  $FutureProviderElement<BackgroundPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BackgroundPreferences> create(Ref ref) {
    return backgroundPreferences(ref);
  }
}

String _$backgroundPreferencesHash() =>
    r'779c69d232d2d93ba803250a23e18838bec59dfd';

@ProviderFor(backgroundLastRun)
final backgroundLastRunProvider = BackgroundLastRunProvider._();

final class BackgroundLastRunProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  BackgroundLastRunProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundLastRunProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundLastRunHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return backgroundLastRun(ref);
  }
}

String _$backgroundLastRunHash() => r'd22a6c18267129ec80bc4247932ca24487e5f1b0';
