import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/gps/gps_fix.dart';
import 'package:healthee/data/gps/gps_local_store.dart';
import 'package:healthee/data/gps/gps_recording_state.dart';
import 'package:healthee/data/gps/location_source.dart';
import 'package:healthee/data/gps/route_point.dart';

/// A run captures its store and identity; an account switch cannot retarget it.
class GpsRun {
  GpsRun({
    required this.local,
    required this.source,
    required this.onChanged,
    required String id,
    required DateTime start,
  }) : value = GpsRecordingState(id: id, start: start, recording: true);
  final GpsLocalStore local;
  final LocationSource source;
  final void Function(GpsRecordingState) onChanged;
  GpsRecordingState value;
  StreamSubscription<GpsFix>? _subscription;
  Future<void> _pending = Future<void>.value();
  Future<void>? _stopping;
  GpsFix? _previous;
  bool _accepting = true;
  static const maxAccuracyM = 50.0;
  static const maxPoints = 28800;

  void listen() {
    _subscription = source.fixes().listen(
      _enqueue,
      onError: (Object error, StackTrace stack) =>
          unawaited(_fail(error, stack)),
      onDone: () {
        if (_accepting) unawaited(stop(interrupted: true));
      },
    );
  }

  void _enqueue(GpsFix fix) {
    if (!_accepting) return;
    _pending = _pending.then((_) => _persist(fix)).onError<Exception>((
      error,
      stack,
    ) {
      // Do not await stop here: it drains this very queue.
      unawaited(_fail(error, stack));
    });
  }

  Future<void> _persist(GpsFix fix) async {
    if (!validFix(fix, value.start!, _previous?.at)) return;
    if (value.points >= maxPoints) {
      throw const FormatException(
        'Recording limit reached. Your route is saved on this phone.',
      );
    }
    final distance =
        value.distanceM +
        (_previous == null
            ? 0
            : Geolocator.distanceBetween(
                _previous!.latitude,
                _previous!.longitude,
                fix.latitude,
                fix.longitude,
              ));
    await local.append(value.id!, fix, distance);
    _previous = fix;
    value = GpsRecordingState(
      id: value.id,
      start: value.start,
      recording: true,
      // The coordinates are RETAINED, not just counted. The recorder screen
      // draws this list; before it existed the screen had a fix count and
      // nothing to plot, which is the whole reason it had no map.
      track: <RoutePoint>[...value.track, _asRoutePoint(fix)],
      distanceM: distance,
    );
    onChanged(value);
  }

  Future<void> stop({bool interrupted = false, String? error}) =>
      _stopping ??= _finish(interrupted, error);

  Future<void> _finish(bool interrupted, String? error) async {
    _accepting = false;
    await _subscription?.cancel();
    await _pending;
    final end = interrupted
        ? (_previous?.at ?? value.start!)
        : DateTime.now().toUtc();
    await local.finish(
      value.id!,
      end,
      status: interrupted ? 'interrupted' : 'ready',
    );
    value = GpsRecordingState(
      id: value.id,
      start: value.start,
      track: value.track,
      distanceM: value.distanceM,
      end: end,
      error: error,
    );
    onChanged(value);
  }

  Future<void> _fail(Object error, StackTrace stack) async {
    AppLog.failure('gps', 'recording route', error, stack);
    try {
      await stop(
        interrupted: true,
        error: error is FormatException
            ? error.message
            : 'GPS stopped. Your saved points remain on this phone.',
      );
    } on Exception catch (failure, trace) {
      AppLog.failure('gps', 'saving interrupted route', failure, trace);
      value = GpsRecordingState(
        id: value.id,
        start: value.start,
        track: value.track,
        distanceM: value.distanceM,
        error:
            'GPS stopped. Could not finalize the route; reopen recordings to recover saved points.',
      );
      onChanged(value);
    }
  }

  /// One accepted fix as the point type every route drawing in this app takes.
  ///
  /// A live fix has no elevation the app trusts (the phone's altitude is the
  /// noisy one `derive/dem.py` exists to replace) and no heart rate yet — the
  /// strap's arrives at upload. Both stay null rather than being filled with the
  /// phone's guess: the map wants the position, and a null is the honest value
  /// for a measurement nothing has taken.
  static RoutePoint _asRoutePoint(GpsFix fix) => RoutePoint(
    at: fix.at,
    latitude: fix.latitude,
    longitude: fix.longitude,
  );

  static bool validFix(GpsFix fix, DateTime start, DateTime? previous) =>
      fix.latitude.isFinite &&
      fix.longitude.isFinite &&
      fix.accuracyM.isFinite &&
      (fix.altitudeM == null || fix.altitudeM!.isFinite) &&
      fix.latitude.abs() <= 90 &&
      fix.longitude.abs() <= 180 &&
      fix.accuracyM >= 0 &&
      fix.accuracyM <= maxAccuracyM &&
      !fix.at.isBefore(start) &&
      !fix.at.isAfter(DateTime.now().toUtc()) &&
      (previous == null || fix.at.isAfter(previous));
}
