import 'package:healthee/core/env.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/api/cached_account_read.dart';
import 'package:healthee/data/api/server_snapshot.dart';
import 'package:healthee/data/challenges/challenge_feed.dart';
import 'package:healthee/data/challenges/challenge_outcome.dart';
import 'package:healthee/data/challenges/program_feed.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'commitment_repository.g.dart';

class CommitmentRepository {
  const CommitmentRepository(this.api);
  final AccountApi api;
  Future<ChallengeFeed> challenges() async =>
      ChallengeFeed.fromJson(await api.get('/api/challenges'));
  Future<ProgramFeed> programs() async =>
      ProgramFeed.fromJson(await api.get('/api/programs'));
  Future<List<ChallengeOutcome>> outcomes() async {
    final data = await api.get(
      '/api/challenges/outcomes',
      query: {'limit': 20},
    );
    return [
      for (final row in data['outcomes']! as List<Object?>)
        ChallengeOutcome.fromJson(row! as Map<String, Object?>),
    ];
  }

  Future<void> challengeAction(int id, String action) {
    if (!const ['adopt', 'abandon', 'adapt'].contains(action)) {
      throw ArgumentError.value(action);
    }
    return _post('/api/challenges/$id/$action');
  }

  Future<void> programAction(int id, String action) {
    if (!const ['adopt', 'abandon'].contains(action)) {
      throw ArgumentError.value(action);
    }
    return _post('/api/programs/$id/$action');
  }

  Future<void> generateChallenges() => _post('/api/challenges/generate');
  Future<void> generateProgram() => _post('/api/programs/generate');
  Future<void> _post(String path) async {
    final result = await api.request(
      path,
      method: 'POST',
      timeout: Env.pushTimeout,
    );
    if (result['ok'] == false) {
      throw const FormatException('Server declined the action');
    }
  }
}

@riverpod
Future<CommitmentRepository> commitmentRepository(Ref ref) async =>
    CommitmentRepository(await ref.watch(accountApiProvider.future));
@riverpod
Stream<ServerSnapshot<ChallengeFeed>> challengeFeed(Ref ref) async* {
  final repository = await ref.watch(commitmentRepositoryProvider.future);
  yield* cachedAccountRead(
    api: repository.api,
    store: ref.watch(localStoreProvider),
    path: '/api/challenges',
    key: 'challenge_feed',
    parse: ChallengeFeed.fromJson,
  );
}

@riverpod
Stream<ServerSnapshot<ProgramFeed>> programFeed(Ref ref) async* {
  final repository = await ref.watch(commitmentRepositoryProvider.future);
  yield* cachedAccountRead(
    api: repository.api,
    store: ref.watch(localStoreProvider),
    path: '/api/programs',
    key: 'program_feed',
    parse: ProgramFeed.fromJson,
  );
}

@riverpod
Stream<ServerSnapshot<List<ChallengeOutcome>>> challengeOutcomes(
  Ref ref,
) async* {
  final repository = await ref.watch(commitmentRepositoryProvider.future);
  yield* cachedAccountRead(
    api: repository.api,
    store: ref.watch(localStoreProvider),
    path: '/api/challenges/outcomes',
    key: 'challenge_outcomes',
    parse: (data) => [
      for (final row in data['outcomes']! as List<Object?>)
        ChallengeOutcome.fromJson(row! as Map<String, Object?>),
    ],
  );
}
