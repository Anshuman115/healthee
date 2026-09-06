import 'package:healthee/data/background/background_preferences.dart';
import 'package:healthee/data/background/background_store.dart';
import 'package:healthee/data/background/background_task.dart';
import 'package:healthee/data/background/background_task_names.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workmanager/workmanager.dart';

part 'background_scheduler.g.dart';

class BackgroundScheduler {
  const BackgroundScheduler(this.workmanager, this.store);
  final Workmanager workmanager;
  final BackgroundStore store;
  static const pullTask = BackgroundTaskNames.pull;
  static const pushTask = BackgroundTaskNames.push;

  Future<void> save(BackgroundPreferences value) async {
    await workmanager.initialize(backgroundDispatcher);
    // Disable callbacks before changing registrations, so partial scheduling cannot run an old plan.
    await store.save(const BackgroundPreferences());
    await workmanager.cancelByUniqueName(pullTask);
    await workmanager.cancelByUniqueName(pushTask);
    if (value.enabled) {
      await _register(pullTask, value.pullMinutes, value, network: false);
      await _register(pushTask, value.pushMinutes, value, network: true);
    }
    await store.save(value);
  }

  Future<void> _register(
    String task,
    int minutes,
    BackgroundPreferences value, {
    required bool network,
  }) => workmanager.registerPeriodicTask(
    task,
    task,
    frequency: Duration(minutes: minutes),
    constraints: Constraints(
      networkType: !network
          ? NetworkType.notRequired
          : value.wifiOnly
          ? NetworkType.unmetered
          : NetworkType.connected,
      requiresCharging: value.chargingOnly,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

@Riverpod(keepAlive: true)
BackgroundScheduler backgroundScheduler(Ref ref) => BackgroundScheduler(
  Workmanager(),
  BackgroundStore(ref.watch(localStoreProvider)),
);

@riverpod
Future<BackgroundPreferences> backgroundPreferences(Ref ref) =>
    ref.watch(backgroundSchedulerProvider).store.preferences();
@riverpod
Future<String?> backgroundLastRun(Ref ref) =>
    ref.watch(backgroundSchedulerProvider).store.read('background_last_run');
