// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notify_completions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notifyCompletions)
final notifyCompletionsProvider = NotifyCompletionsFamily._();

final class NotifyCompletionsProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  NotifyCompletionsProvider._({
    required NotifyCompletionsFamily super.from,
    required bool super.argument,
  }) : super(
         retry: null,
         name: r'notifyCompletionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$notifyCompletionsHash();

  @override
  String toString() {
    return r'notifyCompletionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as bool;
    return notifyCompletions(ref, background: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NotifyCompletionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$notifyCompletionsHash() => r'a00d9dca49519407581fdcf419f3290bad74ab77';

final class NotifyCompletionsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, bool> {
  NotifyCompletionsFamily._()
    : super(
        retry: null,
        name: r'notifyCompletionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NotifyCompletionsProvider call({bool background = false}) =>
      NotifyCompletionsProvider._(argument: background, from: this);

  @override
  String toString() => r'notifyCompletionsProvider';
}
