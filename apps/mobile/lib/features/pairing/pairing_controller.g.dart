// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pairing_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the pairing screen.

@ProviderFor(PairingController)
final pairingControllerProvider = PairingControllerProvider._();

/// Drives the pairing screen.
final class PairingControllerProvider
    extends $NotifierProvider<PairingController, PairingState> {
  /// Drives the pairing screen.
  PairingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pairingControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pairingControllerHash();

  @$internal
  @override
  PairingController create() => PairingController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PairingState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PairingState>(value),
    );
  }
}

String _$pairingControllerHash() => r'5a89afd4c34e1fd3792b0194bb01271cd046a29d';

/// Drives the pairing screen.

abstract class _$PairingController extends $Notifier<PairingState> {
  PairingState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PairingState, PairingState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PairingState, PairingState>,
              PairingState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
