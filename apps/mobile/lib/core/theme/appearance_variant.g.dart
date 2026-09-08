// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appearance_variant.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppearanceController)
final appearanceControllerProvider = AppearanceControllerProvider._();

final class AppearanceControllerProvider
    extends $NotifierProvider<AppearanceController, AppearanceVariant> {
  AppearanceControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appearanceControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appearanceControllerHash();

  @$internal
  @override
  AppearanceController create() => AppearanceController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppearanceVariant value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppearanceVariant>(value),
    );
  }
}

String _$appearanceControllerHash() =>
    r'142bcba1b392b3d4a03e22f768acc2025dd6b273';

abstract class _$AppearanceController extends $Notifier<AppearanceVariant> {
  AppearanceVariant build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppearanceVariant, AppearanceVariant>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppearanceVariant, AppearanceVariant>,
              AppearanceVariant,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
