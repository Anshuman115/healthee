import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/background/background_store.dart';
import 'package:healthee/data/notifications/notification_service.dart';
import 'package:healthee/data/notifications/reminder_preferences.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_providers.g.dart';

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  final service = NotificationService(
    FlutterLocalNotificationsPlugin(),
    BackgroundStore(ref.watch(localStoreProvider)),
  );
  ref.onDispose(service.destinations.close);
  return service;
}

@riverpod
Stream<String> notificationDestination(Ref ref) =>
    ref.watch(notificationServiceProvider).destinations.stream;

@riverpod
Future<void> notificationLifecycle(Ref ref) async {
  final service = ref.watch(notificationServiceProvider);
  await ref.watch(serverSessionProvider.future);
  final session = await ref.watch(credentialsProvider).serverSession();
  await service.restore(session?.cacheScope);
}

@riverpod
Future<ReminderPreferences> reminderPreferences(Ref ref) =>
    ref.watch(notificationServiceProvider).preferences();
