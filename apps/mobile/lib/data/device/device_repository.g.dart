// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Everything the strap measured on the day the app is showing.
///
/// Invalidated by `SyncController` after every sync attempt, so a pull that
/// stored anything is on screen without the owner pulling to refresh.

@ProviderFor(deviceDay)
final deviceDayProvider = DeviceDayProvider._();

/// Everything the strap measured on the day the app is showing.
///
/// Invalidated by `SyncController` after every sync attempt, so a pull that
/// stored anything is on screen without the owner pulling to refresh.

final class DeviceDayProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeviceDay>,
          DeviceDay,
          FutureOr<DeviceDay>
        >
    with $FutureModifier<DeviceDay>, $FutureProvider<DeviceDay> {
  /// Everything the strap measured on the day the app is showing.
  ///
  /// Invalidated by `SyncController` after every sync attempt, so a pull that
  /// stored anything is on screen without the owner pulling to refresh.
  DeviceDayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceDayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceDayHash();

  @$internal
  @override
  $FutureProviderElement<DeviceDay> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DeviceDay> create(Ref ref) {
    return deviceDay(ref);
  }
}

String _$deviceDayHash() => r'c17de1be8f6d57d60decaaf36b0b883d3c129d07';
