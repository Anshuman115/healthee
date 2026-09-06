import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'appearance_preferences.g.dart';

/// One injectable persistence boundary for phone appearance, containing no health data.
class AppearancePreferences {
  AppearancePreferences(this.preferences);
  final SharedPreferencesAsync preferences;
  Future<String?> read(String key) => preferences.getString(key);
  Future<void> write(String key, String value) =>
      preferences.setString(key, value);
}

@Riverpod(keepAlive: true)
AppearancePreferences appearancePreferences(Ref ref) =>
    AppearancePreferences(SharedPreferencesAsync());

@Riverpod(keepAlive: true)
class AppearanceError extends _$AppearanceError {
  @override
  String? build() => null;
  void report(String? value) => state = value;
}
