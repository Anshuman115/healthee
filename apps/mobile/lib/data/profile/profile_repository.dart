import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/profile/health_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_repository.g.dart';

/// An account-bound profile form's reads and explicit changes.
class ProfileRepository {
  const ProfileRepository(this.api);
  final AccountApi api;

  Future<HealthProfile> load() async =>
      HealthProfile.fromJson(await api.get('/api/profile'));

  Future<void> save({
    required String name,
    required double? heightCm,
    required String? sex,
    String? dobDate,
    int? srpa,
    bool updateSrpa = false,
    double? measuredWeightKg,
  }) async {
    final result = await api.request(
      '/api/profile',
      method: 'PATCH',
      body: {
        'name': name.trim(), 'height_cm': heightCm, 'sex': sex,
        // An untouched legacy birthday must not be erased during a name edit.
        'dob_date': ?dobDate,
        if (updateSrpa) 'srpa': srpa,
        'measured_weight_kg': ?measuredWeightKg,
      },
    );
    if (result['ok'] != true) {
      throw const FormatException('Profile was not saved');
    }
  }
}

@riverpod
Future<ProfileRepository> profileRepository(Ref ref) async =>
    ProfileRepository(await ref.watch(accountApiProvider.future));

@riverpod
Future<HealthProfile> healthProfile(Ref ref) async =>
    (await ref.watch(profileRepositoryProvider.future)).load();
