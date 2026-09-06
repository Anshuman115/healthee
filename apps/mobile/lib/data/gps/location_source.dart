import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:healthee/data/gps/gps_fix.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_source.g.dart';

/// Injectable GPS hardware boundary. Permission is requested only on Start.
class LocationSource {
  Future<void> authorize() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const FormatException(
        'Turn on location services to record a route.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const FormatException(
        'Location permission is required. Enable it in phone settings.',
      );
    }
  }

  Stream<GpsFix> fixes() =>
      Geolocator.getPositionStream(locationSettings: _settings()).map(
        (p) => GpsFix(
          at: p.timestamp.toUtc(),
          latitude: p.latitude,
          longitude: p.longitude,
          accuracyM: p.accuracy,
          altitudeM: p.altitudeAccuracy > 0 ? p.altitude : null,
        ),
      );

  LocationSettings _settings() =>
      defaultTargetPlatform == TargetPlatform.android
      ? AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 3),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Recording outdoor workout',
            notificationText: 'Healthee is recording your route.',
            enableWakeLock: true,
          ),
        )
      : AppleSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        );
}

@Riverpod(keepAlive: true)
LocationSource locationSource(Ref ref) => LocationSource();
