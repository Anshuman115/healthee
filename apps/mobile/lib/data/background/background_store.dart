import 'package:drift/drift.dart';
import 'package:healthee/data/background/background_preferences.dart';
import 'package:healthee/data/store/local_store.dart';

class BackgroundStore {
  const BackgroundStore(this.store);
  final LocalStore store;
  Future<String?> read(String key) async => (await (store.select(
    store.syncMeta,
  )..where((row) => row.name.equals(key))).getSingleOrNull())?.value;
  Future<void> write(String key, String value) => store
      .into(store.syncMeta)
      .insertOnConflictUpdate(
        SyncMetaCompanion(name: Value(key), value: Value(value)),
      );
  Future<BackgroundPreferences> preferences() async =>
      BackgroundPreferences.decode(await read('background_preferences'));
  Future<void> save(BackgroundPreferences value) =>
      write('background_preferences', value.encode());
  Future<void> report(String result) => write(
    'background_last_run',
    '${DateTime.now().toIso8601String()}\n$result',
  );
}
