import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/background/background_preferences.dart';
import 'package:healthee/data/background/background_scheduler.dart';
import 'package:healthee/data/background/background_store.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  late LocalStore store;
  late RecordingWorkmanager platform;
  late BackgroundScheduler scheduler;
  setUp(() {
    store = LocalStore.memory();
    platform = RecordingWorkmanager();
    scheduler = BackgroundScheduler(platform, BackgroundStore(store));
  });
  tearDown(() => store.close());

  test('separate collection/upload schedules honor constraints; disable cancels both', () async {
    await scheduler.save(const BackgroundPreferences(enabled: true,
      pullMinutes: 15, pushMinutes: 360, wifiOnly: true, chargingOnly: true));
    final jobs = platform.calls.where((i) => i.memberName == #registerPeriodicTask).toList();
    expect(jobs, hasLength(2));
    expect(jobs[0].namedArguments[#frequency], const Duration(minutes: 15));
    expect(jobs[1].namedArguments[#frequency], const Duration(minutes: 360));
    final pull = jobs[0].namedArguments[#constraints]! as Constraints;
    final push = jobs[1].namedArguments[#constraints]! as Constraints;
    expect(pull.networkType, NetworkType.notRequired);
    expect(push.networkType, NetworkType.unmetered);
    expect(push.requiresCharging, isTrue);
    expect((await scheduler.store.preferences()).enabled, isTrue);
    platform.calls.clear();
    await scheduler.save(const BackgroundPreferences());
    expect(platform.calls.where((i) => i.memberName == #cancelByUniqueName), hasLength(2));
    expect(platform.calls.where((i) => i.memberName == #registerPeriodicTask), isEmpty);
    expect((await scheduler.store.preferences()).enabled, isFalse);
  });
  test('partial platform scheduling leaves callbacks disabled and propagates failure', () async {
    platform.failRegistration = true;
    await expectLater(scheduler.save(const BackgroundPreferences(enabled: true)), throwsFormatException);
    expect((await scheduler.store.preferences()).enabled, isFalse);
  });
}

class RecordingWorkmanager implements Workmanager {
  final calls = <Invocation>[];
  bool failRegistration = false;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (failRegistration && invocation.memberName == #registerPeriodicTask) {
      return Future<void>.error(const FormatException('Scheduling unavailable'));
    }
    return Future<void>.value();
  }
}
