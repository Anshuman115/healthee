import 'dart:convert';

/// Times are local clock minutes, chosen by the owner rather than health targets.
class ReminderPreferences {
  factory ReminderPreferences.decode(String? raw) {
    if (raw == null) return const ReminderPreferences();
    final data = jsonDecode(raw) as Map<String, Object?>;
    final daily = data['daily_minute']! as int;
    final bed = data['bedtime_minute']! as int;
    if (daily < 0 || daily >= 1440 || bed < 0 || bed >= 1440) {
      throw const FormatException('Invalid reminder time');
    }
    return ReminderPreferences(
      scope: data['scope']! as String,
      daily: data['daily']! as bool,
      bedtime: data['bedtime']! as bool,
      completions: data['completions']! as bool,
      dailyMinute: daily,
      bedtimeMinute: bed,
    );
  }
  const ReminderPreferences({
    this.scope = '',
    this.daily = false,
    this.bedtime = false,
    this.completions = false,
    this.dailyMinute = 540,
    this.bedtimeMinute = 1350,
  });
  final String scope;
  final bool daily;
  final bool bedtime;
  final bool completions;
  final int dailyMinute;
  final int bedtimeMinute;
  String encode() => jsonEncode({
    'scope': scope,
    'daily': daily,
    'bedtime': bedtime,
    'completions': completions,
    'daily_minute': dailyMinute,
    'bedtime_minute': bedtimeMinute,
  });
}
