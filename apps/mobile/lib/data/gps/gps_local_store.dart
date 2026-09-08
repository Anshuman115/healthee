import 'package:drift/drift.dart';
import 'package:healthee/data/gps/gps_fix.dart';
import 'package:healthee/data/store/local_store.dart';

/// Route persistence is separate from acquisition and from the upload lifecycle.
class GpsLocalStore {
  const GpsLocalStore(this.store, this.scope);
  final LocalStore store;
  final String scope;

  Future<void> begin(String id, DateTime start) => store
      .into(store.gpsRecordings)
      .insert(
        GpsRecordingsCompanion.insert(
          id: id,
          scope: scope,
          startMs: start.millisecondsSinceEpoch,
          status: 'recording',
        ),
      );

  Future<GpsRecordingRow> recording(String id) async {
    final row =
        await (store.select(store.gpsRecordings)
              ..where((row) => row.id.equals(id) & row.scope.equals(scope)))
            .getSingleOrNull();
    if (row == null) {
      throw const FormatException('Recording is unavailable for this account.');
    }
    return row;
  }

  Future<void> append(String id, GpsFix fix, double distanceM) =>
      store.transaction(() async {
        await recording(id);
        await store
            .into(store.gpsFixes)
            .insert(
              GpsFixesCompanion.insert(
                recordingId: id,
                atMs: fix.at.millisecondsSinceEpoch,
                latitude: fix.latitude,
                longitude: fix.longitude,
                altitudeM: Value(fix.altitudeM),
                accuracyM: fix.accuracyM,
              ),
            );
        await (store.update(store.gpsRecordings)
              ..where((row) => row.id.equals(id) & row.scope.equals(scope)))
            .write(GpsRecordingsCompanion(distanceM: Value(distanceM)));
      });

  Future<void> finish(
    String id,
    DateTime end, {
    String status = 'ready',
  }) async {
    await (store.update(
      store.gpsRecordings,
    )..where((row) => row.id.equals(id) & row.scope.equals(scope))).write(
      GpsRecordingsCompanion(
        endMs: Value(end.millisecondsSinceEpoch),
        status: Value(status),
      ),
    );
  }

  Future<List<GpsFixRow>> fixes(String id) async {
    await recording(id);
    return (store.select(store.gpsFixes)
          ..where((row) => row.recordingId.equals(id))
          ..orderBy([(row) => OrderingTerm.asc(row.atMs)]))
        .get();
  }

  Stream<List<GpsRecordingRow>> watchRecordings() =>
      (store.select(store.gpsRecordings)
            ..where((row) => row.scope.equals(scope))
            ..orderBy([(row) => OrderingTerm.desc(row.startMs)])
            ..limit(100))
          .watch();

  Future<void> recoverInterrupted() async {
    final rows =
        await (store.select(store.gpsRecordings)..where(
              (row) => row.scope.equals(scope) & row.status.equals('recording'),
            ))
            .get();
    for (final row in rows) {
      final last =
          await (store.select(store.gpsFixes)
                ..where((fix) => fix.recordingId.equals(row.id))
                ..orderBy([(fix) => OrderingTerm.desc(fix.atMs)])
                ..limit(1))
              .getSingleOrNull();
      await finish(
        row.id,
        DateTime.fromMillisecondsSinceEpoch(last?.atMs ?? row.startMs),
        status: 'interrupted',
      );
    }
  }
}
