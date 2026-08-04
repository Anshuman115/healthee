// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pairing_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's pairing repository.

@ProviderFor(pairingRepository)
final pairingRepositoryProvider = PairingRepositoryProvider._();

/// The app's pairing repository.

final class PairingRepositoryProvider
    extends
        $FunctionalProvider<
          PairingRepository,
          PairingRepository,
          PairingRepository
        >
    with $Provider<PairingRepository> {
  /// The app's pairing repository.
  PairingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pairingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pairingRepositoryHash();

  @$internal
  @override
  $ProviderElement<PairingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PairingRepository create(Ref ref) {
    return pairingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PairingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PairingRepository>(value),
    );
  }
}

String _$pairingRepositoryHash() => r'82da2b9ce5815f3d3419063d8af26a9dc748ba96';

/// Everything the app needs to know about the current pairing, in one read.
///
/// One provider rather than two because both halves come from the same keystore
/// and are always wanted together — the screen has to say what is stored, and
/// "the strap" is only half of that answer. Two providers would also mean two
/// async consumers on one card, each with its own loading state, flickering
/// independently.
///
/// A null `strap` means nothing is paired, which is what the router keys on.

@ProviderFor(pairingSummary)
final pairingSummaryProvider = PairingSummaryProvider._();

/// Everything the app needs to know about the current pairing, in one read.
///
/// One provider rather than two because both halves come from the same keystore
/// and are always wanted together — the screen has to say what is stored, and
/// "the strap" is only half of that answer. Two providers would also mean two
/// async consumers on one card, each with its own loading state, flickering
/// independently.
///
/// A null `strap` means nothing is paired, which is what the router keys on.

final class PairingSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<({PairedStrap? strap, bool zeppRemembered})>,
          ({PairedStrap? strap, bool zeppRemembered}),
          FutureOr<({PairedStrap? strap, bool zeppRemembered})>
        >
    with
        $FutureModifier<({PairedStrap? strap, bool zeppRemembered})>,
        $FutureProvider<({PairedStrap? strap, bool zeppRemembered})> {
  /// Everything the app needs to know about the current pairing, in one read.
  ///
  /// One provider rather than two because both halves come from the same keystore
  /// and are always wanted together — the screen has to say what is stored, and
  /// "the strap" is only half of that answer. Two providers would also mean two
  /// async consumers on one card, each with its own loading state, flickering
  /// independently.
  ///
  /// A null `strap` means nothing is paired, which is what the router keys on.
  PairingSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pairingSummaryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pairingSummaryHash();

  @$internal
  @override
  $FutureProviderElement<({PairedStrap? strap, bool zeppRemembered})>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({PairedStrap? strap, bool zeppRemembered})> create(Ref ref) {
    return pairingSummary(ref);
  }
}

String _$pairingSummaryHash() => r'5e05d03d2444061bc61787cec1f37f4460266b53';
