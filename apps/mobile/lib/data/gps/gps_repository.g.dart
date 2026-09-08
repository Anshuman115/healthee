// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gps_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(gpsRepository)
final gpsRepositoryProvider = GpsRepositoryProvider._();

final class GpsRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<GpsRepository>,
          GpsRepository,
          FutureOr<GpsRepository>
        >
    with $FutureModifier<GpsRepository>, $FutureProvider<GpsRepository> {
  GpsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gpsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gpsRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<GpsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GpsRepository> create(Ref ref) {
    return gpsRepository(ref);
  }
}

String _$gpsRepositoryHash() => r'67500167c9edbf493bdd31a40b594c81e0305e56';
