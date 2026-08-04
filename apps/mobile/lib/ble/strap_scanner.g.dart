// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'strap_scanner.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's scanner. Overridden in tests.

@ProviderFor(strapScanner)
final strapScannerProvider = StrapScannerProvider._();

/// The app's scanner. Overridden in tests.

final class StrapScannerProvider
    extends $FunctionalProvider<StrapScanner, StrapScanner, StrapScanner>
    with $Provider<StrapScanner> {
  /// The app's scanner. Overridden in tests.
  StrapScannerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'strapScannerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$strapScannerHash();

  @$internal
  @override
  $ProviderElement<StrapScanner> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StrapScanner create(Ref ref) {
    return strapScanner(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StrapScanner value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StrapScanner>(value),
    );
  }
}

String _$strapScannerHash() => r'a0d41306e52f5af6c48386b22803a731a2535bea';
