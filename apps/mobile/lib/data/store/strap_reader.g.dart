// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'strap_reader.dart';

// ignore_for_file: type=lint
mixin _$StrapReaderMixin on DatabaseAccessor<LocalStore> {
  $StrapSamplesTable get strapSamples => attachedDatabase.strapSamples;
  $SleepSessionsTable get sleepSessions => attachedDatabase.sleepSessions;
  $StoredWorkoutsTable get storedWorkouts => attachedDatabase.storedWorkouts;
  $DeviceTotalsTable get deviceTotals => attachedDatabase.deviceTotals;
  $SyncMetaTable get syncMeta => attachedDatabase.syncMeta;
  StrapReaderManager get managers => StrapReaderManager(this);
}

class StrapReaderManager {
  final _$StrapReaderMixin _db;
  StrapReaderManager(this._db);
  $$StrapSamplesTableTableManager get strapSamples =>
      $$StrapSamplesTableTableManager(_db.attachedDatabase, _db.strapSamples);
  $$SleepSessionsTableTableManager get sleepSessions =>
      $$SleepSessionsTableTableManager(_db.attachedDatabase, _db.sleepSessions);
  $$StoredWorkoutsTableTableManager get storedWorkouts =>
      $$StoredWorkoutsTableTableManager(
        _db.attachedDatabase,
        _db.storedWorkouts,
      );
  $$DeviceTotalsTableTableManager get deviceTotals =>
      $$DeviceTotalsTableTableManager(_db.attachedDatabase, _db.deviceTotals);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db.attachedDatabase, _db.syncMeta);
}
