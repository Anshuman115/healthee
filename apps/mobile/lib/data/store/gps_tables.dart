import 'package:drift/drift.dart';

/// Durable phone sessions. Status: recording, interrupted, ready, uploaded.
@DataClassName('GpsRecordingRow')
class GpsRecordings extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer().nullable()();
  TextColumn get status => text()();
  RealColumn get distanceM => real().withDefault(const Constant(0))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Each accepted fix is committed independently; a crash cannot lose the route.
@DataClassName('GpsFixRow')
class GpsFixes extends Table {
  TextColumn get recordingId => text()();
  IntColumn get atMs => integer()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get altitudeM => real().nullable()();
  RealColumn get accuracyM => real()();
  @override
  Set<Column<Object>> get primaryKey => {recordingId, atMs};
}
