import 'package:healthee/data/api/account_identity.dart';
import 'package:healthee/data/challenges/challenge_feed.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/data/challenges/completion_ledger.dart';
import 'package:healthee/data/notifications/notification_providers.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notify_completions.g.dart';

@riverpod
Future<void> notifyCompletions(Ref ref, {bool background = false}) async {
  final service = ref.watch(notificationServiceProvider);
  final preferences = await service.preferences();
  if (!preferences.completions) return;
  final repository = await ref.watch(commitmentRepositoryProvider.future);
  if (preferences.scope != repository.api.sessionScope) return;
  final identity = await ref.watch(accountIdentityProvider.future);
  final ChallengeFeed feed;
  if (background) {
    feed = await repository.challenges();
  } else {
    final value = ref.watch(challengeFeedProvider);
    if (value.isLoading || value.hasError || value.value?.stale != false) {
      return;
    }
    feed = value.value!.data;
  }
  final ledger = CompletionLedger(
    ref.watch(localStoreProvider),
    identity.storageScope,
    channel: 'notify',
  );
  await repository.api.ensureCurrent();
  final fresh = await ledger.takeNew(feed.recent, acknowledge: false);
  for (final challenge in fresh) {
    await service.completion(challenge.id, repository.api);
    await ledger.takeNew([challenge]);
  }
}
