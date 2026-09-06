// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(locationSource)
final locationSourceProvider = LocationSourceProvider._();

final class LocationSourceProvider
    extends $FunctionalProvider<LocationSource, LocationSource, LocationSource>
    with $Provider<LocationSource> {
  LocationSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationSourceHash();

  @$internal
  @override
  $ProviderElement<LocationSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocationSource create(Ref ref) {
    return locationSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocationSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocationSource>(value),
    );
  }
}

String _$locationSourceHash() => r'76d60dc9d5d0dd6216538eec0d9eeca0755641b3';
