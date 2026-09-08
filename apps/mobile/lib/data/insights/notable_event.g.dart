// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notable_event.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notableEvents)
final notableEventsProvider = NotableEventsProvider._();

final class NotableEventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ServerSnapshot<List<NotableEvent>>>,
          ServerSnapshot<List<NotableEvent>>,
          Stream<ServerSnapshot<List<NotableEvent>>>
        >
    with
        $FutureModifier<ServerSnapshot<List<NotableEvent>>>,
        $StreamProvider<ServerSnapshot<List<NotableEvent>>> {
  NotableEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notableEventsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notableEventsHash();

  @$internal
  @override
  $StreamProviderElement<ServerSnapshot<List<NotableEvent>>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ServerSnapshot<List<NotableEvent>>> create(Ref ref) {
    return notableEvents(ref);
  }
}

String _$notableEventsHash() => r'e45fb7a16c1e1404be1418973cc8991fbddc1c75';
