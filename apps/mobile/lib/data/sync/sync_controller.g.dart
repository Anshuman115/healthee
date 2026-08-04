// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's sync engine, wired to the one client, store and scanner.

@ProviderFor(syncEngine)
final syncEngineProvider = SyncEngineProvider._();

/// The app's sync engine, wired to the one client, store and scanner.

final class SyncEngineProvider
    extends $FunctionalProvider<SyncEngine, SyncEngine, SyncEngine>
    with $Provider<SyncEngine> {
  /// The app's sync engine, wired to the one client, store and scanner.
  SyncEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncEngineHash();

  @$internal
  @override
  $ProviderElement<SyncEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncEngine create(Ref ref) {
    return syncEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncEngine>(value),
    );
  }
}

String _$syncEngineHash() => r'8a25407e5aa5e872e39c97dc606b240219a6ddd8';

/// Holds what the link to the strap is doing, and drives it.

@ProviderFor(SyncController)
final syncControllerProvider = SyncControllerProvider._();

/// Holds what the link to the strap is doing, and drives it.
final class SyncControllerProvider
    extends $NotifierProvider<SyncController, StrapConnection> {
  /// Holds what the link to the strap is doing, and drives it.
  SyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncControllerHash();

  @$internal
  @override
  SyncController create() => SyncController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StrapConnection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StrapConnection>(value),
    );
  }
}

String _$syncControllerHash() => r'e39251cea8ed836f9896a6a7f90a67a8a8813cfe';

/// Holds what the link to the strap is doing, and drives it.

abstract class _$SyncController extends $Notifier<StrapConnection> {
  StrapConnection build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<StrapConnection, StrapConnection>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StrapConnection, StrapConnection>,
              StrapConnection,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
