import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/stored_server_session.dart';
import 'package:healthee/data/background/background_store.dart';
import 'package:healthee/data/notifications/notification_service.dart';
import 'package:healthee/data/notifications/reminder_preferences.dart';
import 'package:healthee/data/store/local_store.dart';

import '../pairing/_pairing_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalStore database;
  late BackgroundStore store;
  late RecordingNotifications plugin;
  late NotificationService service;
  late AccountApi api;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_timezone'), (_) async => 'Asia/Kolkata');
    database = LocalStore.memory();
    store = BackgroundStore(database);
    plugin = RecordingNotifications();
    service = NotificationService(plugin, store);
    final credentials = Credentials(FakeSecretStore());
    await credentials.setServerSession(baseUrl: 'https://test.example', token: 'test', kind: StoredCredentialKind.shared);
    api = AccountApi(Dio(), await CacheSession.capture(credentials));
  });
  tearDown(() async { await service.destinations.close(); await database.close(); });

  test('restoring the same account schedules three chosen clocks; sign-out cancels', () async {
    await store.write('reminder_preferences', ReminderPreferences(
      scope: api.sessionScope, daily: true, bedtime: true,
    ).encode());
    await service.restore(api.sessionScope);
    expect(plugin.scheduled, [NotificationService.dailyId,
      NotificationService.windDownId, NotificationService.bedtimeId]);
    plugin.scheduled.clear();
    await service.restore(null);
    expect(plugin.scheduled, isEmpty);
    expect(plugin.cancelled, 2);
  });
  test('permission refusal preserves preferences and queue remains usable for cancellation', () async {
    await expectLater(service.save(ReminderPreferences(scope: api.sessionScope, daily: true), api),
      throwsFormatException);
    expect((await service.preferences()).daily, isFalse);
    await service.restore(null);
    expect(plugin.cancelled, 1);
  });
  test('cold launch forwards only recognized destinations', () async {
    plugin.launch = const NotificationAppLaunchDetails(true,
      notificationResponse: NotificationResponse(notificationResponseType:
        NotificationResponseType.selectedNotification, payload: 'sleep'));
    final destination = service.destinations.stream.first;
    await service.initialize();
    expect(await destination, 'sleep');
  });
  test('initialization failure can be retried', () async {
    plugin.failInit = true;
    await expectLater(service.restore(null), throwsA(isA<PlatformException>()));
    plugin.failInit = false;
    await service.restore(null);
    expect(plugin.cancelled, 1);
  });
}

class RecordingNotifications implements FlutterLocalNotificationsPlugin {
  final scheduled = <int>[];
  int cancelled = 0;
  bool failInit = false;
  NotificationAppLaunchDetails? launch;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #initialize:
        return failInit ? Future<bool?>.error(PlatformException(code: 'unavailable')) : Future<bool?>.value(true);
      case #getNotificationAppLaunchDetails:
        return Future<NotificationAppLaunchDetails?>.value(launch);
      case #resolvePlatformSpecificImplementation:
        return null;
      case #cancelAll:
        cancelled++;
      case #zonedSchedule:
        scheduled.add(invocation.namedArguments[#id]! as int);
    }
    return Future<void>.value();
  }
}
