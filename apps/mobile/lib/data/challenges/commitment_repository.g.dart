// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commitment_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(commitmentRepository)
final commitmentRepositoryProvider = CommitmentRepositoryProvider._();

final class CommitmentRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<CommitmentRepository>,
          CommitmentRepository,
          FutureOr<CommitmentRepository>
        >
    with
        $FutureModifier<CommitmentRepository>,
        $FutureProvider<CommitmentRepository> {
  CommitmentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commitmentRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commitmentRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<CommitmentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CommitmentRepository> create(Ref ref) {
    return commitmentRepository(ref);
  }
}

String _$commitmentRepositoryHash() =>
    r'439fe24f80a3abdb9f56eec272e2b56bf7e70e88';

@ProviderFor(challengeFeed)
final challengeFeedProvider = ChallengeFeedProvider._();

final class ChallengeFeedProvider
    extends
        $FunctionalProvider<
          AsyncValue<ServerSnapshot<ChallengeFeed>>,
          ServerSnapshot<ChallengeFeed>,
          Stream<ServerSnapshot<ChallengeFeed>>
        >
    with
        $FutureModifier<ServerSnapshot<ChallengeFeed>>,
        $StreamProvider<ServerSnapshot<ChallengeFeed>> {
  ChallengeFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'challengeFeedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$challengeFeedHash();

  @$internal
  @override
  $StreamProviderElement<ServerSnapshot<ChallengeFeed>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ServerSnapshot<ChallengeFeed>> create(Ref ref) {
    return challengeFeed(ref);
  }
}

String _$challengeFeedHash() => r'33bd4bcad827e6f6c2375290e45d24f7fce2eaa6';

@ProviderFor(programFeed)
final programFeedProvider = ProgramFeedProvider._();

final class ProgramFeedProvider
    extends
        $FunctionalProvider<
          AsyncValue<ServerSnapshot<ProgramFeed>>,
          ServerSnapshot<ProgramFeed>,
          Stream<ServerSnapshot<ProgramFeed>>
        >
    with
        $FutureModifier<ServerSnapshot<ProgramFeed>>,
        $StreamProvider<ServerSnapshot<ProgramFeed>> {
  ProgramFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'programFeedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$programFeedHash();

  @$internal
  @override
  $StreamProviderElement<ServerSnapshot<ProgramFeed>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ServerSnapshot<ProgramFeed>> create(Ref ref) {
    return programFeed(ref);
  }
}

String _$programFeedHash() => r'decdcd094367358ff815f189db5a5a4c915bd30d';

@ProviderFor(challengeOutcomes)
final challengeOutcomesProvider = ChallengeOutcomesProvider._();

final class ChallengeOutcomesProvider
    extends
        $FunctionalProvider<
          AsyncValue<ServerSnapshot<List<ChallengeOutcome>>>,
          ServerSnapshot<List<ChallengeOutcome>>,
          Stream<ServerSnapshot<List<ChallengeOutcome>>>
        >
    with
        $FutureModifier<ServerSnapshot<List<ChallengeOutcome>>>,
        $StreamProvider<ServerSnapshot<List<ChallengeOutcome>>> {
  ChallengeOutcomesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'challengeOutcomesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$challengeOutcomesHash();

  @$internal
  @override
  $StreamProviderElement<ServerSnapshot<List<ChallengeOutcome>>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ServerSnapshot<List<ChallengeOutcome>>> create(Ref ref) {
    return challengeOutcomes(ref);
  }
}

String _$challengeOutcomesHash() => r'1cb2bea21c81f19b9f3e6aa6adaca3762d8b65a8';
