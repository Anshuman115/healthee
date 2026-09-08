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
///
/// **`viewDate`, not `today`.** The measured half is stored per calendar day and
/// can answer for any day inside the retention window with no network at all, so
/// it is the half that genuinely follows the date control. `view_date.dart` has
/// the whole division; the short version is that a sync still writes under the
/// wall clock, and only the reading follows the reader.

@ProviderFor(deviceDay)
final deviceDayProvider = DeviceDayProvider._();

/// Everything the strap measured on the day the app is showing.
///
/// Invalidated by `SyncController` after every sync attempt, so a pull that
/// stored anything is on screen without the owner pulling to refresh.
///
/// **`viewDate`, not `today`.** The measured half is stored per calendar day and
/// can answer for any day inside the retention window with no network at all, so
/// it is the half that genuinely follows the date control. `view_date.dart` has
/// the whole division; the short version is that a sync still writes under the
/// wall clock, and only the reading follows the reader.

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
  ///
  /// **`viewDate`, not `today`.** The measured half is stored per calendar day and
  /// can answer for any day inside the retention window with no network at all, so
  /// it is the half that genuinely follows the date control. `view_date.dart` has
  /// the whole division; the short version is that a sync still writes under the
  /// wall clock, and only the reading follows the reader.
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

String _$deviceDayHash() => r'e750b44159f126247412989e1151fe5ff3464829';
