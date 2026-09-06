import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/notifications/notification_service.dart';
import 'package:healthee/data/notifications/reminder_preferences.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(data.initializeTimeZones);
  test('tomorrow uses a calendar date across daylight-saving transition', () {
    final zone = tz.getLocation('America/New_York');
    final now = tz.TZDateTime(zone, 2026, 3, 7, 23);
    final next = NotificationService.nextLocalTime(now, 9 * 60);
    expect(next.day, 8);
    expect(next.hour, 9);
    expect(next.timeZoneOffset, const Duration(hours: -4));
  });
  test(
    'reminders default off; chosen times and account survive serialization',
    () {
      expect(ReminderPreferences.decode(null).daily, isFalse);
      const prefs = ReminderPreferences(
        scope: 'owner',
        daily: true,
        dailyMinute: 601,
      );
      final restored = ReminderPreferences.decode(prefs.encode());
      expect(restored.scope, 'owner');
      expect(restored.dailyMinute, 601);
      expect(restored.bedtime, isFalse);
    },
  );
}
