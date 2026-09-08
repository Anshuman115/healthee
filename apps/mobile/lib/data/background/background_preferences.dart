import 'dart:convert';

class BackgroundPreferences {
  factory BackgroundPreferences.decode(String? raw) {
    if (raw == null) return const BackgroundPreferences();
    final data = jsonDecode(raw) as Map<String, Object?>;
    final pull = data['pull']! as int;
    final push = data['push']! as int;
    if (!pullOptions.contains(pull) || !pushOptions.contains(push)) {
      throw const FormatException('Invalid background intervals');
    }
    return BackgroundPreferences(
      enabled: data['enabled']! as bool,
      pullMinutes: pull,
      pushMinutes: push,
      wifiOnly: data['wifi']! as bool,
      chargingOnly: data['charging']! as bool,
    );
  }
  const BackgroundPreferences({
    this.enabled = false,
    this.pullMinutes = 30,
    this.pushMinutes = 60,
    this.wifiOnly = false,
    this.chargingOnly = false,
  });
  final bool enabled;
  final int pullMinutes;
  final int pushMinutes;
  final bool wifiOnly;
  final bool chargingOnly;
  static const pullOptions = [15, 30, 60, 180];
  static const pushOptions = [30, 60, 360];
  String encode() => jsonEncode({
    'enabled': enabled,
    'pull': pullMinutes,
    'push': pushMinutes,
    'wifi': wifiOnly,
    'charging': chargingOnly,
  });
}
