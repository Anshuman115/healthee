// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insight_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The target is a metric id or a workout start instant for those two scopes.

@ProviderFor(generatedInsight)
final generatedInsightProvider = GeneratedInsightFamily._();

/// The target is a metric id or a workout start instant for those two scopes.

final class GeneratedInsightProvider
    extends
        $FunctionalProvider<
          AsyncValue<GeneratedInsight>,
          GeneratedInsight,
          FutureOr<GeneratedInsight>
        >
    with $FutureModifier<GeneratedInsight>, $FutureProvider<GeneratedInsight> {
  /// The target is a metric id or a workout start instant for those two scopes.
  GeneratedInsightProvider._({
    required GeneratedInsightFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'generatedInsightProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$generatedInsightHash();

  @override
  String toString() {
    return r'generatedInsightProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<GeneratedInsight> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GeneratedInsight> create(Ref ref) {
    final argument = this.argument as (String, String);
    return generatedInsight(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is GeneratedInsightProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$generatedInsightHash() => r'cd64d4b542ebcd9c0455447ec11574dfa72704f5';

/// The target is a metric id or a workout start instant for those two scopes.

final class GeneratedInsightFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<GeneratedInsight>,
          (String, String)
        > {
  GeneratedInsightFamily._()
    : super(
        retry: null,
        name: r'generatedInsightProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The target is a metric id or a workout start instant for those two scopes.

  GeneratedInsightProvider call(String scope, String target) =>
      GeneratedInsightProvider._(argument: (scope, target), from: this);

  @override
  String toString() => r'generatedInsightProvider';
}
