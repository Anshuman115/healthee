// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [CoachClient].

@ProviderFor(coachClient)
final coachClientProvider = CoachClientProvider._();

/// The app's [CoachClient].

final class CoachClientProvider
    extends $FunctionalProvider<CoachClient, CoachClient, CoachClient>
    with $Provider<CoachClient> {
  /// The app's [CoachClient].
  CoachClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachClientHash();

  @$internal
  @override
  $ProviderElement<CoachClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CoachClient create(Ref ref) {
    return coachClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachClient>(value),
    );
  }
}

String _$coachClientHash() => r'739f637fbd55f645289521840c841e37b3ffdbac';

/// What the owner is entitled to, re-read on demand.
///
/// Not `keepAlive`: the whole point of the endpoint being uncached server-side is
/// that a balance is only true at the moment it was read, and a provider that held
/// one across the life of the app would put a stale meter in front of a spend.

@ProviderFor(coachEntitlement)
final coachEntitlementProvider = CoachEntitlementProvider._();

/// What the owner is entitled to, re-read on demand.
///
/// Not `keepAlive`: the whole point of the endpoint being uncached server-side is
/// that a balance is only true at the moment it was read, and a provider that held
/// one across the life of the app would put a stale meter in front of a spend.

final class CoachEntitlementProvider
    extends
        $FunctionalProvider<
          AsyncValue<Entitlement>,
          Entitlement,
          FutureOr<Entitlement>
        >
    with $FutureModifier<Entitlement>, $FutureProvider<Entitlement> {
  /// What the owner is entitled to, re-read on demand.
  ///
  /// Not `keepAlive`: the whole point of the endpoint being uncached server-side is
  /// that a balance is only true at the moment it was read, and a provider that held
  /// one across the life of the app would put a stale meter in front of a spend.
  CoachEntitlementProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachEntitlementProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachEntitlementHash();

  @$internal
  @override
  $FutureProviderElement<Entitlement> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Entitlement> create(Ref ref) {
    return coachEntitlement(ref);
  }
}

String _$coachEntitlementHash() => r'863a69a26cae77d955bd2f1e6988f1d8e5cc9293';
