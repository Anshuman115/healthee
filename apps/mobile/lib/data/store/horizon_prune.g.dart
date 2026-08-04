// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'horizon_prune.dart';

// ignore_for_file: type=lint
mixin _$HorizonPruneMixin on DatabaseAccessor<LocalStore> {
  $CachedPayloadsTable get cachedPayloads => attachedDatabase.cachedPayloads;
  $StrapSamplesTable get strapSamples => attachedDatabase.strapSamples;
  $SleepSessionsTable get sleepSessions => attachedDatabase.sleepSessions;
  $StoredWorkoutsTable get storedWorkouts => attachedDatabase.storedWorkouts;
  $DeviceTotalsTable get deviceTotals => attachedDatabase.deviceTotals;
  $SyncMetaTable get syncMeta => attachedDatabase.syncMeta;
  HorizonPruneManager get managers => HorizonPruneManager(this);
}

class HorizonPruneManager {
  final _$HorizonPruneMixin _db;
  HorizonPruneManager(this._db);
  $$CachedPayloadsTableTableManager get cachedPayloads =>
      $$CachedPayloadsTableTableManager(
        _db.attachedDatabase,
        _db.cachedPayloads,
      );
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
