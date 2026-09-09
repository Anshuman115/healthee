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

  /// Asks for a fresh challenge feed. Returns what the run actually produced.
  Future<GenerationOutcome> generateChallenges() =>
      _generate('/api/challenges/generate');

  /// Designs one ladder. Returns what the run actually produced.
  Future<GenerationOutcome> generateProgram() =>
      _generate('/api/programs/generate');

  /// A generation run, and what came back.
  ///
  /// **The reasons were being thrown away.** `_post` read `ok` and returned
  /// void, so a run that the shape gates rejected — a `200` carrying
  /// `generated: 0` and a `rejected` list — was indistinguishable from one that
  /// worked. The server's own docstring is explicit that these *"are different
  /// answers"*, and on the owner's device the difference was a button that
  /// appeared to do nothing, twice, with the explanation sitting in the
  /// response the client dropped.
  Future<GenerationOutcome> _generate(String path) async {
    final result = await api.request(
      path,
      method: 'POST',
      timeout: Env.pushTimeout,
    );
    if (result['ok'] == false) {
      throw const FormatException('Server declined the action');
    }
    return GenerationOutcome(
      generated: (result['generated'] as num?)?.toInt() ?? 0,
      rejected: <String>[
        for (final entry in (result['rejected'] as List? ?? const <Object?>[]))
          if (entry is String) entry,
      ],
    );
  }

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

/// What one generation run produced, and why it produced nothing when it did.
class GenerationOutcome {
  /// Builds an outcome.
  const GenerationOutcome({required this.generated, required this.rejected});

  /// How many challenges or ladders were stored. Zero is a real answer.
  final int generated;

  /// The gates' own words for what it threw out — server-written, quotable.
  final List<String> rejected;

  /// Whether the run stored nothing.
  bool get producedNothing => generated <= 0;
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
