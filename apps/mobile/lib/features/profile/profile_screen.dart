import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/profile/health_profile.dart';
import 'package:healthee/data/profile/profile_repository.dart';
import 'package:healthee/features/profile/widgets/profile_editor.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/current_account_value.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Profile')),
    body: Padding(
      padding: const EdgeInsets.all(Insets.lg),
      child: AsyncView<ProfileRepository>(
        value: currentAccountValue(ref.watch(profileRepositoryProvider)),
        onRetry: () => ref.invalidate(profileRepositoryProvider),
        builder: (context, repository) => AsyncView<HealthProfile>(
          value: currentAccountValue(ref.watch(healthProfileProvider)),
          onRetry: () => ref.invalidate(healthProfileProvider),
          builder: (context, profile) => ProfileEditor(
            key: ObjectKey(repository),
            repository: repository,
            profile: profile,
          ),
        ),
      ),
    ),
  );
}
