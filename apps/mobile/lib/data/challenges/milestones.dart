import 'package:healthee/data/api/account_identity.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/data/challenges/completion_ledger.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'milestones.g.dart';

@Riverpod(keepAlive: true)
Future<List<Challenge>> milestones(Ref ref) async {
  final repository = await ref.watch(commitmentRepositoryProvider.future);
  final value = ref.watch(challengeFeedProvider);
  if (value.isLoading || value.hasError || value.value?.stale != false) {
    return [];
  }
  final feed = value.value!.data;
  final identity = await ref.watch(accountIdentityProvider.future);
  final ledger = CompletionLedger(
    ref.watch(localStoreProvider),
    identity.storageScope,
  );
  await repository.api.ensureCurrent();
  final fresh = await ledger.takeNew(feed.recent);
  await repository.api.ensureCurrent();
  return fresh;
}
