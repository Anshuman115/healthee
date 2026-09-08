// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(journalRepository)
final journalRepositoryProvider = JournalRepositoryProvider._();

final class JournalRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<JournalRepository>,
          JournalRepository,
          FutureOr<JournalRepository>
        >
    with
        $FutureModifier<JournalRepository>,
        $FutureProvider<JournalRepository> {
  JournalRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<JournalRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<JournalRepository> create(Ref ref) {
    return journalRepository(ref);
  }
}

String _$journalRepositoryHash() => r'5a9345c257db64010710088b3b722cc71be5f237';

@ProviderFor(journalFeed)
final journalFeedProvider = JournalFeedProvider._();

final class JournalFeedProvider
    extends
        $FunctionalProvider<
          AsyncValue<ServerSnapshot<JournalFeed>>,
          ServerSnapshot<JournalFeed>,
          Stream<ServerSnapshot<JournalFeed>>
        >
    with
        $FutureModifier<ServerSnapshot<JournalFeed>>,
        $StreamProvider<ServerSnapshot<JournalFeed>> {
  JournalFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalFeedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalFeedHash();

  @$internal
  @override
  $StreamProviderElement<ServerSnapshot<JournalFeed>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ServerSnapshot<JournalFeed>> create(Ref ref) {
    return journalFeed(ref);
  }
}

String _$journalFeedHash() => r'8a7f69fc680769524300c81f5d0f9b49ea346cd5';
