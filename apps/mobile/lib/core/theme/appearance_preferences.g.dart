// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appearance_preferences.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appearancePreferences)
final appearancePreferencesProvider = AppearancePreferencesProvider._();

final class AppearancePreferencesProvider
    extends
        $FunctionalProvider<
          AppearancePreferences,
          AppearancePreferences,
          AppearancePreferences
        >
    with $Provider<AppearancePreferences> {
  AppearancePreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appearancePreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appearancePreferencesHash();

  @$internal
  @override
  $ProviderElement<AppearancePreferences> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppearancePreferences create(Ref ref) {
    return appearancePreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppearancePreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppearancePreferences>(value),
    );
  }
}

String _$appearancePreferencesHash() =>
    r'37176a1d00a7884f341e2d9d25cb5a4549d75e00';

@ProviderFor(AppearanceError)
final appearanceErrorProvider = AppearanceErrorProvider._();

final class AppearanceErrorProvider
    extends $NotifierProvider<AppearanceError, String?> {
  AppearanceErrorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appearanceErrorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appearanceErrorHash();

  @$internal
  @override
  AppearanceError create() => AppearanceError();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$appearanceErrorHash() => r'23ca87196495982b24898a4fdbef39175498c108';

abstract class _$AppearanceError extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
