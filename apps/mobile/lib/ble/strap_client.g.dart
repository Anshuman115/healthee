// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'strap_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's strap client.

@ProviderFor(strapClient)
final strapClientProvider = StrapClientProvider._();

/// The app's strap client.

final class StrapClientProvider
    extends $FunctionalProvider<StrapClient, StrapClient, StrapClient>
    with $Provider<StrapClient> {
  /// The app's strap client.
  StrapClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'strapClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$strapClientHash();

  @$internal
  @override
  $ProviderElement<StrapClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StrapClient create(Ref ref) {
    return strapClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StrapClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StrapClient>(value),
    );
  }
}

String _$strapClientHash() => r'ae5c85fd64918646b8a13c2885e63094e1e013e5';
